import type { RequestHandler } from 'express';
import { AppError } from '../../core/errors/app-error.js';
import { toErrorDetails } from '../../core/validation/zod-error-details.js';
import { createQuestionSchema, createQuizSchema, courseIdParamSchema, quizIdParamSchema, quizResultsQuerySchema } from './quiz.schemas.js';
import { addQuestion, createQuiz, getQuiz, listCourseQuizzes, publishQuiz } from './quiz.service.js';
import { getQuizLeaderboard, getQuizResults } from './quiz.results.service.js';

function invalidRequest(message: string, issues: Parameters<typeof toErrorDetails>[0]) {
  return new AppError(422, 'VALIDATION_ERROR', message, toErrorDetails(issues));
}

export const createQuizController: RequestHandler = async (request, response, next) => {
  const params = courseIdParamSchema.safeParse(request.params);
  const body = createQuizSchema.safeParse(request.body);
  if (!params.success) return next(invalidRequest('The course ID is invalid.', params.error.issues));
  if (!body.success) return next(invalidRequest('The request body is invalid.', body.error.issues));
  if (!request.authUser) return next(new AppError(401, 'AUTHENTICATION_REQUIRED', 'Authentication is required.'));

  try {
    const quiz = await createQuiz(params.data.courseId, request.authUser.id, body.data);
    response.status(201).json({ data: quiz });
  } catch (error: unknown) {
    next(error);
  }
};

export const addQuestionController: RequestHandler = async (request, response, next) => {
  const params = quizIdParamSchema.safeParse(request.params);
  const body = createQuestionSchema.safeParse(request.body);
  if (!params.success) return next(invalidRequest('The quiz ID is invalid.', params.error.issues));
  if (!body.success) return next(invalidRequest('The request body is invalid.', body.error.issues));
  if (!request.authUser) return next(new AppError(401, 'AUTHENTICATION_REQUIRED', 'Authentication is required.'));

  try {
    const question = await addQuestion(params.data.quizId, request.authUser.id, body.data);
    response.status(201).json({ data: question });
  } catch (error: unknown) {
    next(error);
  }
};

export const publishQuizController: RequestHandler = async (request, response, next) => {
  const params = quizIdParamSchema.safeParse(request.params);
  if (!params.success) return next(invalidRequest('The quiz ID is invalid.', params.error.issues));
  if (!request.authUser) return next(new AppError(401, 'AUTHENTICATION_REQUIRED', 'Authentication is required.'));

  try {
    const quiz = await publishQuiz(params.data.quizId, request.authUser.id);
    response.status(200).json({ data: quiz });
  } catch (error: unknown) {
    next(error);
  }
};

export const listCourseQuizzesController: RequestHandler = async (request, response, next) => {
  const params = courseIdParamSchema.safeParse(request.params);
  if (!params.success) return next(invalidRequest('The course ID is invalid.', params.error.issues));
  if (!request.authUser) return next(new AppError(401, 'AUTHENTICATION_REQUIRED', 'Authentication is required.'));

  try {
    const result = await listCourseQuizzes(params.data.courseId, request.authUser.id, request.authUser.role);
    response.status(200).json(result);
  } catch (error: unknown) {
    next(error);
  }
};

export const getQuizController: RequestHandler = async (request, response, next) => {
  const params = quizIdParamSchema.safeParse(request.params);
  if (!params.success) return next(invalidRequest('The quiz ID is invalid.', params.error.issues));
  if (!request.authUser) return next(new AppError(401, 'AUTHENTICATION_REQUIRED', 'Authentication is required.'));

  try {
    const result = await getQuiz(params.data.quizId, request.authUser.id, request.authUser.role);
    response.status(200).json(result);
  } catch (error: unknown) {
    next(error);
  }
};

export const getQuizResultsController: RequestHandler = async (request, response, next) => {
  const params = quizIdParamSchema.safeParse(request.params);
  const query = quizResultsQuerySchema.safeParse(request.query);
  if (!params.success) return next(invalidRequest('The quiz ID is invalid.', params.error.issues));
  if (!query.success) return next(invalidRequest('The pagination parameters are invalid.', query.error.issues));
  if (!request.authUser) return next(new AppError(401, 'AUTHENTICATION_REQUIRED', 'Authentication is required.'));

  try {
    const result = await getQuizResults(params.data.quizId, request.authUser.id, query.data);
    response.status(200).json(result);
  } catch (error: unknown) {
    next(error);
  }
};

export const getQuizLeaderboardController: RequestHandler = async (request, response, next) => {
  const params = quizIdParamSchema.safeParse(request.params);
  const query = quizResultsQuerySchema.safeParse(request.query);
  if (!params.success) return next(invalidRequest('The quiz ID is invalid.', params.error.issues));
  if (!query.success) return next(invalidRequest('The pagination parameters are invalid.', query.error.issues));
  if (!request.authUser) return next(new AppError(401, 'AUTHENTICATION_REQUIRED', 'Authentication is required.'));

  try {
    const result = await getQuizLeaderboard(
      params.data.quizId,
      request.authUser.id,
      request.authUser.role,
      query.data,
    );
    response.status(200).json(result);
  } catch (error: unknown) {
    next(error);
  }
};
