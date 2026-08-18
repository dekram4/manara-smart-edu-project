import { STORAGE_KEYS } from '../constants';
import { readSessionJson, removeSessionValue, writeSessionJson } from './sessionPersistence';

/**
 * Read browser storage defensively.
 *
 * Mobile browsers can briefly expose a partially-written value while another
 * tab/session is syncing. A bad collection must never unmount the dashboard
 * or turn a transient storage error into a logout.
 */
export function readStorageJson<T>(key: string, fallback: T): T {
  try {
    const raw = window.localStorage.getItem(key);
    if (!raw) return fallback;
    const parsed: unknown = JSON.parse(raw);
    return parsed as T;
  } catch {
    return fallback;
  }
}

export function readStorageArray<T>(key: string): T[] {
  const value = readStorageJson<unknown>(key, []);
  return Array.isArray(value) ? value as T[] : [];
}

export function readActiveSession<T>(key: string): T | null {
  const value = readSessionJson<unknown>(key, null);
  return value && typeof value === 'object' ? value as T : null;
}

export function writeActiveSession<T>(key: string, value: T): boolean {
  return writeSessionJson(key, value);
}

export function removeActiveSession(key: string): void {
  removeSessionValue(key);
}

export function readStoredCollections(): {
  students: unknown[];
  parents: unknown[];
  teachers: unknown[];
  quizzes: unknown[];
} {
  return {
    students: readStorageArray(STORAGE_KEYS.STUDENTS),
    parents: readStorageArray(STORAGE_KEYS.PARENTS),
    teachers: readStorageArray(STORAGE_KEYS.TEACHERS),
    quizzes: readStorageArray(STORAGE_KEYS.QUIZ_RESULTS),
  };
}