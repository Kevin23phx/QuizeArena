import type { AuthenticatedUser } from '../core/types/authenticated-user.js';

declare global {
  namespace Express {
    interface Request {
      authUser?: AuthenticatedUser;
    }
  }
}

export {};
