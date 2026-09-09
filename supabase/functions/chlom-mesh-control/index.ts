const cors = {
  "access-control-allow-origin": "*",
  "access-control-allow-headers":
    "authorization, x-client-info, apikey, content-type",
  "cache-control": "no-store",
};

function json(body: Record<string, unknown>, status: number): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...cors, "content-type": "application/json; charset=utf-8" },
  });
}

Deno.serve(async (request) => {
  if (request.method === "OPTIONS") {
    return new Response("ok", { headers: cors });
  }

  if (request.method !== "POST") {
    return json({
      status: "denied",
      decision: "DENY",
      error_code: "METHOD_NOT_ALLOWED",
    }, 405);
  }

  const authorization = request.headers.get("authorization") || "";
  if (!authorization) {
    return json({
      status: "denied",
      decision: "DENY",
      error_code: "AUTH_REQUIRED",
    }, 401);
  }

  // Fail closed before any database call. The legacy v1 RPC does not bind its
  // global idempotency key to the authenticated actor or request digest, and
  // there is no accepted principal-to-action/target authority lease for this
  // public route. Authentication alone must never manufacture CHLOM authority.
  return json({
    service: "ct.chlom.mesh.control.v2",
    status: "held",
    decision: "HOLD",
    error_code: "CONTROL_AUTHORITY_AND_IDEMPOTENCY_GATE_REQUIRED",
    execution_effect: "NONE",
  }, 503);
});
