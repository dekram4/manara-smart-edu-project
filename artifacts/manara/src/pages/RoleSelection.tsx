import React, { useState } from 'react';
import { motion } from 'framer-motion';
import { GameAudioEngine } from '../utils/gameAudioEngine';
import ManaraBrand from '../components/ManaraBrand';

interface RoleCard {
  id: 'teacher' | 'parent' | 'admin';
  title: string;
  subtitle: string;
  description: string;
  icon: string;
  palette: { from: string; via: string; to: string };
  glowColor: string;
  accentLight: string;
  tag: string;
  svgIllustration: React.ReactNode;
}

interface RoleSelectionProps {
  onSelectAdmin: () => void;
  onSelectTeacher: () => void;
  onSelectParent: () => void;
}

/* ─── Per-role SVG illustrations ─── */
const TeacherIllustration = () => (
  <svg viewBox="0 0 120 90" fill="none" className="h-full w-full" aria-hidden="true">
    {/* whiteboard */}
    <rect x="16" y="22" width="70" height="46" rx="4" fill="#d1fae5" fillOpacity="0.5" stroke="#34d399" strokeWidth="1.2" strokeOpacity="0.6" />
    <rect x="20" y="26" width="62" height="38" rx="2" fill="#ecfdf5" fillOpacity="0.3" />
    {/* equation on board */}
    <text x="34" y="46" fontSize="10" fill="#065f46" fillOpacity="0.8" fontFamily="monospace" fontWeight="bold">y = mx + b</text>
    <line x1="28" y1="52" x2="72" y2="52" stroke="#34d399" strokeWidth="1" strokeOpacity="0.4" />
    <circle cx="48" cy="58" r="2.5" fill="#34d399" fillOpacity="0.6" />
    <circle cx="60" cy="56" r="2" fill="#6ee7b7" fillOpacity="0.6" />
    <circle cx="68" cy="54" r="2" fill="#a7f3d0" fillOpacity="0.6" />
    {/* teacher pointer */}
    <line x1="92" y1="28" x2="82" y2="42" stroke="#6ee7b7" strokeWidth="2" strokeLinecap="round" />
    <circle cx="93" cy="26" r="3" fill="#34d399" fillOpacity="0.8" />
    {/* board legs */}
    <line x1="28" y1="68" x2="24" y2="78" stroke="#34d399" strokeWidth="1.5" strokeOpacity="0.5" />
    <line x1="78" y1="68" x2="82" y2="78" stroke="#34d399" strokeWidth="1.5" strokeOpacity="0.5" />
    {/* sparkles */}
    <circle cx="105" cy="30" r="2.2" fill="#fbbf24" fillOpacity="0.7" />
    <circle cx="10"  cy="35" r="1.8" fill="#6ee7b7" fillOpacity="0.6" />
    <circle cx="108" cy="70" r="2"   fill="#a7f3d0" fillOpacity="0.6" />
  </svg>
);

const ParentIllustration = () => (
  <svg viewBox="0 0 120 90" fill="none" className="h-full w-full" aria-hidden="true">
    {/* parent figure */}
    <circle cx="38" cy="28" r="10" fill="#fed7aa" fillOpacity="0.7" />
    <rect x="24" y="40" width="28" height="26" rx="6" fill="#fb923c" fillOpacity="0.55" />
    {/* child figure */}
    <circle cx="78" cy="34" r="7" fill="#fde68a" fillOpacity="0.75" />
    <rect x="67" y="43" width="22" height="20" rx="5" fill="#fbbf24" fillOpacity="0.55" />
    {/* connecting heart */}
    <path d="M58 40 C58 36 62 33 64 36 C66 33 70 36 70 40 C70 44 64 49 64 49 C64 49 58 44 58 40Z"
      fill="#f87171" fillOpacity="0.75" />
    {/* stars around */}
    <circle cx="15"  cy="18" r="2.5" fill="#fbbf24" fillOpacity="0.75" />
    <circle cx="105" cy="22" r="2"   fill="#fb923c" fillOpacity="0.7" />
    <circle cx="10"  cy="70" r="1.8" fill="#fde68a" fillOpacity="0.6" />
    <circle cx="108" cy="72" r="2.2" fill="#fbbf24" fillOpacity="0.65" />
    {/* progress bar */}
    <rect x="20" y="76" width="80" height="5" rx="2.5" fill="#fff7ed" fillOpacity="0.35" />
    <rect x="20" y="76" width="56" height="5" rx="2.5" fill="#fb923c" fillOpacity="0.7" />
  </svg>
);

