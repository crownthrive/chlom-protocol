import { requireApiAuthorization } from '../lib/runtime/auth.js';
import { runBlockchainAnalytics } from '../lib/runtime/bigquery.js';
import { normalizeError } from '../lib/runtime/errors.js';
import { readJsonBody, sendJson, validateOrigin } from '../lib/runtime/http.js';
import { parseAnalyticsInput } from '../lib/runtime/validators.js';

export default async function handler(request, response) {
  if (request.method !== 'POST') {
    response.setHeader('Allow', 'POST');
    return sendJson(response, 405, { ok: false, error: { code: 'METHOD_NOT_ALLOWED' } });
  }
  try {
    validateOrigin(request);
    requireApiAuthorization(request);
    const envelope = await runBlockchainAnalytics(parseAnalyticsInput(readJsonBody(request)));
    return sendJson(response, 200, { ok: true, envelope });
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
