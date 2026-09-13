import React, { useEffect, useRef } from 'react';

/**
 * ما يُسأل عنه المستخدم قبل تنفيذ إجراء لا رجعة فيه.
 *
 * وُضع هذا بديلاً عن window.confirm، وهو ليس مجرد تحسين شكلي: النافذة
 * الأصلية تُحجب داخل إطار iframe من أصل مختلف، أو إطار مقيَّد بلا
 * allow-modals، فتُرجع false بلا أي إشارة — فيبدو زر الحذف وكأنه معطّل.
 * وهذه اللوحة تُفتح داخل إطار في الاستضافة الحالية.
 */
export type ConfirmRequest = {
  title: string;
  message: string;
  /** نص زر التأكيد. الافتراضي «حذف». */
  confirmLabel?: string;
  /** يميّز الإجراءات المدمّرة بالأحمر. الافتراضي true. */
  danger?: boolean;
  onConfirm: () => void;
};

type Props = {
  request: ConfirmRequest | null;
  onClose: () => void;
};

/**
 * نافذة تأكيد داخل الصفحة.
 *
 * زر الإلغاء هو الذي يأخذ التركيز عند الفتح، لا زر التأكيد: الإجراء
 * مدمّر، ومَن يضغط Enter بالعادة يجب أن يلغي لا أن يحذف. ولنفس السبب
 * لا يوجد اختصار Enter للتأكيد.
 */
const ConfirmDialog: React.FC<Props> = ({ request, onClose }) => {
  const cancelRef = useRef<HTMLButtonElement>(null);

  useEffect(() => {
    if (!request) return;
    cancelRef.current?.focus();

    const onKeyDown = (event: KeyboardEvent) => {
      if (event.key === 'Escape') onClose();
    };
    window.addEventListener('keydown', onKeyDown);

    // الصفحة خلف النافذة لا تُمرَّر، وإلا انزلق ما تسأل عنه خارج الرؤية.
    const previousOverflow = document.body.style.overflow;
    document.body.style.overflow = 'hidden';
    return () => {
      window.removeEventListener('keydown', onKeyDown);
      document.body.style.overflow = previousOverflow;
    };
  }, [request, onClose]);

  if (!request) return null;

  const danger = request.danger !== false;
  const accent = danger ? '#dc2626' : '#4f46e5';

  return (
    <div
      role="presentation"
      onClick={onClose}
      style={{
        position: 'fixed',
        inset: 0,
        zIndex: 9999,
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'center',
        padding: '20px',
        backgroundColor: 'rgba(15, 23, 42, 0.55)',
        backdropFilter: 'blur(3px)',
      }}
    >
      <div
        role="alertdialog"
        aria-modal="true"
        aria-labelledby="confirm-dialog-title"
        aria-describedby="confirm-dialog-message"
        dir="rtl"
        // وإلا أغلقت الضغطة داخل النافذة النافذةَ نفسها عبر الخلفية.
        onClick={event => event.stopPropagation()}
        style={{
          width: '100%',
          maxWidth: '440px',
          backgroundColor: '#ffffff',
          borderRadius: '18px',
          padding: '24px',
          boxShadow: '0 24px 60px rgba(15, 23, 42, 0.35)',
          fontFamily: 'inherit',
          textAlign: 'right',
        }}
      >
        <div style={{ display: 'flex', alignItems: 'flex-start', gap: '12px' }}>
          <div
            aria-hidden
            style={{
              flexShrink: 0,
              width: '42px',
              height: '42px',
              borderRadius: '50%',
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center',
              fontSize: '1.3rem',
              backgroundColor: danger ? '#fee2e2' : '#e0e7ff',
            }}
          >
            {danger ? '🗑️' : '❓'}
          </div>
          <div style={{ flex: 1, minWidth: 0 }}>
            <h3
              id="confirm-dialog-title"
              style={{
                margin: 0,
                fontSize: '1.15rem',
                fontWeight: 900,
                color: '#111827',
              }}
            >
              {request.title}
            </h3>
            <p
              id="confirm-dialog-message"
              style={{
                margin: '8px 0 0',
                fontSize: '0.92rem',
                lineHeight: 1.7,
                color: '#4b5563',
                fontWeight: 600,
              }}
            >
              {request.message}
            </p>
          </div>
        </div>

        <div
          style={{
            display: 'flex',
            gap: '10px',
            justifyContent: 'flex-start',
            marginTop: '22px',
          }}
        >
          <button
            onClick={() => {
              request.onConfirm();
              onClose();
            }}
            style={{
              padding: '10px 20px',
              fontSize: '0.9rem',
              fontWeight: 800,
              color: '#ffffff',
              backgroundColor: accent,
              border: 'none',
              borderRadius: '10px',
              cursor: 'pointer',
              fontFamily: 'inherit',
            }}
          >
            {request.confirmLabel ?? 'حذف'}
          </button>
          <button
            ref={cancelRef}
            onClick={onClose}
            style={{
              padding: '10px 20px',
              fontSize: '0.9rem',
              fontWeight: 800,
              color: '#374151',
              backgroundColor: '#f3f4f6',
              border: '1px solid #d1d5db',
              borderRadius: '10px',
              cursor: 'pointer',
              fontFamily: 'inherit',
            }}
          >
            إلغاء
          </button>
        </div>
      </div>
    </div>
  );
};

export default ConfirmDialog;
