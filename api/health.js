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

function configurationHolds({
  apiTokenConfigured,
  googleAnalyticsConfigured,
  rpcChains,
  governanceState,
  ecacConfigured
}) {
  const holds = [];
  if (!apiTokenConfigured) holds.push('CHLOM_API_TOKEN');
  if (!googleAnalyticsConfigured && rpcChains.length === 0) {
    holds.push('CHAIN_OR_ANALYTICS_PROVIDER');
  }
  if (governanceState !== 'promoted') holds.push('CHLOM_GOVERNANCE_STATE');
  if (!ecacConfigured) holds.push('CHLOM_ECAC_DIGEST');
  return holds;
}

export default function handler(request, response) {
  const environment = process.env.VERCEL_ENV || 'local';
  const providerReadback = environment !== 'local';
  const rpcChains = configuredRpcChains();
  const googleAnalyticsConfigured = GOOGLE_CONFIGURATION.every((key) =>
    Boolean(process.env[key])
  );
  const apiTokenConfigured = Boolean(process.env.CHLOM_API_TOKEN);
  const governanceState = process.env.CHLOM_GOVERNANCE_STATE || 'hold';
  const ecacConfigured = Boolean(process.env.CHLOM_ECAC_DIGEST);
  const dataPlaneReady =
    apiTokenConfigured &&
    (googleAnalyticsConfigured || rpcChains.length > 0) &&
    governanceState === 'promoted' &&
    ecacConfigured;
  const holds = configurationHolds({
    apiTokenConfigured,
    googleAnalyticsConfigured,
    rpcChains,
    governanceState,
    ecacConfigured
  });

  response.setHeader('Cache-Control', 'no-store, max-age=0');
  response.setHeader('Content-Type', 'application/json; charset=utf-8');
  response.setHeader('X-Content-Type-Options', 'nosniff');
  response.setHeader('X-Frame-Options', 'DENY');
  response.setHeader('Referrer-Policy', 'no-referrer');
  response.setHeader(
    'X-CHLOM-Readiness',
    dataPlaneReady ? 'READY' : 'CONFIGURATION_HOLD'
  );

  if (!['GET', 'HEAD'].includes(request.method)) {
    return response.status(405).json({
      schema: 'ct.penta.error.v1',
      service: 'chlom-protocol',
      status: 'WRITE_GATED',
      pass_manufactured: false
    });
  }

  const payload = {
    schema: 'ct.chlom.chain-evidence-fabric.health.v2',
    service: 'chlom-protocol',
    role: 'rights_rules_roles_revenue_records_remedies_authority',
    status: providerReadback ? 'OPERATIONAL' : 'BINDING_REQUIRED',
    operating_mode: dataPlaneReady
      ? 'FULL_GOVERNED_DATA_PLANE'
      : 'GOVERNANCE_CONTROL_PLANE_ONLY',
    release: environment === 'production' ? 'production' : 'candidate',
    environment,
    provider_state: providerReadback
      ? `BOUND_${environment.toUpperCase()}`
      : 'BINDING_REQUIRED',
    project_id: 'prj_HewLgMjUiVBNCl0FADFbSggSp2QN',
    repository: 'crownthrive1/chlom-protocol',
    build_sha: process.env.VERCEL_GIT_COMMIT_SHA || 'local-candidate',
    deployment_id: process.env.VERCEL_DEPLOYMENT_ID || null,
    readiness_status: dataPlaneReady ? 'READY' : 'CONFIGURATION_HOLD',
    readiness: {
      apiTokenConfigured,
      googleAnalyticsConfigured,
      googleAnalyticsLocation: process.env.GCP_BIGQUERY_LOCATION || 'US',
      configuredRpcChains: rpcChains,
      governanceState,
      chainWriteEnabled: process.env.CHLOM_CHAIN_WRITE_ENABLED === 'true',
      ecacConfigured,
      holds
    },
    capability_states: {
      governance_and_rights: 'OPERATIONAL',
      provider_liveness: providerReadback ? 'OPERATIONAL' : 'HOLD',
      authenticated_api: apiTokenConfigured ? 'BOUND' : 'GATED',
      rpc_read_lane: rpcChains.length > 0 ? 'BOUND' : 'GATED',
      blockchain_analytics: googleAnalyticsConfigured ? 'BOUND' : 'GATED',
      chain_broadcast:
        process.env.CHLOM_CHAIN_WRITE_ENABLED === 'true' &&
        governanceState === 'promoted' &&
        ecacConfigured
          ? 'BOUND_GOVERNED'
          : 'GATED'
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
      health: '/health',
      rest: ['/api/v1/rpc', '/api/v1/analytics', '/api/v1/attest'],
      mcp: '/api/mcp'
    },
    provider_readback: providerReadback,
    write_state: 'GATED',
    pass_manufactured: false,
    observed_at: new Date().toISOString()
  };

  if (request.method === 'HEAD') {
    return response.status(providerReadback ? 200 : 503).end();
  }

  return response.status(providerReadback ? 200 : 503).json(payload);
}
