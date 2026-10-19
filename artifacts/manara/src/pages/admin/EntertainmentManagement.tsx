import React, { useCallback, useEffect, useRef, useState } from 'react';
import { playLamsaSound } from '../../utils/sounds';
import { managementRequest } from '../../utils/managementApi';

/**
 * «الترفيه والألعاب»: ألعابٌ يضيفها المشرف ويُسندها إلى معلّم.
 *
 * اللعبةُ تظهر في بطاقة «عالم الترفيه» لطلاب المعلم المسند وحدهم، ما دامت
 * مفعّلة — بعد ألعاب الفهرس الثابت، وبالبطاقة والمشغّل نفسيهما.
 *
 * والحفظ عبر `/api/entertainment` لا عبر التخزين المحلي: الخادم يتحقّق من
 * المعلم والرابط، ويكتب في جدول `entertainment_games`.
 */

interface EntertainmentGame {
  id: string;
  title: string;
  description: string;
  embedUrl: string;
  teacherId: string;
  teacherName: string;
  isActive: boolean;
  createdAt: string;
  updatedAt: string;
}

interface ListResponse {
  storage: 'table' | 'kv';
  teachers: Array<{ id: string; name: string }>;
  games: EntertainmentGame[];
}

const EMPTY_FORM = { title: '', description: '', embedUrl: '', teacherId: '', isActive: true };

const inputClass =
  'w-full rounded-2xl border-[3px] border-violet-200 bg-violet-50 p-4 font-bold text-violet-950 outline-none focus:border-violet-400 focus:ring-4 focus:ring-violet-100';

