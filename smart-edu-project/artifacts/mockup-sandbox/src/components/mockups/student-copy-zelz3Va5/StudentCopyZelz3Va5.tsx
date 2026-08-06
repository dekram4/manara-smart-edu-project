import { useState, useEffect } from 'react';
import './_group.css';

function FloatingEmoji({ emoji, delay, x, y }: { emoji: string; delay: number; x: number; y: number }) {
  return (
    <div
      className="lamsa-float absolute text-4xl select-none pointer-events-none"
      style={{
        left: `${x}%`,
        top: `${y}%`,
        animationDelay: `${delay}s`,
        opacity: 0.6,
      }}
    >
      {emoji}
    </div>
  );
}

function StarDecoration({ size, color, x, y, delay }: any) {
  return (
    <svg
      className="lamsa-star absolute"
      style={{
        left: `${x}%`,
        top: `${y}%`,
        animationDelay: `${delay}s`,
        opacity: 0.8,
      }}
      width={size}
      height={size}
      viewBox="0 0 24 24"
      fill={color}
    >
      <path d="M12 2l3.09 6.26L22 9.27l-5 4.87 1.18 6.88L12 17.77l-6.18 3.25L7 14.14 2 9.27l6.91-1.01L12 2z" />
    </svg>
  );
}

export function StudentCopyZelz3Va5() {
  const [username, setUsername] = useState('');
  const [password, setPassword] = useState('');
  const [isShaking, setIsShaking] = useState(false);
  const [showSuccess, setShowSuccess] = useState(false);

  const handleLogin = () => {
    if (!username || !password) {
      setIsShaking(true);
      setTimeout(() => setIsShaking(false), 500);
    } else {
      setShowSuccess(true);
    }
  };

  const emojis = [
    { emoji: '📚', x: 5, y: 10, delay: 0 },
    { emoji: '🎨', x: 85, y: 15, delay: 0.5 },
    { emoji: '🚀', x: 10, y: 70, delay: 1 },
    { emoji: '🌟', x: 90, y: 60, delay: 1.5 },
    { emoji: '🎵', x: 75, y: 80, delay: 2 },
    { emoji: '🧮', x: 15, y: 85, delay: 0.8 },
    { emoji: '🌍', x: 80, y: 5, delay: 1.2 },
    { emoji: '🔬', x: 5, y: 45, delay: 2.5 },
  ];

  if (showSuccess) {
    return (
      <div className="lamsa-root min-h-screen bg-gradient-to-br from-orange-100 via-pink-50 to-yellow-100 flex items-center justify-center p-4">
        <div className="text-center lamsa-bounce">
          <div className="text-8xl mb-6">🎉</div>
          <h2 className="text-4xl font-black text-orange-600 mb-4">أهلاً يا بطل! 🌟</h2>
          <p className="text-xl text-gray-600">جاهز نبدأ مغامرتنا التعليمية؟</p>
          <div className="mt-8 flex justify-center gap-3">
            {['🎈', '🎊', '🌈', '⭐', '🎁'].map((e, i) => (
              <span key={i} className="text-4xl lamsa-bounce" style={{ animationDelay: `${i * 0.2}s` }}>
                {e}
              </span>
            ))}
          </div>
        </div>
      </div>
    );
  }

  return (
    <div className="lamsa-root min-h-screen bg-gradient-to-br from-orange-50 via-rose-50 to-amber-50 flex items-center justify-center p-4 relative overflow-hidden">
      {/* Floating decorations */}
      {emojis.map((e, i) => (
        <FloatingEmoji key={i} {...e} />
      ))}
      <StarDecoration size={30} color="#FFE66D" x={92} y={30} delay={0} />
      <StarDecoration size={20} color="#FF6B9D" x={8} y={25} delay={0.5} />
      <StarDecoration size={25} color="#4ECDC4" x={88} y={75} delay={1} />

      {/* Main card */}
      <div
        className={`relative z-10 w-full max-w-md bg-white/90 backdrop-blur-xl rounded-[2.5rem] shadow-2xl border-4 border-orange-200 p-8 lamsa-bounce ${
          isShaking ? 'animate-[shake_0.5s_ease-in-out]' : ''
        }`}
      >
        {/* Top decoration */}
        <div className="absolute -top-6 left-1/2 -translate-x-1/2">
          <div className="w-20 h-20 bg-gradient-to-br from-orange-400 to-pink-500 rounded-full flex items-center justify-center shadow-lg lamsa-wiggle">
            <span className="text-4xl">🎓</span>
          </div>
        </div>

        <div className="mt-12 text-center">
          <h1 className="text-3xl font-black text-gray-800 mb-2">منارة المعرفة</h1>
          <p className="text-lg text-orange-500 font-bold">بوابة الطالب ✨</p>
        </div>

        <div className="mt-8 space-y-5">
          <div className="relative">
            <label className="block text-right text-gray-700 font-bold mb-2 text-lg">
              👤 اسم المستخدم
            </label>
            <input
              type="text"
              value={username}
              onChange={(e) => setUsername(e.target.value)}
              placeholder="اكتب اسمك هنا..."
              className="w-full px-5 py-4 text-right rounded-2xl border-3 border-orange-200 bg-orange-50/50 text-lg font-semibold text-gray-800 placeholder-gray-400 focus:outline-none focus:border-orange-400 focus:ring-4 focus:ring-orange-100 transition-all duration-300 hover:border-orange-300"
              style={{ borderWidth: '3px' }}
            />
          </div>

          <div className="relative">
            <label className="block text-right text-gray-700 font-bold mb-2 text-lg">
              🔐 كلمة المرور
            </label>
            <input
              type="password"
              value={password}
              onChange={(e) => setPassword(e.target.value)}
              placeholder="كلمة السر السرية 🤫"
              className="w-full px-5 py-4 text-right rounded-2xl border-3 border-orange-200 bg-orange-50/50 text-lg font-semibold text-gray-800 placeholder-gray-400 focus:outline-none focus:border-orange-400 focus:ring-4 focus:ring-orange-100 transition-all duration-300 hover:border-orange-300"
              style={{ borderWidth: '3px' }}
            />
          </div>

          <button
            onClick={handleLogin}
            className="w-full py-4 rounded-2xl bg-gradient-to-r from-orange-400 via-pink-500 to-purple-500 text-white text-xl font-black shadow-lg hover:shadow-xl hover:scale-105 active:scale-95 transition-all duration-300 lamsa-pulse"
          >
            🚀 ادخل للمغامرة!
          </button>
        </div>

        {/* Character illustration */}
        <div className="mt-6 flex justify-center">
          <div className="text-6xl lamsa-float">🦊</div>
        </div>

        <p className="text-center text-gray-500 mt-4 text-sm">
          🌈 تعلم يلعب... يلعب يتعلم!
        </p>
      </div>

      {/* Bottom wave */}
      <div className="absolute bottom-0 left-0 right-0 h-24 opacity-30">
        <svg viewBox="0 0 1440 120" fill="none" xmlns="http://www.w3.org/2000/svg" className="w-full h-full">
          <path d="M0 60C240 100 480 20 720 60C960 100 1200 20 1440 60V120H0V60Z" fill="#FF6B35" />
        </svg>
      </div>

      <style>{`
        @keyframes shake {
          0%, 100% { transform: translateX(0); }
          20% { transform: translateX(-10px); }
          40% { transform: translateX(10px); }
          60% { transform: translateX(-10px); }
          80% { transform: translateX(10px); }
        }
      `}</style>
    </div>
  );
}
