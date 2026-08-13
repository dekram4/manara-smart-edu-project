import express from 'express';
import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import { fileURLToPath } from 'node:url';
import { createServer as createViteServer } from 'vite';
import {
  deleteSupabaseVideo,
  registerSupabaseRoutes,
  uploadSupabaseVideo,
} from './supabase-bridge.js';
import { registerGameEmbedProxy } from './game-embed-proxy.js';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const root = path.resolve(__dirname, '..');
const port = Number(process.env.PORT || 5000);
const isProduction = process.env.NODE_ENV === 'production' || Boolean(process.env.REPLIT_DEPLOYMENT);
const uploadDirectory = path.join(root, 'uploads', 'videos');
fs.mkdirSync(uploadDirectory, { recursive: true });

const ADMIN_SESSION_COOKIE = 'manara_admin_session';
const ADMIN_SESSION_TTL_SECONDS = 60 * 60 * 24 * 14;

function sessionSecret() {
  return process.env.SESSION_SECRET || 'manara-development-session-secret';
}

function signAdminSession(payload) {
  const encoded = Buffer.from(JSON.stringify(payload)).toString('base64url');
  const signature = crypto
    .createHmac('sha256', sessionSecret())
    .update(encoded)
    .digest('base64url');
  return `${encoded}.${signature}`;
}

function verifyAdminSession(value) {
  if (!value) return false;
  const [encoded, signature] = String(value).split('.');
  if (!encoded || !signature) return false;
  const expected = crypto
    .createHmac('sha256', sessionSecret())
    .update(encoded)
    .digest('base64url');
  if (signature.length !== expected.length || !crypto.timingSafeEqual(
    Buffer.from(signature),
    Buffer.from(expected),
  )) return false;
  try {
    const payload = JSON.parse(Buffer.from(encoded, 'base64url').toString('utf8'));
    return payload?.role === 'admin' && Number(payload?.expiresAt) > Date.now();
  } catch {
    return false;
  }
}

function readCookie(req, name) {
  const cookies = String(req.headers.cookie || '')
    .split(';')
    .map((part) => part.trim().split('='))
    .filter(([key]) => key);
  const match = cookies.find(([key]) => key === name);
  return match ? decodeURIComponent(match.slice(1).join('=')) : '';
}

function adminCookieOptions(maxAge = ADMIN_SESSION_TTL_SECONDS) {
  const forwardedProto = String(process.env.NODE_ENV === 'production' ? 'https' : '');
  const secure = forwardedProto === 'https' || process.env.REPLIT_DEPLOYMENT
    ? '; Secure'
    : '';
  return `Path=/; Max-Age=${maxAge}; HttpOnly; SameSite=Lax${secure}`;
}


const app = express();
app.use(express.json({ limit: '5mb' }));

app.post('/api/auth/admin', (req, res) => {
  const configuredUsername = process.env.ADMIN_USERNAME;
  const configuredPassword = process.env.ADMIN_PASSWORD;
  if (!configuredUsername || !configuredPassword) {
    return res.status(503).json({ error: 'Admin credentials are not configured' });
  }
  const username = typeof req.body?.username === 'string' ? req.body.username.trim() : '';
  const password = typeof req.body?.password === 'string' ? req.body.password : '';
  if (!username || !password || username !== configuredUsername || password !== configuredPassword) {
    return res.status(401).json({ error: 'Invalid administrator credentials' });
  }
  res.setHeader(
    'Set-Cookie',
    `${ADMIN_SESSION_COOKIE}=${encodeURIComponent(signAdminSession({
      role: 'admin',
      expiresAt: Date.now() + ADMIN_SESSION_TTL_SECONDS * 1000,
    }))}; ${adminCookieOptions()}`,
  );
  return res.json({ ok: true });
});
app.get('/api/auth/admin/session', (req, res) => {
  return res.json({ authenticated: verifyAdminSession(readCookie(req, ADMIN_SESSION_COOKIE)) });
});
app.post('/api/auth/admin/logout', (_req, res) => {
  res.setHeader('Set-Cookie', `${ADMIN_SESSION_COOKIE}=; ${adminCookieOptions(0)}`);
  return res.json({ ok: true });
});
app.use('/uploads', express.static(path.join(root, 'uploads'), {
  immutable: false,
  maxAge: '1h',
}));

async function callGemini(prompt, { temperature = 0.2, maxOutputTokens = 2048, json = false } = {}) {
  const apiKey = process.env.GEMINI_API_KEY;
  if (!apiKey) {
    const error = new Error('GEMINI_API_KEY is not configured');
    error.statusCode = 503;
    throw error;
  }
  const models = await getGeminiModels(apiKey);
  let lastUnavailableMessage = '';

  for (const model of models) {
    const response = await fetch(
      `https://generativelanguage.googleapis.com/v1beta/${model}:generateContent?key=${encodeURIComponent(apiKey)}`,
      {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          contents: [{ parts: [{ text: prompt }] }],
          generationConfig: {
            temperature,
            maxOutputTokens,
            ...(json ? { responseMimeType: 'application/json' } : {}),
          },
        }),
      },
    );
    const data = await response.json().catch(() => ({}));
    if (response.ok) {
      console.log(`[gemini] generated with ${model.replace(/^models\//, '')}`);
      return data;
    }

    const message = data?.error?.message || 'Gemini request failed';
    const modelUnavailable =
      response.status === 404 ||
      /not found|not available|not supported|new users/i.test(message);
    if (modelUnavailable) {
      lastUnavailableMessage = message;
      console.warn(`[gemini] skipping unavailable model ${model}: ${message}`);
      continue;
    }

    const error = new Error(message);
    error.statusCode = response.status >= 500 ? 502 : response.status;
    throw error;
  }

  const error = new Error(lastUnavailableMessage || 'No available Gemini model');
  error.statusCode = 503;
  throw error;
}

