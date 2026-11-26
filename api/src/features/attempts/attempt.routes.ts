import { Router } from 'express';
import { requireAuthentication } from '../../core/middleware/authentication.middleware.js';
import { requireRoles } from '../../core/middleware/authorization.middleware.js';
import { getAttemptController, startAttemptController, submitAnswerController } from './attempt.controller.js';

export const attemptRouter = Router();

attemptRouter.post('/quizzes/:quizId/attempts', requireAuthentication, requireRoles('student'), startAttemptController);
attemptRouter.get('/attempts/:attemptId', requireAuthentication, requireRoles('student'), getAttemptController);
attemptRouter.post('/attempts/:attemptId/answers', requireAuthentication, requireRoles('student'), submitAnswerController);
