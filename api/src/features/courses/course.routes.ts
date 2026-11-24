import { Router } from 'express';
import { requireAuthentication } from '../../core/middleware/authentication.middleware.js';
import { requireRoles } from '../../core/middleware/authorization.middleware.js';
import { createCourseController, getCourseController, joinCourseController, listCoursesController } from './course.controller.js';

export const courseRouter = Router();

courseRouter.post('/', requireAuthentication, requireRoles('teacher'), createCourseController);
courseRouter.get('/', requireAuthentication, listCoursesController);
courseRouter.get('/:courseId', requireAuthentication, getCourseController);
courseRouter.post('/join', requireAuthentication, requireRoles('student'), joinCourseController);
