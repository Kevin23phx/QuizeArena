import { z } from 'zod';

export const createQuizSchema = z.strictObject({
  title: z.string().trim().min(1).max(100),
  description: z.string().trim().max(500).default(''),
});

export const createQuestionSchema = z.strictObject({
  prompt: z.string().trim().min(1).max(500),
  options: z.array(z.string().trim().min(1).max(150)).min(2).max(6),
  correctOptionIndex: z.number().int().min(0),
  points: z.number().int().min(1).max(100).default(1),
  position: z.number().int().min(0).optional(),
}).refine((question) => question.correctOptionIndex < question.options.length, {
  path: ['correctOptionIndex'],
  message: 'Correct option index must refer to an existing option.',
});

export const courseIdParamSchema = z.strictObject({
  courseId: z.string().regex(/^[0-9a-fA-F]{24}$/),
});

export const quizIdParamSchema = z.strictObject({
  quizId: z.string().regex(/^[0-9a-fA-F]{24}$/),
});

export const quizResultsQuerySchema = z.strictObject({
  page: z.coerce.number().int().min(1).default(1),
  limit: z.coerce.number().int().min(1).max(50).default(20),
});

export type CreateQuizInput = z.infer<typeof createQuizSchema>;
export type CreateQuestionInput = z.infer<typeof createQuestionSchema>;
export type QuizResultsQuery = z.infer<typeof quizResultsQuerySchema>;
