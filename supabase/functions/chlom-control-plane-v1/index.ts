import "jsr:@supabase/functions-js/edge-runtime.d.ts";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SUPABASE_ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
const GATEWAY_CONTRACT = "ct.chlom.authenticated-control-plane-gateway.v1";
const GATEWAY_VERSION = "1.0.0";
const MAX_REQUEST_BYTES = 1_048_576;
const MAX_RESPONSE_BYTES = 2_097_152;

const READ_ACTIONS = new Set(["status", "capabilities"]);
const MUTATION_ACTIONS = new Set([
  "register_asset_binding",
  "record_ownership_interest",
  "record_rights_instrument",
  "record_dla",
  "record_lex_offer",
  "record_agreement_entitlement",
  "record_obligation",
  "record_revenue_policy",
  "preview_settlement",
  "register_token_candidate",
  "report_oracle_signal",
  "bind_dail_proof",
]);
const ALLOWED_ACTIONS = new Set([...READ_ACTIONS, ...MUTATION_ACTIONS]);
const EXCLUDED_ACTIONS = new Set([
  "external_money_movement",
  "production_token_mint_confirmation",
  "tokenomics_activation",
  "validator_activation",
  "public_chain_anchor_confirmation",
  "legal_title_adjudication",
]);

function isAllowedOrigin(origin: string | null): boolean {
  if (!origin) return true;
  try {
    const url = new URL(origin);
    if (url.protocol !== "https:") return false;
    const host = url.hostname.toLowerCase();
    return host === "crownthrive.com" || host.endsWith(".crownthrive.com") ||
      host === "crownthrive.io" || host.endsWith(".crownthrive.io") ||
      host.endsWith(".supabase.co");
  } catch {
    return false;
  }
}

function responseHeaders(origin: string | null, correlationId: string): Headers {
  const headers = new Headers({
    "content-type": "application/json; charset=utf-8",
    "cache-control": "no-store, max-age=0",
    "pragma": "no-cache",
    "x-content-type-options": "nosniff",
    "x-frame-options": "DENY",
    "referrer-policy": "no-referrer",
    "content-security-policy": "default-src 'none'; frame-ancestors 'none'; base-uri 'none'",
    "cross-origin-resource-policy": "same-site",
    "x-chlom-gateway-contract": GATEWAY_CONTRACT,
    "x-chlom-gateway-version": GATEWAY_VERSION,
    "x-correlation-id": correlationId,
    "vary": "Origin",
  });
  if (origin) {
    headers.set("access-control-allow-origin", origin);
    headers.set("access-control-allow-credentials", "true");
    headers.set(
      "access-control-expose-headers",
      "x-chlom-gateway-contract, x-chlom-gateway-version, x-correlation-id",
    );
  }
  return headers;
}

function jsonResponse(
  payload: unknown,
  status: number,
  origin: string | null,
  correlationId: string,
): Response {
  return new Response(JSON.stringify(payload), {
    status,
    headers: responseHeaders(origin, correlationId),
  });
}

function validCorrelationId(value: string | null): string {
  if (value && /^[A-Za-z0-9._:-]{8,128}$/.test(value)) return value;
  return `ctcorr:chlom-gateway:${crypto.randomUUID()}`;
}

function bearer(req: Request): string | null {
  const value = req.headers.get("authorization")?.trim() ?? "";
  return /^Bearer\s+\S+$/i.test(value) ? value : null;
}

async function readJsonBounded(req: Request): Promise<Record<string, unknown>> {
  const declared = Number(req.headers.get("content-length") ?? "0");
  if (Number.isFinite(declared) && declared > MAX_REQUEST_BYTES) {
    throw new Error("REQUEST_BODY_TOO_LARGE");
  }
  if (!req.body) return {};
  const reader = req.body.getReader();
  const chunks: Uint8Array[] = [];
  let size = 0;
  try {
    while (true) {
      const { value, done } = await reader.read();
      if (done) break;
      if (!value) continue;
      size += value.byteLength;
      if (size > MAX_REQUEST_BYTES) {
        await reader.cancel("request byte limit");
        throw new Error("REQUEST_BODY_TOO_LARGE");
      }
      chunks.push(value);
    }
  } finally {
    try {
      reader.releaseLock();
    } catch {
      // no-op
    }
  }
  const bytes = new Uint8Array(size);
  let offset = 0;
  for (const chunk of chunks) {
    bytes.set(chunk, offset);
    offset += chunk.byteLength;
  }
  let parsed: unknown;
  try {
    parsed = JSON.parse(new TextDecoder("utf-8", { fatal: true }).decode(bytes));
  } catch {
    throw new Error("INVALID_JSON");
  }
  if (!parsed || typeof parsed !== "object" || Array.isArray(parsed)) {
    throw new Error("JSON_OBJECT_REQUIRED");
  }
  return parsed as Record<string, unknown>;
}

