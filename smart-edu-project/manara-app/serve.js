const http = require('http');
const path = require('path');
const fs = require('fs');

const PORT = 5000;
const ROOT = path.join(__dirname, 'dist');

const MIME = {
  '.html': 'text/html',
  '.js': 'application/javascript',
  '.css': 'text/css',
  '.json': 'application/json',
  '.png': 'image/png',
  '.jpg': 'image/jpeg',
  '.ico': 'image/x-icon',
  '.woff2': 'font/woff2',
  '.ttf': 'font/ttf',
  '.svg': 'image/svg+xml',
};

const server = http.createServer((req, res) => {
  let filePath = path.join(ROOT, req.url === '/' ? 'index.html' : req.url);
  const ext = path.extname(filePath) || '.html';

  // Handle SPA routing - serve index.html for unknown paths
  if (!fs.existsSync(filePath) && !ext.match(/\.(js|css|png|jpg|ico|woff|ttf|svg|json)$/)) {
    filePath = path.join(ROOT, 'index.html');
  }

  if (!fs.existsSync(filePath)) {
    res.writeHead(404);
    res.end('Not found');
    return;
  }

  const mimeType = MIME[ext] || 'application/octet-stream';
  res.writeHead(200, {
    'Content-Type': mimeType,
    'Cache-Control': 'no-cache',
  });
  fs.createReadStream(filePath).pipe(res);
});

server.listen(PORT, '0.0.0.0', () => {
  console.log(`MANARA web server running on port ${PORT}`);
});
