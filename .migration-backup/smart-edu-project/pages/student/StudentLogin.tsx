import React, { useState } from 'react';
import { motion } from 'framer-motion';
import { GameAudioEngine } from '../../utils/gameAudioEngine';
import ManaraBrand from '../../src/components/ManaraBrand';

interface StudentLoginProps {
  onLogin: (username: string, password: string) => void;
  onBack?: () => void;
}

/* ─── Floating emoji decoration ─── */
function FloatEmoji({ emoji, delay, x, y }: { emoji: string; delay: number; x: number; y: number }) {
  return (
    <div
      aria-hidden="true"
      className="pointer-events-none absolute select-none text-4xl opacity-30"
      style={{
        left: `${x}%`,
        top: `${y}%`,
        animation: `loginFloat 5.5s ease-in-out infinite`,
        animationDelay: `${delay}s`,
        filter: 'drop-shadow(0 0 10px rgba(251,146,60,0.6))',
      }}
    >
      {emoji}
    </div>
  );
}

/* ─── SVG sparkle star ─── */
function SparkStar({ size, color, x, y, delay }: { size: number; color: string; x: number; y: number; delay: number }) {
  return (
    <svg
      aria-hidden="true"
      className="pointer-events-none absolute"
      style={{ left: `${x}%`, top: `${y}%`, animationDelay: `${delay}s`, opacity: 0.75, animation: `loginSpin ${3 + delay}s linear infinite` }}
      width={size}
      height={size}
      viewBox="0 0 24 24"
      fill={color}
    >
      <path d="M12 2l3.09 6.26L22 9.27l-5 4.87 1.18 6.88L12 17.77l-6.18 3.25L7 14.14 2 9.27l6.91-1.01L12 2z" />
    </svg>
  );
}

