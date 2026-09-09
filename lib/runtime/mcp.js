import {
  MCP_ERROR,
  MCP_LATEST_PROTOCOL_VERSION,
  MCP_LEGACY_PROTOCOL_VERSION,
  MCP_SUPPORTED_PROTOCOL_VERSIONS,
} from './constants.js';
import { runtimeReadiness } from './config.js';
import { ChlomError, normalizeError } from './errors.js';
import { prepareAnchorIntent } from './evidence.js';
import { runBlockchainAnalytics } from './bigquery.js';
import { callGovernedRpc, classifyRpcMethod } from './rpc.js';
import { parseAnalyticsInput, parseAnchorInput, parseRpcInput } from './validators.js';

export const MCP_SERVER_INFO = Object.freeze({
  name: 'crownthrive-chlom-chain-evidence-fabric',
  title: 'CHLOM Chain Evidence Fabric',
  version: '1.1.0',
  description:
    'Governed blockchain RPC, Google Blockchain Analytics, CHLOM evidence, and DAIL projection tools.',
  websiteUrl: 'https://chlom-protocol.vercel.app',
});

const OBJECT_SCHEMA = {
  type: 'object',
  additionalProperties: true,
};

export const MCP_TOOLS = Object.freeze([
  {
    name: 'chlom_provider_status',
    title: 'CHLOM Provider Status',
    description:
      'Reports configured CHLOM RPC, Google Blockchain Analytics, governance, and authority readiness without disclosing credentials.',
    inputSchema: { type: 'object', additionalProperties: false },
    outputSchema: OBJECT_SCHEMA,
    annotations: {
      readOnlyHint: true,
      destructiveHint: false,
      idempotentHint: true,
      openWorldHint: false,
    },
  },
  {
    name: 'chlom_chain_read',
    title: 'CHLOM Governed Chain Read',
    description:
      'Executes one allowlisted read-only JSON-RPC method against a server-configured provider and returns a CHLOM evidence envelope.',
    inputSchema: {
      type: 'object',
      additionalProperties: false,
      properties: {
        chain: {
          type: 'string',
          enum: ['base', 'base-sepolia', 'ethereum', 'arbitrum', 'avalanche', 'cronos', 'fantom', 'optimism', 'polygon'],
        },
        method: { type: 'string', minLength: 1, maxLength: 128 },
        params: { type: 'array', maxItems: 64, default: [] },
      },
      required: ['chain', 'method'],
    },
    outputSchema: OBJECT_SCHEMA,
    annotations: {
      readOnlyHint: true,
      destructiveHint: false,
      idempotentHint: true,
      openWorldHint: true,
    },
  },
  {
    name: 'chlom_verify_transaction',
    title: 'CHLOM Verify Transaction',
    description:
      'Reads an EVM transaction receipt through the governed RPC fabric and returns deterministic evidence.',
    inputSchema: {
      type: 'object',
      additionalProperties: false,
      properties: {
        chain: {
          type: 'string',
          enum: ['base', 'base-sepolia', 'ethereum', 'arbitrum', 'avalanche', 'cronos', 'fantom', 'optimism', 'polygon'],
        },
        transactionHash: { type: 'string', pattern: '^0x[0-9a-fA-F]+$' },
      },
      required: ['chain', 'transactionHash'],
    },
    outputSchema: OBJECT_SCHEMA,
    annotations: {
      readOnlyHint: true,
      destructiveHint: false,
      idempotentHint: true,
      openWorldHint: true,
    },
  },
  {
    name: 'chlom_query_blockchain_analytics',
    title: 'CHLOM Google Blockchain Analytics',
    description:
      'Runs one bounded, allowlisted Google Blockchain Analytics query template through BigQuery and returns CHLOM evidence.',
    inputSchema: {
      type: 'object',
      additionalProperties: false,
      properties: {
        chain: {
          type: 'string',
          enum: ['ethereum', 'arbitrum', 'avalanche', 'cronos', 'fantom', 'optimism', 'polygon', 'tron'],
        },
        template: {
          type: 'string',
          enum: ['latest_block', 'transaction_evidence', 'address_activity', 'contract_logs'],
        },
        transactionHash: { type: 'string' },
        address: { type: 'string' },
        lookbackDays: { type: 'integer', minimum: 1, maximum: 31, default: 7 },
        limit: { type: 'integer', minimum: 1, maximum: 250, default: 50 },
      },
      required: ['chain', 'template'],
    },
    outputSchema: OBJECT_SCHEMA,
    annotations: {
      readOnlyHint: true,
      destructiveHint: false,
      idempotentHint: true,
      openWorldHint: true,
    },
  },
  {
    name: 'chlom_prepare_evidence_anchor',
    title: 'CHLOM Prepare Evidence Anchor',
    description:
      'Creates a deterministic, non-broadcast anchor intent for a CHLOM evidence digest. It never submits a transaction.',
    inputSchema: {
      type: 'object',
      additionalProperties: false,
      properties: {
        evidenceDigest: { type: 'string', pattern: '^[0-9a-f]{64}$' },
        targetChain: { type: 'string', enum: ['base', 'base-sepolia', 'ethereum'] },
      },
      required: ['evidenceDigest', 'targetChain'],
    },
    outputSchema: OBJECT_SCHEMA,
    annotations: {
      readOnlyHint: true,
      destructiveHint: false,
      idempotentHint: true,
      openWorldHint: false,
    },
  },
]);

