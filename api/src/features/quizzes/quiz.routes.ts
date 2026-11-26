import { Router } from 'express';
import { requireAuthentication } from '../../core/middleware/authentication.middleware.js';
import { requireRoles } from '../../core/middleware/authorization.middleware.js';
import {
  addQuestionController,
  createQuizController,
  getQuizController,
  getQuizLeaderboardController,
  getQuizResultsController,
  listCourseQuizzesController,
  publishQuizController,
} from './quiz.controller.js';

export const quizRouter = Router();

quizRouter.post('/courses/:courseId/quizzes', requireAuthentication, requireRoles('teacher'), createQuizController);
quizRouter.get('/courses/:courseId/quizzes', requireAuthentication, listCourseQuizzesController);
quizRouter.post('/quizzes/:quizId/questions', requireAuthentication, requireRoles('teacher'), addQuestionController);
quizRouter.post('/quizzes/:quizId/publish', requireAuthentication, requireRoles('teacher'), publishQuizController);
quizRouter.get('/quizzes/:quizId', requireAuthentication, getQuizController);
quizRouter.get('/quizzes/:quizId/results', requireAuthentication, requireRoles('teacher'), getQuizResultsController);
quizRouter.get('/quizzes/:quizId/leaderboard', requireAuthentication, getQuizLeaderboardController);
