import bcrypt from 'bcryptjs';
import { AppError } from '../../core/errors/app-error.js';
import type { LoginInput, RegisterInput } from './auth.schemas.js';
import { UserModel, type UserRole } from './user.model.js';

const BCRYPT_ROUNDS = 12;
const dummyPasswordHash = bcrypt.hash('not-a-real-user-password', BCRYPT_ROUNDS);

function isDuplicateKeyError(error: unknown): boolean {
  return (
    typeof error === 'object' &&
    error !== null &&
    'code' in error &&
    error.code === 11000
  );
}

export async function registerStudent(input: RegisterInput) {
  if (bcrypt.truncates(input.password)) {
    throw new AppError(422, 'PASSWORD_TOO_LONG_IN_BYTES', 'Password exceeds bcrypt’s 72-byte limit.');
  }

  const passwordHash = await bcrypt.hash(input.password, BCRYPT_ROUNDS);

  try {
    const user = await UserModel.create({
      name: input.name,
      email: input.email,
      passwordHash,
      role: 'student',
    });

    return {
      id: user.id,
      name: user.name,
      email: user.email,
      role: user.role as UserRole,
      createdAt: user.createdAt,
    };
  } catch (error: unknown) {
    if (isDuplicateKeyError(error)) {
      throw new AppError(409, 'EMAIL_ALREADY_EXISTS', 'An account with this email already exists.');
    }

    throw error;
  }
}

export async function verifyCredentials(input: LoginInput) {
  if (bcrypt.truncates(input.password)) {
    throw new AppError(401, 'INVALID_CREDENTIALS', 'Email or password is invalid.');
  }

  const user = await UserModel.findOne({ email: input.email }).select('+passwordHash');
  const hashToCompare = user?.passwordHash ?? await dummyPasswordHash;
  const passwordMatches = await bcrypt.compare(input.password, hashToCompare);

  if (!user || !passwordMatches) {
    throw new AppError(401, 'INVALID_CREDENTIALS', 'Email or password is invalid.');
  }

  return {
    id: user.id,
    name: user.name,
    email: user.email,
    role: user.role as UserRole,
    createdAt: user.createdAt,
  };
}
