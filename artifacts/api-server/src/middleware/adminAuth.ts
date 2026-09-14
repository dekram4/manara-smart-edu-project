import type { Request, Response, NextFunction } from "express";
import crypto from "node:crypto";

const ADMIN_SESSION_COOKIE = "manara_admin_session";
export const TEACHER_SESSION_COOKIE = "manara_teacher_session";
export const PARENT_SESSION_COOKIE = "manara_parent_session";

export type ContentActor =
  | { role: "admin" }
  | { role: "teacher"; teacherId: string }
  // ولي الأمر قارئ فقط. لا يملك أي مسار كتابة إطلاقاً، ونطاق قراءته محصور
  // بأبنائه — يُحسم ذلك في `supabaseBridge` لا هنا.
  | { role: "parent"; parentId: string };

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

export function readCookie(req: Request, name: string): string {
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

export function verifyTeacherSession(value: string): ContentActor | null {
  if (!value) return null;
  const [encoded, signature] = String(value).split(".");
  if (!encoded || !signature) return null;
  const expected = crypto
    .createHmac("sha256", sessionSecret())
    .update(encoded)
    .digest("base64url");
  if (
    signature.length !== expected.length ||
    !crypto.timingSafeEqual(Buffer.from(signature), Buffer.from(expected))
  ) {
    return null;
  }
  try {
    const payload = JSON.parse(
      Buffer.from(encoded, "base64url").toString("utf8"),
    );
    const teacherId =
      typeof payload?.teacherId === "string" ? payload.teacherId.trim() : "";
    if (
      payload?.role !== "teacher" ||
      !teacherId ||
      teacherId.length > 200 ||
      Number(payload?.expiresAt) <= Date.now()
    ) {
      return null;
    }
    return { role: "teacher", teacherId };
  } catch {
    return null;
  }
}

export function verifyParentSession(value: string): ContentActor | null {
  if (!value) return null;
  const [encoded, signature] = String(value).split(".");
  if (!encoded || !signature) return null;
  const expected = crypto
    .createHmac("sha256", sessionSecret())
    .update(encoded)
    .digest("base64url");
  if (
    signature.length !== expected.length ||
    !crypto.timingSafeEqual(Buffer.from(signature), Buffer.from(expected))
  ) {
    return null;
  }
  try {
    const payload = JSON.parse(
      Buffer.from(encoded, "base64url").toString("utf8"),
    );
    const parentId =
      typeof payload?.parentId === "string" ? payload.parentId.trim() : "";
    if (
      payload?.role !== "parent" ||
      !parentId ||
      parentId.length > 200 ||
      Number(payload?.expiresAt) <= Date.now()
    ) {
      return null;
    }
    return { role: "parent", parentId };
  } catch {
    return null;
  }
}

/**
 * الفاعل الذي يملك حق الكتابة: المشرف أو المعلم فقط.
 *
 * ولي الأمر عمداً غير مشمول هنا. مسارات الكتابة تستدعي هذه الدالة، فبقاؤه
 * خارجها يجعل منعه من الكتابة خاصية في بنية الكود لا شرطاً قد يُنسى في
 * مسار جديد يُضاف لاحقاً.
 */
export function getContentActor(req: Request): ContentActor | null {
  if (verifyAdminSession(readCookie(req, ADMIN_SESSION_COOKIE))) {
    return { role: "admin" };
  }
  return verifyTeacherSession(readCookie(req, TEACHER_SESSION_COOKIE));
}

/**
 * الفاعل الذي يملك حق القراءة: المشرف والمعلم، ويُضاف إليهم ولي الأمر.
 *
 * مسارات القراءة وحدها تستدعي هذه. الفصل بين الدالتين هو ما يضمن ألا تُفتح
 * لولي الأمر كتابةٌ بالخطأ.
 */
export function getReaderActor(req: Request): ContentActor | null {
  return (
    getContentActor(req) ??
    verifyParentSession(readCookie(req, PARENT_SESSION_COOKIE))
  );
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

export function requireContentManager(
  req: Request,
  res: Response,
  next: NextFunction,
): void {
  const actor = getContentActor(req);
  if (!actor) {
    res.status(401).json({ error: "يجب تسجيل الدخول كمعلم أو مشرف" });
    return;
  }
  res.locals.contentActor = actor;
  next();
}