const EntertainmentManagement: React.FC = () => {
  const [games, setGames] = useState<EntertainmentGame[]>([]);
  const [teachers, setTeachers] = useState<Array<{ id: string; name: string }>>([]);
  const [storage, setStorage] = useState<'table' | 'kv' | null>(null);
  const [loading, setLoading] = useState(true);
  const [loadError, setLoadError] = useState('');
  const [saving, setSaving] = useState(false);
  const [showForm, setShowForm] = useState(false);
  const [editing, setEditing] = useState<EntertainmentGame | null>(null);
  const [formData, setFormData] = useState(EMPTY_FORM);
  const [teacherFilter, setTeacherFilter] = useState('');
  const formRef = useRef<HTMLFormElement>(null);

  const loadGames = useCallback(async () => {
    setLoading(true);
    setLoadError('');
    try {
      const data = await managementRequest<ListResponse>('/api/entertainment');
      setGames(Array.isArray(data?.games) ? data.games : []);
      setTeachers(Array.isArray(data?.teachers) ? data.teachers : []);
      setStorage(data?.storage ?? null);
    } catch (error) {
      setLoadError(error instanceof Error ? error.message : 'تعذر تحميل الألعاب');
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    void loadGames();
  }, [loadGames]);

  // النموذجُ يُفتح أعلى الصفحة والمؤشرُ في أول حقل — كتعديل المحتوى.
  useEffect(() => {
    if (!showForm) return;
    requestAnimationFrame(() => {
      formRef.current?.scrollIntoView({ behavior: 'smooth', block: 'start' });
      formRef.current?.querySelector<HTMLElement>('input, select, textarea')?.focus({ preventScroll: true });
    });
  }, [showForm, editing]);

  const closeForm = () => {
    setShowForm(false);
    setEditing(null);
    setFormData(EMPTY_FORM);
  };

  const beginEditing = (game: EntertainmentGame) => {
    setEditing(game);
    setFormData({
      title: game.title,
      description: game.description,
      embedUrl: game.embedUrl,
      teacherId: game.teacherId,
      isActive: game.isActive,
    });
    setShowForm(true);
    playLamsaSound('click');
  };

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!formData.teacherId) {
      alert('يرجى اختيار المعلم المسؤول عن اللعبة');
      return;
    }
    setSaving(true);
    try {
      const body = JSON.stringify({
        title: formData.title.trim(),
        description: formData.description.trim(),
        embedUrl: formData.embedUrl.trim(),
        teacherId: formData.teacherId,
        isActive: formData.isActive,
      });
      if (editing) {
        await managementRequest(`/api/entertainment/${encodeURIComponent(editing.id)}`, { method: 'PUT', body });
      } else {
        await managementRequest('/api/entertainment', { method: 'POST', body });
      }
      closeForm();
      await loadGames();
      playLamsaSound('success');
    } catch (error) {
      alert(`⚠️ ${error instanceof Error ? error.message : 'تعذر حفظ اللعبة'}`);
    } finally {
      setSaving(false);
    }
  };

  const toggleActive = async (game: EntertainmentGame) => {
    try {
      await managementRequest(`/api/entertainment/${encodeURIComponent(game.id)}`, {
        method: 'PUT',
        body: JSON.stringify({ ...game, isActive: !game.isActive }),
      });
      await loadGames();
      playLamsaSound('pop');
    } catch (error) {
      alert(`⚠️ ${error instanceof Error ? error.message : 'تعذر تحديث حالة اللعبة'}`);
    }
  };

  const handleDelete = async (game: EntertainmentGame) => {
    if (!confirm(`هل أنت متأكد من حذف لعبة «${game.title}»؟`)) return;
    try {
      await managementRequest<null>(`/api/entertainment/${encodeURIComponent(game.id)}`, { method: 'DELETE' });
      await loadGames();
      playLamsaSound('pop');
    } catch (error) {
      alert(`⚠️ ${error instanceof Error ? error.message : 'تعذر حذف اللعبة'}`);
    }
  };

  const visibleGames = games.filter(game => !teacherFilter || game.teacherId === teacherFilter);

  return (
    <div className="dashboard-page dashboard-consistent-page animate-fadeIn">
      <div className="dashboard-section-header">
        <div>
          <h2 className="text-4xl font-black text-violet-900">🎮 الترفيه والألعاب</h2>
          <p className="mt-1 font-medium text-violet-500">
            ألعابٌ تظهر في «عالم الترفيه» لطلاب المعلم المسند إليه فقط
          </p>
        </div>
        <button
          onClick={() => {
            if (showForm) closeForm();
            else {
              setEditing(null);
              setFormData(EMPTY_FORM);
              setShowForm(true);
            }
            playLamsaSound('click');
          }}
          className="rounded-2xl bg-gradient-to-r from-violet-500 to-fuchsia-500 px-6 py-3 font-black text-white shadow-xl transition-all hover:scale-105 active:scale-95"
        >
          {showForm ? (editing ? '↩ إلغاء التعديل والعودة للقائمة' : '❌ إلغاء') : '➕ لعبة جديدة'}
        </button>
      </div>

      {storage === 'kv' && (
        <div className="rounded-2xl border-2 border-amber-300 bg-amber-50 p-3 text-sm font-bold text-amber-900">
          ℹ️ جدول <code>entertainment_games</code> لم يُنشأ بعد في Supabase، فتُحفظ الألعاب مؤقتاً في التخزين المشترك وتعمل كاملةً.
          شغّل ملف <code>entertainment-games.sql</code> في محرّر SQL لنقلها إلى الجدول.
        </div>
      )}

      {showForm && (
        <form
          ref={formRef}
          onSubmit={handleSubmit}
          style={{ scrollMarginTop: '1rem' }}
          className="dashboard-surface flex flex-col space-y-5 border-violet-200 animate-bounce-in"
        >
          <div className="border-b border-violet-100 pb-4">
            <h3 className="text-2xl font-black text-violet-900">
              {editing ? '✏️ تعديل لعبة' : '🎮 إضافة لعبة إلى «عالم الترفيه»'}
            </h3>
            <p className="mt-1 text-sm font-bold text-violet-500">
              تُفتح اللعبة في مشغّل الألعاب داخل التطبيق كبقية الألعاب، ولا يراها إلا طلاب المعلم المختار.
            </p>
          </div>

          <div className="grid grid-cols-1 gap-5 md:grid-cols-2">
            <div>
              <label htmlFor="game-title" className="mb-2 block text-sm font-black text-violet-900">
                🏷️ عنوان / اسم اللعبة <span className="text-red-600">*</span>
              </label>
              <input
                id="game-title"
                type="text"
                required
                maxLength={200}
                placeholder="مثال: مغامرة الكسور"
                value={formData.title}
                onChange={e => setFormData({ ...formData, title: e.target.value })}
                className={inputClass}
              />
            </div>
            <div>
              <label htmlFor="game-teacher" className="mb-2 block text-sm font-black text-violet-900">
                👨‍🏫 المعلم المسؤول <span className="text-red-600">*</span>
              </label>
              <select
                id="game-teacher"
                required
                value={formData.teacherId}
                onChange={e => {
                  e.currentTarget.setCustomValidity('');
                  setFormData({ ...formData, teacherId: e.target.value });
                }}
                onInvalid={e => e.currentTarget.setCustomValidity('يرجى اختيار المعلم المسؤول عن اللعبة')}
                className={inputClass}
              >
                <option value="">اختر المعلم</option>
                {teachers.map(teacher => (
                  <option key={teacher.id} value={teacher.id}>👨‍🏫 {teacher.name}</option>
                ))}
              </select>
              {teachers.length === 0 && !loading && (
                <p className="mt-2 text-sm font-bold text-red-600">لا يوجد معلمون مسجلون بعد لإسناد اللعبة.</p>
              )}
            </div>
          </div>

          <div>
            <label htmlFor="game-url" className="mb-2 block text-sm font-black text-violet-900">
              🔗 رابط اللعبة المباشر أو المضمن <span className="text-red-600">*</span>
            </label>
            <input
              id="game-url"
              type="url"
              required
              dir="ltr"
              placeholder="https://html5.gamedistribution.com/…"
              value={formData.embedUrl}
              onChange={e => setFormData({ ...formData, embedUrl: e.target.value })}
              className={`${inputClass} text-left`}
            />
          </div>

          <div>
            <label htmlFor="game-description" className="mb-2 block text-sm font-black text-violet-900">
              📝 وصف مختصر
            </label>
            <textarea
              id="game-description"
              rows={3}
              maxLength={1000}
              placeholder="سطرٌ يظهر تحت اسم اللعبة في التطبيق (اختياري)"
              value={formData.description}
              onChange={e => setFormData({ ...formData, description: e.target.value })}
              className={`${inputClass} resize-none`}
            />
          </div>

          <label className="flex cursor-pointer items-center gap-3 rounded-2xl border-2 border-violet-100 bg-violet-50/60 p-4">
            <input
              type="checkbox"
              checked={formData.isActive}
              onChange={e => setFormData({ ...formData, isActive: e.target.checked })}
              className="h-6 w-6 accent-violet-600"
            />
            <span className="font-black text-violet-900">
              {formData.isActive ? '✅ مفعّلة — تظهر للطلاب' : '⏸️ معطّلة — مخفية عن الطلاب'}
            </span>
          </label>

          <button
            type="submit"
            disabled={saving}
            className="w-full rounded-2xl bg-gradient-to-r from-violet-500 to-fuchsia-500 py-4 text-xl font-black text-white shadow-xl transition-all hover:-translate-y-0.5 active:scale-95 disabled:opacity-60"
          >
            {saving ? '⏳ جارٍ الحفظ…' : editing ? '💾 حفظ التعديل' : '💾 حفظ ونشر اللعبة'}
          </button>
        </form>
      )}

      {loadError && (
        <div className="whitespace-pre-line rounded-2xl border-2 border-red-200 bg-red-50 p-4 font-bold text-red-700">
          ⚠️ {loadError}
          <button onClick={() => void loadGames()} className="mr-3 rounded-lg bg-white px-3 py-1 text-sm text-red-700 hover:bg-red-100">إعادة المحاولة</button>
        </div>
      )}

      {!editing && (
        <>
          {teachers.length > 0 && (
            <div className="dashboard-filter-surface border-violet-200 bg-violet-50/80">
              <div className="dashboard-filter-grid">
                <select
                  aria-label="فلترة حسب المعلم"
                  value={teacherFilter}
                  onChange={e => setTeacherFilter(e.target.value)}
                  className="rounded-xl border-2 border-violet-200 bg-white p-3 font-bold text-violet-900"
                >
                  <option value="">👨‍🏫 كل المعلمين</option>
                  {teachers.map(teacher => <option key={teacher.id} value={teacher.id}>{teacher.name}</option>)}
                </select>
              </div>
            </div>
          )}

          <div className="dashboard-card-grid dashboard-card-grid-wide">
            {visibleGames.map(game => (
              <article
                key={game.id}
                className={`flex flex-col gap-3 rounded-[28px] border-2 bg-white p-5 shadow-xl transition-all hover:shadow-2xl ${game.isActive ? 'border-violet-100' : 'border-slate-200 opacity-75'}`}
              >
                <div className="flex items-start gap-3">
                  <div className="flex h-14 w-14 shrink-0 items-center justify-center rounded-2xl bg-gradient-to-br from-violet-500 to-fuchsia-500 text-2xl shadow-md" aria-hidden="true">🎮</div>
                  <div className="min-w-0 flex-1">
                    <h3 className="break-words text-xl font-black text-violet-950">{game.title}</h3>
                    {game.description && <p className="mt-1 line-clamp-2 text-sm font-medium text-violet-600">{game.description}</p>}
                  </div>
                </div>
                <p dir="ltr" className="truncate rounded-xl bg-slate-50 px-3 py-2 text-left text-xs font-bold text-slate-500" title={game.embedUrl}>
                  {game.embedUrl}
                </p>
                <div className="flex flex-wrap gap-2">
                  <span className="rounded-lg bg-orange-100 px-2 py-1 text-xs font-bold text-orange-700">👨‍🏫 {game.teacherName || game.teacherId}</span>
                  <span className={`rounded-lg px-2 py-1 text-xs font-bold ${game.isActive ? 'bg-emerald-100 text-emerald-700' : 'bg-slate-100 text-slate-600'}`}>
                    {game.isActive ? '✅ مفعّلة' : '⏸️ معطّلة'}
                  </span>
                </div>
                <div className="mt-auto flex gap-2">
                  <button onClick={() => beginEditing(game)} className="flex-1 rounded-xl bg-violet-100 py-2 text-sm font-bold text-violet-700 transition-all hover:bg-violet-200">✏️ تعديل</button>
                  <button onClick={() => void toggleActive(game)} className="flex-1 rounded-xl bg-sky-100 py-2 text-sm font-bold text-sky-700 transition-all hover:bg-sky-200">
                    {game.isActive ? '⏸️ إخفاء' : '▶️ إظهار'}
                  </button>
                  <button onClick={() => void handleDelete(game)} className="flex-1 rounded-xl bg-red-100 py-2 text-sm font-bold text-red-600 transition-all hover:bg-red-200">❌ حذف</button>
                </div>
              </article>
            ))}
            {!loading && visibleGames.length === 0 && (
              <div className="col-span-full rounded-[40px] border-2 border-dashed border-violet-300 bg-violet-50 p-16 text-center animate-popIn">
                <div className="mb-6 text-7xl">🎮</div>
                <h3 className="mb-3 text-2xl font-black text-violet-800">لا توجد ألعاب بعد</h3>
                <p className="font-bold text-violet-600">أضف لعبة وأسندها إلى معلّم لتظهر لطلابه في «عالم الترفيه».</p>
              </div>
            )}
            {loading && <div className="col-span-full p-10 text-center font-black text-violet-700">⏳ جارٍ تحميل الألعاب…</div>}
          </div>
        </>
      )}
    </div>
  );
};

export default EntertainmentManagement;
