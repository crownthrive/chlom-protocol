import { maximumBytesBilled } from './config.js';
import { ChlomError } from './errors.js';
import { createEvidenceEnvelope } from './evidence.js';
import { getGoogleAccessToken } from './google-auth.js';
import { prepareAnalyticsQuery } from './analytics-templates.js';

function decodeCell(field, value) {
  if (value === null || value === undefined) {
    return null;
  }
  if (field.mode === 'REPEATED' && Array.isArray(value)) {
    return value.map((entry) => decodeCell({ ...field, mode: undefined }, entry?.v));
  }
  if (field.type === 'RECORD' && field.fields && typeof value === 'object') {
    const cells = value.f || [];
    return Object.fromEntries(
      field.fields.map((nested, index) => [nested.name, decodeCell(nested, cells[index]?.v)]),
    );
  }
  if (field.type === 'BOOL' || field.type === 'BOOLEAN') {
    return value === 'true' || value === true;
  }
  return value;
}

function decodeRows(fields, rows = []) {
  return rows.map((row) =>
    Object.fromEntries(
      fields.map((field, index) => [field.name, decodeCell(field, row.f[index]?.v)]),
    ),
  );
}

export async function runBlockchainAnalytics(input) {
  const prepared = prepareAnalyticsQuery(input);
  const projectId = process.env.GCP_PROJECT_ID;
  if (!projectId) {
    throw new ChlomError(
      'CHLOM_GCP_PROJECT_NOT_CONFIGURED',
      'GCP_PROJECT_ID is required for Blockchain Analytics queries.',
      503,
    );
  }
  const accessToken = await getGoogleAccessToken();
  const location = process.env.GCP_BIGQUERY_LOCATION || 'US';
  let response;
  try {
    response = await fetch(
      `https://bigquery.googleapis.com/bigquery/v2/projects/${encodeURIComponent(projectId)}/queries`,
      {
        method: 'POST',
        headers: {
          authorization: `Bearer ${accessToken}`,
          'content-type': 'application/json',
          'user-agent': 'CrownThrive-CHLOM-Chain-Evidence-Fabric/1.1',
        },
        body: JSON.stringify({
          query: prepared.query,
          useLegacySql: false,
          parameterMode: 'NAMED',
          queryParameters: prepared.parameters,
          location,
          timeoutMs: 25_000,
          maximumBytesBilled: maximumBytesBilled(),
          labels: {
            system: 'chlom',
            component: 'chain_evidence_fabric',
            template: prepared.template,
          },
        }),
        cache: 'no-store',
        signal: AbortSignal.timeout(30_000),
      },
    );
  } catch (error) {
    throw new ChlomError(
      'CHLOM_BIGQUERY_UNREACHABLE',
      'Google BigQuery could not be reached.',
      502,
      { reason: String(error?.message || error) },
    );
  }
  const payload = await response.json();
  if (!response.ok || payload.errors?.length) {
    throw new ChlomError(
      'CHLOM_BIGQUERY_QUERY_FAILED',
      'Google Blockchain Analytics query failed.',
      502,
      {
        status: response.status,
        errors: payload.errors,
        template: prepared.template,
        chain: prepared.chain,
      },
    );
  }
  if (payload.jobComplete === false) {
    throw new ChlomError(
      'CHLOM_BIGQUERY_QUERY_PENDING',
      'Blockchain Analytics query did not complete inside the governed timeout.',
      504,
      { template: prepared.template, chain: prepared.chain },
    );
  }
  const fields = payload.schema?.fields || [];
  const rows = decodeRows(fields, payload.rows);
  return createEvidenceEnvelope({
    source: {
      kind: 'google_blockchain_analytics',
      provider: 'google-bigquery-blockchain-analytics',
      chain: prepared.chain,
      operation: prepared.template,
    },
    request: {
      chain: prepared.chain,
      template: prepared.template,
      limit: prepared.limit,
      lookbackDays: prepared.lookbackDays,
      parameters: prepared.parameters.map((entry) => entry.name),
    },
    payload: {
      dataset: prepared.dataset,
      location,
      rowCount: rows.length,
      totalRows: payload.totalRows || String(rows.length),
      totalBytesProcessed: payload.totalBytesProcessed || null,
      cacheHit: payload.cacheHit || false,
      rows,
    },
  });
}
