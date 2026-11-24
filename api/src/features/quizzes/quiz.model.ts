import { model, Schema, type InferSchemaType } from 'mongoose';

export const QUIZ_STATUSES = ['draft', 'published', 'closed'] as const;
export type QuizStatus = (typeof QUIZ_STATUSES)[number];

const quizSchema = new Schema(
  {
    courseId: { type: Schema.Types.ObjectId, ref: 'Course', required: true, index: true },
    teacherId: { type: Schema.Types.ObjectId, ref: 'User', required: true, index: true },
    title: { type: String, required: true, trim: true, maxlength: 100 },
    description: { type: String, trim: true, maxlength: 500, default: '' },
    timePerQuestionSeconds: { type: Number, required: true, default: 10, min: 10, max: 10, immutable: true },
    status: { type: String, enum: QUIZ_STATUSES, required: true, default: 'draft' },
  },
  { timestamps: true, strict: true },
);

quizSchema.index({ courseId: 1, status: 1, createdAt: -1 });

export type QuizDocument = InferSchemaType<typeof quizSchema>;
export const QuizModel = model('Quiz', quizSchema);
