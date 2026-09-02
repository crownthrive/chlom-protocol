const CANON_STATES = new Set([
  "CANON_CONFIRMED", "SOURCE_CLAIM", "DISPUTED", "PROTECTED",
  "SEALED", "OPEN", "SUPERSEDED", "CORRECTED",
]);

export const CIE_AXES = [
  "Place", "People", "Language", "Object", "Ritual", "Sound",
  "Power and Conflict", "Care and Value", "Boundary and Protection",
  "Future and Legacy",
];

export const MANDATORY_GATES = [
  "G00_IDENTITY", "G01_SOURCE_PRESERVATION", "G02_CANON_LOCK", "G03_CIE",
  "G04_NARRATIVE", "G05_HUMANITY_VOICE", "G06_EDITORIAL", "G07_VISUAL",
  "G08_EDITION", "G09_ACCESSIBILITY", "G10_TECHNICAL_QA", "G11_RIGHTS",
  "G12_PRICING_LICENSE", "G13_PENTAGREEN_HANDOFF", "G14_PROVIDER_READBACK",
  "G15_ARCHIVE_TELEMETRY",
];

const nonEmpty = (value) => typeof value === "string" && value.trim().length > 0;
const sha256Like = (value) => /^[0-9a-f]{64}$/i.test(String(value ?? ""));

export function classifyCanonClaim(claim) {
  const status = String(claim?.status ?? "");
  if (!CANON_STATES.has(status)) throw new Error(`unsupported_canon_state:${status}`);
  if (!nonEmpty(claim?.fact_key)) throw new Error("fact_key_required");
  if (!nonEmpty(claim?.source_ref)) throw new Error("source_ref_required");
  if (status === "CORRECTED" && !nonEmpty(claim?.supersedes)) {
    throw new Error("corrected_claim_requires_supersedes");
  }
  return { ...claim, status };
}

export function scoreCIE(scores) {
  const hardMinimums = {
    People: 4,
    "Boundary and Protection": 4,
    "Power and Conflict": 3,
    Language: 3,
  };
  const missing = CIE_AXES.filter((axis) => !(axis in (scores ?? {})));
  const invalid = CIE_AXES.filter((axis) => {
    const value = Number(scores?.[axis]);
    return !Number.isInteger(value) || value < 0 || value > 5;
  });
  if (missing.length || invalid.length) {
    return { pass: false, total: null, missing, invalid, hard_failures: [] };
  }
  const total = CIE_AXES.reduce((sum, axis) => sum + Number(scores[axis]), 0);
  const hard_failures = Object.entries(hardMinimums)
    .filter(([axis, minimum]) => Number(scores[axis]) < minimum)
    .map(([axis, minimum]) => ({ axis, minimum, actual: Number(scores[axis]) }));
  return { pass: total >= 40 && hard_failures.length === 0, total, missing: [], invalid: [], hard_failures };
}

export function validateProduct(product) {
  const errors = [];
  if (!/^VM-PB-R\d{2}-\d{3}$/.test(String(product?.product_id ?? ""))) errors.push("invalid_product_id");
  if (!nonEmpty(product?.title)) errors.push("title_required");
  if (!nonEmpty(product?.version)) errors.push("version_required");
  if (!nonEmpty(product?.category)) errors.push("category_required");
  if (!Number.isFinite(Number(product?.credits)) || Number(product.credits) < 0) errors.push("credits_required");
  if (!nonEmpty(product?.commerce_state)) errors.push("commerce_state_required");
  if (!sha256Like(product?.customer_package_sha256)) errors.push("package_sha256_required");
  return { valid: errors.length === 0, errors };
}

export function validateRotation(rotation) {
  const errors = [];
  const products = Array.isArray(rotation?.products) ? rotation.products : [];
  const completeBooks = products.filter((p) => p.kind === "book" && p.production_complete === true).length;
  if (!nonEmpty(rotation?.rotation_id)) errors.push("rotation_id_required");
  if (completeBooks < 2) errors.push("minimum_two_complete_books_not_met");
  if (products.length < 10) errors.push("minimum_ten_products_not_met");
  const ids = products.map((p) => p.product_id);
  if (new Set(ids).size !== ids.length) errors.push("duplicate_product_id");
  for (const product of products) {
    const check = validateProduct(product);
    if (!check.valid) errors.push(...check.errors.map((e) => `${product?.product_id ?? "unknown"}:${e}`));
  }
  return { valid: errors.length === 0, errors, counts: { complete_books: completeBooks, products: products.length } };
}

export function preparePentaGreenHandoff(product, policy = {}) {
  const check = validateProduct(product);
  if (!check.valid) throw new Error(`invalid_product:${check.errors.join(",")}`);
  const base = Number(product.credits);
  const multipliers = { personal_household: 1, creator_professional: 2, education_impact: 2.5, team_commercial: 4, enterprise_custom_minimum: 10 };
  const scenarios = Object.entries(multipliers).map(([scenario, multiplier]) => ({
    scenario,
    multiplier,
    credits: Math.round(base * multiplier),
    requires_exact_rider: multiplier !== 1,
    activation_state: "SAFE_HOLD",
  }));
  return {
    schema_version: "1.0.0",
    product_id: product.product_id,
    exact_version: product.version,
    exact_package_sha256: product.customer_package_sha256,
    commerce_state: "SAFE_HOLD",
    provider_write: false,
    rights_grant: false,
    scenarios,
    restrictions: policy.restrictions ?? ["no_resale", "no_redistribution", "no_ai_training", "no_adaptation_by_default"],
  };
}

export function preflightRelease(input) {
  const latest = new Map();
  for (const run of input?.qa_runs ?? []) {
    if (!latest.has(run.gate_id)) latest.set(run.gate_id, run.status);
  }
  const missing = MANDATORY_GATES.filter((gate) => !latest.has(gate));
  const nonpassing = MANDATORY_GATES.filter((gate) => latest.has(gate) && !["pass", "waived"].includes(String(latest.get(gate)).toLowerCase()));
  const hard = [];
  if (input?.rights_status !== "cleared") hard.push("rights_not_cleared");
  if (!new Set(["pass", "complete", "cleared"]).has(String(input?.accessibility_status))) hard.push("accessibility_not_complete");
  if (!nonEmpty(input?.source_uri) || !sha256Like(input?.sha256)) hard.push("source_or_checksum_missing");
  if (input?.commerce_state === "SAFE_HOLD") hard.push("commerce_safe_hold");
  if (!input?.provider_readback_verified) hard.push("provider_readback_missing");
  return { release_ready: missing.length === 0 && nonpassing.length === 0 && hard.length === 0, missing_gates: missing, nonpassing_gates: nonpassing, hard_blocks: hard };
}
