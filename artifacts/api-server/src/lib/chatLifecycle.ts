/**
 * دورةُ حياة رسائل «بطاقة الدردشة» — النصّية والصوتية.
 *
 * ── رسالةٌ خاصّة (جوري → روز) ──
 *   • تبقى عند جوري حتى تراها روز. وحين تراها يظهر لجوري أنها قُرئت.
 *   • بعد أن تراها روز: تختفي عند جوري حين تخرج من الدردشة وتعود.
 *   • وتختفي عند روز حين تخرج هي وتعود.
 *
 * ── رسالةٌ للصفّ ──
 *   • يظهر للمرسِل من شاهدها/سمعها بأسمائهم.
 *   • تبقى عند المرسِل حتى يشاهدها كلُّ طلاب الصفّ، ثم تختفي عنده بخروجه وعودته.
 *   • وعند كلِّ طالبٍ تختفي بعد أن يشاهدها ويخرج ويعود.
 *
 * ── «تختفي بالخروج والعودة» ──
 * الزيارةُ تبدأ بفتح الدردشة. وما استُهلك قبل بدء الزيارة الحالية لا يُعرض؛ وما
 * استُهلك أثناءها يبقى ظاهراً حتى نهايتها — فلا تختفي رسالةٌ من أمام الطالب وهو يقرؤها.
 *
 * ── 📌 الحفظ ──
 * حفظٌ قائمٌ يُبقي الرسالةَ لصاحبه وحده، وأقصاه ٢٤ ساعة من لحظته.
 *
 * ── الحذفُ النهائي ──
 * حين يستهلكها كلُّ أطرافها ولا يحفظها أحد. وتنظيفاً للعالق: رسالةٌ رآها كلُّ من
 * أُرسلت إليه ومضى عليها ٢٤ ساعة، أو رسالةٌ أقدمُ من هذه الإيصالات بلا أثرٍ لها ومضى
 * عليها ٢٤ ساعة، أو أيُّ رسالةٍ مضى عليها ٧ أيام — ما لم تكن محفوظة.
 */

const HOUR = 60 * 60 * 1000;

/** أقصى مدّةٍ للحفظ، من لحظته. */
export const CHAT_SAVE_MS = 24 * HOUR;

/** رسالةٌ رآها من أُرسلت إليهم تُكنس بعد هذا. */
export const CHAT_SEEN_TTL_MS = 24 * HOUR;

/** ولا تبقى رسالةٌ أطولَ من هذا مهما كان — إلا محفوظة. */
export const CHAT_MAX_AGE_MS = 7 * 24 * HOUR;

/** إيصالُ طالبٍ لرسالة. */
export interface ChatReceipt {
  messageId: string;
  studentId: string;
  /** أوّلُ مرّةٍ عُرضت له. */
  firstSeenAt: string | null;
  /** آخرُ مرّةٍ عُرضت له. */
  lastSeenAt: string | null;
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

const ageOf = (message: ChatMessageMeta, now: Date) => {
  const created = at(message.createdAt);
  return created === null ? 0 : now.getTime() - created;
};

/** حفظٌ قائمٌ الآن. */
export function isSaved(receipt: ChatReceipt | undefined, now: Date = new Date()): boolean {
  const until = at(receipt?.savedUntil);
  return until !== null && until > now.getTime();
}

/** من أُرسلت إليهم الرسالة — بلا المرسِل: الصفُّ كلُّه، أو المستلمُ وحده. */
export function recipientsOf(message: ChatMessageMeta, classIds: readonly string[]): string[] {
  const ids = message.to === "all" ? classIds : [message.to];
  return [...new Set(ids.filter((id) => id && id !== message.from))];
}

function receiptFor(
  receipts: readonly ChatReceipt[],
  messageId: string,
  studentId: string,
): ChatReceipt | undefined {
  return receipts.find((r) => r.messageId === messageId && r.studentId === studentId);
}

/** من رآها من المستلمين. */
export function seenBy(
  message: ChatMessageMeta,
  recipients: readonly string[],
  receipts: readonly ChatReceipt[],
): string[] {
  return recipients.filter((id) => receiptFor(receipts, message.id, id)?.firstSeenAt);
}

/** متى رآها آخرُ المستلمين — أو \`null\` إن بقي من لم يرها. */
export function allSeenAt(
  message: ChatMessageMeta,
  recipients: readonly string[],
  receipts: readonly ChatReceipt[],
): number | null {
  if (recipients.length === 0) return null;
  let latest = 0;
  for (const id of recipients) {
    const first = at(receiptFor(receipts, message.id, id)?.firstSeenAt);
    if (first === null) return null;
    latest = Math.max(latest, first);
  }
  return latest;
}

/**
 * متى استهلك [studentId] الرسالة — أو \`null\` إن لم يستهلكها بعد.
 *
 * المستلم: أوّلُ ما رآها. والمرسِل: حين رآها بعد أن رآها كلُّ من أُرسلت إليه —
 * أي بعد أن ظهر له أنها قُرئت.
 */
export function consumedAt(
  message: ChatMessageMeta,
  studentId: string,
  recipients: readonly string[],
  receipts: readonly ChatReceipt[],
): number | null {
  const mine = receiptFor(receipts, message.id, studentId);
  if (studentId !== message.from) return at(mine?.firstSeenAt);
  const everyone = allSeenAt(message, recipients, receipts);
  const last = at(mine?.lastSeenAt);
  return everyone !== null && last !== null && last >= everyone ? last : null;
}

/**
 * هل تُعرض الرسالةُ لهذا الطالب في زيارةٍ بدأت عند [visitStart]؟
 */
export function visibleTo(
  message: ChatMessageMeta,
  studentId: string,
  recipients: readonly string[],
  receipts: readonly ChatReceipt[],
  visitStart: Date,
  now: Date = new Date(),
): boolean {
  if (isSaved(receiptFor(receipts, message.id, studentId), now)) return true;
  if (ageOf(message, now) > CHAT_MAX_AGE_MS) return false;
  const consumed = consumedAt(message, studentId, recipients, receipts);
  return consumed === null || consumed >= visitStart.getTime();
}

/** هل تُحذف الرسالةُ نهائياً الآن؟ */
export function shouldPurge(
  message: ChatMessageMeta,
  recipients: readonly string[],
  receipts: readonly ChatReceipt[],
  now: Date = new Date(),
): boolean {
  const own = receipts.filter((r) => r.messageId === message.id);
  if (own.some((r) => isSaved(r, now))) return false;
  const age = ageOf(message, now);
  if (age > CHAT_MAX_AGE_MS) return true;
  // أقدمُ من الإيصالات: لا أثرَ لقراءتها، وعالقةٌ عند أصحابها.
  if (own.length === 0) return age > CHAT_SEEN_TTL_MS;
  const everyone = allSeenAt(message, recipients, receipts);
  if (everyone === null) return false;
  if (age > CHAT_SEEN_TTL_MS) return true;
  return [message.from, ...recipients].every(
    (id) => consumedAt(message, id, recipients, receipts) !== null,
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
