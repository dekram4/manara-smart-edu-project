import React, { useCallback, useEffect, useMemo, useState } from 'react';
import { managementRequest } from '../../utils/managementApi';
import { STORAGE_KEYS } from '../../constants';
import { playLamsaSound } from '../../utils/sounds';

/**
 * صلاحيات بطاقات الطالب: يفتح المعلمُ أو المشرف كلَّ بطاقةٍ في تطبيق الطالب
 * أو يغلقها، لصفٍّ كاملٍ أو لطالبٍ بعينه.
 *
 * ── والأضيقُ يغلب ──
 * قاعدةُ الطالب تغلب قاعدةَ صفّه في كل بطاقة، وما لم تذكره قاعدةٌ فمفتوح.
 * والبطاقةُ المغلقة تظهر للطالب رماديةً بقفل، ولمسُها يقول له: «عذراً،
 * ليس لديك صلاحية لهذه البطاقة، يرجى مراجعة المشرف أو المعلم».
 *
 * شاشةٌ واحدةٌ للدورين كـ `DuelQuestionReview`: ما يُرى وما يُعدَّل يحسمه
 * الخادم — المعلم يرى طلابه وصفوفه وحدها.
 */

type Role = 'admin' | 'teacher';
type CardMap = Record<string, boolean>;

interface CardDef { id: string; label: string }
interface StudentRow { id: string; name: string; grade: string; teacherId: string }
interface CardRule {
  id: string;
  scope: 'class' | 'student';
  studentId: string | null;
  teacherId: string;
  gradeId: string | null;
  cards: CardMap;
  updatedAt: string;
}
interface PermissionsResponse {
  cards: CardDef[];
  teachers: Array<{ id: string; name: string }>;
  students: StudentRow[];
  rules: CardRule[];
}

const CARD_ICONS: Record<string, string> = {
  lesson: '📖',
  cinema: '🎬',
  games: '🎮',
  personality: '🧑‍🎨',
  tutor: '👩‍🏫',
  quiz: '📝',
  solver: '🧮',
  meeting: '📡',
  chat: '💬',
  challenge: '⚔️',
  study: '📚',
};

/** نفسُ تسوية الخادم المختصرة لمقارنة المعرّفات والصفوف. */
const norm = (value: unknown) =>
  String(value ?? '')
    .trim()
    .toLowerCase()
    .replace(/[ً-ْٰـ]/g, '')
    .replace(/[أإآٱ]/g, 'ا')
    .replace(/ى/g, 'ي')
    .replace(/ة/g, 'ه')
    .replace(/\s+/g, ' ');

const allOpen = (cards: CardDef[]): CardMap =>
  Object.fromEntries(cards.map(card => [card.id, true]));

const readGrades = (): string[] => {
  try {
    const value = JSON.parse(localStorage.getItem(STORAGE_KEYS.GRADES) || '[]');
    return Array.isArray(value) ? value.filter((item): item is string => typeof item === 'string') : [];
  } catch {
    return [];
  }
};

interface CardPermissionsProps {
  role: Role;
  /** معرّف المعلم الحالي — للمعلم وحده. */
  teacherId?: string;
}

