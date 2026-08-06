import React from 'react';
import { motion } from 'framer-motion';
import { playLamsaSound } from '../utils/sounds';
import Interactive3DBackground from '../components/effects/Interactive3DBackground';
import Educational3DViewer from '../components/effects/Educational3DViewer';
import EducationalCardEffects from '../components/effects/EducationalCardEffects';

interface RoleCard {
  id: 'student' | 'teacher' | 'parent' | 'admin';
  title: string;
  subtitle: string;
  icon: string;
  gradient: string;
  shadowColor: string;
}

interface RoleSelectionProps {
  onSelectAdmin: () => void;
  onSelectTeacher: () => void;
  onSelectStudent: () => void;
  onSelectParent: () => void;
}

const roles: RoleCard[] = [
  {
    id: 'student',
    title: 'بوابة الطالب',
    subtitle: 'متابعة الدروس، الواجبات، وشارات التفوق',
    icon: '👨‍🎓',
    gradient: 'from-blue-600 via-indigo-600 to-purple-600',
    shadowColor: 'shadow-blue-500/25',
  },
  {
    id: 'teacher',
    title: 'بوابة المعلم',
    subtitle: 'إدارة الفصول، نشر الدروس، والتقييم الذكي',
    icon: '👨‍🏫',
    gradient: 'from-emerald-600 via-teal-600 to-cyan-600',
    shadowColor: 'shadow-emerald-500/25',
  },
  {
    id: 'parent',
    title: 'ولي الأمر',
    subtitle: 'متابعة مستوى الأبناء والتقارير الأكاديمية',
    icon: '👨‍👩‍👧‍👦',
    gradient: 'from-amber-500 via-orange-600 to-red-600',
    shadowColor: 'shadow-orange-500/25',
  },
  {
    id: 'admin',
    title: 'لوحة المشرف',
    subtitle: 'إدارة النظام الشاملة والعمليات الأكاديمية',
    icon: '⚙️',
    gradient: 'from-purple-600 via-pink-600 to-rose-600',
    shadowColor: 'shadow-purple-500/25',
  },
];

const RoleSelection: React.FC<RoleSelectionProps> = (props) => {
  const handlers: Record<RoleCard['id'], () => void> = {
    student: props.onSelectStudent,
    teacher: props.onSelectTeacher,
    parent: props.onSelectParent,
    admin: props.onSelectAdmin,
  };

  return (
    <div
      className="relative flex min-h-screen w-full select-none flex-col items-center justify-center overflow-hidden p-6 font-tajawal"
      dir="rtl"
    >
      <Interactive3DBackground />

      <motion.div
        initial={{ opacity: 0, y: -30 }}
        animate={{ opacity: 1, y: 0 }}
        transition={{ duration: 0.8 }}
        className="z-10 mb-12 text-center"
      >
        <motion.div
          whileHover={{ rotate: 10, scale: 1.1 }}
          className="mb-4 inline-block rounded-3xl border border-white/20 bg-white/10 p-4 shadow-2xl backdrop-blur-xl"
        >
          <span className="text-5xl">🏛️</span>
        </motion.div>
        <h1 className="bg-gradient-to-r from-indigo-200 via-purple-200 to-pink-200 bg-clip-text text-4xl font-black text-transparent md:text-5xl">
          منصة التعليم الذكي
        </h1>
        <p className="mt-3 text-lg font-medium text-slate-400">
          اختر بوابتك المخصصة للدخول إلى المنصة
        </p>
      </motion.div>

      <div className="pointer-events-none absolute left-1/2 top-16 z-[1] hidden h-28 w-44 -translate-x-1/2 opacity-75 md:block">
        <Educational3DViewer className="h-28" fallbackEmoji="📖" />
      </div>

      <div className="z-10 grid w-full max-w-4xl grid-cols-1 gap-6 md:grid-cols-2">
        {roles.map((role, index) => (
          <motion.button
            key={role.id}
            type="button"
            initial={{ opacity: 0, y: 40 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ duration: 0.6, delay: index * 0.15 }}
            whileHover={{
              scale: 1.03,
              rotateX: 5,
              rotateY: -5,
              translateZ: 20,
            }}
            whileTap={{ scale: 0.97 }}
            onMouseEnter={() => playLamsaSound('star')}
            onClick={() => {
              playLamsaSound('success');
              handlers[role.id]();
            }}
            className={`group relative overflow-hidden rounded-3xl border border-white/15 bg-slate-900/60 p-6 text-right shadow-xl backdrop-blur-xl transition-all duration-300 hover:border-white/40 ${role.shadowColor}`}
          >
            <EducationalCardEffects
              accent={role.id === 'student' ? '#60a5fa' : role.id === 'teacher' ? '#2dd4bf' : role.id === 'parent' ? '#fb923c' : '#f472b6'}
              compact
            />
            <div
              className={`pointer-events-none absolute -inset-1 rounded-3xl bg-gradient-to-r ${role.gradient} opacity-0 blur-xl transition-opacity duration-500 group-hover:opacity-20`}
            />

            <div className="relative z-10 flex items-center gap-5">
              <div
                className={`flex h-16 w-16 shrink-0 items-center justify-center rounded-2xl border border-white/20 bg-gradient-to-br text-3xl shadow-lg transition-transform duration-300 group-hover:scale-110 ${role.gradient}`}
              >
                {role.icon}
              </div>

              <div className="min-w-0 flex-1">
                <h3 className="text-2xl font-bold text-white transition-colors group-hover:text-indigo-200">
                  {role.title}
                </h3>
                <p className="mt-1 text-sm leading-relaxed text-slate-400">{role.subtitle}</p>
              </div>

              <div className="flex h-10 w-10 shrink-0 items-center justify-center rounded-full border border-white/10 bg-white/5 text-slate-400 transition-all group-hover:translate-x-[-4px] group-hover:bg-white group-hover:text-slate-900">
                ←
              </div>
            </div>
          </motion.button>
        ))}
      </div>
    </div>
  );
};

export default RoleSelection;