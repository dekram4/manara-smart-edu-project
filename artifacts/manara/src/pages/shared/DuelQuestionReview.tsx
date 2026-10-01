import React, { useCallback, useEffect, useRef, useState } from 'react';

/**
 * مراجعةُ أسئلة «تحدَّ زملاءك»: يستعرضها المعلمُ والمشرف، ويعطّلان منها ويفعّلان.
 *
 * ── لماذا شاشةٌ واحدةٌ للدورين ──
 * القائمةُ نفسها والمرشّحاتُ نفسها، والفرقُ في ما يُرى وما يُعطَّل — وكلاهما
 * يحسمه الخادم ويعيده في `canToggle`. فلو كُتبت مرّتين لافترقتا عند أوّل تعديل.
 *
 * ── والأسئلةُ تعمل فورَ توليدها ──
 * لا تنتظر موافقة: المصفّي في الخادم هو المراجعة، وهذه الشاشةُ لإخراج ما فاته.
 * والسؤالُ المعطّل لا يُختار في أيّ مباراةٍ جديدة، ولا يُحذف — فيُعاد بضغطة.
 */

type Role = 'admin' | 'teacher';

interface DuelQuestion {
  id: string;
  subjectKey: string;
  unit: string;
  gradeBand: string;
  category: string;
  prompt: string;
  choices: string[];
  source: string;
  active: boolean;
  disabledBy: string | null;
  disabledAt: string | null;
  lessonId: string | null;
  lessonTitle: string | null;
  teacherId: string | null;
  createdAt: string;
  canToggle: boolean;
}

interface Filters {
  subject: string;
  source: string;
  status: string;
  q: string;
  mine: boolean;
}

const SUBJECTS: Record<string, string> = {
  '*': 'عامّة (كل المواد)',
  math: 'الرياضيات',
  science: 'العلوم',
  arabic: 'اللغة العربية',
  english: 'اللغة الإنجليزية',
  islamic: 'الدراسات الإسلامية',
  social: 'الاجتماعيات',
};

const CATEGORIES: Record<string, string> = {
  domain: 'من مجال الدرس',
  general: 'معلومات عامة',
  logic: 'ذكاء ومنطق',
  quick: 'سرعة بديهة',
  school: 'ثقافة مدرسية',
};

const SOURCES: Record<string, string> = {
  seed: 'البنك المكتوب',
  ai: 'مولَّد بالذكاء الاصطناعي',
  teacher: 'كتبه معلم',
};

const PAGE = 50;

/**
 * ألوانُ كلّ لوحة بأسمائها الكاملة: Tailwind يبحث عن الصنف مكتوباً في الملف،
 * فصنفٌ يُركَّب من متغيّرٍ لا يُولَّد، ويُعرض بلا لون.
 */
const THEMES = {
  admin: {
    title: 'text-purple-800',
    text: 'text-purple-700',
    strong: 'text-purple-800',
    panel: 'border-purple-200 bg-purple-50',
    field: 'border-purple-200 text-purple-900',
    button: 'bg-purple-600 hover:bg-purple-700',
    chip: 'bg-purple-100 text-purple-800',
    card: 'border-purple-100',
    soft: 'border-purple-200 text-purple-800 hover:bg-purple-50',
    dashed: 'border-purple-200 text-purple-700',
  },
  teacher: {
    title: 'text-amber-800',
    text: 'text-amber-700',
    strong: 'text-amber-800',
    panel: 'border-amber-200 bg-amber-50',
    field: 'border-amber-200 text-amber-900',
    button: 'bg-amber-600 hover:bg-amber-700',
    chip: 'bg-amber-100 text-amber-800',
    card: 'border-amber-100',
    soft: 'border-amber-200 text-amber-800 hover:bg-amber-50',
    dashed: 'border-amber-200 text-amber-700',
  },
} as const;

function disabledByLabel(value: string | null): string {
  if (!value) return '';
  if (value === 'admin') return 'المشرف';
  if (value.startsWith('teacher:')) return `المعلم (${value.slice('teacher:'.length)})`;
  return value;
}

function formatDate(value: string | null): string {
  if (!value) return '';
  const date = new Date(value);
  return Number.isNaN(date.getTime()) ? '' : date.toLocaleDateString('ar');
}

