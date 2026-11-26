import type { RequestHandler } from 'express';
import { AppError } from '../errors/app-error.js';
import type { UserRole } from '../../features/auth/user.model.js';

export function requireRoles(...allowedRoles: UserRole[]): RequestHandler {
  return (request, _response, next) => {
    if (!request.authUser) {
      next(new AppError(401, 'AUTHENTICATION_REQUIRED', 'Authentication is required.'));
      return;
    }

    if (!allowedRoles.includes(request.authUser.role)) {
      next(new AppError(403, 'FORBIDDEN', 'Your role is not allowed to perform this action.'));
      return;
    }

    next();
  };
}
