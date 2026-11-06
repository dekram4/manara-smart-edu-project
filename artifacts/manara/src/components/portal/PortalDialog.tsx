import React, { useEffect, useId } from 'react';
import { createPortal } from 'react-dom';
import { X } from 'lucide-react';

interface PortalDialogProps {
  title: string;
  subtitle?: React.ReactNode;
  /** رسمٌ أو صورةٌ رمزية في طرف الرأس. */
  media?: React.ReactNode;
  /** أزرارٌ في الرأس قبل زرّ الإغلاق (طباعة…). */
  actions?: React.ReactNode;
  onClose: () => void;
  children: React.ReactNode;
}

/**
 * صفحةُ تفاصيل مستقلّة فوق اللوحة: تُفتح من زرّ «التفاصيل» بدل أن تُلحق
 * التفاصيلُ أسفلَ الصفحة فيضيع وليُّ الأمر في التمرير.
 *
 * تُرسم في `body` لا داخل القشرة، فلا تطالها قواعدُ `.manara-enterprise button`
 * القديمة؛ وتُغلق بـ Escape أو بزرّ الإغلاق أو بالنقر خارجها.
 */
const PortalDialog: React.FC<PortalDialogProps> = ({ title, subtitle, media, actions, onClose, children }) => {
  const titleId = useId();

  useEffect(() => {
    const onKey = (event: KeyboardEvent) => {
      if (event.key === 'Escape') onClose();
    };
    window.addEventListener('keydown', onKey);
    const previousOverflow = document.body.style.overflow;
    document.body.style.overflow = 'hidden';
    return () => {
      window.removeEventListener('keydown', onKey);
      document.body.style.overflow = previousOverflow;
    };
  }, [onClose]);

  return createPortal(
    <div className="portal-dialog-backdrop" onMouseDown={(event) => { if (event.target === event.currentTarget) onClose(); }}>
      <section className="portal-dialog" role="dialog" aria-modal="true" aria-labelledby={titleId} dir="rtl">
        <header className="portal-dialog-head">
          {media && <div className="portal-dialog-media">{media}</div>}
          <div className="min-w-0 flex-1">
            <h2 id={titleId}>{title}</h2>
            {subtitle && <p>{subtitle}</p>}
          </div>
          <div className="portal-dialog-actions">
            {actions}
            <button type="button" className="portal-dialog-close" onClick={onClose} aria-label="إغلاق">
              <X aria-hidden="true" />
            </button>
          </div>
        </header>
        <div className="portal-dialog-body">{children}</div>
      </section>
    </div>,
    document.body,
  );
};

export default PortalDialog;
