import {
  GOVERNED_WRITE_RPC_METHODS,
  GOOGLE_RPC_SUNSET,
  MAX_RPC_PARAMS_BYTES,
  PROHIBITED_RPC_PREFIXES,
  READ_ONLY_RPC_METHODS,
} from "./constants";
import {
  CHAIN_REGISTRY,
  assertChainKey,
  envChainSuffix,
  type ChainKey,
} from "./chains";
import { sha256 } from "./crypto";
import { ChlomError } from "./errors";
import { createEvidenceEnvelope } from "./evidence";

export type RpcProvider = {
  name: string;
  endpoint: string;
  deprecated: boolean;
  sunset?: string;
};

export type RpcInput = {
  chain: string;
  method: string;
  params?: unknown[];
  writeAuthorized?: boolean;
};

const PROVIDER_PREFIXES = [
  ["quicknode", "QUICKNODE_RPC_", false],
  ["custom", "CHLOM_RPC_", false],
  ["google-blockchain-rpc-deprecated", "GOOGLE_BLOCKCHAIN_RPC_", true],
  ["alchemy", "ALCHEMY_RPC_", false],
  ["infura", "INFURA_RPC_", false],
] as const;

export function resolveRpcProvider(chain: ChainKey): RpcProvider {
  const suffix = envChainSuffix(chain);

  for (const [name, prefix, deprecated] of PROVIDER_PREFIXES) {
    const endpoint = process.env[`${prefix}${suffix}`]?.trim();
    if (endpoint) {
      let parsed: URL;
      try {
        parsed = new URL(endpoint);
      } catch {
        throw new ChlomError(
          "CHLOM_RPC_ENDPOINT_INVALID",
          `Configured ${name} endpoint for ${chain} is not a valid URL.`,
          500,
        );
      }

      if (parsed.protocol !== "https:") {
        throw new ChlomError(
          "CHLOM_RPC_ENDPOINT_INSECURE",
          `Configured ${name} endpoint for ${chain} must use HTTPS.`,
          500,
        );
      }

      return {
        name,
        endpoint,
        deprecated,
        sunset: deprecated ? GOOGLE_RPC_SUNSET : undefined,
      };
    }
  }

  throw new ChlomError(
    "CHLOM_RPC_PROVIDER_NOT_CONFIGURED",
    `No governed RPC endpoint is configured for ${chain}.`,
    503,
  );
}

export function classifyRpcMethod(method: string): "read" | "write" {
  if (PROHIBITED_RPC_PREFIXES.some((prefix) => method.startsWith(prefix))) {
    throw new ChlomError(
      "CHLOM_RPC_METHOD_PROHIBITED",
      `RPC namespace is prohibited: ${method}`,
      403,
    );
  }

  if (READ_ONLY_RPC_METHODS.has(method)) {
    return "read";
  }

  if (GOVERNED_WRITE_RPC_METHODS.has(method)) {
    return "write";
  }

  throw new ChlomError(
    "CHLOM_RPC_METHOD_NOT_ALLOWLISTED",
    `RPC method is not allowlisted: ${method}`,
    403,
  );
}

export async function callGovernedRpc(input: RpcInput) {
  assertChainKey(input.chain);
  const chain = input.chain;
  const definition = CHAIN_REGISTRY[chain];

  if (!definition.evm) {
    throw new ChlomError(
      "CHLOM_RPC_CHAIN_NOT_EVM",
      `JSON-RPC execution is not enabled for ${definition.displayName}.`,
      400,
    );
  }

  const params = input.params ?? [];
  const paramsBytes = Buffer.byteLength(JSON.stringify(params), "utf8");
  if (paramsBytes > MAX_RPC_PARAMS_BYTES) {
    throw new ChlomError(
      "CHLOM_RPC_PARAMS_TOO_LARGE",
      "RPC parameters exceed the governed payload limit.",
      413,
      { maximumBytes: MAX_RPC_PARAMS_BYTES },
    );
  }

  const mode = classifyRpcMethod(input.method);
  if (mode === "write" && !input.writeAuthorized) {
    throw new ChlomError(
      "CHLOM_RPC_WRITE_AUTHORITY_REQUIRED",
      "This RPC method requires exact CHLOM/ECAC write authority.",
      403,
    );
  }

  const provider = resolveRpcProvider(chain);
  const rpcRequest = {
    jsonrpc: "2.0",
    id: crypto.randomUUID(),
    method: input.method,
    params,
  };

  const response = await fetch(provider.endpoint, {
    method: "POST",
    headers: {
      "content-type": "application/json",
      "user-agent": "CrownThrive-CHLOM-Chain-Evidence-Fabric/1.0",
    },
    body: JSON.stringify(rpcRequest),
    cache: "no-store",
    signal: AbortSignal.timeout(15_000),
  });

  const rawText = await response.text();
  let rpcPayload: unknown;
  try {
    rpcPayload = JSON.parse(rawText);
  } catch {
    throw new ChlomError(
      "CHLOM_RPC_INVALID_RESPONSE",
      "RPC provider returned a non-JSON response.",
      502,
      { provider: provider.name, status: response.status },
    );
  }

  if (!response.ok) {
    throw new ChlomError(
      "CHLOM_RPC_PROVIDER_ERROR",
      "RPC provider rejected the request.",
      502,
      { provider: provider.name, status: response.status },
    );
  }

  const endpointFingerprint = sha256(provider.endpoint);
  return createEvidenceEnvelope({
    source: {
      kind: "rpc",
      provider: provider.name,
      chain,
      operation: input.method,
      endpointFingerprint,
    },
    request: {
      chain,
      method: input.method,
      params,
    },
    payload: {
      response: rpcPayload,
      provider: {
        name: provider.name,
        deprecated: provider.deprecated,
        sunset: provider.sunset,
      },
      expectedChainId: definition.chainIdHex,
    },
    write: mode === "write",
  });
}
