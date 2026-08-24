/**
 * Session-only persistence with an iOS/Safari-safe fallback.
 *
 * Safari private browsing, embedded web views, and storage-quota errors can
 * throw from localStorage. A storage failure must never be interpreted as a
 * logout, so we fall back to sessionStorage and finally an in-memory store.
 */
const memoryStore = new Map<string, string>();

function getStorage(kind: 'local' | 'session'): Storage | null {
  if (typeof window === 'undefined') return null;
  try {
    const storage = kind === 'local' ? window.localStorage : window.sessionStorage;
    const probeKey = '__manara_storage_probe__';
    storage.setItem(probeKey, '1');
    storage.removeItem(probeKey);
    return storage;
  } catch {
    return null;
  }
}

export function readSessionValue(key: string): string | null {
  const local = getStorage('local');
  try {
    const value = local?.getItem(key);
    if (value != null) return value;
  } catch {
    // Try the fallback stores below.
  }

  const session = getStorage('session');
  try {
    const value = session?.getItem(key);
    if (value != null) return value;
  } catch {
    // Use memory below.
  }

  return memoryStore.get(key) ?? null;
}

export function writeSessionValue(key: string, value: string): boolean {
  let persisted = false;
  const local = getStorage('local');
  try {
    local?.setItem(key, value);
    persisted = Boolean(local);
  } catch {
    // Continue with Safari-safe fallbacks.
  }

  if (!persisted) {
    const session = getStorage('session');
    try {
      session?.setItem(key, value);
      persisted = Boolean(session);
    } catch {
      // Use memory below.
    }
  }

  memoryStore.set(key, value);
  return persisted || memoryStore.get(key) === value;
}

export function removeSessionValue(key: string): void {
  for (const storage of [getStorage('local'), getStorage('session')]) {
    try {
      storage?.removeItem(key);
    } catch {
      // A broken storage backend must not block the explicit logout action.
    }
  }
  memoryStore.delete(key);
}

export function readSessionJson<T>(key: string, fallback: T): T {
  const raw = readSessionValue(key);
  if (!raw) return fallback;
  try {
    return JSON.parse(raw) as T;
  } catch {
    return fallback;
  }
}

export function writeSessionJson(key: string, value: unknown): boolean {
  return writeSessionValue(key, JSON.stringify(value));
}

export const SESSION_KEYS = {
  ACTIVE_ROLE: 'smartEdu_activeRole',
  ADMIN_SESSION: 'smartEdu_adminSession',
} as const;