const StudentLogin: React.FC<StudentLoginProps> = ({ onLogin, onBack }) => {
  const [username, setUsername] = useState('');
  const [password, setPassword] = useState('');
  const [loginError, setLoginError] = useState('');
  const [isShaking, setIsShaking] = useState(false);
  const [btnHovered, setBtnHovered] = useState(false);

  const emojis = [
    { emoji: '📚', x: 4,  y: 10, delay: 0 },
    { emoji: '🎨', x: 87, y: 14, delay: 0.5 },
    { emoji: '🚀', x: 8,  y: 68, delay: 1 },
    { emoji: '🌟', x: 89, y: 60, delay: 1.5 },
    { emoji: '🎵', x: 74, y: 80, delay: 2 },
    { emoji: '🧮', x: 13, y: 84, delay: 0.8 },
    { emoji: '🌍', x: 79, y: 4,  delay: 1.2 },
    { emoji: '🔬', x: 4,  y: 44, delay: 2.5 },
  ];

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    if (!username.trim() || !password.trim()) {
      GameAudioEngine.play('wrongAnswer');
      setLoginError('يرجى إدخال اسم المستخدم وكلمة المرور');
      setIsShaking(true);
      setTimeout(() => setIsShaking(false), 520);
      return;
    }
    setLoginError('');
    GameAudioEngine.play('loginChime');
    onLogin(username, password);
  };

  return (
    <div className="relative flex min-h-screen items-center justify-center overflow-hidden p-4" dir="rtl">
      {/* ─── Background ─── */}
      <div className="pointer-events-none absolute inset-0">
        {/* warm dark gradient */}
        <div className="absolute inset-0 bg-[linear-gradient(145deg,_#1a0a00_0%,_#2d1000_35%,_#200a14_65%,_#12001c_100%)]" />
        {/* nebula blobs */}
        <div className="absolute -left-16 top-8 h-72 w-72 animate-pulse rounded-full bg-orange-600/20 blur-[70px]" />
        <div className="absolute -right-20 bottom-0 h-80 w-80 animate-pulse rounded-full bg-pink-600/16 blur-[70px]"
          style={{ animationDelay: '1s' }} />
        <div className="absolute left-1/2 top-1/3 h-48 w-48 -translate-x-1/2 animate-pulse rounded-full bg-amber-400/10 blur-[50px]"
          style={{ animationDelay: '2s' }} />
        {/* top highlight */}
        <div className="absolute inset-x-0 top-0 h-64 bg-[radial-gradient(ellipse_55%_50%_at_50%_0%,_rgba(251,146,60,0.18),_transparent)]" />
        {/* fine grid */}
        <div
          className="absolute inset-0 opacity-[0.055]"
          style={{
            backgroundImage:
              'linear-gradient(rgba(251,146,60,0.5) 1px, transparent 1px), linear-gradient(90deg, rgba(251,146,60,0.5) 1px, transparent 1px)',
            backgroundSize: '48px 48px',
          }}
        />
      </div>

      {/* floating emojis */}
      {emojis.map((e, i) => <FloatEmoji key={i} {...e} />)}

      {/* sparkle stars */}
      <SparkStar size={28} color="#FFE66D" x={91} y={28} delay={0} />
      <SparkStar size={18} color="#FF6B9D" x={7}  y={23} delay={0.7} />
      <SparkStar size={22} color="#4ECDC4" x={87} y={74} delay={1.3} />

      {/* ─── Main login card ─── */}
      <motion.div
        initial={{ opacity: 0, y: 24, scale: 0.95 }}
        animate={{ opacity: 1, y: 0, scale: 1 }}
        transition={{ duration: 0.5, type: 'spring', stiffness: 200, damping: 22 }}
        className="relative z-10 w-full max-w-md"
      >
        {/* Outer glow ring */}
        <div
          className="pointer-events-none absolute -inset-1 rounded-[2.8rem] blur-xl"
          style={{ background: 'radial-gradient(ellipse, rgba(251,146,60,0.3), rgba(236,72,153,0.2), transparent 70%)' }}
        />

        {/* Card */}
        <div
          className={`relative overflow-hidden rounded-[2.5rem] border border-white/10 ${isShaking ? 'animate-loginShake' : ''}`}
          style={{
            background: 'linear-gradient(160deg, rgba(30,12,0,0.97) 0%, rgba(20,6,20,0.97) 100%)',
            backdropFilter: 'blur(24px)',
            boxShadow: '0 32px 80px rgba(0,0,0,0.6), 0 0 0 1px rgba(251,146,60,0.2), inset 0 1px 0 rgba(255,255,255,0.07)',
          }}
        >
          {/* Top aurora decoration */}
          <div
            className="pointer-events-none absolute inset-x-0 top-0 h-40"
            style={{
              background: 'linear-gradient(180deg, rgba(251,146,60,0.16) 0%, rgba(236,72,153,0.10) 40%, transparent 100%)',
            }}
          />
          {/* Top edge line */}
          <div className="pointer-events-none absolute inset-x-0 top-0 h-px bg-[linear-gradient(90deg,transparent,rgba(251,146,60,0.7),rgba(236,72,153,0.5),transparent)]" />
          {/* Bottom edge line */}
          <div className="pointer-events-none absolute inset-x-0 bottom-0 h-px bg-[linear-gradient(90deg,transparent,rgba(251,146,60,0.3),transparent)]" />

          {/* Orbiting mascot */}
          <div className="absolute -top-9 left-1/2 -translate-x-1/2 z-20">
            <motion.div
              animate={{ rotate: [-4, 4, -4] }}
              transition={{ duration: 2.2, repeat: Infinity, ease: 'easeInOut' }}
              className="flex h-[72px] w-[72px] items-center justify-center rounded-full text-4xl shadow-2xl"
              style={{
                background: 'linear-gradient(145deg, #f97316, #ec4899)',
                boxShadow: '0 8px 32px rgba(249,115,22,0.55), 0 0 0 3px rgba(255,255,255,0.08)',
              }}
            >
              🎓
            </motion.div>
          </div>

          <div className="px-8 pb-8 pt-14">
            {/* Back button */}
            {onBack && (
              <button
                type="button"
                onClick={onBack}
                className="mb-5 flex items-center gap-2 text-sm font-bold text-slate-400 transition-all hover:translate-x-[-4px] hover:text-orange-400 active:scale-95"
              >
                <span className="text-base">→</span>
                <span>رجوع لاختيار الحساب</span>
              </button>
            )}

            {/* Header */}
            <div className="mb-7 text-center">
              {/* Decorative icon cluster */}
              <ManaraBrand variant="login" className="text-white" />
              <p className="mt-1.5 text-sm font-bold text-orange-400/80">✨ بوابة الطالب · ادخل وابدأ رحلتك</p>
            </div>

            {/* Error */}
            {loginError && (
              <motion.div
                initial={{ opacity: 0, scale: 0.95 }}
                animate={{ opacity: 1, scale: 1 }}
                className="mb-5 rounded-2xl border border-red-500/30 bg-red-500/10 p-3 text-center"
              >
                <p className="text-sm font-bold text-red-400">{loginError}</p>
              </motion.div>
            )}

            {/* Form */}
            <form onSubmit={handleSubmit} className="space-y-4 text-right">
              {/* Username */}
              <div>
                <label className="mb-2 flex items-center justify-end gap-2 text-sm font-bold text-slate-300">
                  <span>اسم المستخدم أو رقم الهوية</span>
                  <span>👤</span>
                </label>
                <input
                  type="text"
                  value={username}
                  onChange={(e) => { setUsername(e.target.value); setLoginError(''); }}
                  placeholder="اكتب اسمك هنا..."
                  className="w-full rounded-2xl border-2 px-5 py-4 text-right text-base font-semibold text-white placeholder-slate-500 outline-none transition-all duration-300"
                  style={{
                    background: 'rgba(255,255,255,0.05)',
                    borderColor: 'rgba(249,115,22,0.3)',
                  }}
                  onFocus={e => { e.currentTarget.style.borderColor = 'rgba(249,115,22,0.7)'; e.currentTarget.style.boxShadow = '0 0 0 4px rgba(249,115,22,0.12)'; }}
                  onBlur={e => { e.currentTarget.style.borderColor = 'rgba(249,115,22,0.3)'; e.currentTarget.style.boxShadow = 'none'; }}
                />
              </div>

              {/* Password */}
              <div>
                <label className="mb-2 flex items-center justify-end gap-2 text-sm font-bold text-slate-300">
                  <span>كلمة المرور</span>
                  <span>🔐</span>
                </label>
                <input
                  type="password"
                  value={password}
                  onChange={(e) => { setPassword(e.target.value); setLoginError(''); }}
                  placeholder="كلمة السر السرية 🤫"
                  className="w-full rounded-2xl border-2 px-5 py-4 text-right text-base font-semibold text-white placeholder-slate-500 outline-none transition-all duration-300"
                  style={{
                    background: 'rgba(255,255,255,0.05)',
                    borderColor: 'rgba(249,115,22,0.3)',
                  }}
                  onFocus={e => { e.currentTarget.style.borderColor = 'rgba(249,115,22,0.7)'; e.currentTarget.style.boxShadow = '0 0 0 4px rgba(249,115,22,0.12)'; }}
                  onBlur={e => { e.currentTarget.style.borderColor = 'rgba(249,115,22,0.3)'; e.currentTarget.style.boxShadow = 'none'; }}
                />
              </div>

              {/* Submit button */}
              <motion.button
                type="submit"
                onHoverStart={() => {
                  setBtnHovered(true);
                  GameAudioEngine.play('uiHover');
                }}
                onHoverEnd={() => setBtnHovered(false)}
                whileTap={{ scale: 0.97 }}
                className="relative mt-2 w-full overflow-hidden rounded-2xl py-4 text-lg font-black text-white"
                style={{
                  background: 'linear-gradient(135deg, #f97316, #ec4899, #8b5cf6)',
                  boxShadow: btnHovered
                    ? '0 0 0 1px rgba(249,115,22,0.5), 0 16px 48px rgba(249,115,22,0.4)'
                    : '0 8px 28px rgba(249,115,22,0.3)',
                  transition: 'box-shadow 0.3s',
                }}
              >
                {/* shimmer on hover */}
                {btnHovered && (
                  <div
                    className="pointer-events-none absolute inset-0"
                    style={{
                      background: 'linear-gradient(105deg, transparent 35%, rgba(255,255,255,0.2) 50%, transparent 65%)',
                      animation: 'shimmerSweepBtn 1.4s ease-in-out infinite',
                    }}
                  />
                )}
                <span className="relative z-10">🚀 ادخل للمغامرة!</span>
              </motion.button>
            </form>

            {/* Mascot + tagline */}
            <div className="mt-6 flex flex-col items-center gap-2">
              <motion.div
                className="text-5xl"
                animate={{ y: [0, -8, 0] }}
                transition={{ duration: 2.8, repeat: Infinity, ease: 'easeInOut' }}
              >
                🦊
              </motion.div>
              <p className="text-xs font-semibold text-slate-500">🌈 تعلّم يلعب... يلعب يتعلّم!</p>
            </div>
          </div>
        </div>
      </motion.div>

      {/* ─── Global keyframes ─── */}
      <style>{`
        @keyframes loginFloat {
          0%, 100% { transform: translateY(0px) rotate(0deg); }
          50%       { transform: translateY(-14px) rotate(5deg); }
        }
        @keyframes loginSpin {
          from { transform: rotate(0deg); }
          to   { transform: rotate(360deg); }
        }
        @keyframes loginShake {
          0%, 100% { transform: translateX(0); }
          20%      { transform: translateX(-10px); }
          40%      { transform: translateX(10px); }
          60%      { transform: translateX(-8px); }
          80%      { transform: translateX(8px); }
        }
        @keyframes shimmerSweepBtn {
          0%   { background-position: -200% 0; }
          100% { background-position:  200% 0; }
        }
        .animate-loginShake { animation: loginShake 0.5s ease-in-out; }
      `}</style>
    </div>
  );
};

export default StudentLogin;
