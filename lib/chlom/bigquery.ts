import { maximumBytesBilled } from "./config";
import { ChlomError } from "./errors";
import { createEvidenceEnvelope } from "./evidence";
import { getGoogleAccessToken } from "./google-auth";
import {
  prepareAnalyticsQuery,
  type AnalyticsInput,
  type QueryParameter,
} from "./analytics-templates";

type BigQueryField = {
  name: string;
  type: string;
  mode?: string;
  fields?: BigQueryField[];
};

type BigQueryCell = { v: unknown };
type BigQueryRow = { f: BigQueryCell[] };

type BigQueryResponse = {
  jobComplete?: boolean;
  totalRows?: string;
  totalBytesProcessed?: string;
  cacheHit?: boolean;
  schema?: { fields?: BigQueryField[] };
  rows?: BigQueryRow[];
  errors?: Array<{ reason?: string; message?: string }>;
};

function decodeCell(field: BigQueryField, value: unknown): unknown {
  if (value === null || value === undefined) {
    return null;
  }

  if (field.mode === "REPEATED" && Array.isArray(value)) {
    return value.map((entry) =>
      decodeCell(
        { ...field, mode: undefined },
        (entry as { v?: unknown }).v,
      ),
    );
  }

  if (field.type === "RECORD" && field.fields && typeof value === "object") {
    const cells = (value as { f?: BigQueryCell[] }).f ?? [];
    return Object.fromEntries(
      field.fields.map((nestedField, index) => [
        nestedField.name,
        decodeCell(nestedField, cells[index]?.v),
      ]),
    );
  }

  if (field.type === "BOOL" || field.type === "BOOLEAN") {
    return value === "true" || value === true;
  }

  return value;
}

function decodeRows(
  fields: BigQueryField[],
  rows: BigQueryRow[] = [],
): Record<string, unknown>[] {
  return rows.map((row) =>
    Object.fromEntries(
      fields.map((field, index) => [
        field.name,
        decodeCell(field, row.f[index]?.v),
      ]),
    ),
  );
}

function queryParameters(parameters: QueryParameter[]) {
  return parameters.map((parameter) => ({
    name: parameter.name,
    parameterType: parameter.parameterType,
    parameterValue: parameter.parameterValue,
  }));
}

export async function runBlockchainAnalytics(input: AnalyticsInput) {
  const prepared = prepareAnalyticsQuery(input);
  const projectId = process.env.GCP_PROJECT_ID;

  if (!projectId) {
    throw new ChlomError(
      "CHLOM_GCP_PROJECT_NOT_CONFIGURED",
      "GCP_PROJECT_ID is required for Blockchain Analytics queries.",
      503,
    );
  }

  const accessToken = await getGoogleAccessToken();
  const location = process.env.GCP_BIGQUERY_LOCATION ?? "US";
  const response = await fetch(
    `https://bigquery.googleapis.com/bigquery/v2/projects/${encodeURIComponent(projectId)}/queries`,
    {
      method: "POST",
      headers: {
        authorization: `Bearer ${accessToken}`,
        "content-type": "application/json",
        "user-agent": "CrownThrive-CHLOM-Chain-Evidence-Fabric/1.0",
      },
      body: JSON.stringify({
        query: prepared.query,
        useLegacySql: false,
        parameterMode: "NAMED",
        queryParameters: queryParameters(prepared.parameters),
        location,
        timeoutMs: 25_000,
        maximumBytesBilled: maximumBytesBilled(),
        labels: {
          system: "chlom",
          component: "chain_evidence_fabric",
          template: prepared.template.replaceAll("-", "_"),
        },
      }),
      cache: "no-store",
      signal: AbortSignal.timeout(30_000),
    },
  );

  const payload = (await response.json()) as BigQueryResponse;
  if (!response.ok || payload.errors?.length) {
    throw new ChlomError(
      "CHLOM_BIGQUERY_QUERY_FAILED",
      "Google Blockchain Analytics query failed.",
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
      "CHLOM_BIGQUERY_QUERY_PENDING",
      "Blockchain Analytics query did not complete inside the governed timeout.",
      504,
      { template: prepared.template, chain: prepared.chain },
    );
  }

  const fields = payload.schema?.fields ?? [];
  const rows = decodeRows(fields, payload.rows);

  return createEvidenceEnvelope({
    source: {
      kind: "google_blockchain_analytics",
      provider: "google-bigquery-blockchain-analytics",
      chain: prepared.chain,
      operation: prepared.template,
    },
    request: {
      chain: prepared.chain,
      template: prepared.template,
      limit: prepared.limit,
      lookbackDays: prepared.lookbackDays,
      parameters: prepared.parameters.map((parameter) => parameter.name),
    },
    payload: {
      dataset: prepared.dataset,
      location,
      rowCount: rows.length,
      totalRows: payload.totalRows ?? String(rows.length),
      totalBytesProcessed: payload.totalBytesProcessed ?? null,
      cacheHit: payload.cacheHit ?? false,
      rows,
    },
  });
}