const CardPermissions: React.FC<CardPermissionsProps> = ({ role, teacherId }) => {
  const [data, setData] = useState<PermissionsResponse | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  const [mode, setMode] = useState<'class' | 'student'>('class');
  const [classTeacher, setClassTeacher] = useState(role === 'teacher' ? teacherId || '' : '');
  const [classGrade, setClassGrade] = useState('');
  const [studentId, setStudentId] = useState('');
  const [studentQuery, setStudentQuery] = useState('');
  const [draft, setDraft] = useState<CardMap>({});
  const [saving, setSaving] = useState(false);
  const [notice, setNotice] = useState('');

  const load = useCallback(async () => {
    setLoading(true);
    setError('');
    try {
      setData(await managementRequest<PermissionsResponse>('/api/card-permissions'));
    } catch (err) {
      setError(err instanceof Error ? err.message : 'تعذر تحميل صلاحيات البطاقات');
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    void load();
  }, [load]);

  const cards = data?.cards ?? [];
  const students = data?.students ?? [];
  const rules = data?.rules ?? [];

  const teacherOptions = useMemo(() => {
    if (role === 'teacher') return [];
    return data?.teachers ?? [];
  }, [data, role]);

  /** هل هذا الطالب من طلاب هذا المعلم؟ بالمعرّف أو بالاسم، كما يقارن الخادم. */
  const belongsTo = useCallback((student: StudentRow, teacher: string) => {
    if (role === 'teacher') return true;
    const option = teacherOptions.find(item => item.id === teacher);
    const names = [norm(teacher), norm(option?.name)].filter(Boolean);
    return names.includes(norm(student.teacherId));
  }, [role, teacherOptions]);

  /** هل قاعدةُ الصف هذه لمعلّم هذا الطالب؟ المعلمُ لا يرى إلا قواعده أصلاً. */
  const ruleTeacherIs = useCallback((rule: CardRule, studentTeacherId: string) => {
    if (role === 'teacher') return true;
    if (norm(rule.teacherId) === norm(studentTeacherId)) return true;
    const option = teacherOptions.find(item => item.id === rule.teacherId);
    return Boolean(option) && norm(option?.name) === norm(studentTeacherId);
  }, [role, teacherOptions]);

  const classGrades = useMemo(() => {
    if (!classTeacher) return [];
    const grades = students.filter(student => belongsTo(student, classTeacher)).map(student => student.grade);
    const fromRules = rules
      .filter(rule => rule.scope === 'class' && norm(rule.teacherId) === norm(classTeacher))
      .map(rule => rule.gradeId || '');
    return Array.from(new Set([...grades, ...fromRules, ...readGrades()].filter(Boolean)));
  }, [classTeacher, students, rules, belongsTo]);

  const findClassRule = useCallback((teacher: string, grade: string) =>
    rules.find(rule =>
      rule.scope === 'class' &&
      (role === 'teacher' || norm(rule.teacherId) === norm(teacher) ||
        norm(rule.teacherId) === norm(teacherOptions.find(item => item.id === teacher)?.name)) &&
      norm(rule.gradeId) === norm(grade),
    ), [rules, role, teacherOptions]);

  const selectedStudent = students.find(student => student.id === studentId) ?? null;
  const studentRule = selectedStudent
    ? rules.find(rule => rule.scope === 'student' && rule.studentId === selectedStudent.id)
    : undefined;
  const studentClassRule = selectedStudent
    ? rules.find(rule =>
        rule.scope === 'class' &&
        ruleTeacherIs(rule, selectedStudent.teacherId) &&
        norm(rule.gradeId) === norm(selectedStudent.grade),
      )
    : undefined;

  /** الحالة النهائية لطالب: الكل مفتوح، ثم صفّه، ثم قاعدته. */
  const effectiveFor = useCallback((student: StudentRow): CardMap => {
    const classRule = rules.find(rule =>
      rule.scope === 'class' &&
      ruleTeacherIs(rule, student.teacherId) &&
      norm(rule.gradeId) === norm(student.grade),
    );
    const own = rules.find(rule => rule.scope === 'student' && rule.studentId === student.id);
    return { ...allOpen(cards), ...(classRule?.cards ?? {}), ...(own?.cards ?? {}) };
  }, [rules, cards, ruleTeacherIs]);

  // ما يُعرض في المفاتيح يتبع الاختيار: قاعدة الصف، أو حالة الطالب النهائية.
  useEffect(() => {
    if (!cards.length) return;
    if (mode === 'class') {
      const rule = classTeacher && classGrade ? findClassRule(classTeacher, classGrade) : undefined;
      setDraft({ ...allOpen(cards), ...(rule?.cards ?? {}) });
    } else if (selectedStudent) {
      setDraft(effectiveFor(selectedStudent));
    } else {
      setDraft(allOpen(cards));
    }
    setNotice('');
  }, [mode, classTeacher, classGrade, studentId, rules, cards, findClassRule, effectiveFor, selectedStudent]);

  const canEdit = mode === 'class' ? Boolean(classTeacher && classGrade) : Boolean(selectedStudent);
  const activeRule = mode === 'class'
    ? (classTeacher && classGrade ? findClassRule(classTeacher, classGrade) : undefined)
    : studentRule;

  const save = async () => {
    if (!canEdit) return;
    setSaving(true);
    setNotice('');
    try {
      await managementRequest('/api/card-permissions', {
        method: 'PUT',
        body: JSON.stringify(mode === 'class'
          ? { scope: 'class', teacherId: classTeacher, gradeId: classGrade, cards: draft }
          : { scope: 'student', studentId, cards: draft }),
      });
      playLamsaSound('success');
      setNotice('✅ تم حفظ الصلاحيات، وتظهر للطالب عند فتحه التطبيق أو عودته إلى الواجهة.');
      await load();
    } catch (err) {
      setNotice(`⚠️ ${err instanceof Error ? err.message : 'تعذر حفظ الصلاحيات'}`);
    } finally {
      setSaving(false);
    }
  };

  const reset = async () => {
    if (!activeRule) return;
    if (!confirm(mode === 'class'
      ? 'إعادة كل بطاقات هذا الصف إلى «مفتوحة»؟'
      : 'إلغاء إعدادات هذا الطالب الخاصة وإعادته إلى إعدادات صفّه؟')) return;
    setSaving(true);
    try {
      await managementRequest(`/api/card-permissions/${encodeURIComponent(activeRule.id)}`, { method: 'DELETE' });
      playLamsaSound('pop');
      setNotice('✅ تمت إعادة الضبط.');
      await load();
    } catch (err) {
      setNotice(`⚠️ ${err instanceof Error ? err.message : 'تعذر إعادة الضبط'}`);
    } finally {
      setSaving(false);
    }
  };

  const setAll = (value: boolean) => setDraft(Object.fromEntries(cards.map(card => [card.id, value])));

  const visibleStudents = students
    .filter(student => !studentQuery.trim() || norm(student.name).includes(norm(studentQuery)) || norm(student.grade).includes(norm(studentQuery)))
    .sort((a, b) => a.grade.localeCompare(b.grade, 'ar') || a.name.localeCompare(b.name, 'ar'));

  return (
    <div className="dashboard-page dashboard-consistent-page animate-fadeIn" dir="rtl">
      <div className="dashboard-section-header">
        <div>
          <h2 className="text-4xl font-black text-indigo-800">🔐 صلاحيات البطاقات</h2>
          <p className="mt-1 font-medium text-indigo-500">
            افتح أو أغلق كل بطاقة في تطبيق الطالب، لصفٍّ كامل أو لطالبٍ بعينه.
          </p>
        </div>
        <button
          onClick={() => void load()}
          className="rounded-2xl bg-white px-5 py-3 font-black text-indigo-700 shadow hover:bg-indigo-50"
        >
          🔄 تحديث
        </button>
      </div>

      {error && (
        <div className="rounded-2xl border-2 border-red-200 bg-red-50 p-4 font-bold text-red-700">⚠️ {error}</div>
      )}
      {loading && !data && <div className="p-10 text-center font-black text-indigo-700">⏳ جارٍ التحميل…</div>}

      {data && (
        <>
          <div className="flex flex-wrap gap-2 rounded-2xl bg-indigo-50 p-2">
            {([['class', '🏫 صلاحيات صف كامل'], ['student', '👤 صلاحيات طالب']] as const).map(([value, label]) => (
              <button
                key={value}
                onClick={() => setMode(value)}
                className={`flex-1 rounded-xl px-4 py-3 font-black transition ${mode === value ? 'bg-indigo-600 text-white shadow-md' : 'text-indigo-700 hover:bg-white'}`}
              >
                {label}
              </button>
            ))}
          </div>

          <div className="dashboard-surface space-y-5 border-indigo-200">
            {mode === 'class' ? (
              <div className="grid grid-cols-1 gap-4 md:grid-cols-2">
                {role === 'admin' && (
                  <label className="block">
                    <span className="mb-2 block text-sm font-black text-indigo-900">👨‍🏫 المعلم</span>
                    <select
                      value={classTeacher}
                      onChange={e => { setClassTeacher(e.target.value); setClassGrade(''); }}
                      className="w-full rounded-2xl border-[3px] border-indigo-200 bg-indigo-50 p-3 font-black text-indigo-900"
                    >
                      <option value="">اختر المعلم</option>
                      {teacherOptions.map(teacher => <option key={teacher.id} value={teacher.id}>{teacher.name}</option>)}
                    </select>
                  </label>
                )}
                <label className="block">
                  <span className="mb-2 block text-sm font-black text-indigo-900">🎓 الصف الدراسي</span>
                  <select
                    value={classGrade}
                    onChange={e => setClassGrade(e.target.value)}
                    disabled={!classTeacher}
                    className="w-full rounded-2xl border-[3px] border-indigo-200 bg-indigo-50 p-3 font-black text-indigo-900 disabled:opacity-60"
                  >
                    <option value="">{classTeacher ? 'اختر الصف' : 'اختر المعلم أولاً'}</option>
                    {classGrades.map(grade => <option key={grade} value={grade}>{grade}</option>)}
                  </select>
                </label>
              </div>
            ) : (
              <div className="grid grid-cols-1 gap-4 md:grid-cols-2">
                <label className="block">
                  <span className="mb-2 block text-sm font-black text-indigo-900">🔎 بحث بالاسم أو الصف</span>
                  <input
                    value={studentQuery}
                    onChange={e => setStudentQuery(e.target.value)}
                    placeholder="اكتب اسم الطالب…"
                    className="w-full rounded-2xl border-[3px] border-indigo-200 bg-indigo-50 p-3 font-bold"
                  />
                </label>
                <label className="block">
                  <span className="mb-2 block text-sm font-black text-indigo-900">👤 الطالب</span>
                  <select
                    value={studentId}
                    onChange={e => setStudentId(e.target.value)}
                    className="w-full rounded-2xl border-[3px] border-indigo-200 bg-indigo-50 p-3 font-black text-indigo-900"
                  >
                    <option value="">اختر الطالب ({visibleStudents.length})</option>
                    {visibleStudents.map(student => (
                      <option key={student.id} value={student.id}>
                        {student.name}{student.grade ? ` — ${student.grade}` : ''}
                      </option>
                    ))}
                  </select>
                </label>
                {selectedStudent && (
                  <p className="text-sm font-bold text-indigo-600 md:col-span-2">
                    {studentRule
                      ? '⭐ لهذا الطالب إعدادات خاصة تغلب إعدادات صفّه.'
                      : studentClassRule
                        ? 'يتبع هذا الطالب إعدادات صفّه حاليًا. أي حفظ هنا يجعل له إعدادات خاصة.'
                        : 'كل البطاقات مفتوحة لهذا الطالب حاليًا.'}
                  </p>
                )}
              </div>
            )}

            <div className="flex flex-wrap items-center justify-between gap-2">
              <h3 className="text-xl font-black text-indigo-900">البطاقات</h3>
              <div className="flex gap-2">
                <button type="button" disabled={!canEdit} onClick={() => setAll(true)} className="rounded-xl bg-emerald-100 px-3 py-2 text-sm font-black text-emerald-800 disabled:opacity-50">فتح الكل</button>
                <button type="button" disabled={!canEdit} onClick={() => setAll(false)} className="rounded-xl bg-slate-200 px-3 py-2 text-sm font-black text-slate-700 disabled:opacity-50">إغلاق الكل</button>
              </div>
            </div>

            <div className="grid grid-cols-1 gap-3 sm:grid-cols-2 xl:grid-cols-3">
              {cards.map(card => {
                const open = draft[card.id] !== false;
                return (
                  <button
                    key={card.id}
                    type="button"
                    disabled={!canEdit}
                    onClick={() => setDraft(current => ({ ...current, [card.id]: !open }))}
                    aria-pressed={open}
                    className={`flex items-center gap-3 rounded-2xl border-2 p-4 text-right transition disabled:cursor-not-allowed disabled:opacity-50 ${open ? 'border-emerald-300 bg-emerald-50' : 'border-slate-300 bg-slate-100 grayscale'}`}
                  >
                    <span className="text-3xl">{CARD_ICONS[card.id] ?? '🗂️'}</span>
                    <span className="flex-1 font-black text-slate-800">{card.label}</span>
                    <span className={`rounded-full px-3 py-1 text-xs font-black ${open ? 'bg-emerald-500 text-white' : 'bg-slate-500 text-white'}`}>
                      {open ? '✅ مفعّلة' : '🔒 معطّلة'}
                    </span>
                  </button>
                );
              })}
            </div>

            {notice && <p className="rounded-xl bg-indigo-50 p-3 font-bold text-indigo-800">{notice}</p>}

            <div className="flex flex-col gap-3 sm:flex-row">
              <button
                type="button"
                disabled={!canEdit || saving}
                onClick={() => void save()}
                className="flex-1 rounded-2xl bg-gradient-to-r from-indigo-500 to-violet-600 py-4 text-lg font-black text-white shadow-xl disabled:opacity-50"
              >
                {saving ? '⏳ جارٍ الحفظ…' : '💾 حفظ الصلاحيات'}
              </button>
              {activeRule && (
                <button
                  type="button"
                  disabled={saving}
                  onClick={() => void reset()}
                  className="rounded-2xl border-2 border-indigo-200 bg-white px-5 py-4 font-black text-indigo-700 disabled:opacity-50"
                >
                  {mode === 'class' ? '↩️ فتح كل بطاقات الصف' : '↩️ العودة لإعدادات الصف'}
                </button>
              )}
            </div>
          </div>

          <div className="dashboard-surface border-indigo-100">
            <h3 className="mb-3 text-xl font-black text-indigo-900">📋 البطاقات المعطّلة لكل طالب</h3>
            <div className="overflow-x-auto">
              <table className="w-full min-w-[520px] text-right text-sm">
                <thead>
                  <tr className="border-b-2 border-indigo-100 text-indigo-700">
                    <th className="p-2">الطالب</th>
                    <th className="p-2">الصف</th>
                    <th className="p-2">البطاقات المعطّلة</th>
                  </tr>
                </thead>
                <tbody>
                  {visibleStudents.map(student => {
                    const effective = effectiveFor(student);
                    const locked = cards.filter(card => effective[card.id] === false);
                    return (
                      <tr
                        key={student.id}
                        onClick={() => { setMode('student'); setStudentId(student.id); }}
                        className="cursor-pointer border-b border-indigo-50 hover:bg-indigo-50"
                      >
                        <td className="p-2 font-black">{student.name}</td>
                        <td className="p-2">{student.grade}</td>
                        <td className="p-2">
                          {locked.length === 0
                            ? <span className="font-bold text-emerald-600">كلها مفتوحة</span>
                            : locked.map(card => (
                                <span key={card.id} className="mb-1 ml-1 inline-block rounded-lg bg-slate-200 px-2 py-1 text-xs font-bold text-slate-700">🔒 {card.label}</span>
                              ))}
                        </td>
                      </tr>
                    );
                  })}
                  {visibleStudents.length === 0 && (
                    <tr><td colSpan={3} className="p-4 text-center font-bold text-indigo-400">لا يوجد طلاب.</td></tr>
                  )}
                </tbody>
              </table>
            </div>
          </div>
        </>
      )}
    </div>
  );
};

export default CardPermissions;
