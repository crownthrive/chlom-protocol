import { randomUUID } from 'node:crypto';
import { CHLOM_ANCHOR_SCHEMA, CHLOM_EVIDENCE_SCHEMA } from './constants.js';
import { sha256 } from './crypto.js';

export function createEvidenceEnvelope({ source, request, payload, write = false }) {
  const requestDigest = sha256(request);
  const payloadDigest = sha256(payload);
  const eventId = randomUUID();
  const observedAt = new Date().toISOString();
  const authority = {
    riskClass: write ? 'D2' : 'D1',
    mode: write ? 'governed_broadcast' : 'read_only',
    governanceState: process.env.CHLOM_GOVERNANCE_STATE || 'hold',
    chainWriteEnabled: process.env.CHLOM_CHAIN_WRITE_ENABLED === 'true',
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

export function prepareAnchorIntent(evidenceDigest, targetChain) {
  const createdAt = new Date().toISOString();
  const anchorDigest = sha256({
    schema: CHLOM_ANCHOR_SCHEMA,
    evidenceDigest,
    targetChain,
    createdAt,
  });
  return {
    schema: CHLOM_ANCHOR_SCHEMA,
    status: 'HOLD_REQUIRES_GOVERNED_ANCHOR_ADAPTER',
    createdAt,
    targetChain,
    evidenceDigest,
    anchorDigest,
    broadcast: false,
    authority: 'Anchor preparation does not create chain-broadcast authority.',
  };
}
