import express from 'express';
import fetch from 'node-fetch';
import dotenv from 'dotenv';

dotenv.config();

const app = express();
const PORT = process.env.PROXY_PORT || 4000;

// Simple health
app.get('/health', (req, res) => res.send('ok'));

// Proxy endpoint: fetches a URL server-side and returns it.
// Usage: /d-id/open?url=<encoded_url>
app.get('/d-id/open', async (req, res) => {
  const { url } = req.query;
  if (!url || typeof url !== 'string') return res.status(400).send('missing url');

  try {
    // Only allow D-ID studio URLs by default to avoid open proxy abuse
    const allowedHost = 'studio.d-id.com';
    try {
      const u = new URL(url);
      if (!u.hostname.includes(allowedHost)) {
        return res.status(400).send('only studio.d-id.com URLs are allowed');
      }
    } catch (e) {
      return res.status(400).send('invalid url');
    }

    const headers = {};
    if (process.env.D_ID_API_KEY) headers['Authorization'] = `Bearer ${process.env.D_ID_API_KEY}`;

    const upstream = await fetch(url, { headers });
    const contentType = upstream.headers.get('content-type') || 'text/html';

    // stream response back
    res.setHeader('content-type', contentType);
    res.status(upstream.status);
    upstream.body.pipe(res);
  } catch (err) {
    console.error('proxy error', err);
    res.status(500).send('proxy error');
  }
});

app.listen(PORT, () => console.log(`Proxy server running on http://localhost:${PORT}`));
