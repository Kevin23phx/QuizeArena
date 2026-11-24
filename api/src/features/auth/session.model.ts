import { model, Schema, type InferSchemaType } from 'mongoose';

const sessionSchema = new Schema(
  {
    userId: {
      type: Schema.Types.ObjectId,
      ref: 'User',
      required: true,
    },
    refreshTokenHash: {
      type: String,
      required: true,
      select: false,
    },
    consumedRefreshTokenHashes: {
      type: [String],
      default: [],
      select: false,
    },
    expiresAt: {
      type: Date,
      required: true,
    },
    revokedAt: {
      type: Date,
      default: null,
    },
  },
  {
    timestamps: true,
    strict: true,
  },
);

sessionSchema.index({ refreshTokenHash: 1 }, { unique: true });
sessionSchema.index({ consumedRefreshTokenHashes: 1 });
sessionSchema.index({ userId: 1, revokedAt: 1 });
sessionSchema.index({ expiresAt: 1 }, { expireAfterSeconds: 0 });

export type SessionDocument = InferSchemaType<typeof sessionSchema>;

export const SessionModel = model('Session', sessionSchema);
