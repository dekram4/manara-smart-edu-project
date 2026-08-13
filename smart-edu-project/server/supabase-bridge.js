import { ReplitConnectors } from '@replit/connectors-sdk';

const TABLES = new Set([
  'students',
  'parents',
  'teachers',
  'lesson_configs',
  'created_quizzes',
  'quiz_results',
  'interactions',
  'private_messages',
  'public_messages',
  'certificates',
  'app_kv',
]);
// New uploads prefer the public `cinema` bucket. Existing installations may
// already have `videos` or the legacy `manara-videos` bucket, so discovery
// below reuses those instead of trying to create a second bucket.
export const SUPABASE_STORAGE_BUCKET =
  String(process.env.SUPABASE_STORAGE_BUCKET || 'cinema').trim() || 'cinema';
const STORAGE_BUCKET_CANDIDATES = Array.from(new Set([
  SUPABASE_STORAGE_BUCKET,
  'cinema',
  'videos',
  'manara-videos',
]));
let activeStorageBucket = SUPABASE_STORAGE_BUCKET;

const connectors = new ReplitConnectors();
const MIN_REQUEST_INTERVAL_MS = 140;
let lastRequestAt = 0;
let proxyQueue = Promise.resolve();

function hasDirectSupabaseConfig() {
  return Boolean(process.env.SUPABASE_URL && process.env.SUPABASE_ANON_KEY);
}

function isUsableServiceKey(value) {
  const key = String(value || '').trim();
  return key.startsWith('sb_secret_')
    || /^[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+$/.test(key);
}

async function directSupabaseFetch(path, options = {}) {
  const baseUrl = process.env.SUPABASE_URL.replace(/\/+$/, '');
  // Keep the privileged key scoped to Storage only. A malformed or rotated
  // service key must never break the app's normal REST synchronization.
  const isStorageRequest = String(path).startsWith('/storage/');
  const serviceKey = process.env.SUPABASE_SERVICE_ROLE_KEY;
  const apiKey = isStorageRequest && isUsableServiceKey(serviceKey)
    ? serviceKey
    : process.env.SUPABASE_ANON_KEY;
  const headers = new Headers(options.headers || {});
  headers.set('apikey', apiKey);
  // Supabase's newer sb_publishable/sb_secret keys are API keys, not JWTs.
  // Sending one as a Bearer token makes Storage return "Invalid Compact JWS".
  if (String(apiKey).startsWith('sb_')) {
    headers.delete('Authorization');
  } else {
    headers.set('Authorization', `Bearer ${apiKey}`);
  }
  return fetch(`${baseUrl}${path}`, { ...options, headers });
}

function assertTable(table) {
  if (!TABLES.has(table)) {
    const error = new Error('Unsupported Supabase table');
    error.statusCode = 400;
    throw error;
  }
}

export async function proxySupabase(path, options = {}) {
  const request = proxyQueue.then(async () => {
    const waitMs = Math.max(0, MIN_REQUEST_INTERVAL_MS - (Date.now() - lastRequestAt));
    if (waitMs > 0) await new Promise((resolve) => setTimeout(resolve, waitMs));
    lastRequestAt = Date.now();
    if (hasDirectSupabaseConfig()) {
      return directSupabaseFetch(path, options);
    }
    return connectors.proxy('supabase', path, options);
  });
  proxyQueue = request.catch(() => {});
  return request;
}

let storageInitializationPromise;

async function ensureStorageBucket() {
  if (storageInitializationPromise) return storageInitializationPromise;
  storageInitializationPromise = (async () => {
    for (const bucketName of STORAGE_BUCKET_CANDIDATES) {
      const existing = await proxySupabase(`/storage/v1/bucket/${bucketName}`);
      const existingBody = await existing.clone().text().catch(() => '');
      const bucketMissing = existing.status === 404
        || existingBody.includes('NoSuchBucket')
        || existingBody.includes('Bucket not found')
        || /resource was not found/i.test(existingBody);
      if (!existing.ok && !bucketMissing) {
        console.warn(
          `[supabase] could not inspect bucket ${bucketName}: ${existing.status} ${existingBody.slice(0, 180)}`,
        );
        continue;
      }
      if (!existing.ok) continue;

      activeStorageBucket = bucketName;
      // Keep the bucket public for browser previews and direct public access.
      // Upload authorization is supplied by the service-role/connector
      // connection; the SQL policy file documents the anon/authenticated rule.
      let bucket = {};
      try {
        bucket = JSON.parse(existingBody || '{}');
      } catch {
        bucket = {};
      }
      if (bucket.public !== true) {
        const updated = await proxySupabase(
          `/storage/v1/bucket/${bucketName}`,
          {
            method: 'PUT',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({
              public: true,
              allowed_mime_types: ['video/mp4'],
            }),
          },
        );
        if (!updated.ok && updated.status === 413) {
          await proxySupabase(
            `/storage/v1/bucket/${bucketName}`,
            {
              method: 'PUT',
              headers: { 'Content-Type': 'application/json' },
              body: JSON.stringify({ public: true }),
            },
          );
        } else if (!updated.ok) {
          console.warn(
            `[supabase] bucket ${bucketName} exists but could not be made public (${updated.status})`,
          );
        }
      }
      return true;
    }

    const created = await proxySupabase('/storage/v1/bucket', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        id: SUPABASE_STORAGE_BUCKET,
        name: SUPABASE_STORAGE_BUCKET,
        public: true,
        allowed_mime_types: ['video/mp4'],
      }),
    });
    if (created.ok || created.status === 409) return true;
    if (created.status === 413) {
      const retry = await proxySupabase('/storage/v1/bucket', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          id: SUPABASE_STORAGE_BUCKET,
          name: SUPABASE_STORAGE_BUCKET,
          public: true,
        }),
      });
      if (retry.ok || retry.status === 409) {
        activeStorageBucket = SUPABASE_STORAGE_BUCKET;
        return true;
      }
    }

    const createBody = await created.text().catch(() => '');
    console.warn(
      `[supabase] could not create bucket ${SUPABASE_STORAGE_BUCKET}: ${created.status} ${createBody.slice(0, 220)}`,
    );
    return false;
  })().finally(() => {
    storageInitializationPromise = undefined;
  });
  return storageInitializationPromise;
}

