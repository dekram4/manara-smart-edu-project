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

  return (
    <div className="relative overflow-hidden rounded-[36px] border border-fuchsia-300/20 bg-gradient-to-br from-slate-900/95 via-indigo-950/90 to-fuchsia-950/85 p-5 shadow-2xl md:p-8">
      <div className="pointer-events-none absolute -right-24 -top-24 h-64 w-64 rounded-full bg-fuchsia-500/20 blur-3xl" />
      <div className="pointer-events-none absolute -bottom-24 -left-24 h-64 w-64 rounded-full bg-cyan-500/20 blur-3xl" />

      <div className="relative z-10 mb-8 flex flex-col items-center justify-between gap-5 text-center sm:flex-row sm:text-right">
        <div>
          <div className="mb-2 inline-flex items-center gap-2 rounded-full bg-fuchsia-400/15 px-3 py-1 text-xs font-black text-fuchsia-200">
            <span>✨</span> مساحة الإبداع
          </div>
          <h2 className="text-3xl font-black text-white md:text-4xl">صمّم شخصيتك يا بطل!</h2>
          <p className="mt-2 font-bold text-slate-300">اختر شكلك ولونك ولبسك، واجعل إيموجيك يشبهك.</p>
        </div>
        <div className="rounded-3xl border border-white/10 bg-white/10 px-6 py-4 text-center backdrop-blur-md">
          <StudentAvatar appearance={appearance} size="lg" />
          <p className="mt-2 text-xs font-black text-fuchsia-100">{saved ? 'شخصيتك محفوظة ✅' : 'معاينة قبل الحفظ'}</p>
        </div>
      </div>

      <div className="relative z-10 space-y-7">
        <section>
          <h3 className="mb-3 text-lg font-black text-white">1. اختر شكل الشخصية</h3>
          <div className="grid grid-cols-3 gap-2 sm:grid-cols-6">
            {STUDENT_SHAPE_OPTIONS.map(option => (
              <button
                key={option.value}
                type="button"
                onClick={() => choose({ shape: option.value })}
                className={`rounded-2xl border p-3 transition-all hover:-translate-y-1 ${
                  appearance.shape === option.value
                    ? 'border-fuchsia-300 bg-fuchsia-400/25 shadow-lg shadow-fuchsia-500/20'
                    : 'border-white/10 bg-white/5 hover:border-fuchsia-300/50'
                }`}
                aria-label={option.label}
              >
                <span className="block text-4xl">{option.value}</span>
                <span className="mt-1 block truncate text-[10px] font-bold text-slate-300">{option.label}</span>
              </button>
            ))}
          </div>
        </section>

        <section>
          <h3 className="mb-3 text-lg font-black text-white">2. اختر لونك المميز</h3>
          <div className="grid grid-cols-3 gap-2 sm:grid-cols-6">
            {STUDENT_COLOR_OPTIONS.map(option => (
              <button
                key={option.value}
                type="button"
                onClick={() => choose({ color: option.value })}
                className={`rounded-2xl border p-2 transition-all hover:-translate-y-1 ${
                  appearance.color === option.value ? 'border-white bg-white/20 shadow-lg' : 'border-white/10 bg-white/5'
                }`}
                aria-label={option.label}
              >
                <span className="mx-auto block h-12 w-12 rounded-full border-4 border-white/70" style={{ background: option.swatch }} />
                <span className="mt-1 block truncate text-[10px] font-bold text-slate-300">{option.label}</span>
              </button>
            ))}
          </div>
        </section>

        <section>
          <h3 className="mb-3 text-lg font-black text-white">3. اختر لبسك</h3>
          <div className="grid grid-cols-3 gap-2 sm:grid-cols-6">
            {STUDENT_OUTFIT_OPTIONS.map(option => (
              <button
                key={option.value}
                type="button"
                onClick={() => choose({ outfit: option.value })}
                className={`rounded-2xl border p-3 transition-all hover:-translate-y-1 ${
                  appearance.outfit === option.value
                    ? 'border-cyan-300 bg-cyan-400/20 shadow-lg shadow-cyan-500/20'
                    : 'border-white/10 bg-white/5 hover:border-cyan-300/50'
                }`}
                aria-label={option.label}
              >
                <span className="block text-4xl">{option.value}</span>
                <span className="mt-1 block truncate text-[10px] font-bold text-slate-300">{option.label}</span>
              </button>
            ))}
          </div>
        </section>

        <div className="flex flex-col items-center gap-3 rounded-2xl border border-white/10 bg-white/5 p-4 sm:flex-row sm:justify-between">
          <p className="text-center text-sm font-black text-slate-200 sm:text-right">
            {saved ? 'شخصيتك محفوظة في حسابك 🌟' : 'اختياراتك جاهزة! اضغط حفظ لتثبيتها'}
          </p>
          <motion.button
            type="button"
            whileHover={{ scale: saved ? 1 : 1.03 }}
            whileTap={{ scale: saved ? 1 : 0.96 }}
            onClick={saveAppearance}
            disabled={saved}
            className={`w-full rounded-2xl px-6 py-3 text-base font-black shadow-lg transition-all sm:w-auto ${
              saved
                ? 'cursor-not-allowed bg-emerald-400/20 text-emerald-200'
                : 'cursor-pointer bg-gradient-to-r from-fuchsia-400 to-purple-500 text-white shadow-fuchsia-500/25 hover:from-fuchsia-300 hover:to-purple-400'
            }`}
          >
            {saved ? '✅ تم الحفظ' : '💾 حفظ شخصيتي'}
          </motion.button>
        </div>
      </div>
    </div>
  );
};

export default StudentPersonality;