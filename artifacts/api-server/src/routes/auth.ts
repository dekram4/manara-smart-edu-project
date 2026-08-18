import { Router } from "express";
import crypto from "node:crypto";
import { verifyAdminSession } from "../middleware/adminAuth";
import { logger } from "../lib/logger";

const router = Router();

const ADMIN_SESSION_COOKIE = "manara_admin_session";
const ADMIN_SESSION_TTL_SECONDS = 60 * 60 * 24 * 14;

function sessionSecret(): string {
  const secret = process.env.SESSION_SECRET;
  if (!secret) {
    throw new Error(
      "SESSION_SECRET is required but not set — admin auth is disabled.",
    );
  }
  return secret;
}

function signAdminSession(payload: object): string {
  const encoded = Buffer.from(JSON.stringify(payload)).toString("base64url");
  const signature = crypto
    .createHmac("sha256", sessionSecret())
    .update(encoded)
    .digest("base64url");
  return `${encoded}.${signature}`;
}

function readCookie(req: { headers: { cookie?: string } }, name: string): string {
  const cookies = String(req.headers.cookie || "")
    .split(";")
    .map((part) => part.trim().split("="))
    .filter(([key]) => key);
  const match = cookies.find(([key]) => key === name);
  return match ? decodeURIComponent(match.slice(1).join("=")) : "";
}

function adminCookieOptions(maxAge = ADMIN_SESSION_TTL_SECONDS): string {
  const secure =
    process.env.NODE_ENV === "production" || process.env.REPLIT_DEPLOYMENT
      ? "; Secure"
      : "";
  return `Path=/; Max-Age=${maxAge}; HttpOnly; SameSite=Lax${secure}`;
}

router.post("/auth/admin", (req, res) => {
  const configuredUsername = process.env.ADMIN_USERNAME;
  const configuredPassword = process.env.ADMIN_PASSWORD;
  if (!configuredUsername || !configuredPassword) {
    logger.warn("Admin credentials not configured");
    return res.status(503).json({ error: "Admin credentials are not configured" });
  }
  const username =
    typeof req.body?.username === "string" ? req.body.username.trim() : "";
  const password =
    typeof req.body?.password === "string" ? req.body.password : "";
  if (
    !username ||
    !password ||
    username !== configuredUsername ||
    password !== configuredPassword
  ) {
    return res.status(401).json({ error: "Invalid administrator credentials" });
  }
  res.setHeader(
    "Set-Cookie",
    `${ADMIN_SESSION_COOKIE}=${encodeURIComponent(
      signAdminSession({
        role: "admin",
        expiresAt: Date.now() + ADMIN_SESSION_TTL_SECONDS * 1000,
      }),
    )}; ${adminCookieOptions()}`,
  );
  return res.json({ ok: true });
});

router.get("/auth/admin/session", (req, res) => {
  return res.json({
    authenticated: verifyAdminSession(readCookie(req, ADMIN_SESSION_COOKIE)),
  });
});

router.post("/auth/admin/logout", (_req, res) => {
  res.setHeader(
    "Set-Cookie",
    `${ADMIN_SESSION_COOKIE}=; ${adminCookieOptions(0)}`,
  );
  return res.json({ ok: true });
});

export default router;
