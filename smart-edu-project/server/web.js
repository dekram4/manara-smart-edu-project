import express from 'express';
import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import { fileURLToPath } from 'node:url';
import { createServer as createViteServer } from 'vite';
import { registerSupabaseRoutes } from './supabase-bridge.js';
import { registerGameEmbedProxy } from './game-embed-proxy.js';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const root = path.resolve(__dirname, '..');
const port = Number(process.env.PORT || 5000);
const isProduction = process.env.NODE_ENV === 'production' || Boolean(process.env.REPLIT_DEPLOYMENT);
const uploadDirectory = path.join(root, 'uploads', 'videos');
fs.mkdirSync(uploadDirectory, { recursive: true });


const app = express();
app.use(express.json({ limit: '5mb' }));
app.use('/uploads', express.static(path.join(root, 'uploads'), {
  immutable: false,
  maxAge: '1h',
}));

app.post(
  '/api/media/upload',
  express.raw({ type: ['video/mp4', 'application/octet-stream'], limit: '500mb' }),
  async (req, res) => {
    if (!Buffer.isBuffer(req.body) || req.body.length === 0) {
      return res.status(400).json({ error: 'لم يتم اختيار ملف MP4' });
    }
    const contentType = String(req.headers['content-type'] || '').split(';')[0].toLowerCase();
    const originalName = String(req.headers['x-file-name'] || 'video.mp4');
    if (contentType !== 'video/mp4' && path.extname(originalName).toLowerCase() !== '.mp4') {
      return res.status(400).json({ error: 'يسمح برفع ملفات MP4 فقط' });
    }
    const fileName = `${crypto.randomUUID()}.mp4`;
    const filePath = path.join(uploadDirectory, fileName);
    try {
      await fs.promises.writeFile(filePath, req.body);
      return res.status(201).json({
        url: `/uploads/videos/${fileName}`,
        fileName: originalName,
        size: req.body.length,
        contentType: 'video/mp4',
      });
    } catch {
      return res.status(500).json({ error: 'تعذر حفظ ملف الفيديو' });
    }
  },
);

app.post('/api/media/delete', async (req, res) => {
  const rawUrl = typeof req.body?.url === 'string' ? req.body.url : '';
  const relativePath = rawUrl.replace(/^\/+/, '');
  const absolutePath = path.resolve(root, relativePath);
  const uploadRoot = path.resolve(uploadDirectory);
  if (!relativePath.startsWith('uploads/videos/') || !absolutePath.startsWith(`${uploadRoot}${path.sep}`)) {
    return res.status(400).json({ error: 'مسار ملف غير صالح' });
  }
  try {
    await fs.promises.unlink(absolutePath);
  } catch (error) {
    if (error?.code !== 'ENOENT') return res.status(500).json({ error: 'تعذر حذف ملف الفيديو' });
  }
  return res.status(204).end();
});

registerSupabaseRoutes(app);
registerGameEmbedProxy(app);
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