function serverMeta() {
  return { 'io.modelcontextprotocol/serverInfo': MCP_SERVER_INFO };
}

function successResult(result) {
  return {
    resultType: 'complete',
    ...result,
    _meta: {
      ...(result?._meta || {}),
      ...serverMeta(),
    },
  };
}

export function mcpResponse(id, result) {
  return { jsonrpc: '2.0', id, result };
}

export function mcpError(id, code, message, data = undefined) {
  return {
    jsonrpc: '2.0',
    id: id ?? null,
    error: {
      code,
      message,
      ...(data === undefined ? {} : { data }),
    },
  };
}

function headerValue(headers, name) {
  const value = headers?.[name.toLowerCase()];
  return Array.isArray(value) ? value[0] : value;
}

function decodeMirroredHeader(value) {
  if (typeof value !== 'string') {
    return value;
  }
  const match = value.match(/^=\?base64\?([A-Za-z0-9+/=]+)\?=$/);
  if (!match) {
    return value;
  }
  try {
    return Buffer.from(match[1], 'base64').toString('utf8');
  } catch {
    throw new ChlomError('MCP_HEADER_MALFORMED', 'An MCP mirrored header is malformed.', 400);
  }
}

function requestProtocol(body) {
  return body?.params?._meta?.['io.modelcontextprotocol/protocolVersion'];
}

function validateModernMetadata(headers, body) {
  const protocolVersion = requestProtocol(body);
  const headerProtocol = headerValue(headers, 'mcp-protocol-version');
  const methodHeader = decodeMirroredHeader(headerValue(headers, 'mcp-method'));
  if (!headerProtocol || !methodHeader) {
    throw new ChlomError(
      'MCP_HEADER_MISMATCH',
      'Required MCP routing headers are missing.',
      400,
      { mcpCode: MCP_ERROR.HEADER_MISMATCH },
    );
  }
  if (headerProtocol !== protocolVersion || methodHeader !== body.method) {
    throw new ChlomError(
      'MCP_HEADER_MISMATCH',
      'MCP routing headers do not match the JSON-RPC body.',
      400,
      { mcpCode: MCP_ERROR.HEADER_MISMATCH },
    );
  }
  if (body.method === 'tools/call') {
    const nameHeader = decodeMirroredHeader(headerValue(headers, 'mcp-name'));
    if (!nameHeader || nameHeader !== body.params?.name) {
      throw new ChlomError(
        'MCP_HEADER_MISMATCH',
        'Mcp-Name does not match params.name.',
        400,
        { mcpCode: MCP_ERROR.HEADER_MISMATCH },
      );
    }
  }
  const clientInfo = body?.params?._meta?.['io.modelcontextprotocol/clientInfo'];
  if (
    !clientInfo ||
    typeof clientInfo !== 'object' ||
    Array.isArray(clientInfo) ||
    typeof clientInfo.name !== 'string' ||
    typeof clientInfo.version !== 'string'
  ) {
    throw new ChlomError(
      'MCP_INVALID_CLIENT_INFO',
      'Modern MCP requests require clientInfo name and version in params._meta.',
      400,
      { mcpCode: MCP_ERROR.INVALID_PARAMS },
    );
  }
  const capabilities = body?.params?._meta?.['io.modelcontextprotocol/clientCapabilities'];
  if (!capabilities || typeof capabilities !== 'object' || Array.isArray(capabilities)) {
    throw new ChlomError(
      'MCP_MISSING_CLIENT_CAPABILITIES',
      'Modern MCP requests require clientCapabilities in params._meta.',
      400,
      { mcpCode: MCP_ERROR.MISSING_REQUIRED_CLIENT_CAPABILITY },
    );
  }
}

