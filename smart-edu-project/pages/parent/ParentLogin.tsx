import React, { useState } from 'react';

interface ParentLoginProps {
  onLogin: (username: string, password: string) => void;
  onBack?: () => void;
}

const ParentLogin: React.FC<ParentLoginProps> = ({ onLogin, onBack }) => {
  const [username, setUsername] = useState('');
  const [password, setPassword] = useState('');

  return (
    <div className="flex items-center justify-center min-h-screen p-4 bg-gradient-to-br from-rose-50 via-pink-50 to-orange-50 animate-fadeIn relative overflow-hidden">
      {/* floating decorations */}
      <div className="absolute text-4xl opacity-30 select-none pointer-events-none animate-float" style={{ left: '5%', top: '10%' }}>❤️</div>
      <div className="absolute text-4xl opacity-30 select-none pointer-events-none animate-float" style={{ left: '90%', top: '15%', animationDelay: '0.5s' }}>👨‍👩‍👧‍👦</div>
      <div className="absolute text-4xl opacity-30 select-none pointer-events-none animate-float" style={{ left: '8%', top: '70%', animationDelay: '1s' }}>🌟</div>

      <div className="relative z-10 bg-white/90 backdrop-blur-xl p-12 rounded-[2.5rem] shadow-2xl max-w-md w-full text-center border-[3px] border-rose-200 animate-bounce-in">
        {onBack && (
          <button
            type="button"
            onClick={onBack}
            className="flex items-center gap-2 text-gray-400 hover:text-rose-500 font-bold mb-6 transition-all hover:-translate-x-1 active:scale-95"
          >
            <span className="text-xl">→</span>
            <span>رجوع لاختيار الحساب</span>
          </button>
        )}
        <div className="relative mx-auto mb-6">
          <div className="w-24 h-24 rounded-full bg-gradient-to-br from-rose-400 to-pink-500 flex items-center justify-center shadow-xl animate-wiggle">
            <span className="text-5xl">👨‍👩‍👧‍👦</span>
          </div>
          <div className="absolute -top-2 -right-2 text-2xl animate-float">✨</div>
        </div>
        <h1 className="text-4xl font-black mb-2 text-gray-800 animate-popIn">بوابة ولي الأمر</h1>
        <p className="text-rose-500 mb-10 font-bold animate-popIn" style={{ animationDelay: '0.1s' }}>تابع مستوى أبنائك وتقدمهم 👨‍👩‍👧‍👦</p>

        <div className="space-y-5 text-right">
          <input
            value={username}
            onChange={e => setUsername(e.target.value)}
            type="text"
            placeholder="اسم المستخدم"
            className="w-full p-5 bg-rose-50/50 border-[3px] border-rose-200 focus:border-rose-400 focus:ring-4 focus:ring-rose-100 rounded-2xl outline-none transition-all font-bold text-lg hover:border-rose-300"
          />
          <input
            value={password}
            onChange={e => setPassword(e.target.value)}
            type="password"
            placeholder="كلمة المرور"
            className="w-full p-5 bg-rose-50/50 border-[3px] border-rose-200 focus:border-rose-400 focus:ring-4 focus:ring-rose-100 rounded-2xl outline-none transition-all font-bold text-lg hover:border-rose-300"
          />
          <button
            onClick={() => onLogin(username, password)}
            className="w-full bg-gradient-to-r from-rose-400 to-pink-500 text-white py-5 rounded-2xl font-black text-xl hover:scale-[1.02] hover:-translate-y-0.5 hover:shadow-2xl shadow-xl transition-all duration-200 active:scale-95 mt-4 animate-pulse-glow"
          >
            🔐 دخول
          </button>
        </div>
      </div>
    </div>
  );
};

export default ParentLogin;
