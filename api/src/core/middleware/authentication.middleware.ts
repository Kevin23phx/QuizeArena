import type { RequestHandler } from 'express';
import { AppError } from '../errors/app-error.js';
import { UserModel, type UserRole } from '../../features/auth/user.model.js';
import { verifyAccessToken } from '../../features/auth/token.service.js';

export const requireAuthentication: RequestHandler = async (request, _response, next) => {
  const authorization = request.header('authorization');
  const bearerMatch = authorization?.match(/^Bearer\s+(\S+)$/i);

  if (!bearerMatch) {
    next(new AppError(401, 'AUTHENTICATION_REQUIRED', 'A valid Bearer access token is required.'));
    return;
  }

  let userId: string;

  try {
    userId = await verifyAccessToken(bearerMatch[1]);
  } catch {
    next(new AppError(401, 'INVALID_ACCESS_TOKEN', 'Access token is invalid or expired.'));
    return;
  }

  const user = await UserModel.findById(userId).select('_id role');

  if (!user) {
    next(new AppError(401, 'INVALID_ACCESS_TOKEN', 'Access token is invalid or expired.'));
    return;
  }

  request.authUser = {
    id: user.id,
    role: user.role as UserRole,
  };

  next();
};
