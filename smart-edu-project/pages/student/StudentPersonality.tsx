import React, { useState } from 'react';
import { motion } from 'framer-motion';
import { StudentAppearance, StudentInfo } from '../../types';
import { GameAudioEngine } from '../../utils/gameAudioEngine';
import {
  getStudentAppearance,
  STUDENT_COLOR_OPTIONS,
  STUDENT_OUTFIT_OPTIONS,
  STUDENT_SHAPE_OPTIONS,
} from '../../utils/studentAppearance';
import StudentAvatar from './components/StudentAvatar';

interface StudentPersonalityProps {
  student: StudentInfo;
  onSave: (appearance: StudentAppearance) => void;
}

const StudentPersonality: React.FC<StudentPersonalityProps> = ({ student, onSave }) => {
  const [appearance, setAppearance] = useState<StudentAppearance>(() => getStudentAppearance(student));
  const [saved, setSaved] = useState(true);

  const choose = (next: Partial<StudentAppearance>) => {
    GameAudioEngine.play('uiSelect');
    const updated = { ...appearance, ...next };
    setAppearance(updated);
    setSaved(false);
  };

  const saveAppearance = () => {
    if (saved) return;
    GameAudioEngine.play('uiSelect');
    onSave(appearance);
    setSaved(true);
  };

  const selectedShape = STUDENT_SHAPE_OPTIONS.find(option => option.value === appearance.shape);
  const selectedColor = STUDENT_COLOR_OPTIONS.find(option => option.value === appearance.color);
  const selectedOutfit = STUDENT_OUTFIT_OPTIONS.find(option => option.value === appearance.outfit);

  return (
    <div className="relative overflow-hidden rounded-[38px] border border-rose-200 bg-[#fff8fb] p-3 shadow-[0_30px_90px_-28px_rgba(15,23,42,0.75)] sm:p-5 md:p-7">
      <div className="pointer-events-none absolute -right-24 -top-28 h-72 w-72 rounded-full bg-rose-200/60 blur-3xl" />
      <div className="pointer-events-none absolute -bottom-28 -left-24 h-72 w-72 rounded-full bg-cyan-200/60 blur-3xl" />

      <div className="relative z-10 overflow-hidden rounded-[30px] bg-gradient-to-l from-[#172554] via-[#1e1b4b] to-[#312e81] p-5 text-white shadow-2xl sm:p-7">
        <div className="flex flex-col justify-between gap-5 md:flex-row md:items-center">
          <div>
            <div className="mb-3 inline-flex items-center gap-2 rounded-full border border-white/15 bg-white/10 px-3 py-1.5 text-xs font-black text-rose-100 backdrop-blur">
              <span>✦</span> استوديو الشخصية
            </div>
            <h2 className="text-3xl font-black tracking-tight sm:text-4xl">اصنع بطلك بأسلوب احترافي</h2>
            <p className="mt-2 max-w-2xl text-sm font-bold leading-7 text-indigo-100">
              اختر شخصية تعبّر عنك، لونًا مميزًا، وملابس تمنح بطلك هوية خاصة في رحلة منارة.
            </p>
          </div>
          <div className="flex items-center gap-2 self-start rounded-2xl border border-white/10 bg-white/10 px-3 py-2 text-xs font-black text-cyan-100 md:self-auto">
            <span className="h-2.5 w-2.5 animate-pulse rounded-full bg-emerald-300" />
            {saved ? 'محفوظة في حسابك' : 'تعديلات غير محفوظة'}
          </div>
        </div>

        <div className="mt-6 grid gap-5 lg:grid-cols-[minmax(250px,0.75fr)_minmax(0,1.55fr)]">
          <div className="relative overflow-hidden rounded-[28px] border border-white/15 bg-slate-950/55 p-5 shadow-inner lg:sticky lg:top-5 lg:self-start">
            <div className="pointer-events-none absolute inset-0 opacity-60" style={{
              backgroundImage: 'linear-gradient(rgba(255,255,255,0.06) 1px, transparent 1px), linear-gradient(90deg, rgba(255,255,255,0.06) 1px, transparent 1px)',
              backgroundSize: '28px 28px',
            }} />
            <div className="relative z-10 flex items-center justify-between">
              <span className="text-xs font-black text-indigo-200">بطاقة الشخصية</span>
              <span className="rounded-full bg-rose-400/20 px-2.5 py-1 text-[10px] font-black text-rose-100">LIVE PROFILE</span>
            </div>
            <div className="relative z-10 my-7 flex min-h-52 items-center justify-center">
              <div className="absolute h-44 w-44 rounded-full bg-cyan-400/20 blur-3xl" />
              <StudentAvatar appearance={appearance} size="xl" />
            </div>
            <div className="relative z-10 rounded-2xl border border-white/10 bg-white/10 p-4 backdrop-blur">
              <p className="text-lg font-black">{student.name || 'بطلي'}</p>
              <p className="mt-1 text-xs font-bold text-indigo-200">{selectedShape?.label || 'شخصية مميزة'}</p>
              <div className="mt-3 flex flex-wrap gap-2">
                <span className="rounded-full bg-white/10 px-2.5 py-1 text-[10px] font-black text-cyan-100">{selectedColor?.label || 'لون مميز'}</span>
                <span className="rounded-full bg-white/10 px-2.5 py-1 text-[10px] font-black text-rose-100">{selectedOutfit?.label || 'زي خاص'}</span>
              </div>
            </div>
          </div>

          <div className="space-y-4">
            <section className="rounded-[26px] border border-white/10 bg-white/10 p-4 backdrop-blur sm:p-5">
              <div className="mb-4 flex items-center justify-between gap-3">
                <div>
                  <p className="text-xs font-black text-rose-300">01 / الشخصية</p>
                  <h3 className="mt-1 text-lg font-black">اختر بطلك أو بطلتك</h3>
                </div>
                <span className="rounded-xl bg-rose-100 px-2.5 py-1 text-xs font-black text-rose-700">{STUDENT_SHAPE_OPTIONS.length} شخصية</span>
              </div>
              <div className="grid grid-cols-3 gap-2 sm:grid-cols-4 xl:grid-cols-6">
                {STUDENT_SHAPE_OPTIONS.map(option => (
                  <button
                    key={option.value}
                    type="button"
                    onClick={() => choose({ shape: option.value })}
                    className={`group rounded-2xl border p-2.5 transition-all hover:-translate-y-1 ${
                      appearance.shape === option.value
                        ? 'border-rose-400 bg-rose-100 shadow-lg shadow-rose-200'
                        : 'border-slate-200 bg-white hover:border-rose-300 hover:bg-rose-50'
                    }`}
                    aria-label={option.label}
                    aria-pressed={appearance.shape === option.value}
                  >
                    <span className="block text-3xl transition-transform group-hover:scale-110">{option.value}</span>
                    <span className="mt-1 block truncate text-[10px] font-black text-slate-600">{option.label}</span>
                  </button>
                ))}
              </div>
            </section>

            <section className="rounded-[26px] border border-white/10 bg-white/10 p-4 backdrop-blur sm:p-5">
              <div className="mb-4 flex items-center justify-between gap-3">
                <div>
                  <p className="text-xs font-black text-cyan-600">02 / الهوية البصرية</p>
                  <h3 className="mt-1 text-lg font-black text-slate-900">اختر لون الطاقة</h3>
                </div>
                <span className="rounded-xl bg-cyan-100 px-2.5 py-1 text-xs font-black text-cyan-700">{STUDENT_COLOR_OPTIONS.length} ألوان</span>
              </div>
              <div className="grid grid-cols-2 gap-2 sm:grid-cols-5">
                {STUDENT_COLOR_OPTIONS.map(option => (
                  <button
                    key={option.value}
                    type="button"
                    onClick={() => choose({ color: option.value })}
                    className={`flex items-center gap-2 rounded-2xl border p-2 text-right transition-all hover:-translate-y-1 ${
                      appearance.color === option.value ? 'border-cyan-500 bg-cyan-50 shadow-lg shadow-cyan-100' : 'border-slate-200 bg-white hover:border-cyan-300'
                    }`}
                    aria-label={option.label}
                    aria-pressed={appearance.color === option.value}
                  >
                    <span className="h-9 w-9 shrink-0 rounded-xl border-2 border-white shadow-md" style={{ background: option.swatch }} />
                    <span className="truncate text-[10px] font-black text-slate-600">{option.label}</span>
                  </button>
                ))}
              </div>
            </section>

            <section className="rounded-[26px] border border-white/10 bg-white/10 p-4 backdrop-blur sm:p-5">
              <div className="mb-4 flex items-center justify-between gap-3">
                <div>
                  <p className="text-xs font-black text-violet-600">03 / الستايل</p>
                  <h3 className="mt-1 text-lg font-black text-slate-900">أضف الملابس والإكسسوار</h3>
                </div>
                <span className="rounded-xl bg-violet-100 px-2.5 py-1 text-xs font-black text-violet-700">{STUDENT_OUTFIT_OPTIONS.length} خيارات</span>
              </div>
              <div className="grid grid-cols-3 gap-2 sm:grid-cols-4">
                {STUDENT_OUTFIT_OPTIONS.map(option => (
                  <button
                    key={option.value}
                    type="button"
                    onClick={() => choose({ outfit: option.value })}
                    className={`group rounded-2xl border p-3 transition-all hover:-translate-y-1 ${
                      appearance.outfit === option.value
                        ? 'border-violet-400 bg-violet-100 shadow-lg shadow-violet-200'
                        : 'border-slate-200 bg-white hover:border-violet-300 hover:bg-violet-50'
                    }`}
                    aria-label={option.label}
                    aria-pressed={appearance.outfit === option.value}
                  >
                    <span className="block text-3xl transition-transform group-hover:scale-110">{option.value}</span>
                    <span className="mt-1 block truncate text-[10px] font-black text-slate-600">{option.label}</span>
                  </button>
                ))}
              </div>
            </section>

            <div className="flex flex-col gap-3 rounded-[26px] border border-slate-200 bg-white p-4 shadow-sm sm:flex-row sm:items-center sm:justify-between">
              <p className="text-center text-sm font-black text-slate-700 sm:text-right">
                {saved ? 'شخصيتك محفوظة في حسابك 🌟' : 'التغييرات جاهزة — احفظ بطلك الجديد'}
              </p>
              <motion.button
                type="button"
                whileHover={{ scale: saved ? 1 : 1.03 }}
                whileTap={{ scale: saved ? 1 : 0.96 }}
                onClick={saveAppearance}
                disabled={saved}
                className={`w-full rounded-2xl px-7 py-3.5 text-base font-black shadow-lg transition-all sm:w-auto ${
                  saved
                    ? 'cursor-not-allowed bg-emerald-100 text-emerald-700'
                    : 'cursor-pointer bg-gradient-to-r from-rose-500 to-violet-600 text-white shadow-rose-500/25 hover:from-rose-400 hover:to-violet-500'
                }`}
              >
                {saved ? '✅ تم الحفظ' : '💾 حفظ الشخصية'}
              </motion.button>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
};

export default StudentPersonality;