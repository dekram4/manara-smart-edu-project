import React, { useEffect, useState } from 'react';
import { STORAGE_KEYS } from '../constants';
import { ownedTreeArrived, readKv, saveKvConfirmed } from '../db/confirmedSave';
import { getRecordTeacherId } from '../utils/scope';
import { reopenTeacherSession } from '../utils/serverSession';
import { useSyncHydrating } from '../hooks/useSyncHydrating';
import { rehydrateFromServer } from '../db/sync';

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

/**
 * ثِقَل الشجرة: عدد مدخلاتها وعدد دروسها معاً.
 *
 * الرفع التلقائي كان يقيس بعدد المدخلات وحده، ويكتفي بالاختلاف سبباً
 * للرفع. فشجرةٌ محليةٌ فيها مادةٌ واحدة تُرفع فوق شجرةٍ في قاعدة
 * البيانات فيها مادّتان: العددان متساويان والمحتوى مختلف، فيُكتب
 * الأفقر فوق الأغنى ويضيع منهجٌ كامل. والدروس هي ما يُقاس حقاً.
 */
const weigh = (tree: unknown[]): { configs: number; lessons: number } => {
  let lessons = 0;
  for (const config of tree as any[]) {
    for (const subject of config?.subjects ?? []) {
      for (const term of subject?.terms ?? []) {
        for (const names of Object.values(term?.lessons ?? {})) {
          lessons += Array.isArray(names) ? names.length : 0;
        }
      }
    }
  }
  return { configs: tree.length, lessons };
};

const AcademicSaveBar: React.FC<{
  onSaved?: () => void;
  teacherUsername?: string;
  /// صاحب الشجرة، ليُقاس ما وصل بما يملكه هو. بلا معرّف يعود التحقّق
  /// إلى التطابق الحرفي، وهو الصواب للوحة المشرف: هي تكتب الشجرة كلّها.
  teacherId?: string;
}> = ({ onSaved, teacherUsername, teacherId }) => {
  const [state, setState] = useState<State>({ kind: 'idle' });
  const hydrating = useSyncHydrating();

  const save = async (auto: boolean) => {
    const local = readLocalTree();
    setState({ kind: auto ? 'checking' : 'saving' });
    const outcome = await saveKvConfirmed(
      STORAGE_KEYS.HIERARCHICAL_CONFIGS,
      local,
      teacherId ? ownedTreeArrived(teacherId, getRecordTeacherId) : undefined,
    );
    if (outcome.ok === false) {
      setState({ kind: 'failed', reason: outcome.reason });
      return;
    }
    setState({ kind: 'saved', verified: outcome.verified, at: new Date() });
    onSaved?.();
  };

  /** يسحب نسخة قاعدة البيانات إلى هذا الجهاز ثم يعيد قراءة الشاشة. */
  const pull = async () => {
    setState({ kind: 'checking' });
    try {
      await rehydrateFromServer();
      const arrived = readLocalTree();
      setState({ kind: 'saved', verified: arrived.length > 0, at: new Date() });
      onSaved?.();
    } catch (error) {
      setState({
        kind: 'failed',
        reason: error instanceof Error ? error.message : 'تعذّر الجلب من الخادم',
      });
    }
  };

  // عند فتح الصفحة: إن كانت قاعدة البيانات تحمل أقلّ مما يحمله المتصفح،
  // ارفع الفرق فوراً بلا انتظار ضغطة. وإن كانت تحمل أكثر، فلا تمسّها.
  useEffect(() => {
    // التحميل الأول لم ينتهِ: نسخة المتصفح ليست بعدُ نسخةَ الخادم،
    // ورفعُها الآن رفعُ ما قبلَه لا ما بعده.
    if (hydrating) return;
    let cancelled = false;
    (async () => {
      const local = readLocalTree();
      if (local.length === 0) return;
      setState({ kind: 'checking' });
      const remote = await readKv(STORAGE_KEYS.HIERARCHICAL_CONFIGS);
      if (cancelled) return;
      const remoteTree = Array.isArray(remote) ? remote : [];
      if (JSON.stringify(remoteTree) === JSON.stringify(local)) {
        setState({ kind: 'saved', verified: true, at: new Date() });
        return;
      }

      // الأفقر لا يُكتب فوق الأغنى من تلقائه.
      //
      // الفرق بين النسختين لا يقول أيّهما الأحدث. وحين تكون نسخة قاعدة
      // البيانات أغنى — مادةٌ حُقنت من سكربت، أو صفٌّ أضافه المشرف من
      // جهازٍ آخر — فالأرجح أن هذا الجهاز هو المتخلّف. فيُترك الأمر
      // لصاحب الشاشة: الزرّ أمامه إن أراد أن يُثبّت ما يرى.
      const here = weigh(local);
      const there = weigh(remoteTree);
      if (there.lessons > here.lessons || there.configs > here.configs) {
        setState({
          kind: 'failed',
          reason:
            `قاعدة البيانات أغنى مما في هذا الجهاز (${there.lessons} درساً مقابل ${here.lessons}). ` +
            'لم يُرفع شيء حتى لا يُمحى. حدّث الصفحة لتأخذ نسختها.',
        });
        return;
      }
      await save(true);
    })();
    return () => {
      cancelled = true;
    };
    // مرة واحدة بعد انتهاء التحميل الأول.
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [hydrating]);

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
      {/* الاتجاه المعاكس: من قاعدة البيانات إلى الشاشة. وكان الشريط
          يعرف الرفع وحده، فمن كانت نسخته متخلّفة لا حيلة له إلا أن
          يمسح بيانات الموقع بيده. */}
      <button onClick={() => void pull()} disabled={busy} style={styles.sessionButton}>
        🔄 جلب نسخة قاعدة البيانات
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
