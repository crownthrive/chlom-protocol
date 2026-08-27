import { requireApiAuthorization } from '../lib/runtime/auth.js';
import { readJsonBody, sendEmpty, sendJson, validateOrigin } from '../lib/runtime/http.js';
import { mcpErrorFromException, processMcpMessage } from '../lib/runtime/mcp.js';

export default async function handler(request, response) {
  if (request.method !== 'POST') {
    response.setHeader('Allow', 'POST');
    return sendJson(response, 405, {
      jsonrpc: '2.0',
      id: null,
      error: { code: -32600, message: 'The MCP endpoint accepts POST only.' },
    });
  }
  let body;
  try {
    validateOrigin(request);
    requireApiAuthorization(request);
    body = readJsonBody(request);
    const result = await processMcpMessage(request.headers, body);
    if (result.empty) {
      return sendEmpty(response, result.status);
    }
    return sendJson(response, result.status, result.payload, {
      'MCP-Protocol-Version': body?.params?._meta?.['io.modelcontextprotocol/protocolVersion'] ||
        body?.params?.protocolVersion ||
        '2025-11-25',
    });
  } catch (error) {
    const result = mcpErrorFromException(error, body?.id ?? null);
    return sendJson(response, result.status, result.payload);
  }
}
