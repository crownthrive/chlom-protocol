export const CHAIN_KEYS = [
  "base",
  "base-sepolia",
  "ethereum",
  "arbitrum",
  "avalanche",
  "cronos",
  "fantom",
  "optimism",
  "polygon",
  "tron",
] as const;

export type ChainKey = (typeof CHAIN_KEYS)[number];

export type ChainDefinition = {
  key: ChainKey;
  displayName: string;
  evm: boolean;
  chainIdHex?: string;
  analyticsDataset?: string;
};

export const CHAIN_REGISTRY: Record<ChainKey, ChainDefinition> = {
  base: {
    key: "base",
    displayName: "Base Mainnet",
    evm: true,
    chainIdHex: "0x2105",
  },
  "base-sepolia": {
    key: "base-sepolia",
    displayName: "Base Sepolia",
    evm: true,
    chainIdHex: "0x14a34",
  },
  ethereum: {
    key: "ethereum",
    displayName: "Ethereum Mainnet",
    evm: true,
    chainIdHex: "0x1",
    analyticsDataset:
      "bigquery-public-data.goog_blockchain_ethereum_mainnet_us",
  },
  arbitrum: {
    key: "arbitrum",
    displayName: "Arbitrum One",
    evm: true,
    chainIdHex: "0xa4b1",
    analyticsDataset:
      "bigquery-public-data.goog_blockchain_arbitrum_one_us",
  },
  avalanche: {
    key: "avalanche",
    displayName: "Avalanche C-Chain",
    evm: true,
    chainIdHex: "0xa86a",
    analyticsDataset:
      "bigquery-public-data.goog_blockchain_avalanche_contract_chain_us",
  },
  cronos: {
    key: "cronos",
    displayName: "Cronos Mainnet",
    evm: true,
    chainIdHex: "0x19",
    analyticsDataset:
      "bigquery-public-data.goog_blockchain_cronos_mainnet_us",
  },
  fantom: {
    key: "fantom",
    displayName: "Fantom Opera",
    evm: true,
    chainIdHex: "0xfa",
    analyticsDataset:
      "bigquery-public-data.goog_blockchain_fantom_opera_us",
  },
  optimism: {
    key: "optimism",
    displayName: "Optimism Mainnet",
    evm: true,
    chainIdHex: "0xa",
    analyticsDataset:
      "bigquery-public-data.goog_blockchain_optimism_mainnet_us",
  },
  polygon: {
    key: "polygon",
    displayName: "Polygon Mainnet",
    evm: true,
    chainIdHex: "0x89",
    analyticsDataset:
      "bigquery-public-data.goog_blockchain_polygon_mainnet_us",
  },
  tron: {
    key: "tron",
    displayName: "Tron Mainnet",
    evm: false,
    analyticsDataset:
      "bigquery-public-data.goog_blockchain_tron_mainnet_us",
  },
};

export function assertChainKey(value: string): asserts value is ChainKey {
  if (!CHAIN_KEYS.includes(value as ChainKey)) {
    throw new Error(`Unsupported chain: ${value}`);
  }
}

export function envChainSuffix(chain: ChainKey): string {
  return chain.toUpperCase().replaceAll("-", "_");
}
