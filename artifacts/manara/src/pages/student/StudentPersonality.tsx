import React, { useCallback, useState } from 'react';
import { StudentAppearance, StudentInfo } from '../../types';
import { getStudentAppearance } from '../../utils/studentAppearance';
import {
  ReadyPlayerMeCreator,
  ReadyPlayerMeExport,
  ReadyPlayerMeViewer,
} from './components/ReadyPlayerMeAvatar';

interface StudentPersonalityProps {
  student: StudentInfo;
  onSave: (appearance: StudentAppearance) => void;
}

const StudentPersonality: React.FC<StudentPersonalityProps> = ({ student, onSave }) => {
  const [appearance, setAppearance] = useState<StudentAppearance>(() => getStudentAppearance(student));
  const [saved, setSaved] = useState(Boolean(appearance.readyPlayerMeAvatarUrl));

  const handleAvatarExport = useCallback((avatar: ReadyPlayerMeExport) => {
    setAppearance(current => ({ ...current, ...avatar }));
    setSaved(true);
    onSave({ ...appearance, ...avatar });
  }, [appearance, onSave]);

  return (
    <div className="relative min-w-0 overflow-hidden rounded-[38px] border border-cyan-200 bg-[#f7fbff] p-2.5 shadow-[0_30px_90px_-28px_rgba(15,23,42,0.75)] sm:p-5 md:p-7">
      <div className="pointer-events-none absolute -right-24 -top-28 h-72 w-72 rounded-full bg-cyan-200/60 blur-3xl" />
      <div className="pointer-events-none absolute -bottom-28 -left-24 h-72 w-72 rounded-full bg-indigo-200/60 blur-3xl" />

      <div className="relative z-10 overflow-hidden rounded-[30px] bg-gradient-to-l from-[#102a43] via-[#153e75] to-[#164e63] p-4 text-white shadow-2xl sm:p-7">
        <div className="flex flex-col justify-between gap-4 md:flex-row md:items-center">
          <div className="min-w-0">
            <div className="mb-3 inline-flex items-center gap-2 rounded-full border border-white/15 bg-white/10 px-3 py-1.5 text-xs font-black text-cyan-100 backdrop-blur">
              استوديو الأفاتار الكامل
            </div>
            <h2 className="text-2xl font-black tracking-tight sm:text-4xl">صمّم شخصيتك من الرأس إلى القدمين</h2>
            <p className="mt-2 max-w-2xl text-sm font-bold leading-7 text-cyan-100">
              خصّص الملامح، الشعر، الملابس، البنطال والأحذية داخل محرر Ready Player Me ثم احفظ الأفاتار في ملفك.
            </p>
          </div>
          <div className="flex shrink-0 items-center gap-2 self-start rounded-2xl border border-white/10 bg-white/10 px-3 py-2 text-xs font-black text-cyan-100 md:self-auto">
            <span className={`h-2.5 w-2.5 rounded-full ${saved ? 'bg-emerald-300' : 'animate-pulse bg-amber-300'}`} />
            {saved ? 'الأفاتار محفوظ في الحساب' : 'لم يتم حفظ أفاتار بعد'}
          </div>
        </div>

        <div className="mt-5 grid min-w-0 gap-5 lg:grid-cols-[minmax(300px,0.8fr)_minmax(0,1.35fr)]">
          <section className="min-w-0 rounded-[28px] border border-white/15 bg-slate-950/55 p-3 shadow-inner sm:p-4">
            <div className="mb-3 flex items-center justify-between gap-3">
              <div>
                <p className="text-xs font-black text-cyan-200">المعاينة النهائية</p>
                <p className="mt-1 text-sm font-black text-white">{student.name || 'ملف الطالب'}</p>
              </div>
              <span className="rounded-full bg-emerald-400/15 px-2.5 py-1 text-[10px] font-black text-emerald-200">
                Full Body
              </span>
            </div>
            <ReadyPlayerMeViewer
              url={appearance.readyPlayerMeAvatarUrl}
              imageUrl={appearance.readyPlayerMeAvatarImageUrl}
            />
            {appearance.readyPlayerMeAvatarId && (
              <p className="mt-3 truncate text-center text-[10px] font-bold text-slate-400">
                Avatar ID: {appearance.readyPlayerMeAvatarId}
              </p>
            )}
          </section>

          <section className="min-w-0">
            <ReadyPlayerMeCreator
              initialAppearance={appearance}
              onExport={handleAvatarExport}
              onLocalSave={(nextAppearance) => {
                setAppearance(nextAppearance);
                setSaved(true);
                onSave(nextAppearance);
              }}
            />
          </section>
        </div>
      </div>
    </div>
  );
};

export default StudentPersonality;