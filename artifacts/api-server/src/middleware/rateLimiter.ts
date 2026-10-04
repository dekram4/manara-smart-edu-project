/**
 * Simple in-memory IP-based rate limiter.
 * Tracks request counts per IP in a sliding 60-second window.
 */
import type { Request, Response, NextFunction } from "express";

interface Window {
  count: number;
  resetAt: number;
}

const WINDOW_MS = 60_000; // 1 minute

/**
 * One map per limiter.
 *
 * This used to be a single module-level map shared by every limiter, so all
 * of them counted into the same window: a burst on one route consumed the
 * budget of every other. Worse, on Replit every request arrives from the
 * proxy at 127.0.0.1 (see [clientIp]), so the "per IP" window was in practice
 * one counter for the whole platform. Separate maps at least stop one route
 * starving the others; routes behind a student session should prefer
 * [createStudentRateLimit], which counts per student.
 */
const allWindows: Map<string, Window>[] = [];

function clientIp(req: Request): string {
  // Use the raw TCP socket address — this is always 127.0.0.1 on Replit
  // (the internal reverse proxy). Crucially, this value cannot be forged by
  // a caller via X-Forwarded-For, so the rate limit works as a reliable
  // server-side circuit breaker. We intentionally do NOT read X-Forwarded-For
  // because doing so would allow callers to bypass the limit by rotating IPs.
  return req.socket.remoteAddress ?? "unknown";
}

export function createRateLimit(maxPerMinute: number) {
  const windows = new Map<string, Window>();
  allWindows.push(windows);
  return limiter(maxPerMinute, windows, clientIp);
}

/**
 * The same window, counted per client address as the platform's proxy saw it.
 *
 * For public routes with no session to count by — such as serving videos. The
 * socket address is the proxy's (127.0.0.1 on Replit), so counting by it is one
 * window for every visitor: a class opening the same video together — each
 * player sending several Range requests — would lock everyone out.
 *
 * The client address is the LAST entry of X-Forwarded-For: the proxy appends
 * what it saw to whatever the caller sent, so the caller controls the entries
 * to its left but never the last one. Rotating forged entries changes nothing.
 * Without the header (a direct connection) the socket address is used.
 */
export function createClientRateLimit(maxPerMinute: number) {
  const windows = new Map<string, Window>();
  allWindows.push(windows);
  return limiter(maxPerMinute, windows, (req) => {
    const header = req.headers["x-forwarded-for"];
    const raw = Array.isArray(header) ? header[header.length - 1] : header;
    const last = raw?.split(",").pop()?.trim();
    return last ? `client:${last}` : clientIp(req);
  });
}

/**
 * The same window, counted per signed-in student rather than per address.
 *
 * Must run after `requireStudentSession`, which puts the student on
 * `res.locals`. Every pupil in a school shares one public address, and on
 * Replit every request shares 127.0.0.1 — an address limit there throttles
 * the whole school as one. A live duel sends an answer per question from both
 * players; counted per address, two matches at once ran out of budget.
 */
export function createStudentRateLimit(maxPerMinute: number) {
  const windows = new Map<string, Window>();
  allWindows.push(windows);
  return limiter(maxPerMinute, windows, (req, res) => {
    const student = (res.locals as { student?: { id?: unknown } }).student;
    const id = typeof student?.id === "string" ? student.id : "";
    return id ? `student:${id}` : clientIp(req);
  });
}

function limiter(
  maxPerMinute: number,
  windows: Map<string, Window>,
  keyOf: (req: Request, res: Response) => string,
) {
  return function rateLimit(
    req: Request,
    res: Response,
    next: NextFunction,
  ): void {
    const key = keyOf(req, res);
    const now = Date.now();
    const win = windows.get(key);

    if (!win || now >= win.resetAt) {
      windows.set(key, { count: 1, resetAt: now + WINDOW_MS });
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
  for (const windows of allWindows) {
    for (const [key, win] of windows) {
      if (now >= win.resetAt) windows.delete(key);
    }
  }
}, WINDOW_MS);
