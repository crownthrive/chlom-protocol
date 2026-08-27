export const CHLOM_EVIDENCE_SCHEMA = "ct.chlom.chain-evidence.v1" as const;
export const CHLOM_ANCHOR_SCHEMA = "ct.chlom.evidence-anchor-intent.v1" as const;
export const GOOGLE_RPC_SUNSET = "2026-12-15" as const;

export const READ_ONLY_RPC_METHODS = new Set([
  "eth_chainId",
  "eth_blockNumber",
  "eth_getBalance",
  "eth_getBlockByHash",
  "eth_getBlockByNumber",
  "eth_getCode",
  "eth_getLogs",
  "eth_getStorageAt",
  "eth_getTransactionByBlockHashAndIndex",
  "eth_getTransactionByBlockNumberAndIndex",
  "eth_getTransactionByHash",
  "eth_getTransactionCount",
  "eth_getTransactionReceipt",
  "eth_call",
  "eth_estimateGas",
  "eth_feeHistory",
  "eth_gasPrice",
  "net_version",
  "web3_clientVersion",
]);

export const GOVERNED_WRITE_RPC_METHODS = new Set([
  "eth_sendRawTransaction",
]);

export const PROHIBITED_RPC_PREFIXES = [
  "admin_",
  "debug_",
  "engine_",
  "miner_",
  "personal_",
  "txpool_",
];

export const MAX_RPC_PARAMS_BYTES = 64 * 1024;
export const MAX_ANALYTICS_ROWS = 250;
export const MAX_ANALYTICS_LOOKBACK_DAYS = 31;
