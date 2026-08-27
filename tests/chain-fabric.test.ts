import assert from "node:assert/strict";
import test from "node:test";
import { canonicalize, sha256 } from "../lib/chlom/crypto";
import { classifyRpcMethod } from "../lib/chlom/rpc";
import { prepareAnalyticsQuery } from "../lib/chlom/analytics-templates";
import { prepareAnchorIntent } from "../lib/chlom/evidence";

test("canonicalization is deterministic across object key order", () => {
  const left = { b: 2, a: { d: 4, c: 3 } };
  const right = { a: { c: 3, d: 4 }, b: 2 };
  assert.equal(canonicalize(left), canonicalize(right));
  assert.equal(sha256(left), sha256(right));
});

test("read methods are allowed and dangerous namespaces fail closed", () => {
  assert.equal(classifyRpcMethod("eth_getTransactionReceipt"), "read");
  assert.throws(
    () => classifyRpcMethod("personal_unlockAccount"),
    /prohibited/i,
  );
  assert.throws(
    () => classifyRpcMethod("eth_unknownExperimentalMethod"),
    /not allowlisted/i,
  );
});

test("raw broadcast is classified as governed write", () => {
  assert.equal(classifyRpcMethod("eth_sendRawTransaction"), "write");
});

test("analytics templates are static and bounded", () => {
  const prepared = prepareAnalyticsQuery({
    chain: "ethereum",
    template: "address_activity",
    address: "0x1234",
    limit: 9999,
    lookbackDays: 9999,
  });

  assert.equal(prepared.limit, 250);
  assert.equal(prepared.lookbackDays, 31);
  assert.match(prepared.query, /@address/);
  assert.match(prepared.query, /@start_timestamp/);
  assert.doesNotMatch(prepared.query, /0x1234/);
});

test("unsupported Google Analytics chains fail closed", () => {
  assert.throws(
    () =>
      prepareAnalyticsQuery({
        chain: "base",
        template: "latest_block",
      }),
    /not registered/i,
  );
});

test("anchor intent never broadcasts", () => {
  const intent = prepareAnchorIntent("a".repeat(64), "base");
  assert.equal(intent.broadcast, false);
  assert.equal(intent.status, "HOLD_REQUIRES_GOVERNED_ANCHOR_ADAPTER");
});
