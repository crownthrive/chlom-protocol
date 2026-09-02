import test from "node:test";
import assert from "node:assert/strict";
import {
  classifyCanonClaim,
  scoreCIE,
  validateProduct,
  validateRotation,
  preparePentaGreenHandoff,
  preflightRelease,
  MANDATORY_GATES,
} from "../services/pentabooks-v2/factory.mjs";

const sha = "a".repeat(64);
const product = (n, kind = "companion") => ({
  product_id: `VM-PB-R01-${String(n).padStart(3, "0")}`,
  title: `Product ${n}`,
  category: "test",
  version: "1.0.0",
  credits: 40,
  commerce_state: "SAFE_HOLD",
  customer_package_sha256: sha,
  kind,
  production_complete: true,
});

test("canon correction requires a superseded claim", () => {
  assert.throws(
    () => classifyCanonClaim({ fact_key: "x", source_ref: "src", status: "CORRECTED" }),
    /supersedes/,
  );
  assert.equal(
    classifyCanonClaim({ fact_key: "x", source_ref: "src", status: "DISPUTED" }).status,
    "DISPUTED",
  );
});

test("CIE passes only with total and hard minimums", () => {
  const scores = {
    Place: 4,
    People: 4,
    Language: 4,
    Object: 4,
    Ritual: 4,
    Sound: 4,
    "Power and Conflict": 4,
    "Care and Value": 4,
    "Boundary and Protection": 4,
    "Future and Legacy": 4,
  };
  assert.deepEqual(scoreCIE(scores), {
    pass: true,
    total: 40,
    missing: [],
    invalid: [],
    hard_failures: [],
  });
  scores.People = 3;
  assert.equal(scoreCIE(scores).pass, false);
});

test("rotation requires two complete books and ten products", () => {
  const products = Array.from({ length: 10 }, (_, i) => product(i + 1, i < 2 ? "book" : "companion"));
  assert.equal(validateRotation({ rotation_id: "r01", products }).valid, true);
  assert.match(
    validateRotation({ rotation_id: "r01", products: products.slice(1) }).errors.join(","),
    /minimum_two_complete_books/,
  );
});

test("PentaGreen handoff is fail-closed and scenario-bound", () => {
  const handoff = preparePentaGreenHandoff(product(1, "book"));
  assert.equal(handoff.provider_write, false);
  assert.equal(handoff.rights_grant, false);
  assert.equal(handoff.scenarios.find((x) => x.scenario === "team_commercial").credits, 160);
});

test("release preflight holds SAFE_HOLD and missing readback", () => {
  const qa_runs = MANDATORY_GATES.map((gate_id) => ({ gate_id, status: "pass" }));
  const result = preflightRelease({
    qa_runs,
    rights_status: "cleared",
    accessibility_status: "pass",
    source_uri: "drive://exact",
    sha256: sha,
    commerce_state: "SAFE_HOLD",
    provider_readback_verified: false,
  });
  assert.equal(result.release_ready, false);
  assert.deepEqual(result.hard_blocks, ["commerce_safe_hold", "provider_readback_missing"]);
});

test("product validation requires exact fingerprint", () => {
  assert.equal(validateProduct(product(3)).valid, true);
  assert.equal(validateProduct({ ...product(3), customer_package_sha256: "bad" }).valid, false);
});
