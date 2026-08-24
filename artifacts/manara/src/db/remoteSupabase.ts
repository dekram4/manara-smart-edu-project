type RemoteResult<T = unknown> =
  | { data: T; error: null }
  | { data: null; error: RemoteRequestError };

export class RemoteRequestError extends Error {
  readonly status: number;
  readonly retryable: boolean;

  constructor(message: string, status = 0) {
    super(message);
    this.name = 'RemoteRequestError';
    this.status = status;
    this.retryable = status === 0 || status >= 500 || status === 408 || status === 429;
  }
}

class RemoteUnavailableError extends Error {
  silent = true;

  constructor() {
    super('Supabase is unavailable in this environment');
  }
}

let remoteState: 'unknown' | 'ready' | 'unavailable' = 'unknown';
let probePromise: Promise<boolean> | null = null;
let remoteUnavailableUntil = 0;
const REQUEST_TIMEOUT_MS = 10000;
const REQUEST_RETRY_DELAY_MS = 300;

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
  if (remoteState === 'unavailable' && Date.now() < remoteUnavailableUntil) return false;
  if (remoteState === 'unavailable') {
    remoteState = 'unknown';
  }
  if (!probePromise) {
    probePromise = fetchWithTimeout('/api/supabase/health')
      .then((response) => {
        remoteState = response.ok ? 'ready' : 'unavailable';
        remoteUnavailableUntil = response.ok ? 0 : Date.now() + 5000;
        return response.ok;
      })
      .catch(() => {
        remoteState = 'unavailable';
        remoteUnavailableUntil = Date.now() + 5000;
        return false;
      })
      .finally(() => {
        probePromise = null;
      });
  }
  return probePromise;
}

async function request<T>(url: string, init?: RequestInit): Promise<RemoteResult<T>> {
  let lastError: RemoteRequestError = new RemoteUnavailableError();

  for (let attempt = 0; attempt < 3; attempt += 1) {
    if (!(await isRemoteReady())) {
      lastError = new RemoteUnavailableError();
      // Allow the next retry to probe again instead of waiting for the
      // backoff window. This matters when Safari briefly suspends a request.
      remoteState = 'unknown';
      remoteUnavailableUntil = 0;
    } else {
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
        if (response.ok) {
          remoteState = 'ready';
          remoteUnavailableUntil = 0;
          return { data: body as T, error: null };
        }

        const message = typeof body === 'string'
          ? body
          : body?.error || `Supabase request failed (${response.status})`;
        lastError = new RemoteRequestError(message, response.status);

        // Do not clear a user's local session because an upstream request
        // briefly returned JWT/network/connector errors. Let the next attempt
        // re-probe the bridge instead of permanently pinning it unavailable.
        remoteState = 'unknown';
        remoteUnavailableUntil = 0;
      } catch (error) {
        lastError = error instanceof RemoteRequestError
          ? error
          : new RemoteRequestError(
            error instanceof Error ? error.message : 'Supabase request failed',
          );
        remoteState = 'unknown';
        remoteUnavailableUntil = 0;
      }
    }

    if (attempt < 2) {
      await new Promise((resolve) => window.setTimeout(resolve, REQUEST_RETRY_DELAY_MS * (attempt + 1)));
    }
  }

  return { data: null, error: lastError };
}

export const supabase = {
  context() {
    return request<{ role: 'admin' | 'teacher'; scope: string; teacherId?: string }>('/api/supabase/context');
  },
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