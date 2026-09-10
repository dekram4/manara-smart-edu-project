import React, { useEffect, useState } from 'react';
import { getSyncStatus, onSyncStatus, retryPendingSync, type SyncStatus } from '../db/sync';

/**
 * يعرض فشل المزامنة على الشاشة بدل دفنه في الكونسول.
 *
 * السبب: اللوحة تحفظ في localStorage أولاً ثم تعكس الكتابة إلى Supabase.
 * فإن فشلت الكتابة، يرى المعلم تعديله محفوظاً أمامه بينما لم يصل إلى
 * الخادم إطلاقاً — والطالب يبقى يرى المحتوى القديم دون أن يعلم أحد
 * بالسبب. هذا الشريط هو ما يجعل ذلك الفشل مرئياً فور وقوعه.
 *
 * ويفرّق بين حالتين لأن علاجهما مختلف تماماً:
 *  - مؤقت (queued): العملية محفوظة في الطابور، وزر إعادة المحاولة يكفي.
 *  - نهائي (dropped): رفضٌ من الخادم (صلاحية/RLS). إعادة المحاولة لن
 *    تنفع، والتعديل ضاع فعلاً ويجب إعادة إدخاله بعد معالجة الصلاحية.
 */
export function SyncStatusBanner(): React.ReactElement | null {
  const [status, setStatus] = useState<SyncStatus>(getSyncStatus);
  const [dismissed, setDismissed] = useState(false);

  useEffect(() => onSyncStatus(setStatus), []);

  // أي فشل جديد يعيد إظهار الشريط حتى لو أُغلق سابقاً.
  useEffect(() => {
    if (status.lastFailure) setDismissed(false);
  }, [status.lastFailure]);

  const failure = status.lastFailure;
  const hasPending = status.pending > 0;
  if (dismissed || (!failure && !hasPending)) return null;

  const dropped = failure?.kind === 'dropped';
  const palette = dropped
    ? { bg: '#7f1d1d', border: '#fca5a5', accent: '#fee2e2' }
    : { bg: '#78350f', border: '#fcd34d', accent: '#fef3c7' };

  return (
    <div
      dir="rtl"
      role="alert"
      aria-live="assertive"
      style={{
        position: 'fixed',
        insetInlineStart: 16,
        insetInlineEnd: 16,
        bottom: 16,
        zIndex: 9999,
        display: 'flex',
        flexWrap: 'wrap',
        alignItems: 'center',
        gap: 12,
        padding: '14px 18px',
        borderRadius: 18,
        background: palette.bg,
        border: `2px solid ${palette.border}`,
        boxShadow: '0 12px 34px rgba(0,0,0,.34)',
        color: '#fff',
        fontWeight: 800,
      }}
    >
      <span style={{ fontSize: 22, lineHeight: 1 }}>{dropped ? '⛔' : '⚠️'}</span>

      <div style={{ flex: '1 1 320px', minWidth: 240 }}>
        <div style={{ fontSize: 15.5 }}>
          {dropped
            ? 'لم يُحفظ التعديل على الخادم — رفض الخادم العملية'
            : 'تعذّر حفظ التعديل على الخادم'}
        </div>
        <div
          style={{
            fontSize: 12.5,
            fontWeight: 600,
            color: palette.accent,
            marginTop: 4,
            lineHeight: 1.6,
          }}
        >
          {dropped ? (
            <>
              التعديل ظاهر عندك فقط ولن يصل إلى الطلاب. تحقّق من صلاحيات
              حسابك ثم أعد إدخاله.
              {failure?.label ? ` (${failure.label})` : ''}
            </>
          ) : (
            <>
              التعديل محفوظ محلياً وسيُرسل عند نجاح المزامنة. الطلاب لن يروه
              قبل ذلك.
              {hasPending ? ` عمليات معلّقة: ${status.pending}.` : ''}
            </>
          )}
        </div>
        {failure?.message ? (
          <div
            style={{
              fontSize: 11.5,
              fontWeight: 500,
              color: palette.accent,
              opacity: 0.85,
              marginTop: 3,
              wordBreak: 'break-word',
            }}
          >
            {failure.message}
          </div>
        ) : null}
      </div>

      <div style={{ display: 'flex', gap: 8, flexShrink: 0 }}>
        <button
          type="button"
          onClick={() => void retryPendingSync()}
          disabled={status.retrying}
          style={{
            padding: '10px 18px',
            borderRadius: 999,
            border: 'none',
            background: status.retrying ? '#9ca3af' : '#fff',
            color: palette.bg,
            fontWeight: 900,
            fontSize: 13.5,
            cursor: status.retrying ? 'progress' : 'pointer',
          }}
        >
          {status.retrying ? 'جارٍ المزامنة…' : 'إعادة محاولة المزامنة'}
        </button>
        <button
          type="button"
          onClick={() => setDismissed(true)}
          aria-label="إخفاء التنبيه"
          style={{
            padding: '10px 14px',
            borderRadius: 999,
            border: `1px solid ${palette.border}`,
            background: 'transparent',
            color: '#fff',
            fontWeight: 900,
            fontSize: 13.5,
            cursor: 'pointer',
          }}
        >
          إخفاء
        </button>
      </div>
    </div>
  );
}

export default SyncStatusBanner;
