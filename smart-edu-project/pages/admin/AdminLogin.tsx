import React, { useState } from 'react';
import { ADMIN_USERNAME, ADMIN_PASSWORD, STORAGE_KEYS } from '../../constants';
import { passwordsMatch } from '../../utils/password';

interface StoredAdminSettings { adminUsername?: string; adminPassword?: string }

interface AdminLoginProps {
  onLoginSuccess: () => void;
  onBack?: () => void;
}

const AdminLogin: React.FC<AdminLoginProps> = ({ onLoginSuccess, onBack }) => {
  const [username, setUsername] = useState('');
  const [password, setPassword] = useState('');

  const handleLogin = (e: React.FormEvent) => {
    e.preventDefault();
    const saved = localStorage.getItem(STORAGE_KEYS.ADMIN_SETTINGS);
    let adminUser = ADMIN_USERNAME;
    let adminPass = ADMIN_PASSWORD;
    if (saved) {
      try {
        const parsed: StoredAdminSettings = JSON.parse(saved);
        if (parsed.adminUsername) adminUser = parsed.adminUsername;
        if (parsed.adminPassword) adminPass = parsed.adminPassword;
      } catch (e) { /* ignore */ }
    }

    if (username === adminUser && passwordsMatch(password, adminPass)) {
      onLoginSuccess();
    } else {
      alert('خطأ في اسم المستخدم أو كلمة المرور');
    }
  };

  return (
    <div className="flex items-center justify-center min-h-screen p-4 bg-gradient-to-br from-purple-50 via-violet-50 to-orange-50 animate-fadeIn relative overflow-hidden">
      {/* floating decorations */}
      <div className="absolute text-4xl opacity-30 select-none pointer-events-none animate-float" style={{ left: '5%', top: '10%' }}>⚙️</div>
      <div className="absolute text-4xl opacity-30 select-none pointer-events-none animate-float" style={{ left: '90%', top: '15%', animationDelay: '0.5s' }}>⭐</div>
      <div className="absolute text-4xl opacity-30 select-none pointer-events-none animate-float" style={{ left: '8%', top: '70%', animationDelay: '1s' }}>🔒</div>

      <div className="relative z-10 bg-white/90 backdrop-blur-xl p-12 rounded-[2.5rem] shadow-2xl max-w-md w-full text-center border-[3px] border-purple-200 animate-bounce-in">
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
        <div className="relative mx-auto mb-6">
          <div className="w-24 h-24 rounded-full bg-gradient-to-br from-purple-400 to-violet-500 flex items-center justify-center shadow-xl animate-wiggle">
            <span className="text-5xl">👑</span>
          </div>
          <div className="absolute -top-2 -right-2 text-2xl animate-float">✨</div>
        </div>
        <h1 className="text-3xl font-black mb-2 text-gray-800 animate-popIn">بوابة المشرف</h1>
        <p className="text-purple-500 mb-10 font-bold animate-popIn" style={{ animationDelay: '0.1s' }}>إدارة النظام والمحتوى 🔒</p>

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
