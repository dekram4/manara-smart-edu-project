
import React, { useState, useEffect } from 'react';
import { AdminSettings } from '../../types';
import { STORAGE_KEYS, COLORS } from '../../constants';
import { fetchStudentApk, isAcceptableApkUrl, saveStudentApk } from '../../utils/studentApk';

/**
 * رابطُ تحميل تطبيق الطالب: يُحفظ في الخادم لا في هذا المتصفّح — فيظهر
 * لكل زائرٍ لشاشة اختيار الأدوار فور حفظه، بلا تعديل كود.
 */
const StudentApkSettings: React.FC = () => {
  const [url, setUrl] = useState('');
  const [isDefault, setIsDefault] = useState(false);
  const [updatedAt, setUpdatedAt] = useState('');
  const [status, setStatus] = useState<{ kind: 'idle' | 'saving' | 'saved' | 'error'; message?: string }>({ kind: 'idle' });

  useEffect(() => {
    fetchStudentApk()
      .then((setting) => {
        setUrl(setting.url);
        setIsDefault(setting.isDefault);
        setUpdatedAt(setting.updatedAt);
      })
      .catch((error) => setStatus({ kind: 'error', message: error instanceof Error ? error.message : 'تعذّر تحميل الرابط' }));
  }, []);

  const valid = isAcceptableApkUrl(url);

  const save = async () => {
    if (!valid) return;
    setStatus({ kind: 'saving' });
    try {
      const saved = await saveStudentApk(url.trim());
      setUrl(saved.url);
      setIsDefault(false);
      setUpdatedAt(saved.updatedAt);
      setStatus({ kind: 'saved', message: 'تم حفظ الرابط — يظهر الآن في شاشة اختيار الأدوار' });
    } catch (error) {
      setStatus({ kind: 'error', message: error instanceof Error ? error.message : 'تعذّر حفظ الرابط' });
    }
  };

  let note = '';
  if (isDefault) note = 'يُستخدم الآن رابطٌ مؤقّت (آخر نسخة بُنيت في GitHub) إلى أن تحفظ رابطك.';
  else if (updatedAt) note = `آخر تحديث: ${new Date(updatedAt).toLocaleString('ar-SA')}`;

  return (
    <div className="dashboard-surface w-full max-w-2xl space-y-3 text-right" data-testid="student-apk-settings">
      <h3 className="font-bold text-lg">📱 رابط تحميل تطبيق الطالب (Student APK URL)</h3>
      <p className="text-sm text-purple-400">
        يفتحه زرّ «تحميل تطبيق الطالب (Android APK)» في شاشة اختيار الأدوار. يُحفظ في الخادم ويظهر لجميع الزوار فوراً.
      </p>
      <input
        type="url"
        value={url}
        onChange={(e) => { setUrl(e.target.value); setStatus({ kind: 'idle' }); }}
        placeholder="https://example.com/manara-student.apk"
        className="w-full p-4 bg-purple-50 border rounded-2xl outline-none focus:border-purple-400 focus:ring-4 focus:ring-purple-100"
        dir="ltr"
        aria-invalid={!valid && url.length > 0}
      />
      {!valid && url.length > 0 && (
        <p className="text-sm font-bold text-red-500">الرابط يجب أن يبدأ بـ https://</p>
      )}
      {note && <p className="text-xs text-purple-400">{note}</p>}
      <div className="flex flex-wrap items-center gap-3">
        <button
          type="button"
          onClick={save}
          disabled={!valid || status.kind === 'saving'}
          className="bg-purple-500 text-white px-6 py-3 rounded-2xl font-bold hover:bg-purple-600 disabled:cursor-not-allowed disabled:opacity-50"
        >
          {status.kind === 'saving' ? 'جارٍ الحفظ…' : 'حفظ الرابط'}
        </button>
        {valid && (
          <a href={url.trim()} target="_blank" rel="noopener noreferrer" className="text-sm font-bold text-purple-600 underline">
            تجربة الرابط
          </a>
        )}
      </div>
      {status.kind === 'saved' && <p className="text-sm font-bold text-emerald-600">{status.message}</p>}
      {status.kind === 'error' && <p className="whitespace-pre-line text-sm font-bold text-red-500">{status.message}</p>}
    </div>
  );
};

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
    <div className="dashboard-page animate-fadeIn">
       <div className="dashboard-section-header">
        <h1 className="text-3xl font-bold">إعدادات النظام</h1>
        <p className="text-purple-500">تحكم في الخصائص العامة للمنصة</p>
      </div>

        <div className="dashboard-surface w-full max-w-2xl space-y-6 text-right sm:space-y-8">
         <div className="flex items-start justify-between gap-4">
            <div className="min-w-0">
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

         <div className="flex items-start justify-between gap-4">
            <div className="min-w-0">
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

      <div className="mt-6">
        <StudentApkSettings />
      </div>
    </div>
  );
};

export default SystemSettings;
