import { jwtVerify, SignJWT } from 'jose';
import { env } from '../../config/env.js';
import type { UserRole } from './user.model.js';

const accessTokenSecret = new TextEncoder().encode(env.JWT_ACCESS_SECRET);

export async function createAccessToken(userId: string, role: UserRole): Promise<string> {
  return new SignJWT({ role })
    .setProtectedHeader({ alg: 'HS256', typ: 'JWT' })
    .setSubject(userId)
    .setIssuedAt()
    .setExpirationTime(`${env.ACCESS_TOKEN_TTL_SECONDS}s`)
    .sign(accessTokenSecret);
}

export async function verifyAccessToken(accessToken: string): Promise<string> {
  const { payload } = await jwtVerify(accessToken, accessTokenSecret, {
    algorithms: ['HS256'],
  });

  if (typeof payload.sub !== 'string' || payload.sub.length === 0) {
    throw new Error('Access token has no subject.');
  }

  return payload.sub;
}
