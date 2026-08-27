import assert from 'node:assert/strict';
import test from 'node:test';
import { canonicalize, sha256 } from '../lib/runtime/crypto.js';
import { classifyRpcMethod } from '../lib/runtime/rpc.js';
import { prepareAnalyticsQuery } from '../lib/runtime/analytics-templates.js';
import { prepareAnchorIntent } from '../lib/runtime/evidence.js';
import {
  MCP_ERROR,
  MCP_LATEST_PROTOCOL_VERSION,
} from '../lib/runtime/constants.js';
import { processMcpMessage } from '../lib/runtime/mcp.js';
import healthHandler from '../api/health.js';
import { validateOrigin } from '../lib/runtime/http.js';

function modernHeaders(method, name) {
  return {
    'mcp-protocol-version': MCP_LATEST_PROTOCOL_VERSION,
    'mcp-method': method,
    ...(name ? { 'mcp-name': name } : {}),
  };
}

function modernMeta() {
  return {
    'io.modelcontextprotocol/protocolVersion': MCP_LATEST_PROTOCOL_VERSION,
    'io.modelcontextprotocol/clientInfo': { name: 'CHLOM-Test', version: '1.0.0' },
    'io.modelcontextprotocol/clientCapabilities': {},
  };
}

test('canonical evidence hashing is deterministic', () => {
  const left = { b: 2, a: { d: 4, c: 3 } };
  const right = { a: { c: 3, d: 4 }, b: 2 };
  assert.equal(canonicalize(left), canonicalize(right));
  assert.equal(sha256(left), sha256(right));
});

test('RPC policy allows reads, classifies raw broadcast, and blocks dangerous namespaces', () => {
  assert.equal(classifyRpcMethod('eth_getTransactionReceipt'), 'read');
  assert.equal(classifyRpcMethod('eth_sendRawTransaction'), 'write');
  assert.throws(() => classifyRpcMethod('personal_unlockAccount'), /prohibited/i);
  assert.throws(() => classifyRpcMethod('eth_unknownExperimentalMethod'), /not allowlisted/i);
});

test('analytics queries are parameterized, time-partition bounded, and row capped upstream', () => {
  const prepared = prepareAnalyticsQuery({
    chain: 'ethereum',
    template: 'address_activity',
    address: '0x1234',
    limit: 250,
    lookbackDays: 31,
  });
  assert.equal(prepared.limit, 250);
  assert.equal(prepared.lookbackDays, 31);
  assert.match(prepared.query, /block_timestamp >= @start_timestamp/);
  assert.match(prepared.query, /@address/);
  assert.doesNotMatch(prepared.query, /0x1234/);
});

test('transaction analytics includes a partition boundary', () => {
  const prepared = prepareAnalyticsQuery({
    chain: 'polygon',
    template: 'transaction_evidence',
    transactionHash: '0xabcd',
    limit: 1,
    lookbackDays: 7,
  });
  assert.match(prepared.query, /tx\.block_timestamp >= @start_timestamp/);
  assert.match(prepared.query, /tx\.transaction_hash = @transaction_hash/);
});

test('anchor intent is deterministic in authority and never broadcasts', () => {
  const intent = prepareAnchorIntent('a'.repeat(64), 'base');
  assert.equal(intent.broadcast, false);
  assert.equal(intent.status, 'HOLD_REQUIRES_GOVERNED_ANCHOR_ADAPTER');
});

test('modern MCP server/discover advertises current stateless protocol', async () => {
  const body = {
    jsonrpc: '2.0',
    id: 'discover-1',
    method: 'server/discover',
    params: { _meta: modernMeta() },
  };
  const result = await processMcpMessage(modernHeaders('server/discover'), body);
  assert.equal(result.status, 200);
  assert.equal(result.payload.result.resultType, 'complete');
  assert.ok(result.payload.result.supportedVersions.includes(MCP_LATEST_PROTOCOL_VERSION));
  assert.deepEqual(result.payload.result.capabilities, { tools: {} });
});

test('modern MCP rejects routing-header/body mismatch', async () => {
  const body = {
    jsonrpc: '2.0',
    id: 1,
    method: 'tools/list',
    params: { _meta: modernMeta() },
  };
  await assert.rejects(
    () => processMcpMessage(modernHeaders('tools/call'), body),
    (error) => error.details?.mcpCode === MCP_ERROR.HEADER_MISMATCH,
  );
});