const AdminIllustration = () => (
  <svg viewBox="0 0 120 90" fill="none" className="h-full w-full" aria-hidden="true">
    {/* gear large */}
    <circle cx="55" cy="44" r="18" fill="#e879f9" fillOpacity="0.2" stroke="#e879f9" strokeWidth="1.5" strokeOpacity="0.5" />
    <circle cx="55" cy="44" r="10" fill="#a21caf" fillOpacity="0.5" />
    {/* gear teeth */}
    {[0,45,90,135,180,225,270,315].map((deg, i) => {
      const r = Math.PI * deg / 180;
      const x1 = 55 + 18 * Math.cos(r);
      const y1 = 44 + 18 * Math.sin(r);
      const x2 = 55 + 24 * Math.cos(r);
      const y2 = 44 + 24 * Math.sin(r);
      return <line key={i} x1={x1} y1={y1} x2={x2} y2={y2} stroke="#e879f9" strokeWidth="3.5" strokeLinecap="round" strokeOpacity="0.65" />;
    })}
    {/* small gear */}
    <circle cx="88" cy="26" r="9" fill="#f0abfc" fillOpacity="0.18" stroke="#e879f9" strokeWidth="1" strokeOpacity="0.45" />
    <circle cx="88" cy="26" r="5" fill="#a21caf" fillOpacity="0.45" />
    {[0,60,120,180,240,300].map((deg, i) => {
      const r = Math.PI * deg / 180;
      const x1 = 88 + 9 * Math.cos(r);
      const y1 = 26 + 9 * Math.sin(r);
      const x2 = 88 + 12 * Math.cos(r);
      const y2 = 26 + 12 * Math.sin(r);
      return <line key={i} x1={x1} y1={y1} x2={x2} y2={y2} stroke="#e879f9" strokeWidth="2.5" strokeLinecap="round" strokeOpacity="0.55" />;
    })}
    {/* shield */}
    <path d="M24 20 L36 16 L48 20 L48 34 C48 42 36 48 36 48 C36 48 24 42 24 34 Z"
      fill="#fae8ff" fillOpacity="0.18" stroke="#e879f9" strokeWidth="1.2" strokeOpacity="0.5" />
    <polyline points="29,32 34,38 44,26" stroke="#e879f9" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round" strokeOpacity="0.8" />
    {/* data nodes */}
    <circle cx="20"  cy="70" r="3" fill="#e879f9" fillOpacity="0.6" />
    <circle cx="40"  cy="75" r="2" fill="#f0abfc" fillOpacity="0.6" />
    <circle cx="60"  cy="72" r="2.5" fill="#e879f9" fillOpacity="0.5" />
    <circle cx="100" cy="68" r="2" fill="#f0abfc" fillOpacity="0.5" />
    <line x1="20" y1="70" x2="40" y2="75" stroke="#e879f9" strokeWidth="0.8" strokeOpacity="0.4" />
    <line x1="40" y1="75" x2="60" y2="72" stroke="#e879f9" strokeWidth="0.8" strokeOpacity="0.4" />
  </svg>
);

const roles: RoleCard[] = [
  {
    id: 'teacher',
    title: 'بوابة المعلم',
    subtitle: 'علّم • أدِر • قيّم',
    description: 'فصول ذكية، نشر الدروس، وتقارير الأداء',
    icon: '👨‍🏫',
    palette: { from: '#065f46', via: '#059669', to: '#0d9488' },
    glowColor: 'rgba(16,185,129,0.5)',
    accentLight: '#6ee7b7',
    tag: 'معلم',
    svgIllustration: <TeacherIllustration />,
  },
  {
    id: 'parent',
    title: 'ولي الأمر',
    subtitle: 'تابع • راقب • ادعم',
    description: 'متابعة مستوى أبنائك والتقارير الأكاديمية',
    icon: '👨‍👩‍👧',
    palette: { from: '#92400e', via: '#d97706', to: '#ea580c' },
    glowColor: 'rgba(251,146,60,0.5)',
    accentLight: '#fde68a',
    tag: 'ولي أمر',
    svgIllustration: <ParentIllustration />,
  },
  {
    id: 'admin',
    title: 'لوحة المشرف',
    subtitle: 'أدِر • تحكّم • أشرف',
    description: 'إدارة شاملة للمنصة والعمليات الأكاديمية',
    icon: '⚙️',
    palette: { from: '#701a75', via: '#9333ea', to: '#c026d3' },
    glowColor: 'rgba(192,38,211,0.5)',
    accentLight: '#f0abfc',
    tag: 'مشرف',
    svgIllustration: <AdminIllustration />,
  },
];

