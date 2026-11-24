import { model, Schema, type InferSchemaType } from 'mongoose';

const courseMembershipSchema = new Schema(
  {
    courseId: {
      type: Schema.Types.ObjectId,
      ref: 'Course',
      required: true,
    },
    studentId: {
      type: Schema.Types.ObjectId,
      ref: 'User',
      required: true,
    },
    joinedAt: {
      type: Date,
      required: true,
      default: Date.now,
    },
  },
  {
    strict: true,
  },
);

courseMembershipSchema.index({ courseId: 1, studentId: 1 }, { unique: true });
courseMembershipSchema.index({ studentId: 1, joinedAt: -1 });
courseMembershipSchema.index({ courseId: 1, joinedAt: 1 });

export type CourseMembershipDocument = InferSchemaType<typeof courseMembershipSchema>;

export const CourseMembershipModel = model('CourseMembership', courseMembershipSchema);
