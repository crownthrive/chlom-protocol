import { randomUUID } from "node:crypto";
import {
  CHLOM_ANCHOR_SCHEMA,
  CHLOM_EVIDENCE_SCHEMA,
} from "./constants";
import { sha256 } from "./crypto";

export type EvidenceAuthority = {
  riskClass: "D1" | "D2";
  mode: "read_only" | "governed_broadcast";
  governanceState: string;
  chainWriteEnabled: boolean;
};

export type EvidenceEnvelope<T> = {
  schema: typeof CHLOM_EVIDENCE_SCHEMA;
  eventId: string;
  observedAt: string;
  source: {
    kind: "rpc" | "google_blockchain_analytics";
    provider: string;
    chain: string;
    operation: string;
    endpointFingerprint?: string;
  };
  authority: EvidenceAuthority;
  requestDigest: string;
  payloadDigest: string;
  evidenceDigest: string;
  payload: T;
  dailProjection: {
    eventType: string;
    idempotencyKey: string;
    evidenceDigest: string;
  };
};

type EnvelopeInput<T> = {
  source: EvidenceEnvelope<T>["source"];
  request: unknown;
  payload: T;
  write?: boolean;
};

export function createEvidenceEnvelope<T>({
  source,
  request,
  payload,
  write = false,
}: EnvelopeInput<T>): EvidenceEnvelope<T> {
  const requestDigest = sha256(request);
  const payloadDigest = sha256(payload);
  const eventId = randomUUID();
  const observedAt = new Date().toISOString();
  const authority: EvidenceAuthority = {
    riskClass: write ? "D2" : "D1",
    mode: write ? "governed_broadcast" : "read_only",
    governanceState: process.env.CHLOM_GOVERNANCE_STATE ?? "hold",
    chainWriteEnabled: process.env.CHLOM_CHAIN_WRITE_ENABLED === "true",
  };

  const evidenceDigest = sha256({
    schema: CHLOM_EVIDENCE_SCHEMA,
    eventId,
    observedAt,
    source,
    authority,
    requestDigest,
    payloadDigest,
  });

  return {
    schema: CHLOM_EVIDENCE_SCHEMA,
    eventId,
    observedAt,
    source,
    authority,
    requestDigest,
    payloadDigest,
    evidenceDigest,
    payload,
    dailProjection: {
      eventType: `chlom.chain.${source.kind}.${source.operation}`,
      idempotencyKey: evidenceDigest,
      evidenceDigest,
    },
  };
}

export function prepareAnchorIntent(evidenceDigest: string, targetChain: string) {
  const createdAt = new Date().toISOString();
  const anchorDigest = sha256({
    schema: CHLOM_ANCHOR_SCHEMA,
    evidenceDigest,
    targetChain,
    createdAt,
  });

  return {
    schema: CHLOM_ANCHOR_SCHEMA,
    status: "HOLD_REQUIRES_GOVERNED_ANCHOR_ADAPTER",
    createdAt,
    targetChain,
    evidenceDigest,
    anchorDigest,
    broadcast: false,
    authority:
      "Anchor preparation does not create chain-broadcast authority.",
  };
}
