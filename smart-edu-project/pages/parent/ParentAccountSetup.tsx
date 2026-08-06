
import React, { useState } from 'react';
import { ParentInfo } from '../../types';
import { COLORS } from '../../constants';
import { passwordsMatch } from '../../utils/password';

interface ParentAccountSetupProps {
  parent: ParentInfo;
  onPasswordChange: (newPassword: string) => void;
}

const ParentAccountSetup: React.FC<ParentAccountSetupProps> = ({ parent, onPasswordChange }) => {
  const [currentPassword, setCurrentPassword] = useState('');
  const [newPassword, setNewPassword] = useState('');
  const [confirmPassword, setConfirmPassword] = useState('');
  const [error, setError] = useState('');

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    setError('');

    if (!passwordsMatch(currentPassword, parent.password)) {
      setError('كلمة المرور الحالية غير صحيحة');
      return;
    }
    if (newPassword.length < 6) {
      setError('كلمة المرور الجديدة يجب أن تكون 6 أحرف على الأقل');
      return;
    }
    if (newPassword === currentPassword) {
      setError('كلمة المرور الجديدة يجب أن تكون مختلفة عن الحالية');
      return;
    }
    if (newPassword !== confirmPassword) {
      setError('تأكيد كلمة المرور غير متطابق');
      return;
    }

    onPasswordChange(newPassword);
    alert('تم تحديث كلمة المرور بنجاح!');
  };

  return (
    <div className="flex items-center justify-center min-h-screen p-4 bg-rose-50 font-tajawal">
      <div className="bg-white p-12 rounded-[50px] shadow-2xl max-w-lg w-full text-center border-t-8 border-emerald-500">
        <div className="w-24 h-24 bg-rose-100 rounded-full flex items-center justify-center text-4xl mx-auto mb-8 shadow-inner">👤</div>
        <h1 className="text-3xl font-black mb-2 text-rose-800">أهلاً بك {parent.name}!</h1>
        <p className="text-rose-500 mb-10 font-bold">هذه أول مرة تقوم بتسجيل الدخول. يرجى تغيير كلمة المرور الافتراضية لحماية حسابك.</p>
        
        <form onSubmit={handleSubmit} className="space-y-6 text-right">
          <div className="space-y-2">
            <label className="block text-sm font-bold text-rose-700 pr-4">كلمة المرور الحالية</label>
            <input type="password" value={currentPassword} onChange={e => setCurrentPassword(e.target.value)} className="w-full p-4 bg-rose-50 border-2 border-transparent focus:border-rose-400 focus:ring-4 focus:ring-rose-100 rounded-2xl outline-none" required autoFocus />
          </div>
          <div className="space-y-2">
            <label className="block text-sm font-bold text-rose-700 pr-4">كلمة المرور الجديدة</label>
            <input type="password" value={newPassword} onChange={e => setNewPassword(e.target.value)} className="w-full p-4 bg-rose-50 border-2 border-transparent focus:border-rose-400 focus:ring-4 focus:ring-rose-100 rounded-2xl outline-none" required />
            <small className="text-rose-400 text-[10px] mr-2 italic">6 أحرف على الأقل</small>
          </div>
          <div className="space-y-2">
            <label className="block text-sm font-bold text-rose-700 pr-4">تأكيد كلمة المرور</label>
            <input type="password" value={confirmPassword} onChange={e => setConfirmPassword(e.target.value)} className="w-full p-4 bg-rose-50 border-2 border-transparent focus:border-rose-400 focus:ring-4 focus:ring-rose-100 rounded-2xl outline-none" required />
          </div>

          {error && <div className="p-4 bg-red-50 text-red-600 rounded-2xl text-center font-bold border border-red-100 animate-pulse">⚠️ {error}</div>}

          <button type="submit" className="w-full bg-rose-500 text-white py-5 rounded-[24px] font-black text-xl hover:bg-rose-600 shadow-xl shadow-rose-100 transition-all mt-4">🔐 تحديث ودخول النظام</button>
        </form>
      </div>
    </div>
  );
};

export default ParentAccountSetup;
