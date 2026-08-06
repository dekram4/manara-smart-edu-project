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

const connectors = new ReplitConnectors();
const MIN_REQUEST_INTERVAL_MS = 140;
let lastRequestAt = 0;
let proxyQueue = Promise.resolve();

function assertTable(table) {
  if (!TABLES.has(table)) {
    const error = new Error('Unsupported Supabase table');
    error.statusCode = 400;
    throw error;
  }
}

async function proxySupabase(path, options = {}) {
  const request = proxyQueue.then(async () => {
    const waitMs = Math.max(0, MIN_REQUEST_INTERVAL_MS - (Date.now() - lastRequestAt));
    if (waitMs > 0) await new Promise((resolve) => setTimeout(resolve, waitMs));
    lastRequestAt = Date.now();
    return connectors.proxy('supabase', path, options);
  });
  proxyQueue = request.catch(() => {});
  return request;
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
}