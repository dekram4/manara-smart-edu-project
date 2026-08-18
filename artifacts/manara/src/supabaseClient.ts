import { createClient, type SupportedStorage } from '@supabase/supabase-js';

/**
 * Optional browser-side Supabase Auth client.
 *
 * The main MANARA web app uses the server-side bridge in db/remoteSupabase.ts
 * and does not expose server secrets. This client is only created when public
 * VITE_* Supabase Auth variables are explicitly configured for a browser app.
 */
const env = (import.meta as ImportMeta & {
  env?: Record<string, string | undefined>;
}).env || {};

const supabaseUrl = env.VITE_SUPABASE_URL;
const supabaseAnonKey = env.VITE_SUPABASE_ANON_KEY;

const memoryStorage = new Map<string, string>();

const safeStorage: SupportedStorage = {
  getItem: (key) => {
    for (const storage of [
      typeof window !== 'undefined' ? window.localStorage : null,
      typeof window !== 'undefined' ? window.sessionStorage : null,
    ]) {
      try {
        const value = storage?.getItem(key);
        if (value !== null && value !== undefined) return value;
      } catch {
        // Safari private browsing can throw; continue to the fallback.
      }
    }
    return memoryStorage.get(key) ?? null;
  },
  setItem: (key, value) => {
    let stored = false;
    try {
      window.localStorage.setItem(key, value);
      stored = true;
    } catch {
      // Fall through to sessionStorage/memory.
    }
    if (!stored) {
      try {
        window.sessionStorage.setItem(key, value);
        stored = true;
      } catch {
        // Fall through to memory.
      }
    }
    memoryStorage.set(key, value);
  },
  removeItem: (key) => {
    for (const storage of [window.localStorage, window.sessionStorage]) {
      try {
        storage.removeItem(key);
      } catch {
        // A broken storage backend must not block sign-out.
      }
    }
    memoryStorage.delete(key);
  },
};

export const supabase = supabaseUrl && supabaseAnonKey
  ? createClient(supabaseUrl, supabaseAnonKey, {
      auth: {
        persistSession: true,
        autoRefreshToken: true,
        detectSessionInUrl: true,
        storage: safeStorage,
      },
    })
  : null;

export const isSupabaseAuthConfigured = Boolean(supabase);