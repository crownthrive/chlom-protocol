import { createClient } from "npm:@supabase/supabase-js@2";

const cors = {
  "access-control-allow-origin": "*",
  "access-control-allow-methods": "GET, HEAD, OPTIONS",
  "access-control-allow-headers":
    "authorization, x-client-info, apikey, content-type",
  "cache-control": "no-store",
  "x-content-type-options": "nosniff",
};

type JsonObject = Record<string, unknown>;

const asObject = (value: unknown): JsonObject | null =>
  value !== null && typeof value === "object" && !Array.isArray(value)
    ? value as JsonObject
    : null;

const asNonNegativeInteger = (value: unknown): number | null =>
  typeof value === "number" && Number.isSafeInteger(value) && value >= 0
    ? value
    : null;

const degraded = () =>
  new Response(
    JSON.stringify({
      contract: "ct.chlom.mesh.status.v1",
      service: "ct.chlom.mesh.status.v1",
      status: "degraded",
      decision: "HOLD",
      error_code: "DEPENDENCY_UNAVAILABLE",
      public_surface: true,
      secret_values_exposed: false,
    }),
    {
      status: 503,
      headers: { ...cors, "content-type": "application/json; charset=utf-8" },
    },
  );

Deno.serve(async (request) => {
  if (request.method === "OPTIONS") {
    return new Response("ok", { headers: cors });
  }

  if (request.method !== "GET" && request.method !== "HEAD") {
    return new Response(
      JSON.stringify({
        service: "ct.chlom.mesh.status.v1",
        status: "denied",
        decision: "DENY",
        reason: "read_only_endpoint",
      }),
      {
        status: 405,
        headers: { ...cors, "content-type": "application/json" },
      },
    );
  }

  const url = Deno.env.get("SUPABASE_URL");
  // The function is a public, parameter-free read surface, but its database
  // wrapper stays service-role-only. Never forward this credential or accept a
  // caller-selected RPC name/argument.
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!url || !serviceRoleKey) {
    return degraded();
  }

  const client = createClient(url, serviceRoleKey, {
    auth: { persistSession: false },
  });
  const { data, error } = await client.rpc("chlom_mesh_public_status_v1");
  if (error) {
    return degraded();
  }

  // Treat the service-role RPC response as untrusted input. Publish only this
  // fixed aggregate allowlist; never spread database fields onto the public
  // response or expose binding/source/vault/authority references.
  const source = asObject(data);
  const sourceControl = asObject(source?.control_plane);
  const sourceSummary = asObject(source?.binding_summary);
  const sourceHeartbeat = asObject(source?.latest_heartbeat);
  const total = asNonNegativeInteger(sourceSummary?.total);
  const bound = asNonNegativeInteger(sourceSummary?.bound);
  const hold = asNonNegativeInteger(sourceSummary?.hold);
  const degradedCount = asNonNegativeInteger(sourceSummary?.degraded);
  const heartbeatHold = asNonNegativeInteger(sourceHeartbeat?.hold_count);
  const heartbeatDegraded = asNonNegativeInteger(
    sourceHeartbeat?.degraded_count,
  );

  const healthy =
    source !== null &&
    sourceControl?.operating_state === "production_hot" &&
    sourceControl?.fail_closed === true &&
    sourceControl?.no_secret_exposure === true &&
    total !== null && total > 0 &&
    bound === total &&
    hold === 0 &&
    degradedCount === 0 &&
    sourceHeartbeat?.state === "hot" &&
    heartbeatHold === 0 &&
    heartbeatDegraded === 0;

  if (!healthy) {
    return degraded();
  }

  const body = {
    contract: "ct.chlom.mesh.status.v1",
    service: "ct.chlom.mesh.status.v1",
    status: "ok",
    decision: "ALLOW",
    control_plane: {
      operating_state: "production_hot",
      fail_closed: true,
      no_secret_exposure: true,
    },
    binding_summary: {
      total,
      bound,
      hold,
      degraded: degradedCount,
    },
    latest_heartbeat: {
      state: "hot",
      hold_count: heartbeatHold,
      degraded_count: heartbeatDegraded,
    },
    public_surface: true,
    secret_values_exposed: false,
  };

  if (request.method === "HEAD") {
    return new Response(null, { status: 200, headers: cors });
  }

  return new Response(JSON.stringify(body), {
    status: 200,
    headers: { ...cors, "content-type": "application/json; charset=utf-8" },
  });
});
