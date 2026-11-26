import type { UserRole } from '../../features/auth/user.model.js';

export interface AuthenticatedUser {
  id: string;
  role: UserRole;
}
