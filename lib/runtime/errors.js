export class ChlomError extends Error {
  constructor(code, message, status = 400, details = undefined) {
    super(message);
    this.name = 'ChlomError';
    this.code = code;
    this.status = status;
    this.details = details;
  }
}

export function normalizeError(error) {
  if (error instanceof ChlomError) {
    return error;
  }
  if (error instanceof Error) {
    return new ChlomError('CHLOM_INTERNAL_ERROR', error.message, 500);
  }
  return new ChlomError('CHLOM_INTERNAL_ERROR', String(error), 500);
}
