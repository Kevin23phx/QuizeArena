import { z } from 'zod';

export const quizIdParamSchema = z.strictObject({
  quizId: z.string().regex(/^[0-9a-fA-F]{24}$/),
});

export const attemptIdParamSchema = z.strictObject({
  attemptId: z.string().regex(/^[0-9a-fA-F]{24}$/),
});

export const submitAnswerSchema = z.strictObject({
  questionId: z.string().regex(/^[0-9a-fA-F]{24}$/),
  selectedOptionIndex: z.number().int().min(0),
});

export type SubmitAnswerInput = z.infer<typeof submitAnswerSchema>;