interface GenerateJob {
  running: boolean;
  startedAt: string | null;
  finishedAt: string | null;
  summary: {
    total: number;
    processed: number;
    generated: number;
    skipped: number;
    failed: number;
    questions: number;
  } | null;
  error: string | null;
}

/**
 * زرُّ المشرف: توليدُ الأسئلة لكل الدروس.
 *
 * التوليدُ يعمل عادةً عند حفظ الدرس، فالدروسُ المكتوبةُ قبل وجوده بلا أسئلة. وهذا
 * يمرّ عليها كلّها مرّة. وإعادةُ الضغط آمنة: ما وُلّد له يُتخطّى بلا نداءٍ
 * للنموذج، فتكمل التشغيلةُ من حيث توقّفت.
 *
 * والتشغيلةُ تجري في الخادم وتُقرأ حالُها كل ثانيتين: دقائقُ لا يُبقى المتصفّحُ
 * معلّقاً عليها، ومغادرةُ الشاشة لا توقفها.
 */
const GenerateAllPanel: React.FC<{ onFinished: () => void }> = ({ onFinished }) => {
  const [job, setJob] = useState<GenerateJob | null>(null);
  const [ready, setReady] = useState(true);
  const [starting, setStarting] = useState(false);
  const [message, setMessage] = useState('');
  const wasRunning = useRef(false);

  const read = useCallback(async () => {
    try {
      const response = await fetch('/api/duel-questions/generate-all', { credentials: 'same-origin' });
      const body = await response.json().catch(() => ({}));
      if (!response.ok) return;
      setJob(body.job ?? null);
      setReady(body.ready !== false);
    } catch {
      // قراءةٌ تعثّرت: تُعاد في النبضة التالية.
    }
  }, []);

  useEffect(() => {
    void read();
  }, [read]);

  // النبضُ ما دامت التشغيلةُ جارية، والقائمةُ تُعاد عند انتهائها.
  useEffect(() => {
    const running = job?.running === true;
    if (wasRunning.current && !running) onFinished();
    wasRunning.current = running;
    if (!running) return;
    const timer = window.setInterval(() => void read(), 2000);
    return () => window.clearInterval(timer);
  }, [job?.running, read, onFinished]);

  const start = async () => {
    setStarting(true);
    setMessage('');
    try {
      const response = await fetch('/api/duel-questions/generate-all', {
        method: 'POST',
        credentials: 'same-origin',
      });
      const body = await response.json().catch(() => ({}));
      if (body.job) setJob(body.job);
      if (!response.ok && response.status !== 409) {
        setMessage(body?.error || 'تعذّر بدء التوليد');
      }
    } catch {
      setMessage('تعذّر الاتصال بالخادم');
    } finally {
      setStarting(false);
    }
  };

  const summary = job?.summary;
  const running = job?.running === true;
  const percent = summary && summary.total > 0
    ? Math.round((summary.processed / summary.total) * 100)
    : 0;

  return (
    <div className="rounded-2xl border border-purple-200 bg-white p-4 sm:p-5">
      <div className="flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between">
        <div>
          <h3 className="text-lg font-black text-purple-800">✨ توليد الأسئلة لكل الدروس</h3>
          <p className="mt-1 text-sm font-bold text-purple-700">
            يولّد أسئلة من مجال كل درس لم تُولَّد له بعد. الدروس التي لها أسئلة تُتخطّى، فإعادة التشغيل آمنة.
          </p>
        </div>
        <button
          type="button"
          onClick={() => void start()}
          disabled={running || starting || !ready}
          className="shrink-0 rounded-xl bg-purple-600 px-5 py-3 font-black text-white hover:bg-purple-700 disabled:opacity-50"
        >
          {running ? '⏳ جارٍ التوليد…' : starting ? '…' : '✨ ابدأ التوليد'}
        </button>
      </div>

      {!ready && (
        <p role="alert" className="mt-3 rounded-xl bg-amber-50 p-3 text-sm font-bold text-amber-800">
          التوليد غير مهيّأ على الخادم: يلزم مفتاح Gemini واتصال Supabase.
        </p>
      )}
      {message && (
        <p role="alert" className="mt-3 rounded-xl bg-red-50 p-3 text-sm font-bold text-red-700">{message}</p>
      )}

      {summary && (running || job?.finishedAt) && (
        <div className="mt-4" role="status" aria-live="polite">
          <div className="mb-2 flex justify-between text-sm font-bold text-purple-800">
            <span>
              {running ? 'الدروس المفحوصة' : 'انتهى التوليد'}: {summary.processed} من {summary.total}
            </span>
            <span>{percent}%</span>
          </div>
          <div
            className="h-3 overflow-hidden rounded-full bg-purple-100"
            role="progressbar"
            aria-valuemin={0}
            aria-valuemax={summary.total}
            aria-valuenow={summary.processed}
          >
            <div className="h-full rounded-full bg-purple-600 transition-all" style={{ width: `${percent}%` }} />
          </div>
          <div className="mt-3 flex flex-wrap gap-2 text-xs font-bold">
            <span className="rounded-full bg-green-100 px-3 py-1 text-green-800">وُلّد لـ {summary.generated} درساً</span>
            <span className="rounded-full bg-purple-100 px-3 py-1 text-purple-800">{summary.questions} سؤالاً جديداً</span>
            <span className="rounded-full bg-gray-100 px-3 py-1 text-gray-700">تُخطّي {summary.skipped} (لها أسئلة)</span>
            {summary.failed > 0 && (
              <span className="rounded-full bg-red-100 px-3 py-1 text-red-700">تعذّر {summary.failed} — أعد التشغيل لاحقاً</span>
            )}
          </div>
          {!running && summary.total === 0 && (
            <p className="mt-2 text-sm font-bold text-gray-600">
              لا دروس تصلح للتوليد: يلزم أن يكون للدرس نص ومادة معروفة.
            </p>
          )}
        </div>
      )}
      {job?.error && !running && (
        <p role="alert" className="mt-3 rounded-xl bg-red-50 p-3 text-sm font-bold text-red-700">
          توقّف التوليد: {job.error}
        </p>
      )}
    </div>
  );
};

