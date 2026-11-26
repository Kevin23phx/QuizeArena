import { model, Schema, type InferSchemaType } from 'mongoose';

const questionSchema = new Schema(
  {
    quizId: { type: Schema.Types.ObjectId, ref: 'Quiz', required: true },
    prompt: { type: String, required: true, trim: true, maxlength: 500 },
    options: {
      type: [{ type: String, required: true, trim: true, maxlength: 150 }],
      required: true,
      validate: { validator: (options: string[]) => options.length >= 2 && options.length <= 6 },
    },
    correctOptionIndex: { type: Number, required: true, min: 0, select: false },
    points: { type: Number, required: true, min: 1, max: 100, default: 1 },
    position: { type: Number, required: true, min: 0 },
  },
  { timestamps: true, strict: true },
);

questionSchema.index({ quizId: 1, position: 1 }, { unique: true });

export type QuestionDocument = InferSchemaType<typeof questionSchema>;
export const QuestionModel = model('Question', questionSchema);