function classifyEra(headers, body) {
  if (body.method === 'initialize') {
    return 'legacy';
  }
  const requested = requestProtocol(body);
  if (!requested) {
    const protocolHeader = headerValue(headers, 'mcp-protocol-version');
    if (protocolHeader === MCP_LEGACY_PROTOCOL_VERSION) {
      return 'legacy';
    }
    throw new ChlomError(
      'MCP_PROTOCOL_VERSION_REQUIRED',
      'Non-initialize MCP requests require an explicit supported protocol version.',
      400,
      {
        mcpCode: MCP_ERROR.UNSUPPORTED_PROTOCOL_VERSION,
        supported: MCP_SUPPORTED_PROTOCOL_VERSIONS,
        requested: protocolHeader || null,
      },
    );
  }
  if (!MCP_SUPPORTED_PROTOCOL_VERSIONS.includes(requested)) {
    throw new ChlomError(
      'MCP_UNSUPPORTED_PROTOCOL_VERSION',
      `Unsupported MCP protocol version: ${requested}`,
      400,
      {
        mcpCode: MCP_ERROR.UNSUPPORTED_PROTOCOL_VERSION,
        supported: MCP_SUPPORTED_PROTOCOL_VERSIONS,
        requested,
      },
    );
  }
  if (requested === MCP_LATEST_PROTOCOL_VERSION) {
    validateModernMetadata(headers, body);
    return 'modern';
  }
  const protocolHeader = headerValue(headers, 'mcp-protocol-version');
  if (protocolHeader && protocolHeader !== requested) {
    throw new ChlomError(
      'MCP_HEADER_MISMATCH',
      'MCP-Protocol-Version does not match the request body.',
      400,
      { mcpCode: MCP_ERROR.HEADER_MISMATCH },
    );
  }
  return 'legacy';
}

function validateJsonRpc(body) {
  if (!body || typeof body !== 'object' || Array.isArray(body) || body.jsonrpc !== '2.0') {
    throw new ChlomError(
      'MCP_INVALID_REQUEST',
      'The request must be one JSON-RPC 2.0 object.',
      400,
      { mcpCode: MCP_ERROR.INVALID_REQUEST },
    );
  }
  if (typeof body.method !== 'string' || !body.method) {
    throw new ChlomError(
      'MCP_INVALID_REQUEST',
      'The JSON-RPC method is required.',
      400,
      { mcpCode: MCP_ERROR.INVALID_REQUEST },
    );
  }
}

function toolResult(payload, isError = false) {
  const serialized = JSON.stringify(payload, null, 2);
  return successResult({
    content: [{ type: 'text', text: serialized }],
    structuredContent: payload,
    isError,
  });
}

async function executeTool(name, rawArguments) {
  const args = rawArguments === undefined ? {} : rawArguments;
  if (!args || typeof args !== 'object' || Array.isArray(args)) {
    throw new ChlomError('MCP_INVALID_TOOL_ARGUMENTS', 'Tool arguments must be an object.', 400);
  }
  switch (name) {
    case 'chlom_provider_status':
      return runtimeReadiness();
    case 'chlom_chain_read': {
      const input = parseRpcInput(args);
      const mode = classifyRpcMethod(input.method);
      if (mode !== 'read') {
        throw new ChlomError(
          'CHLOM_MCP_WRITE_TOOL_UNAVAILABLE',
          'The MCP chain-read tool cannot execute write methods.',
          403,
        );
      }
      return callGovernedRpc(input);
    }
    case 'chlom_verify_transaction': {
      const input = parseRpcInput({
        chain: args.chain,
        method: 'eth_getTransactionReceipt',
        params: [args.transactionHash],
      });
      if (typeof args.transactionHash !== 'string' || !/^0x[0-9a-fA-F]+$/.test(args.transactionHash)) {
        throw new ChlomError(
          'CHLOM_REQUEST_VALIDATION_FAILED',
          'transactionHash must be a 0x-prefixed hexadecimal value.',
          400,
        );
      }
      return callGovernedRpc(input);
    }
    case 'chlom_query_blockchain_analytics':
      return runBlockchainAnalytics(parseAnalyticsInput(args));
    case 'chlom_prepare_evidence_anchor': {
      const input = parseAnchorInput(args);
      return prepareAnchorIntent(input.evidenceDigest, input.targetChain);
    }
    default:
      throw new ChlomError('MCP_UNKNOWN_TOOL', `Unknown MCP tool: ${String(name)}`, 400);
  }
}

