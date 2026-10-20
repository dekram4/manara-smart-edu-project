/**
 * حالُ فيديو يوتيوب — للوحة المعلم: أيُّ روابطه لم تعد تعمل.
 *
 * ── لماذا ──
 * فيديو «تعليم الألوان والأشكال وتمييزها» الثامن حذفه صاحبه من يوتيوب، فظهر
 * رمادياً عند الطالب ولم يعرف المعلم. واللوحةُ في المتصفّح لا تسأل يوتيوب
 * مباشرةً (CORS)، فيسأله الخادم بـ oEmbed — بلا مفتاح — ويحفظ الجواب ساعات.
 *
 * بلا شبكة هنا: الصياغةُ والتصنيف وحدهما، فيُختبران.
 */

export type YoutubeStatus = "available" | "unavailable" | "embed_blocked" | "unknown";

/** معرّفُ فيديو يوتيوب: ١١ حرفاً من الحروف والأرقام و`-_`. */
export const YOUTUBE_ID = /^[A-Za-z0-9_-]{11}$/;

/** ردُّ oEmbed: 200 متاح، 401/403 منعُ التضمين، 404 محذوفٌ أو خاص، وما سواها مجهول. */
export function youtubeStatusFor(code: number): YoutubeStatus {
  if (code === 200) return "available";
  if (code === 401 || code === 403) return "embed_blocked";
  if (code === 404) return "unavailable";
  return "unknown";
}

/** معرّفُ يوتيوب من رابطه (watch و youtu.be و embed و shorts)، أو `null`. */
export function youtubeIdFromUrl(value: unknown): string | null {
  if (typeof value !== "string") return null;
  try {
    const url = new URL(value.trim());
    const host = url.hostname.replace(/^www\.|^m\./, "");
    let id = "";
    if (host === "youtu.be") id = url.pathname.split("/")[1] ?? "";
    else if (host.endsWith("youtube.com") || host.endsWith("youtube-nocookie.com")) {
      const parts = url.pathname.split("/").filter(Boolean);
      id = url.searchParams.get("v") ?? (["embed", "shorts", "live", "v"].includes(parts[0]) ? parts[1] ?? "" : "");
    }
    return YOUTUBE_ID.test(id) ? id : null;
  } catch {
    return null;
  }
}
