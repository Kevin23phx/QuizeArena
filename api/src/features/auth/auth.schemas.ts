import { z } from 'zod';

export const registerSchema = z.strictObject({
  name: z.string().trim().min(1, 'Name is required').max(50, 'Name must be at most 50 characters'),
  email: z
    .string()
    .trim()
    .toLowerCase()
    .email('Email must be valid'),
  password: z.string().min(1, 'Password is required').max(20, 'Password must be at most 20 characters'),
});

export const loginSchema = z.strictObject({
  email: z
    .string()
    .trim()
    .toLowerCase()
    .email('Email must be valid'),
  password: z.string().min(1, 'Password is required').max(20, 'Password must be at most 20 characters'),
});

export const refreshSchema = z.strictObject({
  refreshToken: z.string().min(1, 'Refresh token is required'),
});

export const logoutSchema = z.strictObject({
  refreshToken: z.string().min(1, 'Refresh token is required'),
});

export type RegisterInput = z.infer<typeof registerSchema>;
export type LoginInput = z.infer<typeof loginSchema>;
export type RefreshInput = z.infer<typeof refreshSchema>;
export type LogoutInput = z.infer<typeof logoutSchema>;
