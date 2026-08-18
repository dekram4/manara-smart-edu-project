import { STORAGE_KEYS } from '../constants';
import {
  readSessionJson,
  readSessionValue,
  removeSessionValue,
  writeSessionJson,
} from './sessionPersistence';
import { readActiveSession } from './storage';

// Keep the legacy student session shape for migration compatibility.
// The web app no longer exposes or mounts the student dashboard; students use Flutter.
export type AuthRole = 'admin' | 'teacher' | 'student' | 'parent';

type AuthSessionRecord = {
  role: AuthRole;
  subjectId?: string;
  issuedAt: number;
  expiresAt: number;
};

const AUTH_SESSION_KEY = 'smartEdu_authSession';
const AUTH_SESSION_TTL_MS = 30 * 24 * 60 * 60 * 1000;

const hasPrincipalIdentity = (value: unknown): value is { id?: string; username?: string; studentIdNumber?: string } => {
  if (!value || typeof value !== 'object') return false;
  const principal = value as { id?: unknown; username?: unknown; studentIdNumber?: unknown };
  return [principal.id, principal.username, principal.studentIdNumber]
    .some((field) => typeof field === 'string' && field.trim().length > 0);
};

const getPrincipalForRole = (role: AuthRole): unknown => {
  if (role === 'student') return readActiveSession(STORAGE_KEYS.ACTIVE_STUDENT);
  if (role === 'teacher') return readActiveSession(STORAGE_KEYS.CURRENT_TEACHER);
  if (role === 'parent') return readActiveSession(STORAGE_KEYS.ACTIVE_PARENT);
  return readSessionValue('smartEdu_adminSession') === '1' ? { id: 'admin' } : null;
};

const getSubjectId = (principal: unknown): string | undefined => {
  if (!hasPrincipalIdentity(principal)) return undefined;
  return principal.id || principal.username || principal.studentIdNumber;
};

export const readAuthSession = (): AuthSessionRecord | null => {
  const session = readSessionJson<AuthSessionRecord | null>(AUTH_SESSION_KEY, null);
  if (!session || !session.role || !Number.isFinite(session.expiresAt)) return null;
  if (session.expiresAt <= Date.now()) {
    removeSessionValue(AUTH_SESSION_KEY);
    return null;
  }
  return session;
};

export const hasValidRoleSession = (role: AuthRole): boolean => {
  const principal = getPrincipalForRole(role);
  if (!hasPrincipalIdentity(principal)) return false;

  const session = readAuthSession();
  // Existing installations may have an active principal but no auth metadata.
  // Accept it once, then bind future restores to an expiring role session.
  return !session || (session.role === role && session.subjectId === getSubjectId(principal));
};

export const ensureRoleSession = (role: AuthRole): boolean => {
  if (!hasValidRoleSession(role)) return false;
  const principal = getPrincipalForRole(role);
  const current = readAuthSession();
  if (!current || current.role !== role || current.subjectId !== getSubjectId(principal)) {
    writeAuthSession(role, getSubjectId(principal));
  }
  return true;
};

export const writeAuthSession = (role: AuthRole, subjectId?: string): void => {
  const now = Date.now();
  writeSessionJson(AUTH_SESSION_KEY, {
    role,
    subjectId,
    issuedAt: now,
    expiresAt: now + AUTH_SESSION_TTL_MS,
  } satisfies AuthSessionRecord);
};

export const clearAuthSessions = (): void => {
  removeSessionValue(AUTH_SESSION_KEY);
};