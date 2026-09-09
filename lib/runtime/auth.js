import { constantTimeEqual } from './crypto.js';
import { ChlomError } from './errors.js';
import { enforceRequestSize, getHeader } from './http.js';

export function requireApiAuthorization(request) {
  enforceRequestSize(request);
  const configured = process.env.CHLOM_API_TOKEN;
  if (!configured) {
    throw new ChlomError(
      'CHLOM_API_TOKEN_NOT_CONFIGURED',
      'The CHLOM API is fail-closed until CHLOM_API_TOKEN is configured.',
      503,
    );
  }
  const header = getHeader(request, 'authorization') || '';
  const supplied = header.startsWith('Bearer ') ? header.slice(7).trim() : '';
  if (!supplied || !constantTimeEqual(supplied, configured)) {
    throw new ChlomError('CHLOM_UNAUTHORIZED', 'A valid CHLOM bearer token is required.', 401);
  }
}

export function assertWriteAuthority(request) {
  if (process.env.CHLOM_CHAIN_WRITE_ENABLED !== 'true') {
    throw new ChlomError(
      'CHLOM_CHAIN_WRITE_DISABLED',
      'Chain broadcast is disabled by CHLOM policy.',
      403,
    );
  }
  if (process.env.CHLOM_GOVERNANCE_STATE !== 'promoted') {
    throw new ChlomError(
      'CHLOM_GOVERNANCE_NOT_PROMOTED',
      'Chain broadcast requires a promoted CHLOM governance state.',
      403,
    );
  }
  const expected = process.env.CHLOM_ECAC_DIGEST;
  const supplied = getHeader(request, 'x-chlom-ecac-digest') || '';
  if (!expected || !supplied || !constantTimeEqual(expected, supplied)) {
    throw new ChlomError(
      'CHLOM_ECAC_MISMATCH',
      'Chain broadcast requires an exact active ECAC digest.',
      403,
    );
  }
}
