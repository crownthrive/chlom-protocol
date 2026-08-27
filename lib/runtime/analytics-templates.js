import { CHAIN_REGISTRY } from './chains.js';
import { ChlomError } from './errors.js';

function requireHex(value, field) {
  if (!value || !/^0x[0-9a-fA-F]+$/.test(value)) {
    throw new ChlomError(
      'CHLOM_ANALYTICS_INPUT_INVALID',
      `${field} must be a 0x-prefixed hexadecimal value.`,
      400,
    );
  }
  return value.toLowerCase();
}

function parameter(name, type, value) {
  return {
    name,
    parameterType: { type },
    parameterValue: { value: String(value) },
  };
}

export function prepareAnalyticsQuery(input) {
  const definition = CHAIN_REGISTRY[input.chain];
  const dataset = definition?.analyticsDataset;
  if (!dataset) {
    throw new ChlomError(
      'CHLOM_ANALYTICS_DATASET_UNAVAILABLE',
      `Google Blockchain Analytics is not registered for ${definition?.displayName || input.chain}.`,
      400,
    );
  }
  const limit = input.template === 'latest_block' || input.template === 'transaction_evidence'
    ? 1
    : input.limit;
  const lookbackDays = input.lookbackDays;
  const startTimestamp = new Date(Date.now() - lookbackDays * 86_400_000).toISOString();

  if (input.template === 'latest_block') {
    return {
      chain: input.chain,
      template: input.template,
      dataset,
      limit: 1,
      lookbackDays,
      parameters: [parameter('start_timestamp', 'TIMESTAMP', startTimestamp)],
      query: `
        SELECT
          MIN(block_number) AS first_block_in_window,
          MAX(block_number) AS newest_block,
          COUNT(1) AS indexed_blocks_in_window
        FROM \`${dataset}.blocks\`
        WHERE block_timestamp >= @start_timestamp
      `.trim(),
    };
  }

  if (input.template === 'transaction_evidence') {
    const transactionHash = requireHex(input.transactionHash, 'transactionHash');
    return {
      chain: input.chain,
      template: input.template,
      dataset,
      limit: 1,
      lookbackDays,
      parameters: [
        parameter('transaction_hash', 'STRING', transactionHash),
        parameter('start_timestamp', 'TIMESTAMP', startTimestamp),
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
        WHERE tx.block_timestamp >= @start_timestamp
          AND tx.transaction_hash = @transaction_hash
        LIMIT 1
      `.trim(),
    };
  }

  const address = requireHex(input.address, 'address');
  const parameters = [
    parameter('limit', 'INT64', limit),
    parameter('address', 'STRING', address),
    parameter('start_timestamp', 'TIMESTAMP', startTimestamp),
  ];

  if (input.template === 'address_activity') {
    return {
      chain: input.chain,
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
          AND (from_address = @address OR to_address = @address)
        ORDER BY block_timestamp DESC
        LIMIT @limit
      `.trim(),
    };
  }

  if (input.template === 'contract_logs') {
    return {
      chain: input.chain,
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
    'CHLOM_ANALYTICS_TEMPLATE_NOT_ALLOWLISTED',
    `Analytics template is not allowlisted: ${String(input.template)}`,
    403,
  );
}
