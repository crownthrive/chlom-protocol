import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";

const headers = {
  "content-type": "application/json; charset=utf-8",
  "cache-control": "no-store",
  "x-ct-runtime": "PentaFederation",
};

const reply = (status: number, body: unknown) =>
  new Response(JSON.stringify(body), { status, headers });

Deno.serve(async (req: Request) => {
  const supabase = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    { auth: { persistSession: false, autoRefreshToken: false } },
  );

  const status = async () => {
    const { data, error } = await supabase
      .schema("penta_runtime")
      .rpc("penta_federation_status_v1");
    if (error) throw new Error(error.message);
    return data;
  };

  try {
    if (req.method === "GET") {
      return reply(200, {
        ok: true,
        service: "ct.penta.federation.control.v1",
        name: "PentaFederation",
        version: "1.0.0",
        parent: "CrownThrive Federation",
        mode: "bounded",
        data: await status(),
      });
    }

    if (req.method !== "POST") {
      return reply(405, { ok: false, error: "method_not_allowed" });
    }

    const body = await req.json().catch(() => ({}));
    const action = String(body?.action ?? "status");

    if (action === "status") {
      return reply(200, { ok: true, action, data: await status() });
    }

    if (action === "member_state") {
      const repoId = String(body?.repo_id ?? "").trim();
      if (!repoId) {
        return reply(400, { ok: false, error: "repo_id_required" });
      }
      const { data, error } = await supabase
        .schema("penta_runtime")
        .rpc("penta_federation_member_state_v1", { p_repo_id: repoId });
      if (error) return reply(500, { ok: false, error: error.message });
      return reply(200, { ok: true, action, data });
    }

    if (action === "route_plan") {
      const repoId = String(body?.repo_id ?? "").trim();
      const agentId = String(body?.agent_id ?? "").trim();
      const operation = String(body?.operation ?? "").trim();
      if (!repoId || !agentId || !operation) {
        return reply(400, {
          ok: false,
          error: "repo_id_agent_id_operation_required",
        });
      }
      const { data, error } = await supabase
        .schema("penta_runtime")
        .rpc("penta_federation_route_plan_v1", {
          p_repo_id: repoId,
          p_agent_id: agentId,
          p_operation: operation,
          p_authority_key: body?.authority_key ?? null,
        });
      if (error) return reply(500, { ok: false, error: error.message });
      return reply(200, { ok: true, action, executed: false, data });
    }

    return reply(400, {
      ok: false,
      error: "unsupported_action",
      supported: ["status", "member_state", "route_plan"],
      guardrail:
        "No provider write, money movement, rights grant, certification execution, child voting activation, or D3 activation is exposed by this facade.",
    });
  } catch (error) {
    return reply(500, {
      ok: false,
      error: error instanceof Error ? error.message : "internal_error",
    });
  }
});
