import "jsr:@supabase/functions-js/edge-runtime.d.ts";

const SERVICE = "ct.autonomous-os.v2";
const VERSION = "2.0.0";
const U = Deno.env.get("SUPABASE_URL") ?? "";
const S = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
const REGISTRY = "https://raw.githubusercontent.com/crownthrive1/chlom-protocol/main/registry/integrations.json";

const hostedToolCatalog = [
  "GitHub","Supabase","Mintlify","Gmail","Google Calendar","Google Contacts","Google Drive",
  "Microsoft Outlook Email","Microsoft Outlook Calendar","Stripe","Vercel","Canva","Figma","Riverside",
  "CoinGecko","CoinMarketCap","Consensus","DoorDash","Etsy","GoDaddy","Jotform","Realtor.com",
  "Semrush","Spotify","Uber Eats","Zoom","OpenAI Platform"
];

const fabric = [
  "crownthrive-services-stack","chlom-api-control","chlom-vault-gateway","chlom-vault-broker",
  "chlom-github-executor-bridge","chlom-interoperability-control","crownthrive-interoperability-plugin",
  "crownthrive-continuity-compiler","crownthrive-api-control","crownthrive-io-crud-canary",
  "crownthrive-io-write-control","adluxe-api-control","stripe-production-control","stripe-institutional-webhook",
  "mailgun-relay-control","cpanel-whm-api-control","cpanel-account-api-control","locticians-api-control",
  "locticians-public-api","locticians-mcp-read","partnero-api-control","partnero-webhook-receiver",
  "crownlytics-api-control","crownpulse-admin-api-control","thrivepush-api-control","thrivetools-seo-api-control",
  "thrivetools-opt-api-control","website-surface-control","repository-federation-bus","ecosystem-rollout-control",
  "developer-marketplace-package-builder","developer-marketplace-readiness","credit-commerce-control",
  "kjv-commerce-control","virality-commerce-control","thriveevergreen-production-control","thriveevergreen-commerce-mesh",
  "thriveevergreen-storefront","thriveledger-control"
];

function json(data: unknown, status = 200) {
  return new Response(JSON.stringify(data, null, 2), {
    status,
    headers: {
      "content-type": "application/json; charset=utf-8",
      "cache-control": "no-store",
      "x-content-type-options": "nosniff"
    }
  });
}

async function probe(url: string, init: RequestInit = {}) {
  const started = Date.now();
  try {
    const r = await fetch(url, { ...init, signal: AbortSignal.timeout(8000) });
    return { reachable: true, http_status: r.status, latency_ms: Date.now() - started };
  } catch (e) {
    return { reachable: false, http_status: null, latency_ms: Date.now() - started, error: e instanceof Error ? e.message.slice(0,160) : "probe_failed" };
  }
}

async function loadRegistry() {
  const r = await fetch(REGISTRY, { signal: AbortSignal.timeout(8000) });
  if (!r.ok) throw new Error(`registry_http_${r.status}`);
  const x = await r.json();
  if (x?.registry_id !== "ct.mesh.integrations.v1") throw new Error("registry_identity_mismatch");
  return x;
}

async function servicesStackHealth() {
  if (!U || !S) return { reachable: false, authenticated: false, error: "runtime_credentials_unavailable" };
  const r = await fetch(`${U}/functions/v1/crownthrive-services-stack`, {
    method: "POST",
    headers: { "content-type": "application/json", authorization: `Bearer ${S}` },
    body: JSON.stringify({ action: "health" }),
    signal: AbortSignal.timeout(8000)
  });
  let body: unknown = null;
  try { body = await r.json(); } catch { body = null; }
  return { reachable: true, authenticated: r.ok, http_status: r.status, body };
}

async function status() {
  const registry = await loadRegistry();
  const publicChecks = await Promise.all([
    ["github_api", "https://api.github.com"],
    ["ofac_sdn", "https://sanctionslistservice.ofac.treas.gov/api/PublicationPreview/exports/SDN_ADVANCED.XML"],
    ["crownthrive_io", "https://crownthrive.io"],
    ["adserve_online", "https://adserver.online"]
  ].map(async ([id,url]) => ({ id, url, ...(await probe(url, { method: "GET", headers: { "user-agent": "CrownThrive-Autonomous-OS-V2/2.0" } })) })));

  const css = await servicesStackHealth();
  const integrations = Array.isArray(registry.integrations) ? registry.integrations : [];
  const io = integrations.find((x:any)=>x.integration_id === "ct.integration.crownthrive.io.mcp");
  const ad = integrations.find((x:any)=>x.integration_id === "ct.integration.adserver.online");
  const assertions = {
    canonical_registry: registry.registry_id === "ct.mesh.integrations.v1",
    vault_only_credentials: registry.integration_policy?.vault_only_credentials === true,
    io_unlimited: io?.provider_limit?.mode === "UNLIMITED",
    adluxe_3m: Number(ad?.provider_limit?.limit) === 3000000,
    services_stack_authenticated: css.authenticated === true
  };
  const pass = Object.values(assertions).every(Boolean) && publicChecks.every((x:any)=>x.reachable);

  return {
    service: SERVICE,
    version: VERSION,
    state: pass ? "OPERATIONAL" : "DEGRADED",
    generated_at: new Date().toISOString(),
    control_plane: {
      canonical_registry: REGISTRY,
      registered_integrations: integrations.length,
      thrivebase_fabric_functions_cataloged: fabric.length,
      hosted_tool_adapters_cataloged: hostedToolCatalog.length
    },
    assertions,
    transport_checks: publicChecks,
    services_stack: css,
    automation: {
      read_health: "ENABLED",
      registry_drift_detection: "ENABLED",
      provider_reachability: "ENABLED",
      internal_service_health: "ENABLED_AUTHENTICATED",
      mutation_routing: "GOVERNED_SCOPED_ADAPTERS_ONLY",
      universal_delete: "DISABLED_BY_DESIGN"
    },
    hosted_tool_adapters: hostedToolCatalog.map(name => ({ name, runtime: "CHATGPT_HOSTED_TOOL", direct_external_invocation: false })),
    thrivebase_fabric: fabric.map(slug => ({ slug, endpoint: `${U}/functions/v1/${slug}`, registered: true })),
    proof: {
      github_source: "https://github.com/crownthrive1/chlom-protocol/tree/main/services/autonomous-os-v2",
      runtime_certification: "https://github.com/crownthrive1/chlom-protocol/actions/workflows/integration-runtime-certification.yml"
    }
  };
}

Deno.serve(async (req: Request) => {
  try {
    if (req.method !== "POST") return json({ error: "method_not_allowed", service: SERVICE }, 405);
    const body = await req.json().catch(() => ({}));
    const action = String(body?.action ?? "status");
    if (action === "status" || action === "health" || action === "test") return json(await status());
    if (action === "catalog") return json({ service: SERVICE, version: VERSION, hosted_tool_adapters: hostedToolCatalog, thrivebase_fabric: fabric });
    return json({ error: "unknown_action", allowed: ["status","health","test","catalog"] }, 400);
  } catch (e) {
    return json({ service: SERVICE, version: VERSION, state: "ERROR", error: e instanceof Error ? e.message : "runtime_error" }, 500);
  }
});