export async function initializeSupabaseStorage() {
  if (!hasDirectSupabaseConfig() && !process.env.REPLIT_CONNECTORS_HOSTNAME) {
    console.warn('[supabase] storage initialization skipped: Supabase is not configured');
    return false;
  }
  try {
    const ready = await ensureStorageBucket();
    if (ready) {
      console.log(`[supabase] storage bucket ready: ${activeStorageBucket}`);
    }
    return ready;
  } catch (error) {
    console.warn('[supabase] storage initialization deferred:', error?.message || error);
    return false;
  }
}

export async function uploadSupabaseVideo(fileName, body) {
  if (!(await ensureStorageBucket())) {
    throw new Error(
      `تعذر تجهيز حاوية Supabase Storage (${SUPABASE_STORAGE_BUCKET}). `
      + 'تحقق من صلاحيات Storage أو طبّق server/supabase-storage.sql مرة واحدة.',
    );
  }
  const upstream = await proxySupabase(
    `/storage/v1/object/${activeStorageBucket}/${encodeURIComponent(fileName)}`,
    {
      method: 'POST',
      headers: {
        'Content-Type': 'video/mp4',
        'x-upsert': 'false',
        'Cache-Control': 'public, max-age=31536000, immutable',
      },
      body,
    },
  );
  if (!upstream.ok) {
    const message = await upstream.text();
    throw new Error(message.slice(0, 300) || 'فشل رفع الفيديو إلى Supabase Storage');
  }
  return `/api/media/videos/${encodeURIComponent(fileName)}`;
}

export async function deleteSupabaseVideo(fileName) {
  const buckets = Array.from(new Set([
    activeStorageBucket,
    ...STORAGE_BUCKET_CANDIDATES,
  ]));
  for (const bucket of buckets) {
    const upstream = await proxySupabase(
      `/storage/v1/object/${bucket}/${encodeURIComponent(fileName)}`,
      { method: 'DELETE' },
    );
    if (upstream.ok || upstream.status === 404) {
      if (upstream.ok) return;
      continue;
    }
    throw new Error('تعذر حذف الفيديو من Supabase Storage');
  }
}

async function fetchVideoFromBucket(bucket, fileName) {
  return proxySupabase(
    `/storage/v1/object/${bucket}/${encodeURIComponent(fileName)}`,
  );
}

async function sendProxyResponse(res, upstream) {
  const text = await upstream.text();
  res.status(upstream.status);
  const contentType = upstream.headers.get('content-type');
  if (contentType) res.setHeader('content-type', contentType);
  if (text) res.send(text);
  else res.end();
}

