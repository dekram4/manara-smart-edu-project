import React, { useState, useEffect } from 'react';
import { motion } from 'framer-motion';
import { playSuccessSound, playErrorSound, playLamsaSound } from '../../utils/sounds';
import { InteractiveScene } from '../../components/InteractiveScene';
import Immersive3DScene from '../../components/Immersive3DScene';

interface StudentLoginProps {
  onLogin: (username: string, password: string) => void;
  onBack?: () => void;
}

/* floating decoration */
function FloatEmoji({ emoji, delay, x, y, size = 'text-4xl' }: { emoji: string; delay: number; x: number; y: number; size?: string }) {
  return (
    <div
      className={`absolute ${size} select-none pointer-events-none opacity-40 animate-float`}
      style={{ left: `${x}%`, top: `${y}%`, animationDelay: `${delay}s` }}
    >
      {emoji}
    </div>
  );
}

/* sparkle star */
function Star({ size, color, x, y, delay }: { size: number; color: string; x: number; y: number; delay: number }) {
  return (
    <svg
      className="absolute animate-spin-slow"
      style={{ left: `${x}%`, top: `${y}%`, animationDelay: `${delay}s`, opacity: 0.7 }}
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
  const [btnHover, setBtnHover] = useState(false);

  /* floating emojis config */
  const emojis = [
    { emoji: '📚', x: 5, y: 10, delay: 0 },
    { emoji: '🎨', x: 88, y: 15, delay: 0.5 },
    { emoji: '🚀', x: 10, y: 70, delay: 1 },
    { emoji: '🌟', x: 90, y: 60, delay: 1.5 },
    { emoji: '🎵', x: 75, y: 80, delay: 2 },
    { emoji: '🧮', x: 15, y: 85, delay: 0.8 },
    { emoji: '🌍', x: 80, y: 5, delay: 1.2 },
    { emoji: '🔬', x: 5, y: 45, delay: 2.5 },
  ];

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    if (!username.trim() || !password.trim()) {
      playLamsaSound('error');
      playErrorSound();
      setLoginError('يرجى إدخال اسم المستخدم وكلمة المرور');
      setIsShaking(true);
      setTimeout(() => setIsShaking(false), 500);
      return;
    }
    setLoginError('');
    playLamsaSound('success');
    playSuccessSound();
    onLogin(username, password);
  };

  return (
    <div className="relative flex items-center justify-center min-h-screen p-4 overflow-hidden bg-gradient-to-br from-orange-50 via-rose-50 to-amber-50">
      {/* floating decorations */}
      {emojis.map((e, i) => (
        <FloatEmoji key={i} {...e} />
      ))}
      <Star size={30} color="#FFE66D" x={92} y={30} delay={0} />
      <Star size={20} color="#FF6B9D" x={8} y={25} delay={0.5} />
      <Star size={25} color="#4ECDC4" x={88} y={75} delay={1} />

      {/* main card */}
      <motion.div initial={{ opacity: 0, y: 16 }} animate={{ opacity: 1, y: 0 }} transition={{ duration: 0.45 }} className="relative z-10 w-full max-w-md">
      <InteractiveScene className="relative z-10 w-full max-w-md p-8 animate-bounce-in" intensity={1.1}>
        <Immersive3DScene accent="#ff6b35" intensity={1.15} />
        <div className={`w-full bg-white/90 backdrop-blur-xl rounded-[2.5rem] shadow-2xl border-4 border-orange-200 p-8 ${
          isShaking ? 'animate-shake' : ''
        }`}>
        {/* back button */}
        {onBack && (
          <button
            type="button"
            onClick={onBack}
            className="flex items-center gap-2 text-gray-400 hover:text-orange-500 font-bold mb-4 transition-all hover:-translate-x-1 active:scale-95"
          >
            <span className="text-xl">→</span>
            <span>رجوع لاختيار الحساب</span>
          </button>
        )}

        {/* top mascot */}
        <div className="absolute -top-8 left-1/2 -translate-x-1/2">
          <div className="w-20 h-20 bg-gradient-to-br from-orange-400 to-pink-500 rounded-full flex items-center justify-center shadow-lg animate-wiggle">
            <span className="text-4xl">🎓</span>
          </div>
        </div>

        <div className="mt-10 text-center">
          <h1 className="text-3xl font-black text-gray-800 mb-1">منارة المعرفة</h1>
          <p className="text-lg text-orange-500 font-bold animate-pulse">بوابة الطالب ✨</p>
        </div>

        {loginError && (
          <div className="mt-4 p-4 bg-red-50 border-2 border-red-200 rounded-2xl animate-bounce-in">
            <p className="text-red-600 font-bold text-sm text-center">{loginError}</p>
          </div>
        )}

        <form onSubmit={handleSubmit} className="mt-6 space-y-5 text-right">
          <div className="relative group">
            <label className="block text-gray-700 font-bold mb-2 text-lg flex items-center justify-end gap-2">
              <span>👤</span>
              <span>اسم المستخدم أو رقم الهوية</span>
            </label>
            <input
              type="text"
              value={username}
              onChange={(e) => {
                setUsername(e.target.value);
                setLoginError('');
              }}
              placeholder="اكتب اسمك هنا..."
              className="w-full px-5 py-4 text-right rounded-2xl border-[3px] border-orange-200 bg-orange-50/50 text-lg font-semibold text-gray-800 placeholder-gray-400 focus:outline-none focus:border-orange-400 focus:ring-4 focus:ring-orange-100 transition-all duration-300 hover:border-orange-300 hover:shadow-md"
            />
          </div>

          <div className="relative group">
            <label className="block text-gray-700 font-bold mb-2 text-lg flex items-center justify-end gap-2">
              <span>🔐</span>
              <span>كلمة المرور</span>
            </label>
            <input
              type="password"
              value={password}
              onChange={(e) => {
                setPassword(e.target.value);
                setLoginError('');
              }}
              placeholder="كلمة السر السرية 🤫"
              className="w-full px-5 py-4 text-right rounded-2xl border-[3px] border-orange-200 bg-orange-50/50 text-lg font-semibold text-gray-800 placeholder-gray-400 focus:outline-none focus:border-orange-400 focus:ring-4 focus:ring-orange-100 transition-all duration-300 hover:border-orange-300 hover:shadow-md"
            />
          </div>

          <button
            type="submit"
            onMouseEnter={() => setBtnHover(true)}
            onMouseLeave={() => setBtnHover(false)}
            className="w-full py-4 rounded-2xl bg-gradient-to-r from-orange-400 via-pink-500 to-purple-500 text-white text-xl font-black shadow-lg hover:shadow-xl transition-all duration-300 active:scale-95 animate-pulse-glow"
            style={{
              transform: btnHover ? 'scale(1.05)' : 'scale(1)',
            }}
          >
            🚀 ادخل للمغامرة!
          </button>
        </form>

        {/* mascot */}
        <div className="mt-4 flex justify-center">
          <div className="text-5xl animate-float">🦊</div>
        </div>

        <p className="text-center text-gray-500 mt-3 text-sm font-semibold">
          🌈 تعلم يلعب... يلعب يتعلم!
        </p>
        </div>
      </InteractiveScene>
      </motion.div>

      {/* bottom wave */}
      <div className="absolute bottom-0 left-0 right-0 h-24 opacity-30 pointer-events-none">
        <svg viewBox="0 0 1440 120" fill="none" xmlns="http://www.w3.org/2000/svg" className="w-full h-full">
          <path d="M0 60C240 100 480 20 720 60C960 100 1200 20 1440 60V120H0V60Z" fill="#FF6B35" />
        </svg>
      </div>

      {/* extra animations */}
      <style>{`
        @keyframes bounce-in {
          0% { transform: scale(0.3); opacity: 0; }
          50% { transform: scale(1.05); }
          70% { transform: scale(0.9); }
          100% { transform: scale(1); opacity: 1; }
        }
        @keyframes shake {
          0%, 100% { transform: translateX(0); }
          20% { transform: translateX(-10px); }
          40% { transform: translateX(10px); }
          60% { transform: translateX(-10px); }
          80% { transform: translateX(10px); }
        }
        @keyframes float {
          0%, 100% { transform: translateY(0px); }
          50% { transform: translateY(-10px); }
        }
        @keyframes wiggle {
          0%, 100% { transform: rotate(-3deg); }
          50% { transform: rotate(3deg); }
        }
        @keyframes spin-slow {
          from { transform: rotate(0deg); }
          to { transform: rotate(360deg); }
        }
        @keyframes pulse-glow {
          0%, 100% { box-shadow: 0 0 5px rgba(255,107,53,0.4); }
          50% { box-shadow: 0 0 20px rgba(255,107,53,0.8), 0 0 40px rgba(255,107,53,0.3); }
        }
        .animate-bounce-in { animation: bounce-in 0.6s ease-out; }
        .animate-shake { animation: shake 0.5s ease-in-out; }
        .animate-float { animation: float 3s ease-in-out infinite; }
        .animate-wiggle { animation: wiggle 0.5s ease-in-out infinite; }
        .animate-spin-slow { animation: spin-slow 3s ease-in-out infinite; }
        .animate-pulse-glow { animation: pulse-glow 2s ease-in-out infinite; }
      `}</style>
    </div>
  );
};

export default StudentLogin;
