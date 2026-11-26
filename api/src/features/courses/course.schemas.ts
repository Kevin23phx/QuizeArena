import { z } from 'zod';

export const createCourseSchema = z.strictObject({
  name: z.string().trim().min(1, 'Course name is required').max(100, 'Course name must be at most 100 characters'),
  description: z.string().trim().max(500, 'Description must be at most 500 characters').default(''),
});

export const joinCourseSchema = z.strictObject({
  joinCode: z.string().trim().toUpperCase().min(1, 'Join code is required').max(32, 'Join code must be at most 32 characters'),
});

export const listCoursesQuerySchema = z.strictObject({
  page: z.coerce.number().int().min(1).default(1),
  limit: z.coerce.number().int().min(1).max(50).default(20),
  q: z.string().trim().min(1).max(100).optional(),
});

export const courseIdParamSchema = z.strictObject({
  courseId: z.string().regex(/^[0-9a-fA-F]{24}$/, 'Course ID must be a valid MongoDB ID'),
});

export type CreateCourseInput = z.infer<typeof createCourseSchema>;
export type JoinCourseInput = z.infer<typeof joinCourseSchema>;
export type ListCoursesQuery = z.infer<typeof listCoursesQuerySchema>;
