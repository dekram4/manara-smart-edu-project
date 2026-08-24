import { Router } from "express";
import crypto from "node:crypto";
import {
  readCookie,
  TEACHER_SESSION_COOKIE,
  verifyAdminSession,
} from "../middleware/adminAuth";
import { logger } from "../lib/logger";
import {
  findStudentByUsername,
  passwordsMatch as studentPasswordsMatch,
  studentToken,
} from "../lib/studentAccess";

const router = Router();

const ADMIN_SESSION_COOKIE = "manara_admin_session";
const ADMIN_SESSION_TTL_SECONDS = 60 * 60 * 24 * 14;
const TEACHER_SESSION_TTL_SECONDS = 60 * 60 * 12;

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

function adminCookieOptions(maxAge = ADMIN_SESSION_TTL_SECONDS): string {
  const secure =
    process.env.NODE_ENV === "production" || process.env.REPLIT_DEPLOYMENT
      ? "; Secure"
      : "";
  return `Path=/; Max-Age=${maxAge}; HttpOnly; SameSite=Lax${secure}`;
}

function teacherCookieOptions(maxAge = TEACHER_SESSION_TTL_SECONDS): string {
  const secure =
    process.env.NODE_ENV === "production" || process.env.REPLIT_DEPLOYMENT
      ? "; Secure"
      : "";
  return `Path=/; Max-Age=${maxAge}; HttpOnly; SameSite=Lax${secure}`;
}

function signTeacherSession(teacherId: string): string {
  return signAdminSession({
    role: "teacher",
    teacherId,
    expiresAt: Date.now() + TEACHER_SESSION_TTL_SECONDS * 1000,
  });
}

function passwordsMatch(input: string, stored: unknown): boolean {
  if (typeof stored !== "string" || !stored) return false;
  const expected = /^[a-f0-9]{64}$/.test(stored)
    ? stored
    : crypto.createHash("sha256").update(stored).digest("hex");
  const received = crypto.createHash("sha256").update(input).digest("hex");
  return crypto.timingSafeEqual(
    Buffer.from(expected, "utf8"),
    Buffer.from(received, "utf8"),
  );
}

async function findTeacher(username: string): Promise<{
  id: string;
  username: string;
  password: unknown;
  mustChangePassword: boolean;
} | null> {
  const supabaseUrl = process.env.SUPABASE_URL;
  const serviceRoleKey = process.env.SUPABASE_SERVICE_ROLE_KEY;
  const anonKey = process.env.SUPABASE_ANON_KEY;
  if (!supabaseUrl || (!serviceRoleKey && !anonKey)) {
    throw new Error("Supabase credentials are required");
  }
  const url = new URL("/rest/v1/teachers", supabaseUrl);
  url.searchParams.set("select", "id,data");
  url.searchParams.set("data->>username", `eq.${username}`);
  const keys = [serviceRoleKey, anonKey].filter(
    (key): key is string => Boolean(key),
  );
  let response: Response | null = null;
  for (const key of keys) {
    response = await fetch(url, {
      headers: {
        apikey: key,
        Authorization: `Bearer ${key}`,
      },
    });
    if (response.ok || (response.status !== 401 && response.status !== 403)) {
      break;
    }
  }
  if (!response?.ok) {
    throw new Error(`Supabase teachers lookup failed (${response?.status || 0})`);
  }
  const rows = (await response.json()) as Array<{
    id?: unknown;
    data?: Record<string, unknown>;
  }>;
  const row = rows.find((item) => item?.data?.username === username);
  if (!row?.data) return null;
  const teacherId =
    typeof row.data.id === "string" && row.data.id.trim()
      ? row.data.id.trim()
      : typeof row.id === "string"
        ? row.id.trim()
        : "";
  return teacherId
    ? {
        id: teacherId,
        username,
        password: row.data.password,
        mustChangePassword: row.data.mustChangePassword === true,
      }
    : null;
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

// Native clients cannot use the web-only cookie flow. They receive a short-lived
// signed bearer token that only identifies the verified student account.
router.post("/auth/student/session", async (req, res) => {
  const username = typeof req.body?.username === "string" ? req.body.username.trim() : "";
  const password = typeof req.body?.password === "string" ? req.body.password : "";
  if (!username || !password) {
    return res.status(400).json({ error: "بيانات دخول الطالب مطلوبة" });
  }
  try {
    const student = await findStudentByUsername(username);
    if (!student || !studentPasswordsMatch(password, student.password)) {
      return res.status(401).json({ error: "بيانات دخول الطالب غير صحيحة" });
    }
    return res.json({
      token: studentToken(student.id),
      expiresAt: Date.now() + 60 * 60 * 12 * 1000,
    });
  } catch (error) {
    logger.error({ err: error }, "Student API session authentication failed");
    return res.status(503).json({ error: "تعذر إنشاء جلسة الطالب الآن. حاول مرة أخرى." });
  }
});

router.post("/auth/teacher/session", async (req, res) => {
  const username =
    typeof req.body?.username === "string" ? req.body.username.trim() : "";
  const password =
    typeof req.body?.password === "string" ? req.body.password : "";
  if (!username || !password) {
    return res.status(400).json({ error: "بيانات دخول المعلم مطلوبة" });
  }

  try {
    const teacher = await findTeacher(username);
    if (!teacher || !passwordsMatch(password, teacher.password)) {
      return res.status(401).json({ error: "بيانات دخول المعلم غير صحيحة" });
    }
    if (teacher.mustChangePassword) {
      return res.status(403).json({
        error: "يجب تغيير كلمة المرور قبل رفع ملفات الفيديو",
      });
    }
    res.setHeader(
      "Set-Cookie",
      `${TEACHER_SESSION_COOKIE}=${encodeURIComponent(
        signTeacherSession(teacher.id),
      )}; ${teacherCookieOptions()}`,
    );
    return res.json({ ok: true });
  } catch (error) {
    logger.error({ err: error }, "Teacher media session authentication failed");
    return res.status(503).json({
      error: "تعذر التحقق من جلسة المعلم الآن. حاول مرة أخرى.",
    });
  }
});

router.post("/auth/admin/logout", (_req, res) => {
  res.setHeader(
    "Set-Cookie",
    `${ADMIN_SESSION_COOKIE}=; ${adminCookieOptions(0)}`,
  );
  return res.json({ ok: true });
});

router.post("/auth/teacher/logout", (_req, res) => {
  res.setHeader(
    "Set-Cookie",
    `${TEACHER_SESSION_COOKIE}=; ${teacherCookieOptions(0)}`,
  );
  return res.json({ ok: true });
});

export default router;
