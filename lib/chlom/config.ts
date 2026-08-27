import { CHAIN_KEYS, type ChainKey, envChainSuffix } from "./chains";

export type RuntimeReadiness = {
  apiTokenConfigured: boolean;
  googleAnalyticsConfigured: boolean;
  googleAnalyticsLocation: string;
  configuredRpcChains: ChainKey[];
  configuredRpcProviders: string[];
  governanceState: string;
  chainWriteEnabled: boolean;
  ecacConfigured: boolean;
};

const requiredGoogleVariables = [
  "GCP_PROJECT_ID",
  "GCP_PROJECT_NUMBER",
  "GCP_SERVICE_ACCOUNT_EMAIL",
  "GCP_WORKLOAD_IDENTITY_POOL_ID",
  "GCP_WORKLOAD_IDENTITY_POOL_PROVIDER_ID",
] as const;

export function googleAnalyticsConfigured(): boolean {
  return requiredGoogleVariables.every((key) => Boolean(process.env[key]));
}

export function configuredRpcChains(): ChainKey[] {
  return CHAIN_KEYS.filter((chain) => {
    const suffix = envChainSuffix(chain);
    return [
      `CHLOM_RPC_${suffix}`,
      `QUICKNODE_RPC_${suffix}`,
      `GOOGLE_BLOCKCHAIN_RPC_${suffix}`,
      `ALCHEMY_RPC_${suffix}`,
      `INFURA_RPC_${suffix}`,
    ].some((key) => Boolean(process.env[key]));
  });
}

export function configuredRpcProviders(): string[] {
  const providers = [
    ["custom", "CHLOM_RPC_"],
    ["quicknode", "QUICKNODE_RPC_"],
    ["google-blockchain-rpc-deprecated", "GOOGLE_BLOCKCHAIN_RPC_"],
    ["alchemy", "ALCHEMY_RPC_"],
    ["infura", "INFURA_RPC_"],
  ] as const;

  return providers
    .filter(([, prefix]) =>
      CHAIN_KEYS.some((chain) =>
        Boolean(process.env[`${prefix}${envChainSuffix(chain)}`]),
      ),
    )
    .map(([name]) => name);
}

export function runtimeReadiness(): RuntimeReadiness {
  return {
    apiTokenConfigured: Boolean(process.env.CHLOM_API_TOKEN),
    googleAnalyticsConfigured: googleAnalyticsConfigured(),
    googleAnalyticsLocation: process.env.GCP_BIGQUERY_LOCATION ?? "US",
    configuredRpcChains: configuredRpcChains(),
    configuredRpcProviders: configuredRpcProviders(),
    governanceState: process.env.CHLOM_GOVERNANCE_STATE ?? "hold",
    chainWriteEnabled: process.env.CHLOM_CHAIN_WRITE_ENABLED === "true",
    ecacConfigured: Boolean(process.env.CHLOM_ECAC_DIGEST),
  };
}

export function maximumBytesBilled(): string {
  const raw = process.env.CHLOM_BIGQUERY_MAX_BYTES_BILLED ?? "536870912";
  return /^\d+$/.test(raw) ? raw : "536870912";
}
