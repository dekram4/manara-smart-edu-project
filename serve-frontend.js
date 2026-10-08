const http = require('http');
const fs = require('fs');
const path = require('path');

const PORT = process.env.PORT || 5000;

// البحث الذكي عن مجلد التجميع dist في عدة مسارات محتملة
const possiblePaths = [
  path.resolve(process.cwd(), 'artifacts/mockup-sandbox/dist'),
  path.resolve(__dirname, 'artifacts/mockup-sandbox/dist'),
  path.resolve(process.cwd(), 'dist'),
  path.resolve(__dirname, 'dist')
];

let DIST_DIR = possiblePaths.find(p => fs.existsSync(p));

console.log(`[SERVER] Listening Port: ${PORT}`);
console.log(`[SERVER] Detected Dist Dir: ${DIST_DIR || 'NOT FOUND YET'}`);

const MIME_TYPES = {
  '.html': 'text/html; charset=utf-8',
  '.js': 'text/javascript',
  '.css': 'text/css',
  '.json': 'application/json',
  '.png': 'image/png',
  '.jpg': 'image/jpeg',
  '.svg': 'image/svg+xml',
  '.ico': 'image/x-icon',
  '.woff': 'font/woff',
  '.woff2': 'font/woff2'
};

const server = http.createServer((req, res) => {
  if (!DIST_DIR) {
    DIST_DIR = possiblePaths.find(p => fs.existsSync(p));
  }

  if (!DIST_DIR) {
    res.writeHead(200, { 'Content-Type': 'text/html; charset=utf-8' });
    return res.end(`
      <div style="font-family:sans-serif; text-align:center; padding:50px;">
        <h2>جاري تحضير ملفات الواجهة...</h2>
        <p>مجلد dist غير موجود في المسارات المتوقعة.</p>
        <p><b>Current Working Dir:</b> ${process.cwd()}</p>
      </div>
    `);
  }

  let reqPath = req.url.split('?')[0];
  let filePath = path.join(DIST_DIR, reqPath === '/' ? 'index.html' : reqPath);

  if (!fs.existsSync(filePath) || fs.statSync(filePath).isDirectory()) {
    filePath = path.join(DIST_DIR, 'index.html');
  }

  const ext = String(path.extname(filePath)).toLowerCase();
  const contentType = MIME_TYPES[ext] || 'application/octet-stream';

  fs.readFile(filePath, (err, content) => {
    if (err) {
      res.writeHead(500, { 'Content-Type': 'text/plain' });
      res.end('File Read Error: ' + err.message);
    } else {
      res.writeHead(200, { 'Content-Type': contentType });
      res.end(content);
    }
  });
});

server.listen(PORT, '0.0.0.0', () => {
  console.log(`[SUCCESS] Server listening on http://0.0.0.0:${PORT}`);
});
