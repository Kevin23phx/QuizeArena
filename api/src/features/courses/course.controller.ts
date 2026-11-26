import type { RequestHandler } from 'express';
import { AppError } from '../../core/errors/app-error.js';
import { toErrorDetails } from '../../core/validation/zod-error-details.js';
import { courseIdParamSchema, createCourseSchema, joinCourseSchema, listCoursesQuerySchema } from './course.schemas.js';
import { createCourse, getCourse, joinCourse, listCourses } from './course.service.js';

export const listCoursesController: RequestHandler = async (request, response, next) => {
  const parsedQuery = listCoursesQuerySchema.safeParse(request.query);

  if (!parsedQuery.success) {
    next(new AppError(
      422,
      'VALIDATION_ERROR',
      'The query parameters are invalid.',
      toErrorDetails(parsedQuery.error.issues),
    ));
    return;
  }

  if (!request.authUser) {
    next(new AppError(401, 'AUTHENTICATION_REQUIRED', 'Authentication is required.'));
    return;
  }

  try {
    const result = await listCourses(request.authUser.id, request.authUser.role, parsedQuery.data);
    response.status(200).json(result);
  } catch (error: unknown) {
    next(error);
  }
};

export const getCourseController: RequestHandler = async (request, response, next) => {
  const parsedParams = courseIdParamSchema.safeParse(request.params);

  if (!parsedParams.success) {
    next(new AppError(
      422,
      'VALIDATION_ERROR',
      'The course ID is invalid.',
      toErrorDetails(parsedParams.error.issues),
    ));
    return;
  }

  if (!request.authUser) {
    next(new AppError(401, 'AUTHENTICATION_REQUIRED', 'Authentication is required.'));
    return;
  }

  try {
    const course = await getCourse(
      parsedParams.data.courseId,
      request.authUser.id,
      request.authUser.role,
    );
    response.status(200).json({ data: course });
  } catch (error: unknown) {
    next(error);
  }
};

export const createCourseController: RequestHandler = async (request, response, next) => {
  const parsedBody = createCourseSchema.safeParse(request.body);

  if (!parsedBody.success) {
    next(new AppError(
      422,
      'VALIDATION_ERROR',
      'The request body is invalid.',
      toErrorDetails(parsedBody.error.issues),
    ));
    return;
  }

  if (!request.authUser) {
    next(new AppError(401, 'AUTHENTICATION_REQUIRED', 'Authentication is required.'));
    return;
  }

  try {
    const course = await createCourse(parsedBody.data, request.authUser.id);
    response.status(201).json({ data: course });
  } catch (error: unknown) {
    next(error);
  }
};

export const joinCourseController: RequestHandler = async (request, response, next) => {
  const parsedBody = joinCourseSchema.safeParse(request.body);

  if (!parsedBody.success) {
    next(new AppError(
      422,
      'VALIDATION_ERROR',
      'The request body is invalid.',
      toErrorDetails(parsedBody.error.issues),
    ));
    return;
  }

  if (!request.authUser) {
    next(new AppError(401, 'AUTHENTICATION_REQUIRED', 'Authentication is required.'));
    return;
  }

  try {
    const result = await joinCourse(parsedBody.data, request.authUser.id);
    response.status(result.created ? 201 : 200).json({ data: result.membership });
  } catch (error: unknown) {
    next(error);
  }
};
