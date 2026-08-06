
import React, { useState, useEffect } from 'react';
import { AdminSettings } from '../../types';
import { STORAGE_KEYS, COLORS } from '../../constants';

const SystemSettings: React.FC = () => {
  const [settings, setSettings] = useState<AdminSettings>({
    chatEnabled: true,
    allowGradeChange: false,
    maxStudentsPerParent: 5,
    quizPassingScore: 60,
    adminContactInfo: '',
  });

  useEffect(() => {
    const saved = localStorage.getItem(STORAGE_KEYS.ADMIN_SETTINGS);
    if (saved) setSettings(JSON.parse(saved));
  }, []);

  const saveSettings = () => {
    localStorage.setItem(STORAGE_KEYS.ADMIN_SETTINGS, JSON.stringify(settings));
    alert('تم حفظ الإعدادات بنجاح');
  };

  return (
    <div className="space-y-10 animate-fadeIn">
      <div>
        <h1 className="text-3xl font-bold">إعدادات النظام</h1>
        <p className="text-purple-500">تحكم في الخصائص العامة للمنصة</p>
      </div>

      <div className="bg-white rounded-3xl shadow-sm border p-10 max-w-2xl space-y-8 text-right">
        <div className="flex items-center justify-between">
           <div>
              <h3 className="font-bold text-lg">تفعيل الدردشة الجماعية</h3>
              <p className="text-sm text-purple-400">السماح للطلاب بالتواصل في غرف الدردشة</p>
           </div>
           <input 
            type="checkbox" 
            checked={settings.chatEnabled} 
            onChange={e => setSettings({...settings, chatEnabled: e.target.checked})}
            className="w-6 h-6"
           />
        </div>

        <div className="flex items-center justify-between">
           <div>
              <h3 className="font-bold text-lg">السماح بتغيير الصف</h3>
              <p className="text-sm text-purple-400">تمكين الطلاب من تغيير صفهم الدراسي بأنفسهم</p>
           </div>
           <input 
            type="checkbox" 
            checked={settings.allowGradeChange} 
            onChange={e => setSettings({...settings, allowGradeChange: e.target.checked})}
            className="w-6 h-6"
           />
        </div>

        <div className="space-y-2">
           <h3 className="font-bold text-lg">درجة النجاح (%)</h3>
           <input 
            type="number" 
            value={settings.quizPassingScore} 
            onChange={e => setSettings({...settings, quizPassingScore: parseInt(e.target.value)})}
            className="w-full p-4 bg-purple-50 border rounded-2xl outline-none focus:border-purple-400 focus:ring-4 focus:ring-purple-100"
           />
        </div>

        <div className="space-y-2">
           <h3 className="font-bold text-lg">📞 رقم هاتف المشرف للتواصل</h3>
           <p className="text-sm text-purple-400">سيظهر هذا الرقم في الدردشة للمعلمين فقط</p>
           <input 
            type="text" 
            value={settings.adminContactInfo || ''} 
            onChange={e => setSettings({...settings, adminContactInfo: e.target.value})}
            placeholder="مثال: 0501234567"
            className="w-full p-4 bg-purple-50 border rounded-2xl outline-none focus:border-purple-400 focus:ring-4 focus:ring-purple-100"
            dir="ltr"
           />
        </div>

        <button 
          onClick={saveSettings}
          className="w-full bg-purple-500 text-white py-4 rounded-2xl font-bold hover:bg-purple-600"
        >
          حفظ التغييرات
        </button>
      </div>
    </div>
  );
};

export default SystemSettings;
