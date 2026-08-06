import React, { useState } from 'react';
import { TeacherInfo } from '../../types';
import { STORAGE_KEYS } from '../../constants';
import { hashPassword, passwordsMatch } from '../../utils/password';
import ManaraBrand from '../../components/ManaraBrand';

interface TeacherLoginProps {
  onLoginSuccess: (teacher: TeacherInfo) => void;
  onBack?: () => void;
}

const TeacherLogin: React.FC<TeacherLoginProps> = ({ onLoginSuccess, onBack }) => {
  const [username, setUsername] = useState('');
  const [password, setPassword] = useState('');
  const [newPassword, setNewPassword] = useState('');
  const [confirmPassword, setConfirmPassword] = useState('');
  const [showChangePassword, setShowChangePassword] = useState(false);
  const [currentTeacher, setCurrentTeacher] = useState<TeacherInfo | null>(null);
  const [error, setError] = useState('');

  const handleLogin = (e: React.FormEvent) => {
    e.preventDefault();
    setError('');

    const teachers: TeacherInfo[] = JSON.parse(localStorage.getItem(STORAGE_KEYS.TEACHERS) || '[]');
    const teacher = teachers.find(t => t.username === username && passwordsMatch(password, t.password));

    if (!teacher) {
      setError('❌ اسم المستخدم أو كلمة المرور غير صحيحة');
      return;
    }

    teacher.lastActivity = new Date().toISOString();
    const updated = teachers.map(t => t.id === teacher.id ? teacher : t);
    localStorage.setItem(STORAGE_KEYS.TEACHERS, JSON.stringify(updated));

    if (teacher.mustChangePassword) {
      setCurrentTeacher(teacher);
      setShowChangePassword(true);
    } else {
      localStorage.setItem(STORAGE_KEYS.CURRENT_TEACHER, JSON.stringify(teacher));
      onLoginSuccess(teacher);
    }
  };

  const handleChangePassword = (e: React.FormEvent) => {
    e.preventDefault();
    setError('');

    if (!newPassword.trim() || !confirmPassword.trim()) {
      setError('⚠️ يرجى ملء جميع الحقول');
      return;
    }

    if (newPassword !== confirmPassword) {
      setError('❌ كلمتا المرور غير متطابقتين');
      return;
    }

    if (newPassword.length < 6) {
      setError('⚠️ كلمة المرور يجب أن تكون 6 أحرف على الأقل');
      return;
    }

    if (!currentTeacher) return;

    const hashedPassword = hashPassword(newPassword);
    const teachers: TeacherInfo[] = JSON.parse(localStorage.getItem(STORAGE_KEYS.TEACHERS) || '[]');
    const updated = teachers.map(t =>
      t.id === currentTeacher.id
        ? { ...t, password: hashedPassword, mustChangePassword: false }
        : t
    );

    localStorage.setItem(STORAGE_KEYS.TEACHERS, JSON.stringify(updated));

    const updatedTeacher = { ...currentTeacher, password: hashedPassword, mustChangePassword: false };
    localStorage.setItem(STORAGE_KEYS.CURRENT_TEACHER, JSON.stringify(updatedTeacher));
    onLoginSuccess(updatedTeacher);
  };

  if (showChangePassword && currentTeacher) {
    return (
      <div className="min-h-screen bg-gradient-to-br from-amber-50 via-orange-50 to-rose-50 flex items-center justify-center p-4 relative overflow-hidden">
        <div className="absolute text-4xl opacity-30 select-none pointer-events-none animate-float" style={{ left: '5%', top: '10%' }}>🔐</div>
        <div className="absolute text-4xl opacity-30 select-none pointer-events-none animate-float" style={{ left: '90%', top: '15%', animationDelay: '0.5s' }}>⭐</div>

        <div className="relative z-10 bg-white/90 backdrop-blur-xl rounded-[2.5rem] shadow-2xl p-12 w-full max-w-md border-[3px] border-amber-200 animate-bounce-in">
          <div className="text-center mb-8">
            <div className="relative mx-auto mb-4 w-20 h-20">
              <div className="w-20 h-20 rounded-full bg-gradient-to-br from-amber-400 to-orange-500 flex items-center justify-center shadow-xl animate-wiggle">
                <span className="text-4xl">🔐</span>
              </div>
            </div>
            <h1 className="text-3xl font-black text-gray-800 mb-2">تغيير كلمة المرور</h1>
            <p className="text-gray-600 font-medium">
              مرحباً {currentTeacher.name}، يجب عليك تغيير كلمة المرور قبل المتابعة
            </p>
          </div>

          {error && (
            <div className="bg-red-50 border-2 border-red-200 text-red-700 p-4 rounded-2xl mb-6 font-bold text-center">
              {error}
            </div>
          )}

          <form onSubmit={handleChangePassword} className="space-y-4">
            <div>
              <label className="block font-bold text-gray-700 mb-2">🔑 كلمة المرور الجديدة</label>
              <input
                type="password"
                value={newPassword}
                onChange={(e) => setNewPassword(e.target.value)}
                className="w-full p-4 border-[3px] border-amber-200 rounded-2xl outline-none focus:border-amber-400 focus:ring-4 focus:ring-amber-100 font-bold text-lg transition-all hover:border-amber-300"
                placeholder="أدخل كلمة المرور الجديدة"
                required
              />
            </div>

            <div>
              <label className="block font-bold text-gray-700 mb-2">✅ تأكيد كلمة المرور</label>
              <input
                type="password"
                value={confirmPassword}
                onChange={(e) => setConfirmPassword(e.target.value)}
                className="w-full p-4 border-[3px] border-amber-200 rounded-2xl outline-none focus:border-amber-400 focus:ring-4 focus:ring-amber-100 font-bold text-lg transition-all hover:border-amber-300"
                placeholder="أعد إدخال كلمة المرور"
                required
              />
            </div>

            <button
              type="submit"
              className="w-full bg-gradient-to-r from-amber-400 to-orange-500 text-white py-5 rounded-2xl font-black text-xl shadow-xl hover:shadow-2xl hover:scale-[1.02] hover:-translate-y-0.5 transition-all duration-200 active:scale-95 animate-pulse-glow"
            >
              💾 حفظ والمتابعة
            </button>
          </form>
        </div>
      </div>
    );
  }

  return (
    <div className="min-h-screen bg-gradient-to-br from-amber-50 via-orange-50 to-rose-50 flex items-center justify-center p-4 animate-fadeIn relative overflow-hidden">
      {/* floating decorations */}
      <div className="absolute text-4xl opacity-30 select-none pointer-events-none animate-float" style={{ left: '5%', top: '10%' }}>🏫</div>
      <div className="absolute text-4xl opacity-30 select-none pointer-events-none animate-float" style={{ left: '90%', top: '15%', animationDelay: '0.5s' }}>⭐</div>
      <div className="absolute text-4xl opacity-30 select-none pointer-events-none animate-float" style={{ left: '8%', top: '70%', animationDelay: '1s' }}>📚</div>

      <div className="relative z-10 bg-white/90 backdrop-blur-xl rounded-[2.5rem] shadow-2xl p-12 w-full max-w-md border-[3px] border-amber-200 animate-bounce-in">
        {onBack && (
          <button
            type="button"
            onClick={onBack}
            className="flex items-center gap-2 text-gray-400 hover:text-amber-500 font-bold mb-6 transition-all hover:-translate-x-1 active:scale-95"
          >
            <span className="text-xl">→</span>
            <span>رجوع لاختيار الحساب</span>
          </button>
        )}
        <div className="text-center mb-8">
          <ManaraBrand variant="login" className="text-gray-800" />
          <h1 className="text-4xl font-black text-gray-800 mb-2 animate-popIn">تسجيل دخول المعلم</h1>
          <p className="text-amber-600 font-bold animate-popIn" style={{ animationDelay: '0.1s' }}>منصة منارة المعرفة التعليمية 🎓</p>
        </div>

        {error && (
          <div className="bg-red-50 border-2 border-red-200 text-red-700 p-4 rounded-2xl mb-6 font-bold text-center">
            {error}
          </div>
        )}

        <form onSubmit={handleLogin} className="space-y-4">
          <div>
            <label className="block font-bold text-gray-700 mb-2">👤 اسم المستخدم</label>
            <input
              type="text"
              value={username}
              onChange={(e) => setUsername(e.target.value)}
              className="w-full p-4 border-[3px] border-amber-200 rounded-2xl outline-none focus:border-amber-400 focus:ring-4 focus:ring-amber-100 font-bold text-lg transition-all hover:border-amber-300"
              placeholder="أدخل اسم المستخدم"
              required
            />
          </div>

          <div>
            <label className="block font-bold text-gray-700 mb-2">🔐 كلمة المرور</label>
            <input
              type="password"
              value={password}
              onChange={(e) => setPassword(e.target.value)}
              className="w-full p-4 border-[3px] border-amber-200 rounded-2xl outline-none focus:border-amber-400 focus:ring-4 focus:ring-amber-100 font-bold text-lg transition-all hover:border-amber-300"
              placeholder="أدخل كلمة المرور"
              required
            />
          </div>

          <button
            type="submit"
            className="w-full bg-gradient-to-r from-amber-400 to-orange-500 text-white py-5 rounded-2xl font-black text-xl shadow-xl hover:shadow-2xl hover:scale-[1.02] hover:-translate-y-0.5 transition-all duration-200 active:scale-95 animate-pulse-glow"
          >
            🚀 تسجيل الدخول
          </button>
        </form>

        <div className="mt-6 text-center">
          <p className="text-gray-500 text-sm">
            للدعم الفني، تواصل مع المشرف
          </p>
        </div>
      </div>
    </div>
  );
};

export default TeacherLogin;
