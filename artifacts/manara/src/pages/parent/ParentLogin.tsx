import React, { useState } from 'react';
import ManaraBrand from '../../components/ManaraBrand';

interface ParentLoginProps {
  onLogin: (username: string, password: string) => void;
  onBack?: () => void;
}

const ParentLogin: React.FC<ParentLoginProps> = ({ onLogin, onBack }) => {
  const [username, setUsername] = useState('');
  const [password, setPassword] = useState('');

  return (
    <div className="flex min-h-screen items-center justify-center overflow-y-auto bg-gradient-to-br from-rose-50 via-pink-50 to-orange-50 p-3 animate-fadeIn relative safe-area-x safe-area-top safe-area-bottom sm:p-4">
      {/* floating decorations */}
      <div className="absolute text-4xl opacity-30 select-none pointer-events-none animate-float" style={{ left: '5%', top: '10%' }}>❤️</div>
      <div className="absolute text-4xl opacity-30 select-none pointer-events-none animate-float" style={{ left: '90%', top: '15%', animationDelay: '0.5s' }}>👨‍👩‍👧‍👦</div>
      <div className="absolute text-4xl opacity-30 select-none pointer-events-none animate-float" style={{ left: '8%', top: '70%', animationDelay: '1s' }}>🌟</div>

      <div className="web-login-panel mobile-modal-panel relative z-10 w-full max-w-md rounded-[2rem] border-[3px] border-rose-200 bg-white/90 p-5 text-center shadow-2xl backdrop-blur-xl animate-bounce-in sm:rounded-[2.5rem] sm:p-8">
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
        <ManaraBrand variant="login" className="mb-6 text-gray-800" />
        <h1 className="text-2xl font-black mb-2 text-gray-800 animate-popIn sm:text-4xl">بوابة ولي الأمر</h1>
        <p className="text-rose-500 mb-6 font-bold animate-popIn sm:mb-10" style={{ animationDelay: '0.1s' }}>تابع مستوى أبنائك وتقدمهم 👨‍👩‍👧‍👦</p>

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
