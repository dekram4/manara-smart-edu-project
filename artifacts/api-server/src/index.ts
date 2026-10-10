import app from "./app";
import { logger } from "./lib/logger";

const rawPort = process.env["PORT"];

if (!rawPort) {
  throw new Error(
    "PORT environment variable is required but was not provided.",
  );
}

const port = Number(rawPort);

if (Number.isNaN(port) || port <= 0) {
  throw new Error(`Invalid PORT value: "${rawPort}"`);
}

const server = app.listen(port, (err) => {
  if (err) {
    logger.error({ err }, "Error listening on port");
    process.exit(1);
  }

  logger.info({ port }, "Server listening");
});

// رفعُ فيديو حتى 500MB على اتصالٍ بطيء يتجاوز الدقائق الخمس التي يقطع
// عندها Node أيَّ طلبٍ افتراضياً (`requestTimeout`) — فيُقطع الرفعُ في
// منتصفه ويرى المعلم خطأً لا سبب له. نصف ساعة تكفي ملفاً بهذا الحجم على
// ‏2.5 Mbit/s تقريباً، وتبقى حدّاً يُغلق الطلبات المعلّقة إلى الأبد.
server.requestTimeout = 30 * 60_000;
