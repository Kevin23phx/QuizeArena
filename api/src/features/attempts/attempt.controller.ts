import type { RequestHandler } from 'express';
import { AppError } from '../../core/errors/app-error.js';
import { toErrorDetails } from '../../core/validation/zod-error-details.js';
import { getAttempt, startAttempt, submitAnswer } from './attempt.service.js';
import { attemptIdParamSchema, quizIdParamSchema, submitAnswerSchema } from './attempt.schemas.js';

function invalidRequest(message: string, issues: Parameters<typeof toErrorDetails>[0]) {
  return new AppError(422, 'VALIDATION_ERROR', message, toErrorDetails(issues));
}

export const startAttemptController: RequestHandler = async (request, response, next) => {
  const params = quizIdParamSchema.safeParse(request.params);
  if (!params.success) return next(invalidRequest('The quiz ID is invalid.', params.error.issues));
  if (!request.authUser) return next(new AppError(401, 'AUTHENTICATION_REQUIRED', 'Authentication is required.'));

  try {
    const result = await startAttempt(params.data.quizId, request.authUser.id);
    response.status(result.created ? 201 : 200).json({ data: result.data });
  } catch (error: unknown) {
    next(error);
  }
};

export const getAttemptController: RequestHandler = async (request, response, next) => {
  const params = attemptIdParamSchema.safeParse(request.params);
  if (!params.success) return next(invalidRequest('The attempt ID is invalid.', params.error.issues));
  if (!request.authUser) return next(new AppError(401, 'AUTHENTICATION_REQUIRED', 'Authentication is required.'));

  try {
    const result = await getAttempt(params.data.attemptId, request.authUser.id);
    response.status(200).json(result);
  } catch (error: unknown) {
    next(error);
  }
};

export const submitAnswerController: RequestHandler = async (request, response, next) => {
  const params = attemptIdParamSchema.safeParse(request.params);
  const body = submitAnswerSchema.safeParse(request.body);
  if (!params.success) return next(invalidRequest('The attempt ID is invalid.', params.error.issues));
  if (!body.success) return next(invalidRequest('The answer body is invalid.', body.error.issues));
  if (!request.authUser) return next(new AppError(401, 'AUTHENTICATION_REQUIRED', 'Authentication is required.'));

  try {
    const result = await submitAnswer(params.data.attemptId, request.authUser.id, body.data);
    response.status(200).json(result);
  } catch (error: unknown) {
    next(error);
  }
};
