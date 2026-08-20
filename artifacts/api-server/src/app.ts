import express, { type Express } from "express";
import cors from "cors";
import pinoHttp from "pino-http";
import path from "node:path";
import { fileURLToPath } from "node:url";
import router from "./routes";
import { uploadDirectory } from "./routes/media";
import { logger } from "./lib/logger";

const __dirname = path.dirname(fileURLToPath(import.meta.url));

const app: Express = express();

// Do NOT set trust proxy: with it, req.ip reads from X-Forwarded-For which
// clients can forge. Without it, req.ip = req.socket.remoteAddress = 127.0.0.1
// (Replit's internal proxy) — a value callers cannot spoof. The Gemini rate
// limiter therefore enforces a global server-side circuit-breaker that no
// header manipulation can bypass.

app.use(
  pinoHttp({
    logger,
    serializers: {
      req(req) {
        return {
          id: req.id,
          method: req.method,
          url: req.url?.split("?")[0],
        };
      },
      res(res) {
        return {
          statusCode: res.statusCode,
        };
      },
    },
  }),
);
// Restrict CORS to the Replit dev domain and localhost only
const allowedOrigins: string[] = [
  "http://localhost",
  "http://127.0.0.1",
  ...(process.env.REPLIT_DEV_DOMAIN
    ? [`https://${process.env.REPLIT_DEV_DOMAIN}`]
    : []),
];
// Allow port variants for local dev (Vite runs on various ports).
const apiCors = cors({
  origin: (origin, cb) => {
    if (!origin) return cb(null, true); // same-origin / server-to-server
    const trusted =
      allowedOrigins.some((o) => origin === o || origin.startsWith(o + ":")) ||
      (process.env.REPLIT_DEV_DOMAIN &&
        origin.endsWith(`.${process.env.REPLIT_DEV_DOMAIN}`));
    cb(trusted ? null : new Error("CORS: origin not allowed"), trusted ?? false);
  },
  credentials: true,
});

app.use((req, res, next) => {
  const isNativeVideoRequest =
    (req.method === "GET" || req.method === "HEAD") &&
    /^\/api\/media\/videos\/[a-zA-Z0-9-]+\.mp4$/.test(req.path) &&
    req.get("origin") === "null";

  // Desktop WebViews can request a media source with an opaque `null` origin.
  // The endpoint is intentionally public and read-only; do not relax CORS for
  // authenticated or mutating API routes.
  if (isNativeVideoRequest) {
    res.setHeader("Access-Control-Allow-Origin", "null");
    res.append("Vary", "Origin");
    return next();
  }

  return apiCors(req, res, next);
});
app.use(express.json());
app.use(express.urlencoded({ extended: true }));

// Serve locally-uploaded videos
app.use("/uploads/videos", express.static(uploadDirectory, { index: false }));

app.use("/api", router);

export default app;
