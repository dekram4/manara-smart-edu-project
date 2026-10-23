import { useCallback, useEffect, useRef, useState } from 'react';

/** أوّلُ حقلٍ يُكتب فيه داخل النموذج. */
const FIRST_FIELD =
  'input:not([type="hidden"]):not([disabled]):not([readonly]), select:not([disabled]), textarea:not([disabled])';

/**
 * يُظهر نموذجَ التعديل حين يُفتح: يمرّر إليه ويضع المؤشّرَ في أوّل حقل.
 *
 * ── لماذا ──
 * في «إدارة الحسابات» يُفتح النموذجُ أعلى الصفحة، وزرُّ «تعديل» في صفٍّ قد
 * يكون العشرين من القائمة. فكان المشرفُ والمعلمُ يضغطان فلا يريان شيئاً
 * يتغيّر، ثم يصعدان بحثاً عن النموذج — أو يظنّان أن الزرّ لا يعمل.
 *
 * `reveal()` تُنادى مع فتح النموذج، والتمريرُ بعد أن يُرسم: النموذجُ قبلها
 * لم يدخل الصفحةَ بعد. ورقمٌ يزيد مع كل نداء، فيُعاد التمريرُ ولو ضُغط
 * «تعديل» على الحساب نفسه مرّتين.
 */
export function useRevealForm<T extends HTMLElement = HTMLDivElement>() {
  const formRef = useRef<T>(null);
  const [request, setRequest] = useState(0);

  useEffect(() => {
    if (!request) return;
    const form = formRef.current;
    if (!form) return;
    const reduceMotion =
      typeof window.matchMedia === 'function' &&
      window.matchMedia('(prefers-reduced-motion: reduce)').matches;
    form.scrollIntoView({ behavior: reduceMotion ? 'auto' : 'smooth', block: 'start' });
    // ‏بلا تمريرٍ ثانٍ من التركيز: التمريرُ الناعم أعلاه يكفي، والتركيزُ يقطعه.
    form.querySelector<HTMLElement>(FIRST_FIELD)?.focus({ preventScroll: true });
  }, [request]);

  const reveal = useCallback(() => setRequest((value) => value + 1), []);
  return { formRef, reveal };
}