test('modern MCP tools/list is deterministic and includes no broadcast tool', async () => {
  const body = {
    jsonrpc: '2.0',
    id: 2,
    method: 'tools/list',
    params: { _meta: modernMeta() },
  };
  const result = await processMcpMessage(modernHeaders('tools/list'), body);
  const names = result.payload.result.tools.map((tool) => tool.name);
  assert.deepEqual(names, [...names].sort((a, b) => {
    const order = [
      'chlom_provider_status',
      'chlom_chain_read',
      'chlom_verify_transaction',
      'chlom_query_blockchain_analytics',
      'chlom_prepare_evidence_anchor',
    ];
    return order.indexOf(a) - order.indexOf(b);
  }));
  assert.equal(names.some((name) => /broadcast|send_raw/i.test(name)), false);
});

test('modern MCP rejects missing client capabilities with the current protocol error', async () => {
  const meta = modernMeta();
  delete meta['io.modelcontextprotocol/clientCapabilities'];
  const body = {
    jsonrpc: '2.0',
    id: 4,
    method: 'tools/list',
    params: { _meta: meta },
  };
  await assert.rejects(
    () => processMcpMessage(modernHeaders('tools/list'), body),
    (error) => error.details?.mcpCode === MCP_ERROR.MISSING_REQUIRED_CLIENT_CAPABILITY,
  );
});

test('non-initialize requests cannot bypass protocol validation by omitting metadata', async () => {
  await assert.rejects(
    () => processMcpMessage({}, {
      jsonrpc: '2.0',
      id: 5,
      method: 'tools/list',
      params: {},
    }),
    (error) => error.details?.mcpCode === MCP_ERROR.UNSUPPORTED_PROTOCOL_VERSION,
  );
});

test('legacy MCP initialize fallback remains available', async () => {
  const result = await processMcpMessage({}, {
    jsonrpc: '2.0',
    id: 3,
    method: 'initialize',
    params: { protocolVersion: '2025-11-25', capabilities: {}, clientInfo: { name: 'legacy', version: '1' } },
  });
  assert.equal(result.status, 200);
  assert.equal(result.payload.result.protocolVersion, '2025-11-25');
});

function mockResponse() {
  return {
    headers: {},
    statusCode: null,
    payload: undefined,
    ended: false,
    setHeader(name, value) {
      this.headers[name.toLowerCase()] = value;
    },
    status(code) {
      this.statusCode = code;
      return this;
    },
    json(payload) {
      this.payload = payload;
      return this;
    },
    end() {
      this.ended = true;
      return this;
    },
  };
}

function withEnvironment(values, callback) {
  const previous = new Map();
  for (const [key, value] of Object.entries(values)) {
    previous.set(key, process.env[key]);
    if (value === undefined) delete process.env[key];
    else process.env[key] = value;
  }
  try {
    return callback();
  } finally {
    for (const [key, value] of previous) {
      if (value === undefined) delete process.env[key];
      else process.env[key] = value;
    }
  }
}

test('provider liveness remains operational while the data plane is explicitly gated', () => {
  withEnvironment({
    VERCEL_ENV: 'preview',
    CHLOM_API_TOKEN: undefined,
    CHLOM_GOVERNANCE_STATE: undefined,
    CHLOM_ECAC_DIGEST: undefined,
    QUICKNODE_RPC_ETHEREUM: undefined,
    GCP_PROJECT_ID: undefined,
  }, () => {
    const response = mockResponse();
    healthHandler({ method: 'GET', headers: {} }, response);
    assert.equal(response.statusCode, 200);
    assert.equal(response.payload.status, 'OPERATIONAL');
    assert.equal(response.payload.readinessStatus, 'CONFIGURATION_HOLD');
    assert.equal(response.headers['x-chlom-readiness'], 'CONFIGURATION_HOLD');
    assert.ok(response.payload.readiness.holds.includes('CHLOM_API_TOKEN'));
  });
});

test('local unbound runtime fails provider readback closed', () => {
  withEnvironment({ VERCEL_ENV: undefined }, () => {
    const response = mockResponse();
    healthHandler({ method: 'HEAD', headers: {} }, response);
    assert.equal(response.statusCode, 503);
    assert.equal(response.ended, true);
  });
});

test('origin validation rejects a foreign browser origin', () => {
  withEnvironment({ CHLOM_ALLOWED_ORIGINS: 'https://chlom-protocol.vercel.app' }, () => {
    assert.throws(
      () => validateOrigin({
        headers: {
          origin: 'https://attacker.example',
          host: 'chlom-protocol.vercel.app',
          'x-forwarded-proto': 'https',
        },
      }),
      /not allowed/i,
    );
  });
});