export function registerSupabaseRoutes(app) {
  app.get('/api/supabase/health', async (_req, res) => {
    try {
      const upstream = await proxySupabase('/rest/v1/students?select=id&limit=1');
      if (!upstream.ok) {
        const body = await upstream.text();
        return res.status(upstream.status).json({
          ok: false,
          configured: true,
          schemaReady: false,
          error: body.slice(0, 500),
        });
      }
      return res.json({ ok: true, configured: true, schemaReady: true });
    } catch (error) {
      console.error('[supabase] health check failed:', error?.message || error);
      return res.status(503).json({
        ok: false,
        configured: false,
        schemaReady: false,
        error: 'Supabase connector is unavailable',
      });
    }
  });

  app.get('/api/supabase/:table', async (req, res) => {
    try {
      const { table } = req.params;
      assertTable(table);
      const query = new URLSearchParams();
      const select = typeof req.query.select === 'string' ? req.query.select : '*';
      query.set('select', select);
      if (typeof req.query.limit === 'string') query.set('limit', req.query.limit);
      const upstream = await proxySupabase(`/rest/v1/${table}?${query.toString()}`);
      return sendProxyResponse(res, upstream);
    } catch (error) {
      const status = error?.statusCode || 502;
      console.error(`[supabase] read ${req.params.table} failed:`, error?.message || error);
      return res.status(status).json({ error: error?.message || 'Supabase read failed' });
    }
  });

  app.post('/api/supabase/:table/upsert', async (req, res) => {
    try {
      const { table } = req.params;
      assertTable(table);
      if (!Array.isArray(req.body?.rows)) {
        return res.status(400).json({ error: 'rows must be an array' });
      }
      const isKv = table === 'app_kv';
      const conflictColumn = isKv ? 'key' : 'id';
      const upstream = await proxySupabase(
        `/rest/v1/${table}?on_conflict=${conflictColumn}`,
        {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
            Prefer: 'resolution=merge-duplicates,return=minimal',
          },
          body: JSON.stringify(req.body.rows),
        },
      );
      return sendProxyResponse(res, upstream);
    } catch (error) {
      const status = error?.statusCode || 502;
      console.error(`[supabase] upsert ${req.params.table} failed:`, error?.message || error);
      return res.status(status).json({ error: error?.message || 'Supabase upsert failed' });
    }
  });

  app.post('/api/supabase/:table/delete', async (req, res) => {
    try {
      const { table } = req.params;
      assertTable(table);
      if (table === 'app_kv' || !Array.isArray(req.body?.ids)) {
        return res.status(400).json({ error: 'ids must be an array for row tables' });
      }
      const ids = req.body.ids
        .filter((id) => id !== null && id !== undefined)
        .map((id) => `"${String(id).replaceAll('"', '\\"')}"`)
        .join(',');
      if (!ids) return res.status(204).end();
      const upstream = await proxySupabase(`/rest/v1/${table}?id=in.(${encodeURIComponent(ids)})`, {
        method: 'DELETE',
        headers: { Prefer: 'return=minimal' },
      });
      return sendProxyResponse(res, upstream);
    } catch (error) {
      const status = error?.statusCode || 502;
      console.error(`[supabase] delete ${req.params.table} failed:`, error?.message || error);
      return res.status(status).json({ error: error?.message || 'Supabase delete failed' });
    }
  });

  app.get('/api/media/videos/:fileName', async (req, res) => {
    const fileName = String(req.params.fileName || '');
    if (!/^[a-zA-Z0-9-]+\.mp4$/.test(fileName)) {
      return res.status(400).json({ error: 'اسم ملف فيديو غير صالح' });
    }
    try {
      const buckets = Array.from(new Set([
        activeStorageBucket,
        ...STORAGE_BUCKET_CANDIDATES,
      ]));
      let upstream;
      for (const bucket of buckets) {
        upstream = await fetchVideoFromBucket(bucket, fileName);
        if (upstream.ok || upstream.status !== 404) break;
      }
      res.status(upstream.status);
      const contentType = upstream.headers.get('content-type');
      const contentLength = upstream.headers.get('content-length');
      if (contentType) res.setHeader('content-type', contentType);
      if (contentLength) res.setHeader('content-length', contentLength);
      res.setHeader('Cache-Control', 'public, max-age=31536000, immutable');
      if (!upstream.body) return res.end();
      const reader = upstream.body.getReader();
      const pump = async () => {
        try {
          while (true) {
            const { done, value } = await reader.read();
            if (done) break;
            res.write(Buffer.from(value));
          }
          res.end();
        } catch {
          res.end();
        }
      };
      await pump();
    } catch {
      return res.status(502).json({ error: 'تعذر قراءة الفيديو من Supabase Storage' });
    }
  });
}