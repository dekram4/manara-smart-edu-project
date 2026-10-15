import { Router, type Request, type Response } from "express";
import rateLimit from "express-rate-limit";
import { requireAdmin } from "../middleware/adminAuth";
import { forwardedClientKey } from "../middleware/rateLimiter";
import { logger } from "../lib/logger";
import { readKv, storeConfig, writeKv } from "../lib/supabaseStore";
import {
  DEFAULT_STUDENT_APK_URL,
  STUDENT_APK_KEY,
  normalizeApkUrl,
  parseStudentApkSetting,
} from "../lib/appSettings";

/**
 * رابطُ تحميل تطبيق الطالب.
 *
 * القراءةُ عامّة: شاشةُ اختيار الأدوار يراها من لم يسجّل الدخول بعد، وهو
 * من يحتاج الرابط. والكتابةُ للمشرف وحده (جلسةٌ موقَّعة).
 */
const router = Router();

const writeLimit = rateLimit({
  windowMs: 60_000,
  limit: 20,
  standardHeaders: "draft-8",
  legacyHeaders: false,
  keyGenerator: (req: Request) => forwardedClientKey(req),
  message: { error: "تجاوزت الحد المسموح به من الطلبات. يرجى الانتظار دقيقة." },
});

router.get("/app-settings/student-apk", async (_req: Request, res: Response) => {
  // يُخزَّن قليلاً في المتصفّح: كلُّ زيارةٍ لشاشة الأدوار تسأل عنه.
  res.setHeader("Cache-Control", "public, max-age=60");
  const config = storeConfig();
  if (!config) {
    res.json({ url: DEFAULT_STUDENT_APK_URL, updatedAt: "", isDefault: true });
    return;
  }
  try {
    const saved = parseStudentApkSetting(await readKv(config, STUDENT_APK_KEY));
    res.json(
      saved
        ? { ...saved, isDefault: false }
        : { url: DEFAULT_STUDENT_APK_URL, updatedAt: "", isDefault: true },
    );
  } catch (error) {
    // تعذّرُ القراءة لا يُخفي الزرّ: يبقى الرابطُ المؤقّت.
    logger.warn({ err: error }, "[app-settings] student APK URL read failed — serving default");
    res.json({ url: DEFAULT_STUDENT_APK_URL, updatedAt: "", isDefault: true });
  }
});

router.put(
  "/app-settings/student-apk",
  writeLimit,
  requireAdmin,
  async (req: Request, res: Response) => {
    const url = normalizeApkUrl((req.body as Record<string, unknown> | undefined)?.url);
    if (!url) {
      res.status(400).json({ error: "الرابط غير صالح — يجب أن يبدأ بـ https://" });
      return;
    }
    const config = storeConfig();
    if (!config) {
      res.status(503).json({ error: "Supabase غير مُعدّ على الخادم" });
      return;
    }
    const value = { url, updatedAt: new Date().toISOString() };
    try {
      await writeKv(config, STUDENT_APK_KEY, value);
      logger.info({ url }, "[app-settings] student APK URL saved");
      res.json({ ...value, isDefault: false });
    } catch (error) {
      logger.error({ err: error }, "[app-settings] student APK URL save failed");
      res.status(502).json({
        error: "تعذّر حفظ الرابط",
        detail: error instanceof Error ? error.message.slice(0, 200) : undefined,
      });
    }
  },
);

export default router;
