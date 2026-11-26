import cors from 'cors';
import express from 'express';
import { rateLimit } from 'express-rate-limit';
import helmet from 'helmet';
import { env } from './config/env.js';
import { errorHandler } from './core/middleware/error.middleware.js';
import { notFoundHandler } from './core/middleware/not-found.middleware.js';
import { authRouter } from './features/auth/auth.routes.js';
import { attemptRouter } from './features/attempts/attempt.routes.js';
import { courseRouter } from './features/courses/course.routes.js';
import { healthRouter } from './features/health/health.routes.js';
import { quizRouter } from './features/quizzes/quiz.routes.js';

export const app = express();

app.disable('x-powered-by');
app.use(helmet());
app.use(cors({ origin: env.CORS_ORIGIN === '*' ? true : env.CORS_ORIGIN }));
app.use(express.json({ limit: '100kb' }));
app.use(rateLimit({ windowMs: 15 * 60 * 1000, limit: 300, standardHeaders: 'draft-8', legacyHeaders: false }));

app.use('/api/v1', healthRouter);
app.use('/api/v1/auth', authRouter);
app.use('/api/v1/courses', courseRouter);
app.use('/api/v1', quizRouter);
app.use('/api/v1', attemptRouter);

app.use(notFoundHandler);
app.use(errorHandler);
