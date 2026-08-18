
import React, { useState } from 'react';
import { motion } from 'framer-motion';
import { StudentInfo } from '../../types';
import { COLORS } from '../../constants';
import { passwordsMatch } from '../../utils/password';
import { playLamsaSound } from '../../utils/sounds';

interface StudentAccountSetupProps {
  student: StudentInfo;
  onPasswordChange: (newPassword: string) => void;
}

const StudentAccountSetup: React.FC<StudentAccountSetupProps> = ({ student, onPasswordChange }) => {
  const [currentPassword, setCurrentPassword] = useState('');
  const [newPassword, setNewPassword] = useState('');
  const [confirmPassword, setConfirmPassword] = useState('');
  const [error, setError] = useState('');

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    setError('');

    if (!passwordsMatch(currentPassword, student.password)) {
      playLamsaSound('error');
      setError('كلمة المرور الحالية غير صحيحة');
      return;
    }
    if (newPassword.length < 6) {
      playLamsaSound('error');
      setError('كلمة المرور الجديدة يجب أن تكون 6 أحرف على الأقل');
      return;
    }
    if (newPassword === currentPassword) {
      playLamsaSound('error');
      setError('كلمة المرور الجديدة يجب أن تكون مختلفة عن الحالية');
      return;
    }
    if (newPassword !== confirmPassword) {
      playLamsaSound('error');
      setError('تأكيد كلمة المرور غير متطابق');
      return;
    }

    playLamsaSound('success');
    onPasswordChange(newPassword);
    alert('رائع! تم تغيير كلمة المرور بنجاح. استعد للتعلم!');
  };

  return (
    <motion.div initial={{ opacity: 0, y: 14 }} animate={{ opacity: 1, y: 0 }} transition={{ duration: 0.4 }} className="flex min-h-screen items-center justify-center overflow-y-auto bg-orange-50 p-3 font-tajawal safe-area-x safe-area-top safe-area-bottom sm:p-4">
      <div className="mobile-modal-panel relative w-full max-w-xl overflow-hidden rounded-[36px] border-t-8 border-orange-500 bg-white p-5 text-center shadow-2xl sm:rounded-[60px] sm:border-t-[12px] sm:p-10">
        <div className="absolute top-0 right-0 w-32 h-32 bg-orange-50 rounded-full -mr-16 -mt-16 opacity-50"></div>
        
        <div className="w-24 h-24 bg-orange-500 text-white rounded-[35px] flex items-center justify-center text-5xl mx-auto mb-8 shadow-xl shadow-orange-100 animate-bounce">🎓</div>
        <h1 className="text-2xl font-black mb-2 text-orange-800 sm:text-4xl">مرحباً بك يا {student.name}!</h1>
        <p className="text-orange-500 mb-6 font-bold sm:mb-8 sm:text-lg">من أجل حماية حسابك ودروسك، يرجى تعيين كلمة مرور جديدة من اختيارك.</p>
        
         <div className="bg-orange-50 p-4 rounded-[24px] mb-6 text-right space-y-2 border border-orange-100 sm:mb-10 sm:rounded-[30px] sm:p-6">
           <div className="flex justify-between text-sm font-bold text-orange-400"><span>الصف الدراسي:</span> <span className="text-orange-500">{student.grade}</span></div>
           <div className="flex justify-between text-sm font-bold text-orange-400"><span>رقم الهوية:</span> <span className="text-orange-500 tracking-widest">{student.studentIdNumber}</span></div>
        </div>

        <form onSubmit={handleSubmit} className="space-y-6 text-right">
          <div className="space-y-2">
            <label className="block text-xs font-black text-orange-400 uppercase tracking-widest mr-4">كلمة المرور الحالية (123456)</label>
            <input type="password" value={currentPassword} onChange={e => setCurrentPassword(e.target.value)} className="w-full p-5 bg-orange-50 border-2 border-transparent focus:border-orange-400 focus:ring-4 focus:ring-orange-100 rounded-3xl outline-none font-bold text-lg shadow-inner" required autoFocus />
          </div>
          <div className="space-y-2">
            <label className="block text-xs font-black text-orange-400 uppercase tracking-widest mr-4">كلمة المرور الجديدة</label>
            <input type="password" value={newPassword} onChange={e => setNewPassword(e.target.value)} className="w-full p-5 bg-orange-50 border-2 border-transparent focus:border-orange-400 focus:ring-4 focus:ring-orange-100 rounded-3xl outline-none font-bold text-lg shadow-inner" required />
          </div>
          <div className="space-y-2">
            <label className="block text-xs font-black text-orange-400 uppercase tracking-widest mr-4">تأكيد كلمة المرور</label>
            <input type="password" value={confirmPassword} onChange={e => setConfirmPassword(e.target.value)} className="w-full p-5 bg-orange-50 border-2 border-transparent focus:border-orange-400 focus:ring-4 focus:ring-orange-100 rounded-3xl outline-none font-bold text-lg shadow-inner" required />
          </div>

          {error && <div className="p-5 bg-red-50 text-red-600 rounded-[25px] text-center font-black border-2 border-red-100 animate-fadeIn">⚠️ {error}</div>}

          <button type="submit" className="w-full bg-orange-500 text-white py-6 rounded-[30px] font-black text-2xl hover:bg-orange-600 shadow-xl shadow-orange-100 transition-all active:scale-95 mt-4">🔐 ابدأ رحلة التعلم</button>
        </form>
      </div>
    </motion.div>
  );
};

export default StudentAccountSetup;
