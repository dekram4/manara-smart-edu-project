import React, { useState } from 'react';
import ManaraBrand from '../../components/ManaraBrand';

interface ParentLoginProps {
  onLogin: (username: string, password: string) => Promise<string | null>;
  onBack?: () => void;
}

const ParentLogin: React.FC<ParentLoginProps> = ({ onLogin, onBack }) => {
  const [username, setUsername] = useState('');
  const [password, setPassword] = useState('');
  const [error, setError] = useState('');
  const [submitting, setSubmitting] = useState(false);

  const handleSubmit = async (event: React.FormEvent) => {
    event.preventDefault();
    if (submitting) return;
    setError('');
    setSubmitting(true);
    try {
      const message = await onLogin(username.trim(), password);
      if (message) setError(message);
    } finally {
      setSubmitting(false);
    }
  };

  return (
    <div className="login-shell manara-enterprise flex items-center justify-center bg-gradient-to-br from-slate-100 via-blue-50 to-slate-200 animate-fadeIn relative safe-area-x safe-area-top safe-area-bottom sm:p-4">
      {/* floating decorations */}
      <div className="absolute text-4xl opacity-30 select-none pointer-events-none animate-float" style={{ left: '5%', top: '10%' }}>❤️</div>
      <div className="absolute text-4xl opacity-30 select-none pointer-events-none animate-float" style={{ left: '90%', top: '15%', animationDelay: '0.5s' }}>👨‍👩‍👧‍👦</div>
      <div className="absolute text-4xl opacity-30 select-none pointer-events-none animate-float" style={{ left: '8%', top: '70%', animationDelay: '1s' }}>🌟</div>

      <div className="login-card web-login-panel mobile-modal-panel relative z-10 rounded-[2rem] border-2 border-slate-200 bg-white p-5 text-center shadow-2xl backdrop-blur-xl animate-bounce-in sm:rounded-[2.5rem] sm:p-8">
        {onBack && (
          <button
            type="button"
            onClick={onBack}
            className="flex items-center gap-2 text-gray-400 hover:text-blue-700 font-bold mb-6 transition-all hover:-translate-x-1 active:scale-95"
          >
            <span className="text-xl">→</span>
            <span>رجوع لاختيار الحساب</span>
          </button>
        )}
        <ManaraBrand variant="login" className="mb-6 text-gray-800" />
        <h1 className="text-2xl font-black mb-2 text-gray-800 animate-popIn sm:text-4xl">بوابة ولي الأمر</h1>
        <p className="text-blue-700 mb-6 font-bold animate-popIn sm:mb-10" style={{ animationDelay: '0.1s' }}>تابع مستوى أبنائك وتقدمهم 👨‍👩‍👧‍👦</p>

        {error && (
          <div className="mb-5 rounded-2xl border-2 border-red-200 bg-red-50 p-4 text-center font-bold text-red-700">
            {error}
          </div>
        )}
        <form onSubmit={handleSubmit} className="login-form space-y-5 text-right">
          <input
            value={username}
            onChange={e => setUsername(e.target.value)}
            type="text"
            name="username"
            autoComplete="username"
            autoCapitalize="none"
            spellCheck={false}
            placeholder="اسم المستخدم"
            className="login-input min-h-[48px] px-4 py-3 border-2 border-slate-200 rounded-2xl outline-none focus:border-blue-500 focus:ring-2 focus:ring-blue-500/20 font-bold text-lg transition-all hover:border-blue-400"
          />
          <input
            value={password}
            onChange={e => setPassword(e.target.value)}
            type="password"
            name="password"
            autoComplete="current-password"
            placeholder="كلمة المرور"
            className="login-input min-h-[48px] px-4 py-3 border-2 border-slate-200 rounded-2xl outline-none focus:border-blue-500 focus:ring-2 focus:ring-blue-500/20 font-bold text-lg transition-all hover:border-blue-400"
          />
          <button
            type="submit"
            disabled={submitting}
            className="login-submit min-h-[52px] px-6 py-4 bg-blue-600 hover:bg-blue-700 text-white rounded-2xl font-black text-xl shadow-xl shadow-slate-200/50 hover:shadow-2xl hover:scale-[1.02] hover:-translate-y-0.5 transition-all duration-200 active:scale-95 flex items-center justify-center gap-3 whitespace-nowrap"
          >
            {submitting ? 'جارٍ التحقق…' : '🔐 دخول'}
          </button>
        </form>
      </div>
    </div>
  );
};

export default ParentLogin;
