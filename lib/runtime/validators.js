import { CHAIN_KEYS } from './chains.js';
import { ChlomError } from './errors.js';
import { MAX_ANALYTICS_LOOKBACK_DAYS, MAX_ANALYTICS_ROWS } from './constants.js';

function requireObject(value, label = 'value') {
  if (!value || typeof value !== 'object' || Array.isArray(value)) {
    throw new ChlomError('CHLOM_REQUEST_VALIDATION_FAILED', `${label} must be an object.`, 400);
  }
  return value;
}

function requireString(value, label, { min = 1, max = 256 } = {}) {
  if (typeof value !== 'string' || value.length < min || value.length > max) {
    throw new ChlomError(
      'CHLOM_REQUEST_VALIDATION_FAILED',
      `${label} must be a string between ${min} and ${max} characters.`,
      400,
    );
  }
  return value;
}

function requireChain(value) {
  const chain = requireString(value, 'chain', { min: 1, max: 64 });
  if (!CHAIN_KEYS.includes(chain)) {
    throw new ChlomError('CHLOM_UNSUPPORTED_CHAIN', `Unsupported chain: ${chain}`, 400);
  }
  return chain;
}

function optionalBoundedInteger(value, label, fallback, minimum, maximum) {
  if (value === undefined || value === null) {
    return fallback;
  }
  if (!Number.isInteger(value) || value < minimum || value > maximum) {
    throw new ChlomError(
      'CHLOM_REQUEST_VALIDATION_FAILED',
      `${label} must be an integer from ${minimum} through ${maximum}.`,
      400,
    );
  }
  return value;
}

export function parseRpcInput(raw) {
  const value = requireObject(raw, 'RPC request');
  const params = value.params === undefined ? [] : value.params;
  if (!Array.isArray(params) || params.length > 64) {
    throw new ChlomError(
      'CHLOM_REQUEST_VALIDATION_FAILED',
      'params must be an array with no more than 64 entries.',
      400,
    );
  }
  return {
    chain: requireChain(value.chain),
    method: requireString(value.method, 'method', { min: 1, max: 128 }),
    params,
  };
}

export function parseAnalyticsInput(raw) {
  const value = requireObject(raw, 'Analytics request');
  const templates = [
    'latest_block',
    'transaction_evidence',
    'address_activity',
    'contract_logs',
  ];
  const template = requireString(value.template, 'template', { min: 1, max: 64 });
  if (!templates.includes(template)) {
    throw new ChlomError(
      'CHLOM_ANALYTICS_TEMPLATE_NOT_ALLOWLISTED',
      `Analytics template is not allowlisted: ${template}`,
      403,
    );
  }
  return {
    chain: requireChain(value.chain),
    template,
    transactionHash:
      value.transactionHash === undefined
        ? undefined
        : requireString(value.transactionHash, 'transactionHash', { min: 3, max: 132 }),
    address:
      value.address === undefined
        ? undefined
        : requireString(value.address, 'address', { min: 3, max: 132 }),
    lookbackDays: optionalBoundedInteger(
      value.lookbackDays,
      'lookbackDays',
      7,
      1,
      MAX_ANALYTICS_LOOKBACK_DAYS,
    ),
    limit: optionalBoundedInteger(value.limit, 'limit', 50, 1, MAX_ANALYTICS_ROWS),
  };
}

export function parseAnchorInput(raw) {
  const value = requireObject(raw, 'Anchor request');
  const evidenceDigest = requireString(value.evidenceDigest, 'evidenceDigest', {
    min: 64,
    max: 64,
  });
  if (!/^[0-9a-f]{64}$/.test(evidenceDigest)) {
    throw new ChlomError(
      'CHLOM_REQUEST_VALIDATION_FAILED',
      'evidenceDigest must be a lowercase SHA-256 hexadecimal digest.',
      400,
    );
  }
  const targetChain = requireChain(value.targetChain);
  if (!['base', 'base-sepolia', 'ethereum'].includes(targetChain)) {
    throw new ChlomError(
      'CHLOM_ANCHOR_CHAIN_NOT_ALLOWLISTED',
      `Evidence anchoring is not allowlisted for ${targetChain}.`,
      403,
    );
  }
  return { evidenceDigest, targetChain };
}
