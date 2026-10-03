/**
 * عمرُ رسائل دردشة الصفّ: تختفي بعد قراءتها، وتُحفظ ٢٤ ساعةً أقصى.
 *
 * ── القواعد ──
 *   • الطالبُ لا يرى رسالةً قرأها (أو سمعها) وغادر الدردشة — إلا إن حفظها.
 *   • الحفظُ لهذا الطالب وحده، وينتهي بعد ٢٤ ساعةً من لحظته، أو حين يلغيه.
 *   • الرسالةُ تُحذف نهائياً — ومعها مقطعُها — حين يقرؤها كلُّ من أُرسلت إليه ولا
 *     يحفظها أحد، أو حين يمضي عليها ٢٤ ساعةً ولا حفظَ قائماً لها.
 *
 * ── لماذا وحدةٌ نقيّة ──
 * الحذفُ لا رجعةَ فيه. فقرارُه يُقرأ في مكانٍ واحد ويُختبر بلا شبكة: رسالةٌ تُحذف
 * قبل أن يقرأها زميلٌ لم يفتح الدردشة بعد خطأٌ لا يُصلَح.
 */

/** عمرُ الرسالة غير المحفوظة. */
export const CHAT_TTL_MS = 24 * 60 * 60 * 1000;

/** أقصى مدّةٍ للحفظ، من لحظته. */
export const CHAT_SAVE_MS = 24 * 60 * 60 * 1000;

/** إيصالُ طالبٍ لرسالة: متى قرأها، وحتى متى حفظها. */
export interface ChatReceipt {
  messageId: string;
  studentId: string;
  seenAt: string | null;
  savedUntil: string | null;
}

export interface ChatMessageMeta {
  id: string;
  from: string;
  to: string;
  createdAt: string;
}

const at = (value: string | null | undefined): number | null => {
  if (!value) return null;
  const time = Date.parse(value);
  return Number.isNaN(time) ? null : time;
};

/** حفظٌ قائمٌ الآن. */
export function isSaved(receipt: ChatReceipt | undefined, now: Date = new Date()): boolean {
  const until = at(receipt?.savedUntil);
  return until !== null && until > now.getTime();
}

/** مضى على الرسالة عمرُها. */
export function isExpired(message: ChatMessageMeta, now: Date = new Date()): boolean {
  const created = at(message.createdAt);
  return created !== null && now.getTime() - created > CHAT_TTL_MS;
}

/**
 * هل يرى الطالبُ هذه الرسالة؟
 *
 * لم يقرأها بعد، أو حفظها حفظاً قائماً. ورسالةٌ مضى عمرُها لا تُرى إلا محفوظة.
 */
export function visibleTo(
  message: ChatMessageMeta,
  mine: ChatReceipt | undefined,
  now: Date = new Date(),
): boolean {
  if (isSaved(mine, now)) return true;
  if (isExpired(message, now)) return false;
  return !mine?.seenAt;
}

/** من أُرسلت إليه الرسالة: الصفُّ كلُّه مع المرسِل، أو المرسِلُ والمستلم. */
export function recipientsOf(message: ChatMessageMeta, classIds: readonly string[]): string[] {
  const ids = message.to === "all" ? [...classIds, message.from] : [message.from, message.to];
  return [...new Set(ids.filter(Boolean))];
}

/**
 * هل تُحذف الرسالةُ نهائياً الآن؟
 *
 * لا حفظَ قائماً لها عند أحد، ثم: قرأها كلُّ من أُرسلت إليه، أو مضى عمرُها.
 * ومن لم يقرأها بعد يُبقيها — حتى نهاية عمرها.
 */
export function shouldPurge(
  message: ChatMessageMeta,
  recipients: readonly string[],
  receipts: readonly ChatReceipt[],
  now: Date = new Date(),
): boolean {
  const mine = receipts.filter((receipt) => receipt.messageId === message.id);
  if (mine.some((receipt) => isSaved(receipt, now))) return false;
  if (isExpired(message, now)) return true;
  if (recipients.length === 0) return false;
  return recipients.every((id) =>
    mine.some((receipt) => receipt.studentId === id && receipt.seenAt !== null),
  );
}

/** نهايةُ حفظٍ يبدأ الآن. */
export function saveUntil(now: Date = new Date()): string {
  return new Date(now.getTime() + CHAT_SAVE_MS).toISOString();
}

/** معرّفُ رسالة دردشة: بشكلٍ يُعرف، لا يُمرَّر غيرُه إلى استعلام. */
export function isChatMessageId(value: unknown): value is string {
  return typeof value === "string" && /^chat_[A-Za-z0-9_-]{8,80}$/.test(value);
}
