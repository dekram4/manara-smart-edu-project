import crypto from "node:crypto";

/**
 * تخزينُ كلمات المرور والتحقّق منها — موضعٌ واحد للطالب والمعلم وولي الأمر.
 *
 * ── لماذا ──
 * كانت كلُّ كلمة مرورٍ تُخزَّن بصمةَ SHA-256 مجرّدة بلا ملح: سريعةً بما يكفي
 * لتجريب ملايين الكلمات في الثانية، وواحدةً لكل من اختار الكلمة نفسها. فبصمةٌ
 * تتسرّب تُكسر في دقائق إن كانت الكلمة قصيرة — وكلماتُ الأطفال قصيرة.
 *
 * ── الصيغة: scrypt فوق بصمة SHA-256 ──
 * `scrypt1$<ملحٌ base64url>$<ناتجٌ base64url>` ، والناتجُ
 * scrypt( sha256hex(كلمة المرور) ، ملحٌ عشوائيّ لكل حساب ).
 *
 * والبصمةُ القديمة تدخل scrypt كما هي، لثلاثة أسباب:
 *  ١. تُرقّى الحساباتُ كلُّها الآن بلا انتظار دخول أحد: البصمةُ المخزّنة هي
 *     مدخلُ scrypt نفسه، فتُلفّ في مكانها (`wrapLegacyHash`).
 *  ٢. لوحاتُ الويب ترسل كلمةَ المرور بصمةَ SHA-256 حين تُنشئ حساباً أو تغيّره،
 *     والخادمُ يلفّها بـ scrypt قبل الحفظ — فلا تُخزَّن بصمةٌ ضعيفة أبداً.
 *  ٣. التحقّقُ من بصمةٍ مُرسلة ممكن (`verifyPrehash`)، فيعرف جسرُ المزامنة إن
 *     كانت البصمة الواردة هي نفسُ المخزّنة فلا يكتب فوقها.
 */

const SCHEME = "scrypt1";
/** N=2^15، r=8، p=1: نحو ٣٢ ميغابايت و٥٠–١٠٠ مللي ثانية للتحقّق الواحد. */
const N = 1 << 15;
const R = 8;
const P = 1;
const KEY_LENGTH = 32;
const SALT_LENGTH = 16;
const MAX_MEMORY = 64 * 1024 * 1024;

const SHA256_HEX = /^[a-f0-9]{64}$/i;

export function sha256Hex(value: string): string {
  return crypto.createHash("sha256").update(value, "utf8").digest("hex");
}

function scrypt(prehash: string, salt: Buffer): Buffer {
  return crypto.scryptSync(prehash.toLowerCase(), salt, KEY_LENGTH, {
    N,
    r: R,
    p: P,
    maxmem: MAX_MEMORY,
  });
}

/** هل [stored] بالصيغة الآمنة؟ */
export function isStrongHash(stored: unknown): boolean {
  return typeof stored === "string" && stored.startsWith(`${SCHEME}$`);
}

/** هل [value] بصمةُ SHA-256 (من الصيغة القديمة أو مُرسلةٌ من لوحة الويب)؟ */
export function isSha256Hex(value: unknown): value is string {
  return typeof value === "string" && SHA256_HEX.test(value);
}

/** يلفّ بصمةَ SHA-256 بـ scrypt بملحٍ جديد. */
export function wrapPrehash(prehashHex: string): string {
  const salt = crypto.randomBytes(SALT_LENGTH);
  const derived = scrypt(prehashHex, salt);
  return `${SCHEME}$${salt.toString("base64url")}$${derived.toString("base64url")}`;
}

/** كلمةُ مرورٍ صريحة ← صيغةُ التخزين الآمنة. */
export function hashPassword(plain: string): string {
  return wrapPrehash(sha256Hex(plain));
}

/**
 * يرقّي قيمةً مخزّنة بالصيغة القديمة إلى الآمنة بلا معرفة كلمة المرور:
 * بصمةُ SHA-256 تُلفّ كما هي، والنصُّ الصريح (أقدمُ الصيغ) تُحسب بصمتُه ثم
 * يُلفّ. والآمنةُ تبقى كما هي.
 */
