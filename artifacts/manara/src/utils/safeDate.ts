/**
 * تاريخٌ مقروءٌ، أو شَرطةٌ مكان ما لا يُقرأ.
 *
 * ── لماذا لا يُنادى `toLocaleDateString` مباشرةً ──
 * السجلّاتُ المعروضةُ في اللوحات كتبها الخادمُ أو نسخةٌ أقدمُ من التطبيق، وفيها
 * ما لا تاريخَ له: حقلٌ غائبٌ، أو نصٌّ ليس تاريخاً. و`new Date(undefined)`
 * لا يرمي — يُخرج تاريخاً غيرَ صالح — فيُطبع لوليّ الأمر «Invalid Date» في
 * بطاقةِ نتيجةِ ابنه.
 *
 * فيُفحص الصلاحُ، وتُقرأ الشَرطةُ على أنها «غيرُ مسجَّل» — وهو ما تعنيه.
 */
export function formatSafeDate(
  value: unknown,
  options: Intl.DateTimeFormatOptions = { month: 'short', day: 'numeric' },
  locale = 'ar-SA',
): string {
  if (value === null || value === undefined || value === '') return '—';
  const date = value instanceof Date ? value : new Date(value as string | number);
  if (Number.isNaN(date.getTime())) return '—';
  try {
    return date.toLocaleDateString(locale, options);
  } catch {
    // لغةٌ أو خياراتٌ لا يعرفها المتصفّح: يُعرض التاريخُ بصيغته القياسية.
    return date.toISOString().slice(0, 10);
  }
}
