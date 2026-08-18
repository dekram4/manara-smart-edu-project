import { sha256 } from 'js-sha256';

// ============================================================
// أدوات تشفير كلمات المرور (تجزئة أحادية الاتجاه عبر SHA-256)
// لا يمكن فك التجزئة: نقارن بصمة الإدخال ببصمة المخزّن فقط.
// متزامنة بالكامل حتى لا تتغيّر بنية تسجيل الدخول الحالية.
// ============================================================

// تجزئة كلمة المرور إلى بصمة سداسية عشرية بطول 64 خانة
export function hashPassword(plain: string): string {
  return sha256(String(plain ?? ''));
}

// هل القيمة مجزّأة أصلاً؟ (64 خانة سداسية عشرية)
export function isHashed(value?: string | null): boolean {
  return !!value && /^[a-f0-9]{64}$/.test(value);
}

// يضمن أن القيمة مجزّأة: يجزّئها إن كانت نصاً صريحاً، ويتركها إن كانت مجزّأة
export function ensureHashed(value?: string | null): string {
  if (!value) return '';
  return isHashed(value) ? value : hashPassword(value);
}

// مقارنة آمنة: يدعم المخزّن المجزّأ، ويتسامح مع النص الصريح القديم (قبل الترقية)
export function passwordsMatch(input: string, stored?: string | null): boolean {
  if (!stored) return false;
  if (isHashed(stored)) return hashPassword(input) === stored;
  // قيمة قديمة غير مجزّأة (للتوافق أثناء الانتقال)
  return input === stored;
}
