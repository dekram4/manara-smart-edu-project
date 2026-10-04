import express, { type Express } from "express";
import cors from "cors";
import pinoHttp from "pino-http";
import path from "node:path";
import { fileURLToPath } from "node:url";
import router from "./routes";
import { uploadDirectory, videoDownloadRateLimit } from "./routes/media";
import { logger } from "./lib/logger";
import { isTrustedOrigin } from "./lib/trustedOrigin";

const __dirname = path.dirname(fileURLToPath(import.meta.url));

const app: Express = express();
app.disable("x-powered-by");

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
/**
 * ── من يُسمح له بالقراءة، والرفضُ كيف يُقال ──
 *
 * القرارُ في [isTrustedOrigin] وعليه اختبار: كان سطرين هنا لا يُختبران،
 * فبقي خمسةَ أشهر يردّ أصلَ النشر نفسه بلا أن يُلاحظ — القائمةُ كانت
 * تحمل `REPLIT_DEV_DOMAIN` وحده، وهو متغيّرٌ لا يُضبط في النشر.
 *
 * وأثرُه أنّ كلَّ طلبٍ من المتصفّح في الإنتاج كان يفشل: دخولُ المعلم،
 * والمشرف، وولي الأمر، وكلُّ مسارٍ سواها. ويُرى «كلمة المرور خاطئة» لأن
 * الواجهة تقرأ أيَّ ردٍّ غير ناجحٍ كذلك.
 *
 * والرفضُ الآن يمنع الترويسة ولا يرفع خطأ: `cb(null, false)` يجعل الحزمة
 * تُغفل ترويسات CORS، فيمنع المتصفّحُ القراءةَ بنفسه ويقول سببَه في
 * الـConsole. و`cb(new Error(...))` — وهو ما كان — يقلب الرفضَ إلى ٥٠٠:
 * يخفي السبب عن المتصفّح، ويجعل الخادمَ يبدو معطوباً وهو يطبّق سياسة.
 */
const apiCors = (req: express.Request) =>
  cors({
    origin: (origin, cb) => {
      if (!origin) return cb(null, true); // same-origin / server-to-server
      cb(
        null,
        isTrustedOrigin(origin, {
          host: req.get("host"),
          devDomain: process.env.REPLIT_DEV_DOMAIN,
          deployDomains: process.env.REPLIT_DOMAINS,
        }),
      );
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

  return apiCors(req)(req, res, next);
});
// مسارُ حلّ المسائل وحده يقبل جسداً كبيراً: الطفل يصوّر مسألته،
// والصورة تصل مرمّزةً بـ base64 فتبلغ ميغابايتات.
//
// وحدُّ `express.json` الافتراضي مئةُ كيلوبايت — فكان الطلب يُردّ بـ413
// ورسالةِ خطأٍ ليست JSON، فيفشل فكُّها في التطبيق ويرى الطفل «استجابة
// الخدمة غير صالحة» عن طلبٍ لم يبلغ الخادم أصلاً.
//
// ويُوضع قبل المحلّل العام: أوّلُ محلّلٍ يقرأ الجسد يملؤه، والثاني
// يتخطّاه. ولو رُفع الحدّ عامّاً لصار كلُّ مسارٍ في الخادم يقبل عشرة
// ميغابايتات ممّن لا جلسة له.
//
// والحدّ هنا أوسع قليلاً من حدّ الصورة في المسار (ستة ميغابايتات) لأن
// الجسد يحمل معها السؤال والمعرّف وترميز JSON.
app.use("/api/gemini/answer", express.json({ limit: "10mb" }));
// والرسالةُ الصوتية في الدردشة: ثلاثون ثانيةً ≈ ستون كيلوبايت، وبـ base64 أكثرُ
// بالثلث. والسقفُ الحقيقيّ في `parseChatVoice`، وهذا أوسعُ منه قليلاً.
app.use("/api/student/chat/voice", express.json({ limit: "320kb" }));
app.use(express.json());
app.use(express.urlencoded({ extended: true }));

// Serve locally-uploaded videos
// الملفّاتُ نفسُها التي يخدمها /api/media/videos — وبالحدّ نفسه.
app.use("/uploads/videos", videoDownloadRateLimit, express.static(uploadDirectory, { index: false }));

app.use("/api", router);

/**
 * مسارٌ غيرُ موجود تحت /api: ردٌّ JSON لا صفحةُ HTML.
 *
 * ── لماذا ──
 * كان Express يردّ «Cannot POST /api/...» صفحةً، فيفشل التطبيقُ في فكّها ويقول
 * للطفل «تعذّر الوصول» — وهي رسالةُ انقطاع الشبكة. وهكذا ظهر مسارُ الرسائل
 * الصوتية قبل نشره على الخادم: خللَ اتصالٍ لا مساراً غيرَ منشور.
 */
app.use("/api", (req: express.Request, res: express.Response) => {
  res.status(404).json({
    error: "هذه الخدمة غير متوفرة على الخادم بعد",
    code: "not_found",
    path: req.path,
  });
});

/**
 * آخرُ حارس: خطأٌ أفلت من مسارٍ يعود JSON ويُسجَّل.
 *
 * ── لماذا ──
 * بلا هذا يردّ Express على ما أفلت صفحةَ HTML فيها «Internal Server
 * Error» وحدها: لا سببٌ في الجسد، ولا سطرٌ في السجلّ باسم الخطأ. وواجهةُ
 * الويب تقرأ الردّ JSON فيفشل الفكّ، فتُظهر رسالتَها الاحتياطية — «اسم
 * المستخدم أو كلمة المرور غير صحيحة» — عن خطأٍ لا علاقة له بكلمة المرور.
 *
 * وهكذا أُخفي رفضُ CORS خمسةَ أشهر: الخادم يعمل من الطرفية، ويفشل من
 * المتصفّح، ورسالةُ الخطأ تشير إلى مكانٍ آخر.
 *
 * والأربعةُ مُعامِلاتٍ لازمة: Express يعرف معالجَ الأخطاء بعددها، فحذفُ
 * `next` يجعله وسيطاً عادياً لا يُنادى عند خطأ.
 */
app.use(
  (
    error: unknown,
    req: express.Request,
    res: express.Response,
    _next: express.NextFunction,
  ) => {
    logger.error(
      { err: error, url: req.url?.split("?")[0], method: req.method },
      "[api] unhandled route error",
    );
    if (res.headersSent) return;
    // أخطاءُ قارئ الجسد تحمل رمزَها: جسدٌ أكبر من الحدّ أو JSON معطوب. وكانت
    // تصير 500 عامّاً، فلا يُعرف أنّ المقطعَ الصوتيَّ كان أكبرَ من المسموح.
    const parser = error as { type?: unknown; status?: unknown };
    if (parser?.type === "entity.too.large") {
      res.status(413).json({ error: "حجم الطلب أكبر من المسموح", code: "too_large" });
      return;
    }
    if (parser?.type === "entity.parse.failed") {
      res.status(400).json({ error: "صيغة الطلب غير صالحة", code: "bad_json" });
      return;
    }
    res.status(500).json({ error: "تعذّر تنفيذ الطلب الآن. حاول مرة أخرى." });
  },
);

export default app;
