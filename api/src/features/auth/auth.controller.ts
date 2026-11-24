import type { RequestHandler } from 'express';
import { env } from '../../config/env.js';
import { AppError } from '../../core/errors/app-error.js';
import { toErrorDetails } from '../../core/validation/zod-error-details.js';
import { registerStudent, verifyCredentials } from './auth.service.js';
import { loginSchema, logoutSchema, refreshSchema, registerSchema } from './auth.schemas.js';
import { createAccessToken } from './token.service.js';
import {
  createSessionForUser,
  revokeSessionById,
  revokeSessionByRefreshToken,
  rotateRefreshToken,
} from './session.service.js';
import { UserModel, type UserRole } from './user.model.js';

export const registerController: RequestHandler = async (request, response, next) => {
  const parsedBody = registerSchema.safeParse(request.body);

  if (!parsedBody.success) {
    next(new AppError(
      422,
      'VALIDATION_ERROR',
      'The request body is invalid.',
      toErrorDetails(parsedBody.error.issues),
    ));
    return;
  }

  try {
    const user = await registerStudent(parsedBody.data);
    response.status(201).json({ data: user });
  } catch (error: unknown) {
    next(error);
  }
};

export const loginController: RequestHandler = async (request, response, next) => {
  const parsedBody = loginSchema.safeParse(request.body);

  if (!parsedBody.success) {
    next(new AppError(
      422,
      'VALIDATION_ERROR',
      'The request body is invalid.',
      toErrorDetails(parsedBody.error.issues),
    ));
    return;
  }

  try {
    const user = await verifyCredentials(parsedBody.data);
    const accessToken = await createAccessToken(user.id, user.role);
    const session = await createSessionForUser(user.id);

    response.status(200).json({
      data: {
        accessToken,
        refreshToken: session.refreshToken,
        tokenType: 'Bearer',
        accessTokenExpiresInSeconds: env.ACCESS_TOKEN_TTL_SECONDS,
        user,
      },
    });
  } catch (error: unknown) {
    next(error);
  }
};

export const refreshController: RequestHandler = async (request, response, next) => {
  const parsedBody = refreshSchema.safeParse(request.body);

  if (!parsedBody.success) {
    next(new AppError(
      422,
      'VALIDATION_ERROR',
      'The request body is invalid.',
      toErrorDetails(parsedBody.error.issues),
    ));
    return;
  }

  try {
    const session = await rotateRefreshToken(parsedBody.data.refreshToken);
    const user = await UserModel.findById(session.userId);

    if (!user) {
      await revokeSessionById(session.sessionId);
      throw new AppError(401, 'INVALID_REFRESH_TOKEN', 'Refresh token is invalid.');
    }

    const accessToken = await createAccessToken(user.id, user.role as UserRole);

    response.status(200).json({
      data: {
        accessToken,
        refreshToken: session.refreshToken,
        tokenType: 'Bearer',
        accessTokenExpiresInSeconds: env.ACCESS_TOKEN_TTL_SECONDS,
      },
    });
  } catch (error: unknown) {
    next(error);
  }
};

export const logoutController: RequestHandler = async (request, response, next) => {
  const parsedBody = logoutSchema.safeParse(request.body);

  if (!parsedBody.success) {
    next(new AppError(
      422,
      'VALIDATION_ERROR',
      'The request body is invalid.',
      toErrorDetails(parsedBody.error.issues),
    ));
    return;
  }

  try {
    await revokeSessionByRefreshToken(parsedBody.data.refreshToken);
    response.status(204).send();
  } catch (error: unknown) {
    next(error);
  }
};
