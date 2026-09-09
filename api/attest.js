import { requireApiAuthorization } from '../lib/runtime/auth.js';
import { normalizeError } from '../lib/runtime/errors.js';
import { prepareAnchorIntent } from '../lib/runtime/evidence.js';
import { readJsonBody, sendJson, validateOrigin } from '../lib/runtime/http.js';
import { parseAnchorInput } from '../lib/runtime/validators.js';

export default async function handler(request, response) {
  if (request.method !== 'POST') {
    response.setHeader('Allow', 'POST');
    return sendJson(response, 405, { ok: false, error: { code: 'METHOD_NOT_ALLOWED' } });
  }
  try {
    validateOrigin(request);
    requireApiAuthorization(request);
    const input = parseAnchorInput(readJsonBody(request));
    return sendJson(response, 200, {
      ok: true,
      anchorIntent: prepareAnchorIntent(input.evidenceDigest, input.targetChain),
    });
  } catch (error) {
    const normalized = normalizeError(error);
    return sendJson(response, normalized.status, {
      ok: false,
      error: {
        code: normalized.code,
        message: normalized.message,
        details: normalized.details,
      },
    });
  }
}
