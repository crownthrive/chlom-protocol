import "jsr:@supabase/functions-js/edge-runtime.d.ts";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SERVICE_ROLE = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";

const SERVER = {
  name: "PentaRoute Autonomy",
  service: "ct.pentaroute.autonomy.v3",
  phase: 3,
  contract: "v3",
};

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      "content-type": "application/json; charset=utf-8",
      "cache-control": "no-store",
      "x-content-type-options": "nosniff",
    },
  });
}

function jwtRole(req: Request) {
  const raw = req.headers.get("authorization") ?? "";
  const token = raw.replace(/^Bearer\s+/i, "");
  const payload = token.split(".")[1];
  if (!payload) return "";

  try {
    const normalized = payload.replace(/-/g, "+").replace(/_/g, "/");
    const padded = normalized + "=".repeat((4 - (normalized.length % 4)) % 4);
    const parsed = JSON.parse(atob(padded));
    return String(parsed.role ?? "");
  } catch {
    return "";
  }
}

async function rpc(name: string) {
  const response = await fetch(`${SUPABASE_URL}/rest/v1/rpc/${name}`, {
    method: "POST",
    headers: {
      apikey: SERVICE_ROLE,
      authorization: `Bearer ${SERVICE_ROLE}`,
      "content-type": "application/json",
    },
    body: "{}",
  });

  const text = await response.text();
  if (!response.ok) {
    throw new Error(`${name}:${response.status}:${text.slice(0, 400)}`);
  }

  try {
    return text ? JSON.parse(text) : null;
  } catch {
    return text;
  }
}

Deno.serve(async (req: Request) => {
  try {
    if (req.method === "GET") {
      const status = await rpc("pentaroute_autonomy_status_v3");
      return json({ ok: true, server: SERVER, status });
    }

    if (req.method !== "POST") {
      return json({ ok: false, error: "method_not_allowed", server: SERVER }, 405);
    }

    if (jwtRole(req) !== "service_role") {
      return json({ ok: false, error: "service_role_required", server: SERVER }, 403);
    }

    const body = await req.json().catch(() => ({}));
    const action = String(body?.action ?? "cycle");
    if (action !== "cycle") {
      return json({ ok: false, error: "unsupported_action", server: SERVER }, 400);
    }

    const result = await rpc("pentaroute_autonomy_cycle_v3");
    return json({ ok: true, server: SERVER, result });
  } catch (error) {
    return json(
      {
        ok: false,
        server: SERVER,
        error: error instanceof Error ? error.message : "unknown_error",
        guardrails: {
          autonomy_ceiling: "A2",
          max_auto_risk: "D2",
          self_approval: false,
          d3_human_governance: true,
          universal_delete: false,
        },
      },
      503,
    );
  }
});
