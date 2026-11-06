import React, { useEffect, useMemo, useRef, useState } from 'react';
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
 */
const DocumentPreview: React.FC<DocumentPreviewProps> = ({ title, document: doc, pageWidth, onClose }) => {
  const stageRef = useRef<HTMLDivElement | null>(null);
  const [scale, setScale] = useState(1);
  const [height, setHeight] = useState(800);
  const srcDoc = useMemo(() => sanitizeDocument(doc), [doc]);

  useEffect(() => {
    const stage = stageRef.current;
    if (!stage) return undefined;
    // ‏صفحةُ الشهادة تُرى كاملة بلا تمرير؛ والتقريرُ الطويل يُصغَّر بالعرض ويُمرَّر.
    const fit = () => {
      const byWidth = (stage.clientWidth - 16) / pageWidth;
      const byHeight = (stage.clientHeight - 16) / (pageWidth * 0.77);
      setScale(Math.min(1, pageWidth > 1000 ? Math.min(byWidth, byHeight) : byWidth));
    };
    fit();
    const observer = new ResizeObserver(fit);
    observer.observe(stage);
    return () => observer.disconnect();
  }, [pageWidth]);

  useEffect(() => {
    const onKey = (event: KeyboardEvent) => {
      if (event.key === 'Escape') onClose();
    };
    window.addEventListener('keydown', onKey);
    return () => window.removeEventListener('keydown', onKey);
  }, [onClose]);

  return (
    <div className="fixed inset-0 z-[10000] flex items-center justify-center bg-slate-900/60 p-3 sm:p-6" role="dialog" aria-modal="true" aria-label={title} dir="rtl">
      <div className="flex max-h-full w-full max-w-6xl flex-col overflow-hidden rounded-xl bg-white shadow-2xl">
        <div className="flex items-center gap-3 border-b border-slate-200 px-4 py-3">
          <h2 className="min-w-0 flex-1 truncate text-base font-extrabold text-slate-800">{title}</h2>
          <button type="button" className="portal-btn portal-btn-primary" onClick={() => printDocument(doc, { autoPrintDelayMs: 600 })}>
            <Printer aria-hidden="true" /> طباعة
          </button>
          <button type="button" className="portal-btn portal-btn-secondary" onClick={onClose} aria-label="إغلاق المعاينة">
            <X aria-hidden="true" />
          </button>
        </div>
        <div ref={stageRef} className="min-h-0 flex-1 overflow-auto bg-slate-100 p-2">
          <div style={{ width: pageWidth * scale, height: height * scale, margin: '0 auto' }}>
            <iframe
              title={title}
              srcDoc={srcDoc}
              sandbox="allow-same-origin"
              onLoad={(event) => {
                const body = event.currentTarget.contentDocument?.documentElement;
                if (body) setHeight(body.scrollHeight);
              }}
              style={{ width: pageWidth, height, border: 0, transform: `scale(${scale})`, transformOrigin: 'top right', background: '#fff' }}
            />
          </div>
        </div>
      </div>
    </div>
  );
};

export default DocumentPreview;
