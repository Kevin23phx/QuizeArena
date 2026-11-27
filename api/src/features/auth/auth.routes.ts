import { Router } from 'express';
import { rateLimit } from 'express-rate-limit';
import { env } from '../../config/env.js';
import { loginController, logoutController, refreshController, registerController } from './auth.controller.js';

export const authRouter = Router();

const createAuthRateLimiter = () => rateLimit({
  windowMs: 15 * 60 * 1000,
  limit: 10,
  skip: () => env.NODE_ENV === 'test',
  standardHeaders: 'draft-8',
  legacyHeaders: false,
  message: {
    error: {
      code: 'RATE_LIMITED',
      message: 'Too many authentication attempts. Please try again later.',
      details: [],
    },
  },
});

authRouter.post('/register', createAuthRateLimiter(), registerController);
authRouter.post('/login', createAuthRateLimiter(), loginController);
authRouter.post('/refresh', createAuthRateLimiter(), refreshController);
authRouter.post('/logout', logoutController);