interface FloatingLearningObjectProps {
  icon: string;
  label: string;
  color: string;
  left: string;
  top: string;
  delay: number;
  duration: number;
  size?: 'sm' | 'md' | 'lg';
  hiddenOnMobile?: boolean;
}

const FloatingLearningObject: React.FC<FloatingLearningObjectProps> = ({
  icon,
  label,
  color,
  left,
  top,
  delay,
  duration,
  size = 'md',
  hiddenOnMobile = false,
}) => {
  const dimensions = {
    sm: { shell: 'h-14 w-14', icon: 'text-2xl', orbit: 'inset-[-7px]', label: 'text-[9px]' },
    md: { shell: 'h-[72px] w-[72px]', icon: 'text-3xl', orbit: 'inset-[-9px]', label: 'text-[10px]' },
    lg: { shell: 'h-20 w-20', icon: 'text-4xl', orbit: 'inset-[-10px]', label: 'text-[11px]' },
  }[size];

  return (
    <motion.div
      className={`pointer-events-auto absolute z-[2] ${hiddenOnMobile ? 'hidden sm:block' : ''}`}
      style={{ left, top }}
      initial={{ opacity: 0, scale: 0.65 }}
      animate={{
        opacity: [0.55, 0.9, 0.55],
        y: [0, -18, 0],
        x: [0, 7, 0],
        rotate: [-3, 4, -3],
        scale: [1, 1.06, 1],
      }}
      transition={{
        duration,
        delay,
        repeat: Infinity,
        ease: 'easeInOut',
      }}
      whileHover={{ scale: 1.16, opacity: 1, zIndex: 20 }}
    >
      <div className="relative flex flex-col items-center">
        {/* orbital rings give the emoji a crafted, educational-tech look */}
        <motion.div
          className={`pointer-events-none absolute ${dimensions.orbit} rounded-full border border-dashed`}
          style={{
            borderColor: `${color}70`,
            boxShadow: `0 0 18px ${color}35`,
          }}
          animate={{ rotate: 360 }}
          transition={{ duration: duration * 1.8, repeat: Infinity, ease: 'linear' }}
        />
        <motion.div
          className={`pointer-events-none absolute ${dimensions.orbit} rounded-full border`}
          style={{
            borderColor: `${color}25`,
            transform: 'rotate(58deg) scaleX(0.55)',
          }}
          animate={{ rotate: [58, 418] }}
          transition={{ duration: duration * 2.2, repeat: Infinity, ease: 'linear' }}
        />

        {/* glass emoji badge */}
        <div
          className={`${dimensions.shell} flex items-center justify-center rounded-[22px] border backdrop-blur-xl`}
          style={{
            background: `linear-gradient(145deg, ${color}32, rgba(15,23,42,0.76))`,
            borderColor: `${color}65`,
            boxShadow: `0 10px 28px rgba(0,0,0,0.3), 0 0 30px ${color}25, inset 0 1px 0 rgba(255,255,255,0.18)`,
          }}
        >
          <motion.span
            aria-hidden="true"
            className={`${dimensions.icon} select-none drop-shadow-[0_0_10px_rgba(255,255,255,0.45)]`}
            animate={{ rotate: [-5, 5, -5], scale: [1, 1.1, 1] }}
            transition={{ duration: duration * 0.7, repeat: Infinity, ease: 'easeInOut', delay: delay + 0.2 }}
            whileHover={{ rotate: 12, scale: 1.24 }}
          >
            {icon}
          </motion.span>
        </div>

        {/* small professional label */}
        <span
          className={`mt-2 rounded-full border px-2 py-0.5 font-bold tracking-wide text-white/70 backdrop-blur-md ${dimensions.label}`}
          style={{
            background: `${color}18`,
            borderColor: `${color}35`,
          }}
        >
          {label}
        </span>
      </div>
    </motion.div>
  );
};