const DuelQuestionReview: React.FC<{ role: Role }> = ({ role }) => {
  const theme = THEMES[role];
  const [filters, setFilters] = useState<Filters>({ subject: '', source: '', status: '', q: '', mine: false });
  const [search, setSearch] = useState('');
  const [questions, setQuestions] = useState<DuelQuestion[]>([]);
  const [hasMore, setHasMore] = useState(false);
  /** موضعُ الصفحة التالية في القاعدة، كما يقوله الخادم — لا عددُ المعروض. */
  const [nextOffset, setNextOffset] = useState(0);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  const [busy, setBusy] = useState<string | null>(null);
  const [notice, setNotice] = useState('');

  const load = useCallback(async (offset: number) => {
    setLoading(true);
    setError('');
    const params = new URLSearchParams({ limit: String(PAGE), offset: String(offset) });
    if (filters.subject) params.set('subject', filters.subject);
    if (filters.source) params.set('source', filters.source);
    if (filters.status) params.set('status', filters.status);
    if (filters.q) params.set('q', filters.q);
    if (role === 'teacher' && filters.mine) params.set('mine', '1');
    try {
      const response = await fetch(`/api/duel-questions?${params}`, { credentials: 'same-origin' });
      const body = await response.json().catch(() => ({}));
      if (!response.ok) throw new Error(body?.error || 'تعذّر تحميل الأسئلة');
      const page: DuelQuestion[] = Array.isArray(body.questions) ? body.questions : [];
      setQuestions((current) => (offset === 0 ? page : [...current, ...page]));
      setHasMore(body.hasMore === true);
      setNextOffset(typeof body.nextOffset === 'number' ? body.nextOffset : offset + page.length);
    } catch (failure) {
      setError(failure instanceof Error ? failure.message : 'تعذّر تحميل الأسئلة');
    } finally {
      setLoading(false);
    }
  }, [filters, role]);

  useEffect(() => {
    void load(0);
  }, [load]);

  /** بعد التوليد الشامل: الأسئلةُ الجديدة تظهر بلا إعادة فتح الشاشة. */
  const reloadList = useCallback(() => {
    void load(0);
  }, [load]);

  const toggle = async (question: DuelQuestion) => {
    if (busy) return;
    setBusy(question.id);
    setNotice('');
    try {
      const response = await fetch(`/api/duel-questions/${encodeURIComponent(question.id)}/active`, {
        method: 'POST',
        credentials: 'same-origin',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ active: !question.active }),
      });
      const body = await response.json().catch(() => ({}));
      if (!response.ok) throw new Error(body?.error || 'تعذّر حفظ التغيير');
      const updated: DuelQuestion | null = body.question ?? null;
      setQuestions((current) =>
        current.map((item) =>
          item.id === question.id
            ? {
                ...item,
                active: updated ? updated.active : !item.active,
                disabledBy: updated ? updated.disabledBy : item.disabledBy,
                disabledAt: updated ? updated.disabledAt : item.disabledAt,
              }
            : item,
        ),
      );
      setNotice(question.active ? 'عُطّل السؤال: لن يظهر في المباريات الجديدة.' : 'فُعّل السؤال من جديد.');
    } catch (failure) {
      setNotice(failure instanceof Error ? failure.message : 'تعذّر حفظ التغيير');
    } finally {
      setBusy(null);
    }
  };

  const activeCount = questions.filter((question) => question.active).length;
  const selectClass = `rounded-xl border bg-white p-3 font-bold ${theme.field}`;

  return (
    <div className="dashboard-page dashboard-consistent-page animate-fadeIn">
      <div>
        <h2 className={`text-3xl font-black ${theme.title}`}>⚔️ أسئلة «تحدَّ زملاءك»</h2>
        <p className={`mt-2 text-sm font-bold ${theme.text}`}>
          {role === 'admin'
            ? 'كل أسئلة المبارزة في كل المواد. السؤال المعطّل لا يُختار في أي مباراة جديدة، ويُعاد بضغطة.'
            : 'أسئلة المبارزة التي يلعبها طلابك. تعطّل ما وُلّد من دروسك، والأسئلة المشتركة بين الصفوف يعطّلها المشرف.'}
        </p>
      </div>

      {role === 'admin' && <GenerateAllPanel onFinished={reloadList} />}

      <div className={`rounded-2xl border p-4 ${theme.panel}`}>
        <form
          className="grid grid-cols-1 gap-3 sm:grid-cols-2 xl:grid-cols-5"
          onSubmit={(event) => {
            event.preventDefault();
            setFilters((current) => ({ ...current, q: search.trim() }));
          }}
        >
          <select
            aria-label="المادة"
            value={filters.subject}
            onChange={(event) => setFilters({ ...filters, subject: event.target.value })}
            className={selectClass}
          >
            <option value="">كل المواد</option>
            {Object.entries(SUBJECTS).map(([key, label]) => (
              <option key={key} value={key}>{label}</option>
            ))}
          </select>
          <select
            aria-label="المصدر"
            value={filters.source}
            onChange={(event) => setFilters({ ...filters, source: event.target.value })}
            className={selectClass}
          >
            <option value="">كل المصادر</option>
            {Object.entries(SOURCES).map(([key, label]) => (
              <option key={key} value={key}>{label}</option>
            ))}
          </select>
          <select
            aria-label="الحالة"
            value={filters.status}
            onChange={(event) => setFilters({ ...filters, status: event.target.value })}
            className={selectClass}
          >
            <option value="">المفعّلة والمعطّلة</option>
            <option value="active">المفعّلة فقط</option>
            <option value="disabled">المعطّلة فقط</option>
          </select>
          <input
            type="search"
            value={search}
            onChange={(event) => setSearch(event.target.value)}
            placeholder="ابحث في نص السؤال…"
            className={selectClass}
          />
          <button
            type="submit"
            className={`rounded-xl px-4 py-3 font-black text-white ${theme.button}`}
          >
            🔎 بحث
          </button>
        </form>
        {role === 'teacher' && (
          <label className={`mt-3 flex items-center gap-2 text-sm font-bold ${theme.strong}`}>
            <input
              type="checkbox"
              checked={filters.mine}
              onChange={(event) => setFilters({ ...filters, mine: event.target.checked })}
            />
            أسئلة دروسي فقط
          </label>
        )}
      </div>

      {notice && (
        <div role="status" className={`rounded-xl border bg-white p-3 text-sm font-bold ${theme.soft}`}>
          {notice}
        </div>
      )}
      {error && (
        <div role="alert" className="rounded-xl border border-red-200 bg-red-50 p-4 font-bold text-red-700">
          {error}
        </div>
      )}

      {!error && (
        <p className={`text-sm font-bold ${theme.text}`}>
          المعروض: {questions.length} سؤالاً — المفعّل منها {activeCount}
        </p>
      )}

      <div className="space-y-3">
        {questions.map((question) => {
          const answer = question.choices[0];
          return (
            <div
              key={question.id}
              className={`rounded-2xl border-2 bg-white p-4 transition-all sm:p-5 ${
                question.active ? theme.card : 'border-gray-200 opacity-70'
              }`}
            >
              <div className="flex flex-col gap-3 sm:flex-row sm:items-start sm:justify-between">
                <div className="min-w-0 flex-1">
                  <div className="mb-2 flex flex-wrap gap-2 text-xs font-bold">
                    <span className={`rounded-full px-3 py-1 ${theme.chip}`}>
                      {SUBJECTS[question.subjectKey] ?? question.subjectKey}
                    </span>
                    <span className="rounded-full bg-sky-100 px-3 py-1 text-sky-800">
                      {CATEGORIES[question.category] ?? question.category}
                    </span>
                    <span className="rounded-full bg-gray-100 px-3 py-1 text-gray-700">
                      {SOURCES[question.source] ?? question.source}
                    </span>
                    {question.lessonTitle && (
                      <span className="rounded-full bg-emerald-50 px-3 py-1 text-emerald-800">
                        📘 {question.lessonTitle}
                      </span>
                    )}
                    {!question.active && (
                      <span className="rounded-full bg-red-100 px-3 py-1 text-red-700">معطّل</span>
                    )}
                  </div>
                  <p className="text-lg font-black text-gray-900 break-words">{question.prompt}</p>
                  <div className="mt-3 flex flex-wrap gap-2">
                    {question.choices.map((choice, index) => (
                      <span
                        key={`${question.id}-${index}`}
                        className={`rounded-lg px-3 py-1 text-sm font-bold ${
                          choice === answer && index === 0
                            ? 'bg-green-100 text-green-800'
                            : 'bg-gray-50 text-gray-600'
                        }`}
                      >
                        {index === 0 ? '✓ ' : ''}{choice}
                      </span>
                    ))}
                  </div>
                  {!question.active && question.disabledBy && (
                    <p className="mt-2 text-xs font-bold text-gray-500">
                      عطّله {disabledByLabel(question.disabledBy)}
                      {question.disabledAt ? ` في ${formatDate(question.disabledAt)}` : ''}
                    </p>
                  )}
                </div>
                <div className="shrink-0">
                  {question.canToggle ? (
                    <button
                      type="button"
                      onClick={() => void toggle(question)}
                      disabled={busy !== null}
                      aria-pressed={!question.active}
                      className={`w-full rounded-xl px-4 py-2 text-sm font-black transition-all disabled:opacity-50 sm:w-auto ${
                        question.active
                          ? 'bg-red-100 text-red-700 hover:bg-red-200'
                          : 'bg-green-100 text-green-700 hover:bg-green-200'
                      }`}
                    >
                      {busy === question.id ? '…' : question.active ? '⛔ تعطيل' : '✅ تفعيل'}
                    </button>
                  ) : (
                    <span className="block rounded-xl bg-gray-50 px-3 py-2 text-xs font-bold text-gray-500">
                      مشترك — يعطّله المشرف
                    </span>
                  )}
                </div>
              </div>
            </div>
          );
        })}

        {!loading && !error && questions.length === 0 && (
          <div className={`rounded-2xl border border-dashed bg-white p-8 text-center font-bold ${theme.dashed}`}>
            لا أسئلة بهذه المرشّحات.
          </div>
        )}
        {loading && (
          <div className={`p-6 text-center font-bold ${theme.text}`}>جارٍ التحميل…</div>
        )}
        {!loading && hasMore && (
          <button
            type="button"
            onClick={() => void load(nextOffset)}
            className={`w-full rounded-xl border bg-white p-3 font-black ${theme.soft}`}
          >
            تحميل المزيد
          </button>
        )}
      </div>
    </div>
  );
};

export default DuelQuestionReview;
