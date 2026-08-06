import express from 'express';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { createServer as createViteServer } from 'vite';
import { registerSupabaseRoutes } from './supabase-bridge.js';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const root = path.resolve(__dirname, '..');
const port = Number(process.env.PORT || 5000);
const isProduction = process.env.NODE_ENV === 'production' || Boolean(process.env.REPLIT_DEPLOYMENT);

const app = express();
app.use(express.json({ limit: '5mb' }));
registerSupabaseRoutes(app);
app.get('/health', (_req, res) => res.json({ ok: true }));

if (isProduction) {
  const dist = path.join(root, 'dist');
  app.use(express.static(dist, { index: false }));
  app.get('*', (_req, res) => res.sendFile(path.join(dist, 'index.html')));
} else {
  const vite = await createViteServer({
    root,
    server: { middlewareMode: true, hmr: false, allowedHosts: true },
    appType: 'spa',
  });
  app.use(vite.middlewares);
}

app.listen(port, '0.0.0.0', () => {
  console.log(`Manara web server running on port ${port} (${isProduction ? 'production' : 'development'})`);
});