import { model, Schema, type InferSchemaType } from 'mongoose';

export const ATTEMPT_STATUSES = ['in_progress', 'completed'] as const;

const answerSchema = new Schema(
  {
    questionId: { type: Schema.Types.ObjectId, ref: 'Question', required: true },
    selectedOptionIndex: { type: Number, min: 0, default: null },
    isCorrect: { type: Boolean, required: true },
    pointsEarned: { type: Number, min: 0, required: true },
    answeredAt: { type: Date, required: true },
  },
  { _id: false, strict: true },
);

const attemptSchema = new Schema(
  {
    quizId: { type: Schema.Types.ObjectId, ref: 'Quiz', required: true },
    studentId: { type: Schema.Types.ObjectId, ref: 'User', required: true },
    questionIds: { type: [{ type: Schema.Types.ObjectId, ref: 'Question' }], required: true },
    currentQuestionIndex: { type: Number, required: true, min: 0, default: 0 },
    currentQuestionStartedAt: { type: Date, required: true },
    startedAt: { type: Date, required: true },
    status: { type: String, enum: ATTEMPT_STATUSES, required: true, default: 'in_progress' },
    answers: { type: [answerSchema], default: [] },
    score: { type: Number, required: true, min: 0, default: 0 },
    totalPoints: { type: Number, required: true, min: 0 },
    submittedAt: { type: Date },
  },
  { timestamps: true, strict: true, optimisticConcurrency: true },
);

attemptSchema.index({ quizId: 1, studentId: 1 }, { unique: true });
attemptSchema.index({ studentId: 1, startedAt: -1 });

export type AttemptDocument = InferSchemaType<typeof attemptSchema>;
export const AttemptModel = model('Attempt', attemptSchema);
