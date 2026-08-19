
import React, { useState } from 'react';
import { TeacherInfo } from '../../types';
import { STORAGE_KEYS } from '../../constants';
import { hashPassword, passwordsMatch } from '../../utils/password';

interface MyAccountProps {
  teacher: TeacherInfo;
  onUpdate: (updated: TeacherInfo) => void;
}

const MyAccount: React.FC<MyAccountProps> = ({ teacher, onUpdate }) => {
  const [showChangePassword, setShowChangePassword] = useState(false);
  const [currentPassword, setCurrentPassword] = useState('');
  const [newPassword, setNewPassword] = useState('');
  const [confirmPassword, setConfirmPassword] = useState('');
  const [error, setError] = useState('');

  const handleChangePassword = (e: React.FormEvent) => {
    e.preventDefault();
    setError('');

    if (!passwordsMatch(currentPassword, teacher.password)) {
      setError('❌ كلمة المرور الحالية غير صحيحة');
      return;
    }

    if (newPassword !== confirmPassword) {
      setError('❌ كلمتا المرور الجديدة غير متطابقتين');
      return;
    }

    if (newPassword.length < 6) {
      setError('⚠️ كلمة المرور يجب أن تكون 6 أحرف على الأقل');
      return;
    }

    const hashedPassword = hashPassword(newPassword);
    const teachers: TeacherInfo[] = JSON.parse(localStorage.getItem(STORAGE_KEYS.TEACHERS) || '[]');
    const updated = teachers.map(t => 
      t.id === teacher.id ? { ...t, password: hashedPassword, mustChangePassword: false } : t
    );

    localStorage.setItem(STORAGE_KEYS.TEACHERS, JSON.stringify(updated));
    
    const updatedTeacher = { ...teacher, password: hashedPassword, mustChangePassword: false };
    onUpdate(updatedTeacher);
    
    setShowChangePassword(false);
    setCurrentPassword('');
    setNewPassword('');
    setConfirmPassword('');
    alert('✅ تم تغيير كلمة المرور بنجاح');
  };

  return (
    <div className="dashboard-page dashboard-consistent-page animate-fadeIn">
       <div className="dashboard-section-header">
         <h1 className="text-4xl font-black text-amber-900">👤 حسابي</h1>
       </div>

      {/* معلومات الحساب */}
       <div className="dashboard-surface border-amber-100">
        <h2 className="text-2xl font-black text-amber-900 mb-6">📋 معلومات الحساب</h2>
        
         <div className="dashboard-card-grid">
           <div className="dashboard-account-record bg-amber-50 p-6 rounded-2xl">
            <p className="text-sm text-amber-500 font-bold mb-1">الاسم الكامل</p>
            <p className="text-2xl font-black text-blue-900">{teacher.name}</p>
          </div>

           <div className="dashboard-account-record bg-green-50 p-6 rounded-2xl">
            <p className="text-sm text-green-600 font-bold mb-1">اسم المستخدم</p>
            <p className="text-2xl font-black text-green-900">@{teacher.username}</p>
          </div>

           <div className="dashboard-account-record bg-purple-50 p-6 rounded-2xl">
            <p className="text-sm text-purple-600 font-bold mb-1">هوية المعلم</p>
            <p className="text-2xl font-black text-purple-900">{teacher.teacherId}</p>
          </div>

           <div className="dashboard-account-record bg-orange-50 p-6 rounded-2xl">
            <p className="text-sm text-orange-600 font-bold mb-1">تاريخ الإنشاء</p>
            <p className="text-2xl font-black text-orange-900">
              {new Date(teacher.createdAt).toLocaleDateString('ar-SA')}
            </p>
          </div>
        </div>
      </div>

      {/* تغيير كلمة المرور */}
       <div className="dashboard-surface border-amber-100">
         <div className="dashboard-section-header mb-6">
          <h2 className="text-2xl font-black text-amber-900">🔐 كلمة المرور</h2>
          <button
            onClick={() => setShowChangePassword(!showChangePassword)}
            className="bg-blue-600 hover:bg-blue-700 text-white px-6 py-3 rounded-2xl font-bold transition-all"
          >
            {showChangePassword ? '❌ إلغاء' : '🔄 تغيير كلمة المرور'}
          </button>
        </div>

        {showChangePassword && (
          <form onSubmit={handleChangePassword} className="space-y-4">
            {error && (
              <div className="bg-red-50 border-2 border-red-200 text-red-700 p-4 rounded-2xl font-bold text-center">
                {error}
              </div>
            )}

            <div>
              <label className="block font-bold text-amber-700 mb-2">🔑 كلمة المرور الحالية</label>
              <input
                type="password"
                value={currentPassword}
                onChange={(e) => setCurrentPassword(e.target.value)}
                className="w-full p-4 border-2 border-amber-200 rounded-2xl outline-none focus:border-amber-400 font-bold text-lg"
                placeholder="أدخل كلمة المرور الحالية"
                required
              />
            </div>

            <div>
              <label className="block font-bold text-amber-700 mb-2">🆕 كلمة المرور الجديدة</label>
              <input
                type="password"
                value={newPassword}
                onChange={(e) => setNewPassword(e.target.value)}
                className="w-full p-4 border-2 border-amber-200 rounded-2xl outline-none focus:border-amber-400 font-bold text-lg"
                placeholder="أدخل كلمة المرور الجديدة"
                required
              />
            </div>

            <div>
              <label className="block font-bold text-amber-700 mb-2">✅ تأكيد كلمة المرور</label>
              <input
                type="password"
                value={confirmPassword}
                onChange={(e) => setConfirmPassword(e.target.value)}
                className="w-full p-4 border-2 border-amber-200 rounded-2xl outline-none focus:border-amber-400 font-bold text-lg"
                placeholder="أعد إدخال كلمة المرور الجديدة"
                required
              />
            </div>

            <button
              type="submit"
              className="w-full bg-gradient-to-r from-amber-400 to-orange-500 text-white py-5 rounded-[24px] font-black text-xl shadow-xl hover:shadow-2xl transition-all"
            >
              💾 حفظ كلمة المرور الجديدة
            </button>
          </form>
        )}
      </div>
    </div>
  );
};

export default MyAccount;
