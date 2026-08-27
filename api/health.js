const CHAIN_SUFFIXES = [
  'BASE',
  'BASE_SEPOLIA',
  'ETHEREUM',
  'ARBITRUM',
  'AVALANCHE',
  'CRONOS',
  'FANTOM',
  'OPTIMISM',
  'POLYGON',
  'TRON'
];

const RPC_PREFIXES = [
  'CHLOM_RPC_',
  'QUICKNODE_RPC_',
  'GOOGLE_BLOCKCHAIN_RPC_',
  'ALCHEMY_RPC_',
  'INFURA_RPC_'
];

const GOOGLE_CONFIGURATION = [
  'GCP_PROJECT_ID',
  'GCP_PROJECT_NUMBER',
  'GCP_SERVICE_ACCOUNT_EMAIL',
  'GCP_WORKLOAD_IDENTITY_POOL_ID',
  'GCP_WORKLOAD_IDENTITY_POOL_PROVIDER_ID'
];

function configuredRpcChains() {
  return CHAIN_SUFFIXES.filter((chain) =>
    RPC_PREFIXES.some((prefix) => Boolean(process.env[`${prefix}${chain}`]))
  ).map((chain) => chain.toLowerCase().replaceAll('_', '-'));
}

export default function handler(request, response) {
  const environment = process.env.VERCEL_ENV || 'local';
  const rpcChains = configuredRpcChains();
  const googleAnalyticsConfigured = GOOGLE_CONFIGURATION.every((key) =>
    Boolean(process.env[key])
  );
  const apiTokenConfigured = Boolean(process.env.CHLOM_API_TOKEN);
  const ready =
    apiTokenConfigured && (googleAnalyticsConfigured || rpcChains.length > 0);

  response.setHeader('Cache-Control', 'no-store, max-age=0');
  response.setHeader('Content-Type', 'application/json; charset=utf-8');
  response.setHeader('X-Content-Type-Options', 'nosniff');
  response.setHeader('X-Frame-Options', 'DENY');
  response.setHeader('Referrer-Policy', 'no-referrer');

  if (!['GET', 'HEAD'].includes(request.method)) {
    return response.status(405).json({
      schema: 'ct.penta.error.v1',
      service: 'chlom-protocol',
      status: 'WRITE_GATED',
      pass_manufactured: false
    });
  }

  const payload = {
    schema: 'ct.chlom.chain-evidence-fabric.health.v1',
    service: 'chlom-protocol',
    role: 'rights_rules_roles_revenue_records_remedies_authority',
    status: ready ? 'READY' : 'CONFIGURATION_HOLD',
    release: environment === 'production' ? 'production' : 'candidate',
    environment,
    provider_state: environment === 'local'
      ? 'BINDING_REQUIRED'
      : `BOUND_${environment.toUpperCase()}`,
    project_id: 'prj_HewLgMjUiVBNCl0FADFbSggSp2QN',
    repository: 'crownthrive1/chlom-protocol',
    build_sha: process.env.VERCEL_GIT_COMMIT_SHA || 'local-candidate',
    deployment_id: process.env.VERCEL_DEPLOYMENT_ID || null,
    readiness: {
      apiTokenConfigured,
      googleAnalyticsConfigured,
      googleAnalyticsLocation: process.env.GCP_BIGQUERY_LOCATION || 'US',
      configuredRpcChains: rpcChains,
      governanceState: process.env.CHLOM_GOVERNANCE_STATE || 'hold',
      chainWriteEnabled: process.env.CHLOM_CHAIN_WRITE_ENABLED === 'true',
      ecacConfigured: Boolean(process.env.CHLOM_ECAC_DIGEST)
    },
    boundaries: {
      privateKeysAccepted: false,
      arbitrarySqlAccepted: false,
      arbitraryRpcEndpointAccepted: false,
      rpcReadAllowlist: true,
      chainBroadcastFailClosed: true
    },
    provider_notice: {
      googleBlockchainRpcStatus: 'TRANSITIONAL_DEPRECATED',
      googleBlockchainRpcSunset: '2026-12-15',
      durableGoogleLane: 'Blockchain Analytics / BigQuery'
    },
    capabilities: [
      'identity-and-rights-boundary',
      'policy-and-governance-contracts',
      'consent-and-provenance',
      'licensing-and-revenue-rules',
      'provider-neutral-rpc',
      'google-blockchain-analytics',
      'chlom-evidence-envelopes',
      'dail-projections',
      'mcp-streamable-http'
    ],
    endpoints: {
      rest: ['/api/v1/rpc', '/api/v1/analytics', '/api/v1/attest'],
      mcp: '/api/mcp'
    },
    provider_readback: environment !== 'local',
    write_state: 'GATED',
    pass_manufactured: false,
    observed_at: new Date().toISOString()
  };

  if (request.method === 'HEAD') {
    return response.status(ready ? 200 : 503).end();
  }

  return response.status(ready ? 200 : 503).json(payload);
}
