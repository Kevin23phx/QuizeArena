import { model, Schema, type InferSchemaType } from 'mongoose';

const courseSchema = new Schema(
  {
    name: {
      type: String,
      required: true,
      trim: true,
      maxlength: 100,
    },
    description: {
      type: String,
      trim: true,
      maxlength: 500,
      default: '',
    },
    teacherId: {
      type: Schema.Types.ObjectId,
      ref: 'User',
      required: true,
    },
    joinCode: {
      type: String,
      required: true,
      uppercase: true,
      maxlength: 32,
      unique: true,
      select: false,
    },
  },
  {
    timestamps: true,
    strict: true,
  },
);

courseSchema.index({ teacherId: 1, createdAt: -1 });
courseSchema.index({ name: 'text' });

export type CourseDocument = InferSchemaType<typeof courseSchema>;

export const CourseModel = model('Course', courseSchema);
