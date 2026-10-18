import React, { useEffect, useRef } from 'react';

/**
 * غلافٌ لجدولٍ عريض: يُتنقَّل بين أعمدته بأسهم لوحة المفاتيح وعجلة الفأرة
 * مباشرةً، بلا نزولٍ إلى آخر الصفحة بحثاً عن شريط التمرير الأفقيّ.
 *
 * ── كيف ──
 * • ارتفاعٌ على قدر الشاشة ورأسٌ ثابت (`.dashboard-table-scroll` في index.css):
 *   شريطا التمرير ظاهران داخل الشاشة دائماً.
 * • الأسهم ←/→ تقفز عموداً تقريباً، وHome/End إلى أوّل الجدول وآخره — متى
 *   كان التركيزُ على الجدول (يُركَّز بالنقر عليه أو بـTab).
 * • العجلة: عموديّةٌ تمرّر الصفوف ما بقيت صفوفٌ تُمرَّر، فإن لم يبقَ (أو لم
 *   يكن في الجدول تمريرٌ عموديّ أصلاً) نقلت بين الأعمدة. وShift+العجلة ولوحةُ
 *   اللمس الأفقية تعمل كما في المتصفّح.
 * • الاتجاه: في العربية «التالي» يساراً، فالعجلةُ للأسفل والسهمُ الأيسر يمضيان
 *   إلى الأعمدة التالية.
 */
interface HorizontalScrollRegionProps {
  /** وصفٌ لقارئ الشاشة. */
  label: string;
  /** سطرُ إرشادٍ قصير فوق الجدول. */
  hint?: string;
  className?: string;
  children: React.ReactNode;
}

const COLUMN_STEP = 220;

const HorizontalScrollRegion: React.FC<HorizontalScrollRegionProps> = ({ label, hint, className = '', children }) => {
  const ref = useRef<HTMLDivElement>(null);

  useEffect(() => {
    const el = ref.current;
    if (!el) return undefined;

    const onWheel = (event: WheelEvent) => {
      if (event.ctrlKey || event.shiftKey) return; // تكبيرٌ، أو تمريرٌ أفقيّ أصيل
      if (Math.abs(event.deltaX) >= Math.abs(event.deltaY)) return; // لوحةُ لمسٍ أفقية
      const canScrollX = el.scrollWidth > el.clientWidth + 1;
      if (!canScrollX) return;
      const down = event.deltaY > 0;
      const verticalRoom = down
        ? el.scrollTop + el.clientHeight < el.scrollHeight - 1
        : el.scrollTop > 0;
      if (verticalRoom) return; // ما زالت صفوفٌ تُمرَّر
      const rtl = getComputedStyle(el).direction === 'rtl';
      const before = el.scrollLeft;
      el.scrollBy({ left: (rtl ? -1 : 1) * event.deltaY, behavior: 'auto' });
      // ‏لم يتحرّك (بلغ طرف الأعمدة): تُترك العجلةُ للصفحة.
      if (el.scrollLeft !== before) event.preventDefault();
    };

    el.addEventListener('wheel', onWheel, { passive: false });
    return () => el.removeEventListener('wheel', onWheel);
  }, []);

  const onKeyDown = (event: React.KeyboardEvent<HTMLDivElement>) => {
    const el = ref.current;
    if (!el || event.target !== el) return; // حقلٌ أو زرٌّ داخل الجدول يحتفظ بأسهمه
    const rtl = getComputedStyle(el).direction === 'rtl';
    const max = el.scrollWidth - el.clientWidth;
    switch (event.key) {
      case 'ArrowLeft':
        el.scrollBy({ left: -COLUMN_STEP });
        break;
      case 'ArrowRight':
        el.scrollBy({ left: COLUMN_STEP });
        break;
      case 'Home':
        el.scrollTo({ left: 0 });
        break;
      case 'End':
        el.scrollTo({ left: rtl ? -max : max });
        break;
      default:
        return;
    }
    event.preventDefault();
  };

  return (
    <>
      {hint && <p className="dashboard-table-scroll-hint">{hint}</p>}
      <div
        ref={ref}
        className={`dashboard-table-scroll ${className}`.trim()}
        role="region"
        aria-label={label}
        tabIndex={0}
        onKeyDown={onKeyDown}
      >
        {children}
      </div>
    </>
  );
};

export default HorizontalScrollRegion;
