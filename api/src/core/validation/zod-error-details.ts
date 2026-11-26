import type { ZodIssue } from 'zod';
import type { ErrorDetail } from '../errors/app-error.js';

export function toErrorDetails(issues: readonly ZodIssue[]): ErrorDetail[] {
  return issues.flatMap((issue) => {
    if (issue.code === 'unrecognized_keys') {
      return issue.keys.map((key) => ({ field: key, message: 'Unknown field.' }));
    }

    return [{
      field: issue.path.map(String).join('.') || 'body',
      message: issue.message,
    }];
  });
}