async function handleToolCall(body) {
  const name = body.params?.name;
  if (typeof name !== 'string' || !MCP_TOOLS.some((tool) => tool.name === name)) {
    throw new ChlomError('MCP_UNKNOWN_TOOL', `Unknown MCP tool: ${String(name)}`, 400);
  }
  try {
    return toolResult(await executeTool(name, body.params?.arguments));
  } catch (error) {
    const normalized = normalizeError(error);
    if (normalized.code === 'MCP_UNKNOWN_TOOL' || normalized.code === 'MCP_INVALID_TOOL_ARGUMENTS') {
      throw normalized;
    }
    return toolResult(
      {
        ok: false,
        error: {
          code: normalized.code,
          message: normalized.message,
          status: normalized.status,
        },
      },
      true,
    );
  }
}

export async function processMcpMessage(headers, body) {
  validateJsonRpc(body);
  const era = classifyEra(headers, body);
  const id = body.id ?? null;

  if (body.method === 'initialize') {
    const requested = body.params?.protocolVersion;
    const selected = MCP_SUPPORTED_PROTOCOL_VERSIONS.includes(requested)
      ? requested
      : MCP_LEGACY_PROTOCOL_VERSION;
    return {
      status: 200,
      payload: mcpResponse(id, {
        protocolVersion: selected,
        capabilities: { tools: { listChanged: false } },
        serverInfo: MCP_SERVER_INFO,
        instructions:
          'CHLOM tools are read-only and evidence-producing. No tool accepts private keys or broadcasts transactions.',
      }),
    };
  }

  if (body.method === 'notifications/initialized') {
    return { status: 202, empty: true };
  }

  if (body.method === 'server/discover') {
    if (era !== 'modern') {
      return {
        status: 404,
        payload: mcpError(id, MCP_ERROR.METHOD_NOT_FOUND, 'Method not found.'),
      };
    }
    return {
      status: 200,
      payload: mcpResponse(
        id,
        successResult({
          supportedVersions: MCP_SUPPORTED_PROTOCOL_VERSIONS,
          capabilities: { tools: {} },
          instructions:
            'Use CHLOM tools for governed read-only chain evidence. RPC endpoints and BigQuery SQL are server-controlled. Chain broadcast and private-key custody are not exposed.',
          ttlMs: 300000,
          cacheScope: 'private',
        }),
      ),
    };
  }

  if (body.method === 'ping') {
    return { status: 200, payload: mcpResponse(id, successResult({})) };
  }

  if (body.method === 'tools/list') {
    return {
      status: 200,
      payload: mcpResponse(
        id,
        successResult({
          tools: MCP_TOOLS,
          ttlMs: 300000,
          cacheScope: 'private',
        }),
      ),
    };
  }

  if (body.method === 'tools/call') {
    return {
      status: 200,
      payload: mcpResponse(id, await handleToolCall(body)),
    };
  }

  return {
    status: era === 'modern' ? 404 : 200,
    payload: mcpError(id, MCP_ERROR.METHOD_NOT_FOUND, 'Method not found.'),
  };
}

export function mcpErrorFromException(error, id = null) {
  const normalized = normalizeError(error);
  const code = normalized.details?.mcpCode ||
    (normalized.status === 401 || normalized.status === 403 || normalized.status === 503
      ? MCP_ERROR.AUTHORIZATION_FAILED
      : normalized.status === 400
        ? MCP_ERROR.INVALID_PARAMS
        : MCP_ERROR.INTERNAL_ERROR);
  const data = normalized.code === 'MCP_UNSUPPORTED_PROTOCOL_VERSION' ||
    normalized.code === 'MCP_PROTOCOL_VERSION_REQUIRED'
    ? {
        supported: normalized.details?.supported || MCP_SUPPORTED_PROTOCOL_VERSIONS,
        requested: normalized.details?.requested,
      }
    : { chlomCode: normalized.code };
  return {
    status: normalized.status,
    payload: mcpError(id, code, normalized.message, data),
  };
}
