import React, { useCallback, useEffect, useMemo, useRef, useState } from 'react';
import { createPortal } from 'react-dom';
import { Printer, X } from 'lucide-react';
import { SafeHtml, printDocument, sanitizeDocument } from '../../utils/printHtml';

interface DocumentPreviewProps {
  title: string;
  document: SafeHtml;
  /** عرضُ الصفحة بالبكسل عند ٩٦ نقطة في البوصة: A4 أفقية ١١٢٣، وعمودية ٧٩٤. */
  pageWidth: number;
  onClose: () => void;
}

/**
 * معاينةُ مستندٍ رسمي قبل طباعته: المستندُ نفسه الذي يُطبع، في إطارٍ معزول
 * يُصغَّر ليسع النافذة. فلا تختلف المعاينةُ عن الورقة في شيء.
 *
 * ── ما كان يتعطّل ──
 * كانت النافذةُ عمودَ flex بلا ارتفاعٍ محدّد، ومساحةُ المستند `flex-1` فيه:
 * لا شيءَ يمنحها ارتفاعاً، فتنكمش إلى صفر. والتصغيرُ يُحسب من ارتفاعها فيصير
 * قريباً من الصفر — فتُفتح على الهاتف نافذةٌ بعنوانها وزرّ الطباعة وشريطٍ
 * فارغ مكان الشهادة. وكانت تُرسم داخل الصفحة، فأيُّ عنصرٍ فوقها فيه تحويلٌ
 * (transform) أو تمريرٌ يقصّها.
 *
 * والآن: للنافذة ارتفاعٌ صريح، وتُرسم في `document.body` مباشرة، والتصغيرُ
 * يُحسب من الارتفاع الحقيقي للمستند بعد تحميل خطوطه وصوره.
 */
const DocumentPreview: React.FC<DocumentPreviewProps> = ({ title, document: doc, pageWidth, onClose }) => {
  const stageRef = useRef<HTMLDivElement | null>(null);
  const frameRef = useRef<HTMLIFrameElement | null>(null);
  const [stage, setStage] = useState({ width: 0, height: 0 });
  const [docHeight, setDocHeight] = useState(Math.round(pageWidth * 0.75));
  const srcDoc = useMemo(() => sanitizeDocument(doc), [doc]);

  useEffect(() => {
    const element = stageRef.current;
    if (!element) return undefined;
    const measure = () => setStage({ width: element.clientWidth, height: element.clientHeight });
    measure();
    const observer = new ResizeObserver(measure);
    observer.observe(element);
    return () => observer.disconnect();
  }, []);

  useEffect(() => {
    const onKey = (event: KeyboardEvent) => {
      if (event.key === 'Escape') onClose();
    };
    window.addEventListener('keydown', onKey);
    const previousOverflow = window.document.body.style.overflow;
    window.document.body.style.overflow = 'hidden';
    return () => {
      window.removeEventListener('keydown', onKey);
      window.document.body.style.overflow = previousOverflow;
    };
  }, [onClose]);

  const measureDocument = useCallback(() => {
    const root = frameRef.current?.contentDocument?.documentElement;
    if (root && root.scrollHeight > 0) setDocHeight(root.scrollHeight);
  }, []);

  const onFrameLoad = () => {
    measureDocument();
    // ‏الخطوطُ تصل بعد الحدث فيتغيّر الطول: يُقاس مرّةً ثانية بعدها.
    const fonts = frameRef.current?.contentDocument?.fonts;
    fonts?.ready.then(measureDocument).catch(() => undefined);
    window.setTimeout(measureDocument, 600);
  };

  const gutter = 16;
  const byWidth = stage.width > 0 ? (stage.width - gutter) / pageWidth : 1;
  // ‏الصفحةُ الأفقية (الشهادة) تُرى كاملةً بلا تمرير؛ والتقريرُ الطويل يُصغَّر بالعرض ويُمرَّر.
  const landscape = pageWidth > 1000;
  const byHeight = landscape && stage.height > 120 ? (stage.height - gutter) / Math.min(docHeight, pageWidth * 0.8) : Infinity;
  const scale = Math.max(0.1, Math.min(1, byWidth, byHeight));

  return createPortal(
    <div
      className="fixed inset-0 z-[10000] flex items-center justify-center bg-slate-900/60 p-2 sm:p-6"
      role="dialog"
      aria-modal="true"
      aria-label={title}
      dir="rtl"
      onClick={onClose}
    >
      <div
        className="flex w-full max-w-6xl flex-col overflow-hidden rounded-xl bg-white font-tajawal shadow-2xl"
        style={{ height: 'min(92dvh, 100%)' }}
        onClick={(event) => event.stopPropagation()}
      >
        <div className="flex shrink-0 items-center gap-2 border-b border-slate-200 px-3 py-2.5 sm:px-4 sm:py-3">
          <h2 className="min-w-0 flex-1 truncate text-sm font-extrabold text-slate-800 sm:text-base">{title}</h2>
          <button
            type="button"
            className="inline-flex min-h-10 items-center gap-1.5 rounded-lg bg-[#1f4e8c] px-4 text-sm font-bold text-white hover:bg-[#173d6e]"
            onClick={() => printDocument(doc, { autoPrintDelayMs: 600 })}
          >
            <Printer size={17} aria-hidden="true" /> طباعة
          </button>
          <button
            type="button"
            className="inline-flex h-10 w-10 items-center justify-center rounded-lg border border-slate-300 text-slate-600 hover:bg-slate-50"
            onClick={onClose}
            aria-label="إغلاق المعاينة"
          >
            <X size={18} aria-hidden="true" />
          </button>
        </div>
        <div ref={stageRef} className="min-h-0 flex-1 overflow-auto bg-slate-100 p-2">
          <div style={{ width: pageWidth * scale, height: docHeight * scale, margin: '0 auto', overflow: 'hidden' }}>
            <iframe
              ref={frameRef}
              title={title}
              srcDoc={srcDoc}
              sandbox="allow-same-origin"
              onLoad={onFrameLoad}
              style={{
                width: pageWidth,
                // ‏index.css يقصر كل iframe على عرض حاويته (`max-width: 100%`)، فتُقصّ الصفحة.
                maxWidth: 'none',
                height: docHeight,
                border: 0,
                transform: `scale(${scale})`,
                transformOrigin: 'top right',
                background: '#fff',
                display: 'block',
              }}
              scrolling="no"
            />
          </div>
        </div>
      </div>
    </div>,
    window.document.body,
  );
};

export default DocumentPreview;
