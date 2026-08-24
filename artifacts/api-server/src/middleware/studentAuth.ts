import type { NextFunction, Request, Response } from "express";
import { findStudentById, verifyStudentToken } from "../lib/studentAccess";

function bearerToken(req: Request): string {
  const value = String(req.get("authorization") || "");
  return value.startsWith("Bearer ") ? value.slice(7).trim() : "";
}

export async function requireStudentSession(
  req: Request,
  res: Response,
  next: NextFunction,
): Promise<void> {
  const studentId = verifyStudentToken(bearerToken(req));
  if (!studentId) {
    res.status(401).json({ error: "يجب تسجيل الدخول كطالب لاستخدام هذه الخدمة" });
    return;
  }
  try {
    const student = await findStudentById(studentId);
    if (!student) {
      res.status(401).json({ error: "جلسة الطالب لم تعد صالحة" });
      return;
    }
    res.locals.student = student;
    next();
  } catch {
    res.status(503).json({ error: "تعذر التحقق من حساب الطالب الآن" });
  }
}