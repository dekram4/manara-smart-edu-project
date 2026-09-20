import React, { useEffect, useState } from 'react';
import { STORAGE_KEYS } from '../constants';
import { readKv, saveKvConfirmed } from '../db/confirmedSave';
import { reopenTeacherSession } from '../utils/serverSession';

/**
 * «حفظ وتثبيت الإعدادات الأكاديمية»، ومعه حالة الحفظ.
 *
 * الشجرة تُحفظ عند كل تعديل عبر المزامنة، لكن فشل الإرسال كان يدخل الطابور
 * بصمت: المعلم يرى شجرته أمامه ويظنّها في قاعدة البيانات وهي ليست فيها.
 * هذا الشريط يقول الحقيقة: يقارن ما في المتصفح بما في `app_kv`، ويرفع
 * الفرق من تلقائه عند فتح الصفحة، ويترك الزر لمن أراد التثبيت بيده.
 */

type State =
  | { kind: 'idle' }
  | { kind: 'checking' }
  | { kind: 'saving' }
  | { kind: 'saved'; verified: boolean; at: Date }
  | { kind: 'failed'; reason: string };

const readLocalTree = (): unknown[] => {
  try {
    const parsed = JSON.parse(localStorage.getItem(STORAGE_KEYS.HIERARCHICAL_CONFIGS) || '[]');
    return Array.isArray(parsed) ? parsed : [];
  } catch {
    return [];
  }
};

const AcademicSaveBar: React.FC<{ onSaved?: () => void; teacherUsername?: string }> = ({
  onSaved,
  teacherUsername,
}) => {
  const [state, setState] = useState<State>({ kind: 'idle' });

  const save = async (auto: boolean) => {
    const local = readLocalTree();
    setState({ kind: auto ? 'checking' : 'saving' });
    const outcome = await saveKvConfirmed(STORAGE_KEYS.HIERARCHICAL_CONFIGS, local);
    if (outcome.ok === false) {
      setState({ kind: 'failed', reason: outcome.reason });
      return;
    }
    setState({ kind: 'saved', verified: outcome.verified, at: new Date() });
    onSaved?.();
  };

  // عند فتح الصفحة: إن كانت قاعدة البيانات تحمل أقلّ مما يحمله المتصفح،
  // ارفع الفرق فوراً بلا انتظار ضغطة.
  useEffect(() => {
    let cancelled = false;
    (async () => {
      const local = readLocalTree();
      if (local.length === 0) return;
      setState({ kind: 'checking' });
      const remote = await readKv(STORAGE_KEYS.HIERARCHICAL_CONFIGS);
      if (cancelled) return;
      const remoteCount = Array.isArray(remote) ? remote.length : 0;
      if (remoteCount >= local.length && JSON.stringify(remote) === JSON.stringify(local)) {
        setState({ kind: 'saved', verified: true, at: new Date() });
        return;
      }
      await save(true);
    })();
    return () => {
      cancelled = true;
    };
    // مرة واحدة عند فتح الشاشة.
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  const status = (() => {
    switch (state.kind) {
      case 'checking':
        return { text: '⏳ جارٍ التحقّق من قاعدة البيانات…', color: '#92400e', background: '#fef3c7' };
      case 'saving':
        return { text: '⏳ جارٍ الحفظ…', color: '#92400e', background: '#fef3c7' };
      case 'saved':
        return state.verified
          ? { text: '✅ محفوظ في قاعدة البيانات', color: '#065f46', background: '#d1fae5' }
          : { text: '✅ أُرسل — وتعذّر التحقّق من القراءة', color: '#92400e', background: '#fef3c7' };
      case 'failed':
        return { text: `⚠️ لم يُحفظ: ${state.reason}`, color: '#991b1b', background: '#fee2e2' };
      default:
        return { text: 'لم يُتحقّق بعد', color: '#475569', background: '#f1f5f9' };
    }
  })();

  const busy = state.kind === 'saving' || state.kind === 'checking';

  /// الرفض بـ 401 يعني جلسة منتهية أو غير مفتوحة أصلاً — وهي حالة
  /// تُعالَج بإدخال كلمة المرور، لا بتسجيل خروج ودخول.
  const looksLikeSession =
    state.kind === 'failed' &&
    /401|تسجيل الدخول|صلاحي|جلس/.test(state.reason);

  const reopen = async () => {
    if (!teacherUsername) return;
    const result = await reopenTeacherSession(teacherUsername);
    if (result.ok === false) {
      setState({ kind: 'failed', reason: result.reason });
      return;
    }
    await save(false);
  };

  return (
    <div style={styles.bar}>
      <button onClick={() => void save(false)} disabled={busy} style={styles.button}>
        💾 حفظ وتثبيت الإعدادات الأكاديمية
      </button>
      <span style={{ ...styles.status, color: status.color, backgroundColor: status.background }}>
        {status.text}
      </span>
      {looksLikeSession && teacherUsername && (
        <button onClick={() => void reopen()} style={styles.sessionButton}>
          🔑 إعادة فتح جلسة الحفظ ثم إعادة المحاولة
        </button>
      )}
      {state.kind === 'saved' && (
        <span style={styles.time}>
          {state.at.toLocaleTimeString('ar-SA')}
        </span>
      )}
    </div>
  );
};

const styles: { [key: string]: React.CSSProperties } = {
  bar: {
    display: 'flex',
    flexWrap: 'wrap',
    alignItems: 'center',
    gap: '10px',
    padding: '12px 14px',
    marginBottom: '16px',
    backgroundColor: 'white',
    border: '1px solid #e5e7eb',
    borderRadius: '12px',
  },
  button: {
    padding: '10px 16px',
    backgroundColor: '#1d4ed8',
    color: 'white',
    border: 'none',
    borderRadius: '10px',
    cursor: 'pointer',
    fontWeight: 'bold',
    fontSize: '0.9rem',
  },
  status: {
    padding: '6px 12px',
    borderRadius: '999px',
    fontSize: '0.82rem',
    fontWeight: 'bold',
  },
  sessionButton: {
    padding: '9px 14px',
    backgroundColor: '#b45309',
    color: 'white',
    border: 'none',
    borderRadius: '10px',
    cursor: 'pointer',
    fontWeight: 'bold',
    fontSize: '0.82rem',
  },
  time: { color: '#94a3b8', fontSize: '0.75rem' },
};

export default AcademicSaveBar;