const RoleSelection: React.FC<RoleSelectionProps> = (props) => {
  const [hoveredId, setHoveredId] = useState<string | null>(null);

  const handlers: Record<RoleCard['id'], () => void> = {
    teacher: props.onSelectTeacher,
    parent: props.onSelectParent,
    admin: props.onSelectAdmin,
  };

  return (
    <div
      className="role-selection-shell relative flex min-h-screen w-full select-none flex-col items-center justify-center overflow-hidden p-5 font-tajawal"
      dir="rtl"
    >
      {/* ─── Rich gradient background ─── */}
      <div className="pointer-events-none absolute inset-0">
        <div className="absolute inset-0 bg-[linear-gradient(145deg,_#04041a_0%,_#0d0b33_40%,_#0a1628_70%,_#03051a_100%)]" />
        {/* animated nebula orbs */}
        <div className="absolute -left-32 top-0 h-[42vw] w-[42vw] max-h-[520px] max-w-[520px] animate-pulse rounded-full bg-indigo-600/18 blur-[80px]" />
        <div className="absolute -right-24 bottom-0 h-[38vw] w-[38vw] max-h-[480px] max-w-[480px] animate-pulse rounded-full bg-purple-600/15 blur-[80px]" style={{ animationDelay: '1.2s' }} />
        <div className="absolute left-1/2 top-1/4 h-[26vw] w-[26vw] max-h-[320px] max-w-[320px] -translate-x-1/2 animate-pulse rounded-full bg-cyan-500/8 blur-[60px]" style={{ animationDelay: '2.4s' }} />
        {/* grid overlay */}
        <div
          className="absolute inset-0 opacity-[0.07]"
          style={{
            backgroundImage:
              'linear-gradient(rgba(148,163,184,0.5) 1px, transparent 1px), linear-gradient(90deg, rgba(148,163,184,0.5) 1px, transparent 1px)',
            backgroundSize: '52px 52px',
          }}
        />
        {/* top-centre radial highlight */}
        <div className="absolute inset-x-0 top-0 h-80 bg-[radial-gradient(ellipse_70%_60%_at_50%_0%,rgba(129,140,248,0.2),transparent)]" />
        {/* Floating educational objects: each has its own orbit, glow, motion and label. */}
        <FloatingLearningObject icon="📚" label="القراءة" color="#818cf8" left="4%" top="17%" delay={0} duration={6.4} size="lg" hiddenOnMobile />
        <FloatingLearningObject icon="✏️" label="الإبداع" color="#fbbf24" left="89%" top="14%" delay={0.7} duration={5.8} size="md" hiddenOnMobile />
        <FloatingLearningObject icon="🔬" label="العلوم" color="#2dd4bf" left="7%" top="73%" delay={1.3} duration={6.8} size="md" hiddenOnMobile />
        <FloatingLearningObject icon="🌍" label="اكتشف العالم" color="#38bdf8" left="87%" top="70%" delay={1.9} duration={7.2} size="lg" hiddenOnMobile />
        <FloatingLearningObject icon="🧮" label="الرياضيات" color="#f472b6" left="18%" top="5%" delay={0.4} duration={6.1} size="sm" hiddenOnMobile />
        <FloatingLearningObject icon="🎨" label="الفن" color="#c084fc" left="76%" top="5%" delay={1.1} duration={5.4} size="sm" hiddenOnMobile />
        <FloatingLearningObject icon="⭐" label="إنجاز" color="#facc15" left="45%" top="88%" delay={2.1} duration={5.9} size="sm" />
      </div>

      {/* ─── Header ─── */}
      <motion.div
        initial={{ opacity: 0, y: -28 }}
        animate={{ opacity: 1, y: 0 }}
        transition={{ duration: 0.7, ease: 'easeOut' }}
         className="role-selection-header relative z-10 mb-8 text-center sm:mb-10"
      >
        <ManaraBrand variant="hero" className="text-white" />
        <p className="mt-2 text-base font-medium text-slate-400">
          اختر بوابتك وابدأ رحلتك التعليمية الذكية ✨
        </p>
      </motion.div>

      {/* ─── Role cards grid ─── */}
       <div className="role-selection-grid relative z-10 grid w-full max-w-6xl grid-cols-1 gap-5 sm:grid-cols-2 sm:gap-6 xl:grid-cols-3">
        {roles.map((role, index) => {
          const isHovered = hoveredId === role.id;
          return (
            <motion.button
              key={role.id}
              type="button"
              initial={{ opacity: 0, y: 44, scale: 0.93 }}
              animate={{ opacity: 1, y: 0, scale: 1 }}
              transition={{ duration: 0.55, delay: index * 0.12, type: 'spring', stiffness: 200, damping: 22 }}
              whileHover={{ scale: 1.025, y: -6 }}
              whileTap={{ scale: 0.97 }}
              onMouseEnter={() => { setHoveredId(role.id); GameAudioEngine.play('uiHover'); }}
              onMouseLeave={() => setHoveredId(null)}
              onClick={() => { GameAudioEngine.play('uiSelect'); handlers[role.id](); }}
                className="role-selection-card group relative min-h-48 overflow-hidden text-right sm:min-h-56"
              style={{
                 borderRadius: '30px',
                 border: `1px solid rgba(255,255,255,${isHovered ? 0.24 : 0.11})`,
                 transition: 'border-color 0.3s, box-shadow 0.3s, transform 0.3s',
                boxShadow: isHovered
                   ? `0 0 0 1px ${role.glowColor}, 0 24px 72px ${role.glowColor}, 0 12px 30px rgba(0,0,0,0.52), inset 0 1px 0 rgba(255,255,255,0.2)`
                   : '0 14px 38px rgba(0,0,0,0.42), inset 0 1px 0 rgba(255,255,255,0.1)',
              }}
            >
              {/* Card background */}
              <div
                className="absolute inset-0"
                style={{
                  background: `
                    linear-gradient(145deg, ${role.palette.from}28 0%, ${role.palette.via}18 50%, ${role.palette.to}12 100%),
                    linear-gradient(180deg, rgba(15,15,35,0.92) 0%, rgba(8,8,24,0.96) 100%)
                  `,
                  borderRadius: 'inherit',
                }}
              />

               {/* Deep color wash for the game-like card surface */}
               <div
                 className="pointer-events-none absolute inset-0 opacity-70"
                 style={{
                   background: `radial-gradient(circle at 85% 35%, ${role.palette.via}38, transparent 42%), radial-gradient(circle at 15% 100%, ${role.palette.to}20, transparent 48%)`,
                 }}
               />

               {/* SVG illustration — large atmospheric art behind the role icon */}
              <div
                  className="pointer-events-none absolute -right-2 top-1/2 h-44 w-52 -translate-y-1/2 scale-125 origin-center opacity-25 transition-all duration-500 group-hover:scale-[1.38] group-hover:opacity-55 sm:h-48 sm:w-60"
              >
                {role.svgIllustration}
              </div>

               {/* Decorative game HUD corner brackets */}
               <div
                 className="pointer-events-none absolute right-4 top-4 h-5 w-5 border-r-2 border-t-2 opacity-50"
                 style={{ borderColor: role.accentLight }}
               />
               <div
                 className="pointer-events-none absolute bottom-4 left-4 h-5 w-5 border-b-2 border-l-2 opacity-35"
                 style={{ borderColor: role.accentLight }}
               />

              {/* Shimmer sweep on hover */}
              <div
                className="pointer-events-none absolute inset-0 rounded-[inherit] opacity-0 transition-opacity duration-300 group-hover:opacity-100"
                style={{
                  background: `linear-gradient(105deg, transparent 38%, ${role.accentLight}18 52%, transparent 66%)`,
                  backgroundSize: '200% 100%',
                  animation: isHovered ? 'shimmerSweepRole 2.8s ease-in-out infinite' : 'none',
                }}
              />

              {/* Top edge accent line */}
              <div
                className="pointer-events-none absolute inset-x-0 top-0 h-px rounded-full transition-opacity duration-300 group-hover:opacity-100"
                style={{
                  background: `linear-gradient(90deg, transparent, ${role.accentLight}90, transparent)`,
                  opacity: isHovered ? 1 : 0.35,
                }}
              />

              {/* Corner glow */}
              <div
                className="pointer-events-none absolute -right-8 -top-8 h-28 w-28 rounded-full blur-2xl transition-opacity duration-400"
                style={{
                  background: `radial-gradient(circle, ${role.palette.via}55, transparent)`,
                  opacity: isHovered ? 1 : 0.35,
                }}
              />

               {/* Card content: large focal icon + readable mission copy */}
               <div className="relative z-10 flex h-full items-center gap-4 p-5 sm:gap-6 sm:p-6">
                 {/* Role icon badge */}
                <div
                   className="relative flex h-28 w-28 shrink-0 items-center justify-center rounded-[30px] text-[4.7rem] shadow-2xl transition-transform duration-300 group-hover:scale-110 group-hover:rotate-[-4deg] sm:h-32 sm:w-32 sm:text-[5.5rem]"
                  style={{
                     background: `linear-gradient(145deg, ${role.palette.from}f2, ${role.palette.via}e8 52%, ${role.palette.to}f5)`,
                     border: `2px solid ${role.accentLight}55`,
                     boxShadow: `0 14px 34px ${role.glowColor}, 0 0 0 7px ${role.palette.via}12, inset 0 2px 0 rgba(255,255,255,0.28), inset 0 -12px 24px rgba(0,0,0,0.2)`,
                  }}
                >
                   <div
                     className="pointer-events-none absolute inset-2 rounded-[24px] border border-white/20"
                     style={{ boxShadow: `inset 0 0 22px ${role.accentLight}20` }}
                   />
                   <div
                     className="pointer-events-none absolute -inset-3 rounded-[36px] opacity-60 blur-xl transition-opacity duration-300 group-hover:opacity-100"
                     style={{ background: role.glowColor }}
                   />
                  <motion.span
                    aria-hidden="true"
                     className="relative z-10 select-none drop-shadow-[0_8px_8px_rgba(0,0,0,0.42)]"
                    animate={
                      isHovered
                        ? { y: [0, -5, 0], rotate: [-7, 7, -3, 0], scale: [1, 1.14, 1.05, 1] }
                        : { y: [0, -2, 0], rotate: [-2, 2, -2] }
                    }
                    transition={{
                      duration: isHovered ? 0.75 : 3.4,
                      repeat: Infinity,
                      ease: 'easeInOut',
                    }}
                  >
                    {role.icon}
                  </motion.span>
                </div>

                {/* Text block */}
                <div className="min-w-0 flex-1">
                  {/* Tag pill */}
                  <span
                     className="mb-2 inline-flex items-center gap-1.5 rounded-full px-3 py-1 text-[11px] font-black uppercase tracking-widest shadow-lg"
                    style={{
                       background: `${role.palette.via}38`,
                      color: role.accentLight,
                       border: `1px solid ${role.accentLight}45`,
                    }}
                  >
                     <span className="h-1.5 w-1.5 rounded-full bg-current shadow-[0_0_8px_currentColor]" />
                    {role.tag}
                  </span>
                   <h3 className="text-[1.45rem] font-black leading-tight text-white drop-shadow-md transition-colors sm:text-[1.65rem] group-hover:text-white">
                    {role.title}
                  </h3>
                  <p
                     className="mt-1 text-xs font-black tracking-wide sm:text-sm"
                    style={{ color: role.accentLight }}
                  >
                    {role.subtitle}
                  </p>
                    <p className="mt-2 max-w-xs text-[13px] font-medium leading-relaxed text-slate-400 transition-colors group-hover:text-slate-200 sm:text-sm">
                    {role.description}
                  </p>
                </div>

                {/* Arrow indicator */}
                <motion.div
                  animate={isHovered ? { x: -4, scale: 1.15 } : { x: 0, scale: 1 }}
                  transition={{ duration: 0.25 }}
                   className="flex h-11 w-11 shrink-0 items-center justify-center rounded-2xl text-xl font-black transition-all duration-300"
                  style={{
                    background: isHovered ? role.palette.via : 'rgba(255,255,255,0.06)',
                    color: isHovered ? '#fff' : 'rgba(255,255,255,0.4)',
                    border: `1px solid ${isHovered ? role.accentLight + '50' : 'rgba(255,255,255,0.08)'}`,
                    boxShadow: isHovered ? `0 0 18px ${role.glowColor}` : 'none',
                  }}
                >
                  ←
                </motion.div>
              </div>
            </motion.button>
          );
        })}
      </div>

      {/* ─── Bottom tagline ─── */}
      <motion.p
        initial={{ opacity: 0 }}
        animate={{ opacity: 1 }}
        transition={{ delay: 0.9 }}
        className="relative z-10 mt-8 text-sm text-slate-600"
      >
        منصة التعليم الذكي · التعلّم في كل مكان وزمان
      </motion.p>

      {/* ─── Global keyframes ─── */}
      <style>{`
        @keyframes floatIcon {
          0%, 100% { transform: translateY(0px) rotate(0deg); }
          50%       { transform: translateY(-14px) rotate(4deg); }
        }
        @keyframes shimmerSweepRole {
          0%   { background-position: -200% 0; }
          60%  { background-position:  200% 0; }
          100% { background-position:  200% 0; }
        }
      `}</style>
    </div>
  );
};

export default RoleSelection;
