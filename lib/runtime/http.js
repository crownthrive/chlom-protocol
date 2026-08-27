import { MAX_REQUEST_BYTES } from './constants.js';
import { ChlomError } from './errors.js';

export function getHeader(request, name) {
  const value = request?.headers?.[name.toLowerCase()];
  return Array.isArray(value) ? value[0] : value;
}

export function setSecurityHeaders(response) {
  response.setHeader('Cache-Control', 'no-store, max-age=0');
  response.setHeader('X-Content-Type-Options', 'nosniff');
  response.setHeader('X-Frame-Options', 'DENY');
  response.setHeader('Referrer-Policy', 'no-referrer');
  response.setHeader('Permissions-Policy', 'camera=(), microphone=(), geolocation=(), payment=()');
}

export function sendJson(response, status, payload, headers = {}) {
  setSecurityHeaders(response);
  response.setHeader('Content-Type', 'application/json; charset=utf-8');
  for (const [name, value] of Object.entries(headers)) {
    response.setHeader(name, value);
  }
  return response.status(status).json(payload);
}

export function sendEmpty(response, status, headers = {}) {
  setSecurityHeaders(response);
  for (const [name, value] of Object.entries(headers)) {
    response.setHeader(name, value);
  }
  return response.status(status).end();
}

export function enforceRequestSize(request) {
  const raw = getHeader(request, 'content-length');
  const contentLength = raw ? Number(raw) : 0;
  if (Number.isFinite(contentLength) && contentLength > MAX_REQUEST_BYTES) {
    throw new ChlomError(
      'CHLOM_REQUEST_TOO_LARGE',
      'Request body exceeds the governed payload limit.',
      413,
      { maximumBytes: MAX_REQUEST_BYTES },
    );
  }
}

export function readJsonBody(request) {
  enforceRequestSize(request);
  const body = request.body;
  if (body && typeof body === 'object' && !Buffer.isBuffer(body)) {
    return body;
  }
  if (Buffer.isBuffer(body)) {
    try {
      return JSON.parse(body.toString('utf8'));
    } catch {
      throw new ChlomError('CHLOM_INVALID_JSON', 'Request body is not valid JSON.', 400);
    }
  }
  if (typeof body === 'string' && body.trim()) {
    try {
      return JSON.parse(body);
    } catch {
      throw new ChlomError('CHLOM_INVALID_JSON', 'Request body is not valid JSON.', 400);
    }
  }
  throw new ChlomError('CHLOM_BODY_REQUIRED', 'A JSON request body is required.', 400);
}

function configuredAllowedOrigins(request) {
  const explicit = (process.env.CHLOM_ALLOWED_ORIGINS || '')
    .split(',')
    .map((value) => value.trim())
    .filter(Boolean);
  const host = getHeader(request, 'x-forwarded-host') || getHeader(request, 'host');
  const protocol = getHeader(request, 'x-forwarded-proto') || 'https';
  if (host) {
    explicit.push(`${protocol}://${host}`);
  }
  return new Set(explicit);
}

export function validateOrigin(request) {
  const origin = getHeader(request, 'origin');
  if (!origin) {
    return;
  }
  const allowed = configuredAllowedOrigins(request);
  if (!allowed.has(origin)) {
    throw new ChlomError(
      'CHLOM_ORIGIN_REJECTED',
      'The request Origin is not allowed by the CHLOM perimeter.',
      403,
      { origin },
    );
  }
}
