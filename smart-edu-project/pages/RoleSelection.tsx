import React from 'react';
import { motion } from 'framer-motion';
import { soundPop } from '../App';
import { getStickerAsset } from '../utils/contentAssets';
import PremiumBackground from '../components/PremiumBackground';

interface RoleSelectionProps {
  onSelectAdmin: () => void;
  onSelectTeacher: () => void;
  onSelectStudent: () => void;
  onSelectParent: () => void;
}

const roles = [
  {
    id: 'student',
    title: 'بوابة الأبطال (الطالب)',
    icon: '🎓',
    color: 'from-amber-400 to-orange-500',
    shadow: 'shadow-orange-500/40',
    border: 'border-orange-600',
    desc: 'ألعاب، أوسمة، وتحديات ممتعة!',
    action: 'onSelectStudent',
  },
  {
    id: 'teacher',
    title: 'المعلم الذكي',
    icon: '👨‍🏫',
    color: 'from-blue-500 to-indigo-600',
    shadow: 'shadow-indigo-500/40',
    border: 'border-indigo-700',
    desc: 'إدارة الدروس والاختبارات',
    action: 'onSelectTeacher',
  },
  {
    id: 'parent',
    title: 'ولي الأمر',
    icon: '👨‍👩‍👧',
    color: 'from-emerald-400 to-teal-600',
    shadow: 'shadow-teal-500/40',
    border: 'border-teal-700',
    desc: 'متابعة مستوى الأبطال',
    action: 'onSelectParent',
  },
  {
    id: 'admin',
    title: 'الإدارة والتحكم',
    icon: '⚡',
    color: 'from-purple-500 to-pink-600',
    shadow: 'shadow-pink-500/40',
    border: 'border-pink-700',
    desc: 'إعدادات النظام الشاملة',
    action: 'onSelectAdmin',
  },
];

const RoleSelection: React.FC<RoleSelectionProps> = (props) => {
  return (
    <div className="min-h-screen bg-[linear-gradient(135deg,_#0f172a,_#1e1b4b,_#312e81)] text-white flex flex-col items-center justify-center p-6 relative overflow-hidden font-tajawal">
      <PremiumBackground accent="#38bdf8" />
      <div className="absolute top-10 left-1/2 -translate-x-1/2 w-[32rem] h-[32rem] bg-cyan-500/20 rounded-full blur-3xl pointer-events-none" />
      <div className="absolute bottom-0 right-0 w-[26rem] h-[26rem] bg-fuchsia-500/20 rounded-full blur-3xl pointer-events-none" />

      <div className="absolute bottom-8 left-8 z-10 rounded-3xl border border-white/20 bg-white/10 px-4 py-3 backdrop-blur-lg">
        <p className="text-xs font-black uppercase tracking-[0.3em] text-cyan-200">ملصقات جاهزة</p>
        <div className="mt-2 flex gap-2">
          {['star','trophy','badge','spark'].map((key) => (
            <img key={key} src={getStickerAsset(key)} alt={key} className="h-10 w-10 rounded-2xl border border-white/20 bg-white/80 p-1 shadow" />
          ))}
        </div>
      </div>

      {/* العنوان الرئيسي بأيقونة متحركة */}
      <motion.div initial={{ y: 20, opacity: 0 }} animate={{ y: 0, opacity: 1 }} transition={{ duration: 0.5 }} className="text-center z-10 mb-10">
        <motion.div animate={{ y: [0, -10, 0] }} transition={{ repeat: Infinity, duration: 2.2 }} className="text-7xl inline-block mb-3 filter drop-shadow-lg">
          🚀
        </motion.div>
        <h1 className="text-4xl md:text-5xl font-black bg-gradient-to-r from-yellow-300 via-pink-400 to-cyan-300 bg-clip-text text-transparent">
          منصة المنارة التعليمية
        </h1>
        <p className="text-slate-300 mt-2 text-lg font-bold">اختر بوابتك وابدأ المغامرة!</p>
      </motion.div>

      {/* شبكة البطاقات الكبيرة بخاصية Game Engine UI */}
      <div className="grid grid-cols-1 md:grid-cols-2 gap-6 w-full max-w-4xl z-10 mt-2">
        {roles.map((role, idx) => {
          const handler = props[role.action as keyof RoleSelectionProps];

          return (
            <motion.button
              key={role.id}
              initial={{ y: 24, opacity: 0 }}
              animate={{ y: 0, opacity: 1 }}
              transition={{ delay: idx * 0.08, duration: 0.35 }}
              whileHover={{ scale: 1.04, y: -6, rotate: -0.8, boxShadow: '0 24px 60px rgba(0,0,0,0.28)' }}
              whileTap={{ scale: 0.97, rotate: -0.5 }}
              onClick={() => {
                soundPop.play();
                handler();
              }}
              className={`bg-gradient-to-br ${role.color} p-6 rounded-3xl ${role.shadow} shadow-2xl border-b-8 ${role.border} text-right flex items-center justify-between cursor-pointer transition-all duration-150 relative overflow-hidden group`}
            >
              <div className="z-10">
                <h3 className="text-2xl font-black text-white drop-shadow-sm">{role.title}</h3>
                <p className="text-white font-medium text-sm mt-1">{role.desc}</p>
              </div>

              {/* أيقونة كبيرة بارزة */}
              <span className="text-6xl z-10 filter drop-shadow-md select-none">
                {role.icon}
              </span>
            </motion.button>
          );
        })}
      </div>

    </div>
  );
};

export default RoleSelection;