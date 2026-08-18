import React, { useState } from 'react';
import ManaraBrand from '../../components/ManaraBrand';

interface AdminLoginProps {
  onLoginSuccess: () => void;
  onBack?: () => void;
}

const AdminLogin: React.FC<AdminLoginProps> = ({ onLoginSuccess, onBack }) => {
  const [username, setUsername] = useState('');
  const [password, setPassword] = useState('');

  const handleLogin = async (e: React.FormEvent) => {
    e.preventDefault();
    try {
      const response = await fetch('/api/auth/admin', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ username: username.trim(), password }),
      });
      if (response.ok) {
      onLoginSuccess();
        return;
      }
      if (response.status === 503) {
        alert('⚠️ لم يتم إعداد بيانات دخول المشرف في Secrets بعد');
        return;
      }
    } catch {
      // Keep the same generic message for network and credential failures.
    }
    alert('خطأ في اسم المستخدم أو كلمة المرور');
  };

  return (
    <div className="flex min-h-screen items-center justify-center overflow-y-auto p-3 sm:p-4 bg-gradient-to-br from-purple-50 via-violet-50 to-orange-50 animate-fadeIn relative safe-area-x safe-area-top safe-area-bottom">
      {/* floating decorations */}
      <div className="absolute text-4xl opacity-30 select-none pointer-events-none animate-float" style={{ left: '5%', top: '10%' }}>⚙️</div>
      <div className="absolute text-4xl opacity-30 select-none pointer-events-none animate-float" style={{ left: '90%', top: '15%', animationDelay: '0.5s' }}>⭐</div>
      <div className="absolute text-4xl opacity-30 select-none pointer-events-none animate-float" style={{ left: '8%', top: '70%', animationDelay: '1s' }}>🔒</div>

      <div className="mobile-modal-panel relative z-10 w-full max-w-md rounded-[2rem] border-[3px] border-purple-200 bg-white/90 p-5 text-center shadow-2xl backdrop-blur-xl animate-bounce-in sm:rounded-[2.5rem] sm:p-8">
        {onBack && (
          <button
            type="button"
            onClick={onBack}
            className="flex items-center gap-2 text-gray-400 hover:text-purple-500 font-bold mb-6 transition-all hover:-translate-x-1 active:scale-95"
          >
            <span className="text-xl">→</span>
            <span>رجوع لاختيار الحساب</span>
          </button>
        )}
        <ManaraBrand variant="login" className="mb-6 text-gray-800" />
        <h1 className="text-2xl font-black mb-2 text-gray-800 animate-popIn sm:text-3xl">بوابة المشرف</h1>
        <p className="text-purple-500 mb-6 font-bold animate-popIn sm:mb-10" style={{ animationDelay: '0.1s' }}>إدارة النظام والمحتوى 🔒</p>

        <form onSubmit={handleLogin} className="space-y-6 text-right">
          <div>
            <label className="block text-sm font-bold text-gray-700 mb-2 px-1">اسم المستخدم</label>
            <input
              type="text"
              value={username}
              onChange={(e) => setUsername(e.target.value)}
              className="w-full p-4 bg-purple-50/50 border-[3px] border-purple-200 focus:border-purple-400 focus:ring-4 focus:ring-purple-100 outline-none rounded-2xl transition-all hover:border-purple-300"
              placeholder="Username"
              required
            />
          </div>
          <div>
            <label className="block text-sm font-bold text-gray-700 mb-2 px-1">كلمة المرور</label>
            <input
              type="password"
              value={password}
              onChange={(e) => setPassword(e.target.value)}
              className="w-full p-4 bg-purple-50/50 border-[3px] border-purple-200 focus:border-purple-400 focus:ring-4 focus:ring-purple-100 outline-none rounded-2xl transition-all hover:border-purple-300"
              placeholder="••••••••"
              required
            />
          </div>
          <button
            type="submit"
            className="w-full bg-gradient-to-r from-purple-400 to-violet-500 text-white py-5 rounded-2xl font-black text-xl hover:scale-[1.02] hover:-translate-y-0.5 hover:shadow-xl shadow-lg transition-all duration-200 active:scale-95 animate-pulse-glow"
          >
            🔒 دخول النظام
          </button>
        </form>
      </div>
    </div>
  );
};

export default AdminLogin;
