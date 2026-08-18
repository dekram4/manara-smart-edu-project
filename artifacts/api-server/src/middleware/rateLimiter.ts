/**
 * Simple in-memory IP-based rate limiter.
 * Tracks request counts per IP in a sliding 60-second window.
 */
import type { Request, Response, NextFunction } from "express";

interface Window {
  count: number;
  resetAt: number;
}

const windows = new Map<string, Window>();
const WINDOW_MS = 60_000; // 1 minute

function clientIp(req: Request): string {
  // Use the raw TCP socket address — this is always 127.0.0.1 on Replit
  // (the internal reverse proxy). Crucially, this value cannot be forged by
  // a caller via X-Forwarded-For, so the rate limit works as a reliable
  // server-side circuit breaker. We intentionally do NOT read X-Forwarded-For
  // because doing so would allow callers to bypass the limit by rotating IPs.
  return req.socket.remoteAddress ?? "unknown";
}

export function createRateLimit(maxPerMinute: number) {
  return function rateLimit(
    req: Request,
    res: Response,
    next: NextFunction,
  ): void {
    const ip = clientIp(req);
    const now = Date.now();
    const win = windows.get(ip);

    if (!win || now >= win.resetAt) {
      windows.set(ip, { count: 1, resetAt: now + WINDOW_MS });
      next();
      return;
    }

    if (win.count >= maxPerMinute) {
      res.status(429).json({
        error: "تجاوزت الحد المسموح به من الطلبات. يرجى الانتظار دقيقة.",
      });
      return;
    }

    win.count += 1;
    next();
  };
}

// Periodically prune expired entries to avoid unbounded memory growth
setInterval(() => {
  const now = Date.now();
  for (const [ip, win] of windows) {
    if (now >= win.resetAt) windows.delete(ip);
  }
}, WINDOW_MS);
