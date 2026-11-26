import { createHash, randomBytes } from 'node:crypto';
import { env } from '../../config/env.js';
import { AppError } from '../../core/errors/app-error.js';
import { SessionModel } from './session.model.js';

export function createRefreshToken(): string {
  return randomBytes(32).toString('base64url');
}

export function hashRefreshToken(refreshToken: string): string {
  return createHash('sha256').update(refreshToken).digest('hex');
}

export async function createSessionForUser(userId: string) {
  const refreshToken = createRefreshToken();
  const refreshTokenHash = hashRefreshToken(refreshToken);
  const expiresAt = new Date(Date.now() + env.REFRESH_TOKEN_TTL_SECONDS * 1000);

  const session = await SessionModel.create({
    userId,
    refreshTokenHash,
    expiresAt,
  });

  return {
    sessionId: session.id,
    refreshToken,
    expiresAt: session.expiresAt,
  };
}

export async function rotateRefreshToken(presentedToken: string) {
  const presentedHash = hashRefreshToken(presentedToken);
  const now = new Date();
  const currentSession = await SessionModel.findOne({ refreshTokenHash: presentedHash })
    .select('+refreshTokenHash');

  if (!currentSession) {
    const reusedSession = await SessionModel.findOne({ consumedRefreshTokenHashes: presentedHash });

    if (reusedSession && !reusedSession.revokedAt) {
      await SessionModel.updateOne(
        { _id: reusedSession._id, revokedAt: null },
        { $set: { revokedAt: now } },
      );
    }

    throw new AppError(401, 'INVALID_REFRESH_TOKEN', 'Refresh token is invalid.');
  }

  if (currentSession.revokedAt || currentSession.expiresAt <= now) {
    throw new AppError(401, 'INVALID_REFRESH_TOKEN', 'Refresh token is invalid.');
  }

  const refreshToken = createRefreshToken();
  const refreshTokenHash = hashRefreshToken(refreshToken);
  const expiresAt = new Date(Date.now() + env.REFRESH_TOKEN_TTL_SECONDS * 1000);
  const rotatedSession = await SessionModel.findOneAndUpdate(
    {
      _id: currentSession._id,
      refreshTokenHash: presentedHash,
      revokedAt: null,
      expiresAt: { $gt: now },
    },
    {
      $set: { refreshTokenHash, expiresAt },
      $addToSet: { consumedRefreshTokenHashes: presentedHash },
    },
    { new: true },
  );

  if (!rotatedSession) {
    await SessionModel.updateOne(
      { _id: currentSession._id, revokedAt: null },
      { $set: { revokedAt: now } },
    );
    throw new AppError(401, 'INVALID_REFRESH_TOKEN', 'Refresh token is invalid.');
  }

  return {
    sessionId: rotatedSession.id,
    userId: rotatedSession.userId.toString(),
    refreshToken,
    expiresAt: rotatedSession.expiresAt,
  };
}

export async function revokeSessionById(sessionId: string): Promise<void> {
  await SessionModel.updateOne(
    { _id: sessionId, revokedAt: null },
    { $set: { revokedAt: new Date() } },
  );
}

export async function revokeSessionByRefreshToken(refreshToken: string): Promise<void> {
  const refreshTokenHash = hashRefreshToken(refreshToken);

  await SessionModel.updateOne(
    {
      $or: [
        { refreshTokenHash },
        { consumedRefreshTokenHashes: refreshTokenHash },
      ],
      revokedAt: null,
    },
    { $set: { revokedAt: new Date() } },
  );
}