export function upgradeStoredValue(stored: unknown): string | null {
  if (typeof stored !== "string" || !stored) return null;
  if (isStrongHash(stored)) return stored;
  return wrapPrehash(isSha256Hex(stored) ? stored : sha256Hex(stored));
}

function verifyStrong(prehashHex: string, stored: string): boolean {
  const parts = stored.split("$");
  if (parts.length !== 3) return false;
  let salt: Buffer;
  let expected: Buffer;
  try {
    salt = Buffer.from(parts[1], "base64url");
    expected = Buffer.from(parts[2], "base64url");
  } catch {
    return false;
  }
  if (salt.length !== SALT_LENGTH || expected.length !== KEY_LENGTH) return false;
  return crypto.timingSafeEqual(scrypt(prehashHex, salt), expected);
}

function equalStrings(a: string, b: string): boolean {
  const left = Buffer.from(a, "utf8");
  const right = Buffer.from(b, "utf8");
  return left.length === right.length && crypto.timingSafeEqual(left, right);
}

/**
 * يتحقّق من بصمة SHA-256 مُرسلة مقابل المخزَّن، بأيّ صيغةٍ كان.
 */
export function verifyPrehash(prehashHex: string, stored: unknown): boolean {
  if (typeof stored !== "string" || !stored || !isSha256Hex(prehashHex)) return false;
  const prehash = prehashHex.toLowerCase();
  if (isStrongHash(stored)) return verifyStrong(prehash, stored);
  if (isSha256Hex(stored)) return equalStrings(prehash, stored.toLowerCase());
  return equalStrings(prehash, sha256Hex(stored));
}

export interface PasswordCheck {
  ok: boolean;
  /**
   * القيمةُ الآمنة التي تُكتب مكان المخزَّن، إن كان بصيغةٍ قديمة ونجح
   * التحقّق — «ترقيةٌ عند أوّل دخولٍ ناجح». وإلا `null`.
   */
  upgrade: string | null;
}

/** يتحقّق من كلمة مرورٍ صريحة مقابل المخزَّن، ويقول إن كان يحتاج ترقية. */
export function verifyPassword(input: string, stored: unknown): PasswordCheck {
  if (typeof input !== "string" || !input || typeof stored !== "string" || !stored) {
    return { ok: false, upgrade: null };
  }
  const ok = verifyPrehash(sha256Hex(input), stored);
  return { ok, upgrade: ok && !isStrongHash(stored) ? hashPassword(input) : null };
}

/**
 * ما يُخزَّن حين ترسل لوحةُ الويب سجلاً فيه كلمةُ مرور ([incoming]) والمخزَّنُ
 * الآن [stored]. لا يُخزَّن أبداً إلا الصيغةُ الآمنة:
 *  • بلا كلمة مرور في الوارد ← يبقى المخزَّن (اللوحاتُ لا تستلم البصمات أصلاً).
 *  • بصمةٌ واردة تطابق المخزَّن ← يبقى المخزَّن (نسخةٌ قديمة في المتصفّح لا تُنزّله).
 *  • بصمةٌ أو كلمةٌ جديدة ← تُلفّ بـ scrypt (حسابٌ جديد، أو كلمةُ مرورٍ غُيّرت).
 */
export function passwordToStore(incoming: unknown, stored: unknown): string | null {
  const current = typeof stored === "string" && stored ? stored : null;
  if (typeof incoming !== "string" || !incoming) {
    return current ? upgradeStoredValue(current) : null;
  }
  if (isStrongHash(incoming)) return current ?? incoming;
  const prehash = isSha256Hex(incoming) ? incoming.toLowerCase() : sha256Hex(incoming);
  if (current && verifyPrehash(prehash, current)) return upgradeStoredValue(current);
  return wrapPrehash(prehash);
}

/** حقولٌ لا تغادر الخادم أبداً في سجلّ حساب. */
export const SECRET_ACCOUNT_FIELDS = ["password"] as const;

/** سجلُّ حسابٍ بلا كلمة مرور. */
export function withoutSecrets<T extends Record<string, unknown>>(data: T): Omit<T, "password"> {
  const { password: _password, ...safe } = data;
  return safe;
}
