export const CHLOM_EVIDENCE_SCHEMA = 'ct.chlom.chain-evidence.v1';
export const CHLOM_ANCHOR_SCHEMA = 'ct.chlom.evidence-anchor-intent.v1';
export const CHLOM_RUNTIME_SCHEMA = 'ct.chlom.chain-evidence-fabric.runtime.v1';
export const GOOGLE_RPC_SUNSET = '2026-12-15';

export const MCP_LATEST_PROTOCOL_VERSION = '2026-07-28';
export const MCP_LEGACY_PROTOCOL_VERSION = '2025-11-25';
export const MCP_SUPPORTED_PROTOCOL_VERSIONS = [
  MCP_LATEST_PROTOCOL_VERSION,
  MCP_LEGACY_PROTOCOL_VERSION,
];

export const MCP_ERROR = Object.freeze({
  PARSE_ERROR: -32700,
  INVALID_REQUEST: -32600,
  METHOD_NOT_FOUND: -32601,
  INVALID_PARAMS: -32602,
  INTERNAL_ERROR: -32603,
  HEADER_MISMATCH: -32020,
  MISSING_REQUIRED_CLIENT_CAPABILITY: -32021,
  UNSUPPORTED_PROTOCOL_VERSION: -32022,
  AUTHORIZATION_FAILED: -32030,
});

export const READ_ONLY_RPC_METHODS = new Set([
  'eth_chainId',
  'eth_blockNumber',
  'eth_getBalance',
  'eth_getBlockByHash',
  'eth_getBlockByNumber',
  'eth_getCode',
  'eth_getLogs',
  'eth_getStorageAt',
  'eth_getTransactionByBlockHashAndIndex',
  'eth_getTransactionByBlockNumberAndIndex',
  'eth_getTransactionByHash',
  'eth_getTransactionCount',
  'eth_getTransactionReceipt',
  'eth_call',
  'eth_estimateGas',
  'eth_feeHistory',
  'eth_gasPrice',
  'net_version',
  'web3_clientVersion',
]);

export const GOVERNED_WRITE_RPC_METHODS = new Set([
  'eth_sendRawTransaction',
]);

export const PROHIBITED_RPC_PREFIXES = [
  'admin_',
  'debug_',
  'engine_',
  'miner_',
  'personal_',
  'txpool_',
];

export const MAX_REQUEST_BYTES = 128 * 1024;
export const MAX_RPC_PARAMS_BYTES = 64 * 1024;
export const MAX_ANALYTICS_ROWS = 250;
export const MAX_ANALYTICS_LOOKBACK_DAYS = 31;
