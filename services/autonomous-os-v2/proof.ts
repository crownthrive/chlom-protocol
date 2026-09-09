import "jsr:@supabase/functions-js/edge-runtime.d.ts";

const U = Deno.env.get("SUPABASE_URL") ?? "";
const S = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
const SERVICE = "ct.autonomous-os.v2.proof";

function json(data: unknown, status = 200) {
  return new Response(JSON.stringify(data, null, 2), {
    status,
    headers: {
      "content-type": "application/json; charset=utf-8",
      "cache-control": "no-store",
      "access-control-allow-origin": "*",
      "x-content-type-options": "nosniff"
    }
  });
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response(null, { status: 204, headers: { "access-control-allow-origin": "*", "access-control-allow-methods": "GET,OPTIONS" } });
  if (req.method !== "GET") return json({ error: "method_not_allowed" }, 405);
  if (!U || !S) return json({ service: SERVICE, state: "DEGRADED", error: "runtime_not_configured" }, 503);
  const started = Date.now();
  try {
    const r = await fetch(`${U}/functions/v1/crownthrive-autonomous-os-v2`, {
      method: "POST",
      headers: { "content-type": "application/json", authorization: `Bearer ${S}` },
      body: JSON.stringify({ action: "test" }),
      signal: AbortSignal.timeout(15000)
    });
    const body = await r.json();
    return json({
      proof_service: SERVICE,
      proof_version: "2.0.0",
      verified_at: new Date().toISOString(),
      test_latency_ms: Date.now() - started,
      protected_runtime_http_status: r.status,
      protected_runtime_reached: r.ok,
      result: body,
      verify_yourself: {
        source: "https://github.com/crownthrive1/chlom-protocol/tree/main/services/autonomous-os-v2",
        canonical_registry: "https://github.com/crownthrive1/chlom-protocol/blob/main/registry/integrations.json",
        github_runtime_tests: "https://github.com/crownthrive1/chlom-protocol/actions/workflows/integration-runtime-certification.yml"
      }
    }, r.ok ? 200 : 502);
  } catch (e) {
    return json({ proof_service: SERVICE, state: "ERROR", error: e instanceof Error ? e.message : "proof_failed" }, 500);
  }
});