async function invokeDispatch(
  authorization: string,
  action: string,
  payload: Record<string, unknown>,
  idempotencyKey: string | null,
): Promise<{ status: number; data: unknown }> {
  if (!SUPABASE_URL || !SUPABASE_ANON_KEY) {
    throw new Error("GATEWAY_RUNTIME_NOT_CONFIGURED");
  }
  const response = await fetch(`${SUPABASE_URL}/rest/v1/rpc/chlom_api_dispatch_v2`, {
    method: "POST",
    headers: {
      "content-type": "application/json",
      "accept": "application/json",
      "apikey": SUPABASE_ANON_KEY,
      "authorization": authorization,
      "x-client-info": `chlom-control-plane-v1/${GATEWAY_VERSION}`,
    },
    body: JSON.stringify({
      p_action: action,
      p_payload: payload,
      p_idempotency_key: idempotencyKey,
    }),
  });

  const text = await response.text();
  if (new TextEncoder().encode(text).byteLength > MAX_RESPONSE_BYTES) {
    throw new Error("UPSTREAM_RESPONSE_TOO_LARGE");
  }
  let data: unknown = null;
  if (text) {
    try {
      data = JSON.parse(text);
    } catch {
      data = { code: "UPSTREAM_NON_JSON_RESPONSE" };
    }
  }
  return { status: response.status, data };
}

function suffixPath(req: Request): string {
  const path = new URL(req.url).pathname;
  const marker = "/chlom-control-plane-v1";
  const index = path.indexOf(marker);
  if (index < 0) return "/";
  return path.slice(index + marker.length).replace(/\/+$/, "") || "/";
}

Deno.serve(async (req: Request) => {
  const origin = req.headers.get("origin");
  const correlationId = validCorrelationId(req.headers.get("x-correlation-id"));

  if (!isAllowedOrigin(origin)) {
    return jsonResponse({ ok: false, code: "ORIGIN_DENIED" }, 403, null, correlationId);
  }

  if (req.method === "OPTIONS") {
    const headers = responseHeaders(origin, correlationId);
    headers.set("access-control-allow-methods", "GET, POST, OPTIONS");
    headers.set(
      "access-control-allow-headers",
      "authorization, apikey, content-type, idempotency-key, x-correlation-id",
    );
    headers.set("access-control-max-age", "600");
    headers.delete("content-type");
    return new Response(null, { status: 204, headers });
  }

  const authorization = bearer(req);
  if (!authorization) {
    return jsonResponse({ ok: false, code: "BEARER_TOKEN_REQUIRED" }, 401, origin, correlationId);
  }

  const route = suffixPath(req);
  let action = "";
  let payload: Record<string, unknown> = {};

  try {
    if (req.method === "GET" && (route === "/" || route === "/status")) {
      action = "status";
    } else if (req.method === "GET" && (route === "/capabilities" || route === "/health")) {
      action = "capabilities";
    } else if (req.method === "POST" && (route === "/" || route === "/dispatch")) {
      const input = await readJsonBounded(req);
      action = String(input.action ?? "").trim().toLowerCase();
      const suppliedPayload = input.payload ?? {};
      if (!suppliedPayload || typeof suppliedPayload !== "object" || Array.isArray(suppliedPayload)) {
        return jsonResponse({ ok: false, code: "PAYLOAD_OBJECT_REQUIRED" }, 400, origin, correlationId);
      }
      payload = suppliedPayload as Record<string, unknown>;
    } else {
      return jsonResponse({ ok: false, code: "ROUTE_NOT_FOUND" }, 404, origin, correlationId);
    }
  } catch (error) {
    const code = error instanceof Error ? error.message : "INVALID_REQUEST";
    const status = code === "REQUEST_BODY_TOO_LARGE" ? 413 : 400;
    return jsonResponse({ ok: false, code }, status, origin, correlationId);
  }

  if (EXCLUDED_ACTIONS.has(action)) {
    return jsonResponse(
      { ok: false, code: "ACTION_EXPLICITLY_EXCLUDED", action, external_execution_enabled: false },
      403,
      origin,
      correlationId,
    );
  }
  if (!ALLOWED_ACTIONS.has(action)) {
    return jsonResponse({ ok: false, code: "ACTION_NOT_ALLOWED", action }, 400, origin, correlationId);
  }

  let idempotencyKey: string | null = null;
  if (MUTATION_ACTIONS.has(action)) {
    idempotencyKey = req.headers.get("idempotency-key")?.trim() ?? null;
    if (!idempotencyKey) {
      return jsonResponse({ ok: false, code: "IDEMPOTENCY_KEY_REQUIRED" }, 400, origin, correlationId);
    }
    if (idempotencyKey.length > 128) {
      return jsonResponse({ ok: false, code: "IDEMPOTENCY_KEY_TOO_LONG" }, 400, origin, correlationId);
    }
  }

  try {
    const upstream = await invokeDispatch(authorization, action, payload, idempotencyKey);
    if (upstream.status < 200 || upstream.status >= 300) {
      const mapped = upstream.status === 401 || upstream.status === 403
        ? upstream.status
        : upstream.status === 400 || upstream.status === 409
        ? upstream.status
        : 502;
      return jsonResponse(
        {
          ok: false,
          code: "CHLOM_DISPATCH_REJECTED",
          upstream_status: upstream.status,
          detail: upstream.data,
          external_execution_enabled: false,
        },
        mapped,
        origin,
        correlationId,
      );
    }

    return jsonResponse(
      {
        gateway_contract: GATEWAY_CONTRACT,
        gateway_version: GATEWAY_VERSION,
        correlation_id: correlationId,
        external_execution_enabled: false,
        data: upstream.data,
      },
      200,
      origin,
      correlationId,
    );
  } catch (error) {
    const code = error instanceof Error ? error.message : "GATEWAY_FAILURE";
    return jsonResponse(
      { ok: false, code, external_execution_enabled: false },
      500,
      origin,
      correlationId,
    );
  }
});
