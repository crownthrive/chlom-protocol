import { constantTimeEqual } from "./crypto";
import { ChlomError } from "./errors";

const MAX_REQUEST_BYTES = 128 * 1024;

export function requireBoundedRequest(request: Request): void {
  const contentLength = request.headers.get("content-length");
  if (contentLength && Number(contentLength) > MAX_REQUEST_BYTES) {
    throw new ChlomError(
      "CHLOM_REQUEST_TOO_LARGE",
      "Request body exceeds the governed payload limit.",
      413,
      { maximumBytes: MAX_REQUEST_BYTES },
    );
  }
}

export function requireApiAuthorization(request: Request): void {
  requireBoundedRequest(request);

  const configured = process.env.CHLOM_API_TOKEN;
  if (!configured) {
    throw new ChlomError(
      "CHLOM_API_TOKEN_NOT_CONFIGURED",
      "The CHLOM API is fail-closed until CHLOM_API_TOKEN is configured.",
      503,
    );
  }

  const header = request.headers.get("authorization") ?? "";
  const supplied = header.startsWith("Bearer ") ? header.slice(7).trim() : "";

  if (!supplied || !constantTimeEqual(supplied, configured)) {
    throw new ChlomError(
      "CHLOM_UNAUTHORIZED",
      "A valid CHLOM bearer token is required.",
      401,
    );
  }
}

export function assertWriteAuthority(request: Request): void {
  if (process.env.CHLOM_CHAIN_WRITE_ENABLED !== "true") {
    throw new ChlomError(
      "CHLOM_CHAIN_WRITE_DISABLED",
      "Chain broadcast is disabled by CHLOM policy.",
      403,
    );
  }

  if (process.env.CHLOM_GOVERNANCE_STATE !== "promoted") {
    throw new ChlomError(
      "CHLOM_GOVERNANCE_NOT_PROMOTED",
      "Chain broadcast requires a promoted CHLOM governance state.",
      403,
    );
  }

  const expectedEcac = process.env.CHLOM_ECAC_DIGEST;
  const suppliedEcac = request.headers.get("x-chlom-ecac-digest") ?? "";

  if (
    !expectedEcac ||
    !suppliedEcac ||
    !constantTimeEqual(expectedEcac, suppliedEcac)
  ) {
    throw new ChlomError(
      "CHLOM_ECAC_MISMATCH",
      "Chain broadcast requires an exact active ECAC digest.",
      403,
    );
  }
}
