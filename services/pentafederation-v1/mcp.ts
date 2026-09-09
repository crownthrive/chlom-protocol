import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";

const PROTOCOL = "2026-07-28";
const headers = {
  "content-type": "application/json; charset=utf-8",
  "cache-control": "no-store",
  "MCP-Protocol-Version": PROTOCOL,
  "x-ct-runtime": "PentaFederation",
};

const json = (status: number, body: unknown) =>
  new Response(JSON.stringify(body), { status, headers });
const result = (id: unknown, value: unknown) =>
  json(200, { jsonrpc: "2.0", id, result: value });
const rpcError = (
  id: unknown,
  code: number,
  message: string,
  data?: unknown,
) =>
  json(200, {
    jsonrpc: "2.0",
    id,
    error: { code, message, ...(data === undefined ? {} : { data }) },
  });

Deno.serve(async (req: Request) => {
  if (req.method !== "POST") {
    return json(405, { error: "method_not_allowed" });
  }
  if (req.headers.get("MCP-Protocol-Version") !== PROTOCOL) {
    return json(400, {
      error: "unsupported_protocol_version",
      expected: PROTOCOL,
    });
  }

  const envelope = await req.json().catch(() => null);
  if (
    !envelope || envelope.jsonrpc !== "2.0" ||
    typeof envelope.method !== "string"
  ) {
    return rpcError(envelope?.id ?? null, -32600, "Invalid Request");
  }

  const id = envelope.id ?? null;
  const supabase = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    { auth: { persistSession: false, autoRefreshToken: false } },
  );

  if (envelope.method === "server/discover") {
    return result(id, {
      name: "CrownThrive PentaFederation MCP",
      version: "1.0.0",
      protocolVersion: PROTOCOL,
      stateless: true,
      parent: "CrownThrive Federation",
      governance: {
        authorityCeiling: "A2/D2",
        d3HumanReserved: true,
        selfApproval: false,
        providerWriteInherited: false,
        moneyMovementInherited: false,
        rightsGrantInherited: false,
        failClosed: true,
      },
    });
  }

  if (envelope.method === "tools/list") {
    return result(id, {
      tools: [
        {
          name: "penta_federation_status",
          description:
            "Read PentaFederation and canonical repository-federation status.",
          inputSchema: {
            type: "object",
            properties: {},
            additionalProperties: false,
          },
        },
        {
          name: "penta_federation_member_state",
          description:
            "Read the governed state and bounded agent capability inventory for one registered federation repository.",
          inputSchema: {
            type: "object",
            required: ["repo_id"],
            properties: { repo_id: { type: "string" } },
            additionalProperties: false,
          },
        },
        {
          name: "penta_federation_route_plan",
          description:
            "Evaluate whether a bounded federation route is currently permitted. This does not execute a write or create authority.",
          inputSchema: {
            type: "object",
            required: ["repo_id", "agent_id", "operation"],
            properties: {
              repo_id: { type: "string" },
              agent_id: { type: "string" },
              operation: {
                type: "string",
                enum: [
                  "status",
                  "bootstrap",
                  "heartbeat",
                  "publish",
                  "pull",
                  "ack",
                  "reference",
                  "algorithm",
                  "certify",
                  "sync_agents",
                ],
              },
              authority_key: { type: ["string", "null"] },
            },
            additionalProperties: false,
          },
        },
      ],
    });
  }

  if (envelope.method !== "tools/call") {
    return rpcError(id, -32601, "Method not found");
  }

  const name = String(envelope.params?.name ?? "");
  const args = envelope.params?.arguments ?? {};

  if (name === "penta_federation_status") {
    const { data, error } = await supabase
      .schema("penta_runtime")
      .rpc("penta_federation_status_v1");
    if (error) {
      return rpcError(id, -32000, "Federation status failed", error.message);
    }
    return result(id, {
      content: [{ type: "text", text: JSON.stringify(data) }],
      structuredContent: data,
      isError: false,
    });
  }

  if (name === "penta_federation_member_state") {
    const repoId = String(args?.repo_id ?? "").trim();
    if (!repoId) return rpcError(id, -32602, "repo_id is required");
    const { data, error } = await supabase
      .schema("penta_runtime")
      .rpc("penta_federation_member_state_v1", { p_repo_id: repoId });
    if (error) {
      return rpcError(id, -32000, "Member state failed", error.message);
    }
    return result(id, {
      content: [{ type: "text", text: JSON.stringify(data) }],
      structuredContent: data,
      isError: false,
    });
  }

  if (name === "penta_federation_route_plan") {
    const repoId = String(args?.repo_id ?? "").trim();
    const agentId = String(args?.agent_id ?? "").trim();
    const operation = String(args?.operation ?? "").trim();
    if (!repoId || !agentId || !operation) {
      return rpcError(
        id,
        -32602,
        "repo_id, agent_id, and operation are required",
      );
    }
    const { data, error } = await supabase
      .schema("penta_runtime")
      .rpc("penta_federation_route_plan_v1", {
        p_repo_id: repoId,
        p_agent_id: agentId,
        p_operation: operation,
        p_authority_key: args?.authority_key ?? null,
      });
    if (error) {
      return rpcError(id, -32000, "Route evaluation failed", error.message);
    }
    return result(id, {
      content: [{ type: "text", text: JSON.stringify(data) }],
      structuredContent: data,
      isError: false,
    });
  }

  return rpcError(id, -32601, "Unknown tool", { name });
});