let geminiModelsPromise;

async function getGeminiModels(apiKey) {
  if (!geminiModelsPromise) {
    geminiModelsPromise = (async () => {
      const configuredModel = String(process.env.GEMINI_MODEL || '').trim().replace(/^models\//, '');
      const response = await fetch(
        `https://generativelanguage.googleapis.com/v1beta/models?key=${encodeURIComponent(apiKey)}`,
      );
      const data = await response.json().catch(() => ({}));
      if (!response.ok) {
        const error = new Error('Gemini model discovery failed');
        error.statusCode = response.status >= 500 ? 502 : response.status;
        throw error;
      }

      const availableModels = Array.isArray(data.models)
        ? data.models
            .filter((item) => item?.name && item.supportedGenerationMethods?.includes('generateContent'))
            .map((item) => String(item.name).replace(/^models\//, ''))
        : [];

      const preferredModels = [
        configuredModel,
        'gemini-flash-latest',
        'gemini-flash-lite-latest',
        'gemini-3.5-flash',
        'gemini-3.1-flash-lite',
        'gemini-2.5-flash-lite',
        'gemini-2.5-flash',
      ].filter(Boolean);

      const models = [
        ...preferredModels.filter((candidate) => availableModels.includes(candidate)),
        ...availableModels.filter(
          (candidate) =>
            !preferredModels.includes(candidate) &&
            /flash/i.test(candidate) &&
            !/(tts|image|audio)/i.test(candidate),
        ),
        ...availableModels.filter((candidate) => !preferredModels.includes(candidate)),
      ];

      if (models.length === 0) {
        const error = new Error('No Gemini model supports generateContent');
        error.statusCode = 503;
        throw error;
      }
      console.log(`[gemini] discovered ${models.length} candidate model(s)`);
      return models.map((model) => `models/${model}`);
    })().catch((error) => {
      geminiModelsPromise = undefined;
      throw error;
    });
  }
  return geminiModelsPromise;
}

function getGeminiText(data) {
  return data?.candidates?.[0]?.content?.parts
    ?.map((part) => (typeof part?.text === 'string' ? part.text : ''))
    .join('')
    .trim() || null;
}

app.post('/api/gemini/answer', async (req, res) => {
  const lesson = typeof req.body?.lesson === 'string' ? req.body.lesson.trim() : '';
  const question = typeof req.body?.question === 'string' ? req.body.question.trim() : '';
  if (!lesson || !question || lesson.length > 12000 || question.length > 2000) {
    return res.status(400).json({ error: 'محتوى الدرس أو السؤال غير صالح' });
  }
  const prompt = `أنت مساعد تعليمي ذكي. اقرأ النص التالي:\n\n${lesson}\n\nالسؤال: ${question}\n\nأجب إجابة مباشرة، ذكية، مفصلة، وبدون مقدمات أو تكرار للسؤال. إذا لم تجد الإجابة في نص الدرس، قل بوضوح: "هذا السؤال ليس من ضمن الدرس ولا أستطيع الإجابة عليه" ولا تستخدم معرفتك العامة. فقط أعطِ الجواب النهائي للطالب.\n`;
  try {
    const data = await callGemini(prompt);
    return res.json({
      answer: getGeminiText(data),
    });
  } catch (error) {
    console.error('[gemini] answer failed:', error.message);
    return res.status(error.statusCode || 500).json({ error: 'تعذر الاتصال بخدمة الذكاء الاصطناعي' });
  }
});

app.post('/api/gemini/generate-quiz', async (req, res) => {
  const prompt = typeof req.body?.prompt === 'string' ? req.body.prompt.trim() : '';
  const temperature = Number.isFinite(req.body?.temperature) ? req.body.temperature : 0.7;
  const maxOutputTokens = Number.isFinite(req.body?.maxOutputTokens)
    ? Math.min(Math.max(req.body.maxOutputTokens, 256), 9000)
    : 3000;
  if (!prompt || prompt.length > 14000) {
    return res.status(400).json({ error: 'طلب توليد الاختبار غير صالح' });
  }
  try {
    const data = await callGemini(prompt, { temperature, maxOutputTokens, json: true });
    return res.json(data);
  } catch (error) {
    console.error('[gemini] quiz generation failed:', error.message);
    return res.status(error.statusCode || 500).json({ error: 'تعذر توليد الاختبار بالذكاء الاصطناعي' });
  }
});

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
    try {
      const fileName = `${crypto.randomUUID()}.mp4`;
      const url = await uploadSupabaseVideo(fileName, req.body);
      return res.status(201).json({
        url,
        fileName: originalName,
        size: req.body.length,
        contentType: 'video/mp4',
      });
    } catch (error) {
      console.error('[media] Supabase Storage upload failed:', error?.message || error);
      return res.status(502).json({ error: error?.message || 'تعذر حفظ ملف الفيديو في Supabase Storage' });
    }
  },
);

app.post('/api/media/delete', async (req, res) => {
  const rawUrl = typeof req.body?.url === 'string' ? req.body.url : '';
  const supabaseMatch = rawUrl.match(/^\/api\/media\/videos\/([a-zA-Z0-9-]+\.mp4)$/);
  if (supabaseMatch) {
    try {
      await deleteSupabaseVideo(supabaseMatch[1]);
      return res.status(204).end();
    } catch (error) {
      console.error('[media] Supabase Storage delete failed:', error?.message || error);
      return res.status(502).json({ error: 'تعذر حذف ملف الفيديو من Supabase Storage' });
    }
  }
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