import {
  CHAIN_REGISTRY,
  assertChainKey,
  type ChainKey,
} from "./chains";
import {
  MAX_ANALYTICS_LOOKBACK_DAYS,
  MAX_ANALYTICS_ROWS,
} from "./constants";
import { ChlomError } from "./errors";

export type AnalyticsTemplate =
  | "latest_block"
  | "transaction_evidence"
  | "address_activity"
  | "contract_logs";

export type AnalyticsInput = {
  chain: string;
  template: AnalyticsTemplate;
  transactionHash?: string;
  address?: string;
  lookbackDays?: number;
  limit?: number;
};

export type QueryParameter = {
  name: string;
  parameterType: { type: "STRING" | "INT64" | "TIMESTAMP" };
  parameterValue: { value: string };
};

export type PreparedAnalyticsQuery = {
  chain: ChainKey;
  template: AnalyticsTemplate;
  dataset: string;
  query: string;
  parameters: QueryParameter[];
  limit: number;
  lookbackDays: number;
};

function requireHex(value: string | undefined, field: string): string {
  if (!value || !/^0x[0-9a-fA-F]+$/.test(value)) {
    throw new ChlomError(
      "CHLOM_ANALYTICS_INPUT_INVALID",
      `${field} must be a 0x-prefixed hexadecimal value.`,
      400,
    );
  }
  return value.toLowerCase();
}

export function prepareAnalyticsQuery(
  input: AnalyticsInput,
): PreparedAnalyticsQuery {
  assertChainKey(input.chain);
  const chain = input.chain;
  const definition = CHAIN_REGISTRY[chain];
  const dataset = definition.analyticsDataset;

  if (!dataset) {
    throw new ChlomError(
      "CHLOM_ANALYTICS_DATASET_UNAVAILABLE",
      `Google Blockchain Analytics is not registered for ${definition.displayName}.`,
      400,
    );
  }

  const limit = Math.min(
    Math.max(Math.trunc(input.limit ?? 50), 1),
    MAX_ANALYTICS_ROWS,
  );
  const lookbackDays = Math.min(
    Math.max(Math.trunc(input.lookbackDays ?? 7), 1),
    MAX_ANALYTICS_LOOKBACK_DAYS,
  );
  const startTimestamp = new Date(
    Date.now() - lookbackDays * 86_400_000,
  ).toISOString();

  const commonParameters: QueryParameter[] = [
    {
      name: "limit",
      parameterType: { type: "INT64" },
      parameterValue: { value: String(limit) },
    },
  ];

  if (input.template === "latest_block") {
    return {
      chain,
      template: input.template,
      dataset,
      limit: 1,
      lookbackDays,
      parameters: [],
      query: `
        SELECT
          MIN(block_number) AS first_block,
          MAX(block_number) AS newest_block,
          COUNT(1) AS indexed_blocks
        FROM \`${dataset}.blocks\`
      `.trim(),
    };
  }

  if (input.template === "transaction_evidence") {
    const transactionHash = requireHex(
      input.transactionHash,
      "transactionHash",
    );
    return {
      chain,
      template: input.template,
      dataset,
      limit: 1,
      lookbackDays,
      parameters: [
        {
          name: "transaction_hash",
          parameterType: { type: "STRING" },
          parameterValue: { value: transactionHash },
        },
      ],
      query: `
        SELECT
          tx.block_number,
          tx.block_hash,
          tx.block_timestamp,
          tx.transaction_hash,
          tx.transaction_index,
          tx.from_address,
          tx.to_address,
          tx.value.bignumeric_value AS value_wei,
          tx.gas,
          tx.gas_price,
          receipt.status,
          receipt.gas_used,
          receipt.contract_address
        FROM \`${dataset}.transactions\` AS tx
        LEFT JOIN \`${dataset}.receipts\` AS receipt
          USING (block_hash, transaction_hash)
        WHERE tx.transaction_hash = @transaction_hash
        LIMIT 1
      `.trim(),
    };
  }

  const address = requireHex(input.address, "address");
  const parameters: QueryParameter[] = [
    ...commonParameters,
    {
      name: "address",
      parameterType: { type: "STRING" },
      parameterValue: { value: address },
    },
    {
      name: "start_timestamp",
      parameterType: { type: "TIMESTAMP" },
      parameterValue: { value: startTimestamp },
    },
  ];

  if (input.template === "address_activity") {
    return {
      chain,
      template: input.template,
      dataset,
      limit,
      lookbackDays,
      parameters,
      query: `
        SELECT
          block_number,
          block_hash,
          block_timestamp,
          transaction_hash,
          transaction_index,
          from_address,
          to_address,
          value.bignumeric_value AS value_wei,
          gas,
          gas_price
        FROM \`${dataset}.transactions\`
        WHERE block_timestamp >= @start_timestamp
          AND (
            from_address = @address
            OR to_address = @address
          )
        ORDER BY block_timestamp DESC
        LIMIT @limit
      `.trim(),
    };
  }

  if (input.template === "contract_logs") {
    return {
      chain,
      template: input.template,
      dataset,
      limit,
      lookbackDays,
      parameters,
      query: `
        SELECT
          block_number,
          block_hash,
          block_timestamp,
          transaction_hash,
          transaction_index,
          log_index,
          address,
          data,
          topics
        FROM \`${dataset}.logs\`
        WHERE block_timestamp >= @start_timestamp
          AND address = @address
        ORDER BY block_timestamp DESC, log_index DESC
        LIMIT @limit
      `.trim(),
    };
  }

  throw new ChlomError(
    "CHLOM_ANALYTICS_TEMPLATE_NOT_ALLOWLISTED",
    `Analytics template is not allowlisted: ${String(input.template)}`,
    403,
  );
}
