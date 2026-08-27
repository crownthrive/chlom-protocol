import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type, x-engine-mode",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Cache-Control": "no-store",
};

const json = (body: unknown, status = 200) => new Response(JSON.stringify(body), {
  status,
  headers: { ...cors, "Content-Type": "application/json" },
});

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  if (req.method !== "POST") return json({ ok: false, error: "method_not_allowed" }, 405);

  const mode = req.headers.get("x-engine-mode") ?? "simulation";
  if (mode !== "simulation") {
    return json({
      ok: false,
      state: "HOLD",
      production_settlement: "blocked",
      reason: "Production settlement remains fail-closed until PentaCredentials, executed contracts, provider readiness, PentaCertify D3 governance, reconciliation, reversal/dispute certification, canary evidence, and explicit production authority are satisfied."
    }, 423);
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  const authHeader = req.headers.get("Authorization");
  if (!supabaseUrl || !serviceKey) return json({ ok: false, error: "runtime_configuration_missing" }, 500);
  if (!authHeader?.startsWith("Bearer ")) return json({ ok: false, error: "missing_authorization" }, 401);

  const admin = createClient(supabaseUrl, serviceKey, { global: { headers: { Authorization: authHeader } } });
  const { data: userData, error: userError } = await admin.auth.getUser(authHeader.slice(7));
  if (userError || !userData.user) return json({ ok: false, error: "unauthorized" }, 401);

  let body: Record<string, unknown>;
  try { body = await req.json(); } catch { return json({ ok: false, error: "invalid_json" }, 400); }
  if (String(body.action ?? "simulate_allocation") !== "simulate_allocation") return json({ ok: false, error: "unsupported_action" }, 400);

  const grossMinor = Number(body.gross_minor);
  if (!Number.isSafeInteger(grossMinor) || grossMinor < 0) return json({ ok: false, error: "gross_minor_must_be_nonnegative_integer" }, 400);
  const idempotencyKey = String(body.idempotency_key ?? crypto.randomUUID());
  const payload = {
    idempotency_key: idempotencyKey,
    provider_ref: String(body.provider_ref ?? "simulation:provider"),
    contract_key: String(body.contract_key ?? "CT-SFE-PROVIDER-80-1.0"),
    policy_key: "CT-SFE-80-10-5-3-2",
    currency: String(body.currency ?? "USD").toUpperCase(),
    gross_minor: grossMinor,
    state: "received",
    compliance_state: "pass",
    rights_state: "pass",
    allocation_state: "pending",
    metadata: { mode: "simulation", actor: userData.user.id },
  };

  const { error: insertError } = await admin.from("ct_self_funding_transactions").upsert(payload, { onConflict: "idempotency_key", ignoreDuplicates: true });
  if (insertError) return json({ ok: false, error: insertError.message }, 500);

  const { data: tx, error: txError } = await admin.from("ct_self_funding_transactions").select("transaction_id,idempotency_key,state,allocation_state,gross_minor,currency,policy_key,contract_key").eq("idempotency_key", idempotencyKey).single();
  if (txError || !tx) return json({ ok: false, error: txError?.message ?? "transaction_not_found" }, 500);

  const { data: allocations, error: calcError } = await admin.rpc("ct_calculate_self_funding_allocations", { p_transaction_id: tx.transaction_id });
  if (calcError) return json({ ok: false, error: calcError.message }, 422);

  const total = (allocations ?? []).reduce((sum: number, row: { amount_minor: number }) => sum + Number(row.amount_minor), 0);
  if (total !== grossMinor) return json({ ok: false, error: "allocation_total_mismatch", expected: grossMinor, actual: total }, 500);

  return json({
    ok: true,
    mode: "simulation",
    production_settlement: "blocked",
    transaction: tx,
    idempotency_key: idempotencyKey,
    allocations,
    allocation_total_minor: total,
    policy: "CT-SFE-80-10-5-3-2@1.0.0",
    provider_rail: "Stripe Connect / separate charges and transfers",
    governance: ["CHLOM", "PentaGreen", "PentaCertify", "PentaCredentials", "PentaBuild", "PentaRelease"],
  });
});
