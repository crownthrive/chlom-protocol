import {
  CHLOM_RUNTIME_SCHEMA,
  GOOGLE_RPC_SUNSET,
  MCP_LATEST_PROTOCOL_VERSION,
  MCP_SUPPORTED_PROTOCOL_VERSIONS,
} from '../lib/runtime/constants.js';
import { runtimeReadiness } from '../lib/runtime/config.js';
import { sendJson, sendEmpty } from '../lib/runtime/http.js';

function configurationHolds(readiness) {
  const holds = [];
  if (!readiness.apiTokenConfigured) holds.push('CHLOM_API_TOKEN');
  if (!readiness.googleAnalyticsConfigured && readiness.configuredRpcChains.length === 0) {
    holds.push('CHAIN_OR_ANALYTICS_PROVIDER');
  }
  if (readiness.governanceState !== 'promoted') holds.push('CHLOM_GOVERNANCE_STATE');
  if (!readiness.ecacConfigured) holds.push('CHLOM_ECAC_DIGEST');
  return holds;
}

export default function handler(request, response) {
  if (!['GET', 'HEAD'].includes(request.method)) {
    response.setHeader('Allow', 'GET, HEAD');
    return sendJson(response, 405, {
      schema: 'ct.penta.error.v1',
      service: 'chlom-protocol',
      status: 'WRITE_GATED',
      passManufactured: false,
      pass_manufactured: false,
      error: { code: 'METHOD_NOT_ALLOWED', message: 'Only GET and HEAD are supported.' },
    });
  }

  const environment = process.env.VERCEL_ENV || 'local';
  const providerReadback = environment !== 'local';
  const readiness = runtimeReadiness();
  const holds = configurationHolds(readiness);
  const dataPlaneReady = holds.length === 0;
  const chainBroadcastBound =
    readiness.chainWriteEnabled &&
    readiness.governanceState === 'promoted' &&
    readiness.ecacConfigured;
  const readinessStatus = dataPlaneReady ? 'READY' : 'CONFIGURATION_HOLD';
  const operatingMode = dataPlaneReady
    ? 'FULL_GOVERNED_DATA_PLANE'
    : 'GOVERNANCE_CONTROL_PLANE_ONLY';
  const providerState = providerReadback
    ? `BOUND_${environment.toUpperCase()}`
    : 'BINDING_REQUIRED';
  const projectId = 'prj_HewLgMjUiVBNCl0FADFbSggSp2QN';
  const buildSha = process.env.VERCEL_GIT_COMMIT_SHA || 'local-candidate';
  const deploymentId = process.env.VERCEL_DEPLOYMENT_ID || null;
  const observedAt = new Date().toISOString();
  const capabilityStates = {
    governanceAndRights: 'OPERATIONAL',
    providerLiveness: providerReadback ? 'OPERATIONAL' : 'HOLD',
    authenticatedApi: readiness.apiTokenConfigured ? 'BOUND' : 'GATED',
    rpcReadLane: readiness.configuredRpcChains.length > 0 ? 'BOUND' : 'GATED',
    blockchainAnalytics: readiness.googleAnalyticsConfigured ? 'BOUND' : 'GATED',
    chainBroadcast: chainBroadcastBound ? 'BOUND_GOVERNED' : 'GATED',
  };

  response.setHeader('X-CHLOM-Readiness', readinessStatus);

  const payload = {
    ok: true,
    schema: 'ct.chlom.chain-evidence-fabric.health.v2',
    runtimeSchema: CHLOM_RUNTIME_SCHEMA,
    service: 'CHLOM Chain Evidence Fabric',
    canonicalService: 'chlom-protocol',
    role: 'rights_rules_roles_revenue_records_remedies_authority',
    version: '1.1.1',
    status: providerReadback ? 'OPERATIONAL' : 'BINDING_REQUIRED',
    readinessStatus,
    readiness_status: readinessStatus,
    operatingMode,
    operating_mode: operatingMode,
    release: environment === 'production' ? 'production' : 'candidate',
    environment,
    providerState,
    provider_state: providerState,
    projectId,
    project_id: projectId,
    repository: 'crownthrive1/chlom-protocol',
    buildSha,
    build_sha: buildSha,
    deploymentId,
    deployment_id: deploymentId,
    observedAt,
    observed_at: observedAt,
    readiness: {
      ...readiness,
      holds,
    },
    capabilityStates,
    capability_states: {
      governance_and_rights: capabilityStates.governanceAndRights,
      provider_liveness: capabilityStates.providerLiveness,
      authenticated_api: capabilityStates.authenticatedApi,
      rpc_read_lane: capabilityStates.rpcReadLane,
      blockchain_analytics: capabilityStates.blockchainAnalytics,
      chain_broadcast: capabilityStates.chainBroadcast,
    },
    boundaries: {
      privateKeysAccepted: false,
      arbitrarySqlAccepted: false,
      arbitraryRpcEndpointAccepted: false,
      rpcReadAllowlist: true,
      chainBroadcastFailClosed: true,
    },
    providerNotice: {
      googleBlockchainRpcStatus: 'TRANSITIONAL_DEPRECATED',
      googleBlockchainRpcSunset: GOOGLE_RPC_SUNSET,
      durableGoogleLane: 'Blockchain Analytics / BigQuery',
    },
    mcp: {
      endpoint: '/api/mcp',
      latestProtocolVersion: MCP_LATEST_PROTOCOL_VERSION,
      supportedProtocolVersions: MCP_SUPPORTED_PROTOCOL_VERSIONS,
      transport: 'streamable_http_stateless',
      chainBroadcastToolExposed: false,
    },
    endpoints: {
      health: '/health',
      rest: ['/api/v1/rpc', '/api/v1/analytics', '/api/v1/attest'],
      mcp: '/api/mcp',
    },
    providerReadback,
    provider_readback: providerReadback,
    writeState: 'GATED',
    write_state: 'GATED',
    passManufactured: false,
    pass_manufactured: false,
  };

  if (request.method === 'HEAD') {
    return sendEmpty(response, providerReadback ? 200 : 503);
  }
  return sendJson(response, providerReadback ? 200 : 503, payload);
}
