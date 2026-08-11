type RemoteResult<T = unknown> = { data: T; error: null } | { data: null; error: Error };

class RemoteUnavailableError extends Error {
  silent = true;

  constructor() {
    super('Supabase is unavailable in this environment');
  }
}

let remoteState: 'unknown' | 'ready' | 'unavailable' = 'unknown';
let probePromise: Promise<boolean> | null = null;
const REQUEST_TIMEOUT_MS = 10000;

async function fetchWithTimeout(url: string, init?: RequestInit): Promise<Response> {
  const controller = new AbortController();
  const timeoutId = window.setTimeout(() => controller.abort(), REQUEST_TIMEOUT_MS);
  try {
    return await fetch(url, {
      ...init,
      signal: init?.signal ?? controller.signal,
    });
  } finally {
    window.clearTimeout(timeoutId);
  }
}

async function isRemoteReady(): Promise<boolean> {
  if (remoteState === 'ready') return true;
  if (remoteState === 'unavailable') return false;
  if (!probePromise) {
    probePromise = fetchWithTimeout('/api/supabase/health')
      .then((response) => {
        remoteState = response.ok ? 'ready' : 'unavailable';
        return response.ok;
      })
      .catch(() => {
        remoteState = 'unavailable';
        return false;
      });
  }
  return probePromise;
}

async function request<T>(url: string, init?: RequestInit): Promise<RemoteResult<T>> {
  if (!(await isRemoteReady())) {
    // Development preview may not have access to a production-only connector.
    // Keep localStorage as the offline source of truth without noisy errors.
    return { data: null, error: new RemoteUnavailableError() };
  }
  try {
      const response = await fetchWithTimeout(url, init);
    const text = await response.text();
    let body: any = null;
    if (text) {
      try {
        body = JSON.parse(text);
      } catch {
        body = text;
      }
    }
    if (!response.ok) {
      if (response.status === 401 || response.status === 403 || response.status === 404) {
        remoteState = 'unavailable';
      }
      const message = typeof body === 'string' ? body : body?.error || `Supabase request failed (${response.status})`;
      return { data: null, error: new Error(message) };
    }
    return { data: body as T, error: null };
  } catch (error) {
    return { data: null, error: error instanceof Error ? error : new Error('Supabase request failed') };
  }
}

export const supabase = {
  from(table: string) {
    return {
      select(columns = '*') {
        return request<any[]>(`/api/supabase/${encodeURIComponent(table)}?select=${encodeURIComponent(columns)}`);
      },
      upsert(rows: any | any[], _options?: { onConflict?: string }) {
        return request(`/api/supabase/${encodeURIComponent(table)}/upsert`, {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ rows: Array.isArray(rows) ? rows : [rows] }),
        });
      },
      delete() {
        return {
          in(_column: string, ids: string[]) {
            return request(`/api/supabase/${encodeURIComponent(table)}/delete`, {
              method: 'POST',
              headers: { 'Content-Type': 'application/json' },
              body: JSON.stringify({ ids }),
            });
          },
        };
      },
    };
  },
};