import type { Request, Response, NextFunction } from "express";
import crypto from "node:crypto";

const ADMIN_SESSION_COOKIE = "manara_admin_session";

function sessionSecret(): string {
  const secret = process.env.SESSION_SECRET;
  if (!secret) {
    throw new Error(
      "SESSION_SECRET environment variable is required but not set. " +
        "Admin authentication is disabled until it is configured.",
    );
  }
  return secret;
}

function readCookie(req: Request, name: string): string {
  const cookies = String(req.headers.cookie || "")
    .split(";")
    .map((part) => part.trim().split("="))
    .filter(([key]) => key);
  const match = cookies.find(([key]) => key === name);
  return match ? decodeURIComponent(match.slice(1).join("=")) : "";
}

export function verifyAdminSession(value: string): boolean {
  if (!value) return false;
  const [encoded, signature] = String(value).split(".");
  if (!encoded || !signature) return false;
  const expected = crypto
    .createHmac("sha256", sessionSecret())
    .update(encoded)
    .digest("base64url");
  if (
    signature.length !== expected.length ||
    !crypto.timingSafeEqual(Buffer.from(signature), Buffer.from(expected))
  )
    return false;
  try {
    const payload = JSON.parse(
      Buffer.from(encoded, "base64url").toString("utf8"),
    );
    return (
      payload?.role === "admin" && Number(payload?.expiresAt) > Date.now()
    );
  } catch {
    return false;
  }
}

export function requireAdmin(
  req: Request,
  res: Response,
  next: NextFunction,
): void {
  if (!verifyAdminSession(readCookie(req, ADMIN_SESSION_COOKIE))) {
    res.status(401).json({ error: "يجب تسجيل الدخول كمسؤول" });
    return;
  }
  next();
}
