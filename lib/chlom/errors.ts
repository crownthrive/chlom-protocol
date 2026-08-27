export class ChlomError extends Error {
  readonly code: string;
  readonly status: number;
  readonly details?: Record<string, unknown>;

  constructor(
    code: string,
    message: string,
    status = 400,
    details?: Record<string, unknown>,
  ) {
    super(message);
    this.name = "ChlomError";
    this.code = code;
    this.status = status;
    this.details = details;
  }
}

function isValidationError(
  error: unknown,
): error is { issues: Array<Record<string, unknown>> } {
  return Boolean(
    error &&
      typeof error === "object" &&
      "issues" in error &&
      Array.isArray((error as { issues?: unknown }).issues),
  );
}

export function errorResponse(error: unknown): Response {
  if (error instanceof ChlomError) {
    return Response.json(
      {
        ok: false,
        error: {
          code: error.code,
          message: error.message,
          details: error.details,
        },
      },
      { status: error.status },
    );
  }

  if (isValidationError(error)) {
    return Response.json(
      {
        ok: false,
        error: {
          code: "CHLOM_REQUEST_VALIDATION_FAILED",
          message: "Request validation failed.",
          details: { issues: error.issues },
        },
      },
      { status: 400 },
    );
  }

  console.error("CHLOM_UNHANDLED_ERROR", error);
  return Response.json(
    {
      ok: false,
      error: {
        code: "CHLOM_INTERNAL_ERROR",
        message: "Unexpected CHLOM runtime failure.",
      },
    },
    { status: 500 },
  );
}
