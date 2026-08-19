import React, { useEffect, useMemo, useState } from 'react';
import {
  PermissionPackage,
  PermissionPackageRole,
  Permissions,
} from '../../types';
import { COLORS, DEFAULT_PERMISSIONS, STORAGE_KEYS } from '../../constants';
import { getPermissionPackages, getPermissions } from '../../permissions';

interface PermissionPackagesProps {
  onUpdate?: () => void;
}

const roleLabels: Record<PermissionPackageRole, string> = {
  teacher: '👨‍🏫 المعلمين',
  parent: '👨‍👩‍👧 أولياء الأمور',
  student: '🎓 الطلاب',
};

const permissionLabels: Record<string, string> = {
  canManageAcademicSettings: 'إدارة الإعدادات الأكاديمية',
  canEditGeneralSettings: 'تعديل الإعدادات العامة',
  canManageContent: 'إدارة المحتوى التعليمي',
  canManageVideos: 'إدارة الفيديوهات',
  canCreateParents: 'إنشاء أولياء أمور',
  canEditParents: 'تعديل أولياء أمور',
  canDeleteParents: 'حذف أولياء أمور',
  canManageParentPermissions: 'منح صلاحيات مخصصة لولي الأمر',
  canCreatePermissionPackages: 'إنشاء بكجات صلاحيات',
  canCreateStudents: 'إنشاء طلاب/أبناء',
  canEditStudents: 'تعديل الطلاب/الأبناء',
  canDeleteStudents: 'حذف الطلاب/الأبناء',
  canViewReports: 'عرض التقارير',
  canManageQuizzes: 'إدارة الاختبارات',
  canResetStudentPassword: 'إعادة تعيين كلمة مرور الأبناء',
  canChangeGrade: 'تغيير الصف',
  canChatWithSupport: 'الدردشة مع الدعم',
  canAccessChat: 'الوصول للدردشة',
  canAccessLiveMeeting: 'الوصول للقاءات المباشرة',
  canRetakeQuiz: 'إعادة الاختبار',
  canViewSolutions: 'عرض الحلول',
  canDownloadCertificates: 'تحميل الشهادات',
};

const limitLabels: Record<string, string> = {
  maxParents: 'الحد الأقصى لأولياء الأمور',
  maxStudents: 'الحد الأقصى للطلاب/الأبناء',
  maxContent: 'الحد الأقصى للمحتوى',
  maxVideos: 'الحد الأقصى للفيديوهات',
  maxStorageMb: 'مساحة الفيديوهات بالميجابايت',
};

const roleLimitKeys: Record<PermissionPackageRole, string[]> = {
  teacher: ['maxParents', 'maxStudents', 'maxContent', 'maxVideos', 'maxStorageMb'],
  parent: ['maxStudents'],
  student: [],
};

const clone = <T,>(value: T): T => JSON.parse(JSON.stringify(value));

const PermissionPackages: React.FC<PermissionPackagesProps> = ({ onUpdate }) => {
  const [packages, setPackages] = useState<PermissionPackage[]>([]);
  const [activeRole, setActiveRole] = useState<PermissionPackageRole>('teacher');
  const [editingPackage, setEditingPackage] = useState<PermissionPackage | null>(null);
  const [name, setName] = useState('');
  const [description, setDescription] = useState('');
  const [draft, setDraft] = useState<Record<string, boolean | number>>({});

  const startNew = (role = activeRole) => {
    setActiveRole(role);
    setEditingPackage(null);
    setName('');
    setDescription('');
    setDraft(clone((getPermissions()[role] || DEFAULT_PERMISSIONS[role]) as Record<string, boolean | number>));
  };

  const loadPackages = () => setPackages(getPermissionPackages());

  useEffect(() => {
    loadPackages();
    startNew('teacher');
  }, []);

  const handleEdit = (pkg: PermissionPackage) => {
    setActiveRole(pkg.role);
    setEditingPackage(pkg);
    setName(pkg.name);
    setDescription(pkg.description || '');
    setDraft(clone(pkg.permissions as Record<string, boolean | number>));
  };

  const handleSave = (event: React.FormEvent) => {
    event.preventDefault();
    if (!name.trim()) {
      alert('يرجى كتابة اسم إعداد الصلاحيات');
      return;
    }

    const now = new Date().toISOString();
    // Read the latest local value before writing so a second save can never
    // overwrite a package that was saved moments earlier.
    const latestPackages = getPermissionPackages();
    const nextPackage: PermissionPackage = {
      id: editingPackage?.id || `permission_package_${Date.now()}_${globalThis.crypto?.randomUUID?.() || Math.random().toString(36).slice(2)}`,
      name: name.trim(),
      description: description.trim(),
      role: activeRole,
      permissions: clone(
        (Object.keys(draft).length > 0
          ? draft
          : getPermissions()[activeRole] || DEFAULT_PERMISSIONS[activeRole]) as PermissionPackage['permissions'],
      ),
      createdAt: editingPackage?.createdAt || now,
      updatedAt: now,
    };
    const updated = editingPackage
      ? latestPackages.map(pkg => pkg.id === editingPackage.id ? nextPackage : pkg)
      : [...latestPackages, nextPackage];

    localStorage.setItem(STORAGE_KEYS.PERMISSION_PACKAGES, JSON.stringify(updated));
    setPackages(updated);
    setEditingPackage(null);
    setName('');
    setDescription('');
    setDraft(clone((getPermissions()[activeRole] || DEFAULT_PERMISSIONS[activeRole]) as Record<string, boolean | number>));
    alert(`✅ تم حفظ إعداد ${nextPackage.name} بنجاح — إجمالي الإعدادات ${roleLabels[activeRole]}: ${updated.filter(pkg => pkg.role === activeRole).length}`);
    onUpdate?.();
  };

  const handleDelete = (pkg: PermissionPackage) => {
    const teachers = JSON.parse(localStorage.getItem(STORAGE_KEYS.TEACHERS) || '[]');
    const parents = JSON.parse(localStorage.getItem(STORAGE_KEYS.PARENTS) || '[]');
    const students = JSON.parse(localStorage.getItem(STORAGE_KEYS.STUDENTS) || '[]');
    const used =
      teachers.some((item: any) => item.permissionPackageId === pkg.id) ||
      parents.some((item: any) => item.permissionPackageId === pkg.id) ||
      students.some((item: any) => item.permissionPackageId === pkg.id);

    if (used) {
      alert('⚠️ لا يمكن حذف إعداد مستخدم حاليًا. غيّر الإعداد المرتبط بالحسابات أولاً.');
      return;
    }
    if (!confirm(`حذف إعداد الصلاحيات «${pkg.name}»؟`)) return;

    const updated = packages.filter(item => item.id !== pkg.id);
    localStorage.setItem(STORAGE_KEYS.PERMISSION_PACKAGES, JSON.stringify(updated));
    setPackages(updated);
    if (editingPackage?.id === pkg.id) startNew(activeRole);
    onUpdate?.();
  };

  const visiblePackages = useMemo(
    () => packages.filter(pkg => pkg.role === activeRole),
    [packages, activeRole],
  );

  const togglePermission = (key: string) => {
    setDraft(previous => ({ ...previous, [key]: !previous[key] }));
  };

  return (
    <div className="dashboard-page dashboard-consistent-page animate-fadeIn" dir="rtl">
       <div className="dashboard-section-header">
        <div>
          <h1 className="text-3xl font-black text-purple-900">🔐 إدارة الصلاحيات</h1>
          <p className="mt-1 font-bold text-purple-500">
           أنشئ إعدادات متعددة ومستقلة ثم اربط كل حساب بإعداد الصلاحيات المناسب له
          </p>
        </div>
        <button
          onClick={() => startNew(activeRole)}
          className="rounded-2xl bg-gradient-to-r from-purple-600 to-violet-600 px-6 py-3 font-black text-white shadow-lg hover:shadow-xl"
        >
           ➕ إنشاء إعداد صلاحيات جديد
        </button>
      </div>

       <div className="dashboard-card-grid">
        {(Object.keys(roleLabels) as PermissionPackageRole[]).map(role => (
          <button
            key={role}
            onClick={() => { setActiveRole(role); if (!editingPackage) startNew(role); }}
            className={`rounded-2xl border-2 p-4 text-right font-black transition-all ${
              activeRole === role
                ? 'border-purple-500 bg-purple-50 text-purple-900 shadow-md'
                : 'border-purple-100 bg-white text-purple-500 hover:border-purple-300'
            }`}
          >
            {roleLabels[role]}
            <span className="mt-1 block text-xs font-bold opacity-70">
               {packages.filter(pkg => pkg.role === role).length} إعدادات
            </span>
          </button>
        ))}
      </div>

      <div className="grid min-w-0 grid-cols-1 gap-6 xl:grid-cols-[minmax(0,1fr)_minmax(0,1.1fr)]">
         <div className="dashboard-surface min-w-0 space-y-3">
          <h2 className="text-xl font-black text-purple-900">إعدادات الصلاحيات المحفوظة — {roleLabels[activeRole]}</h2>
           <p className="text-sm font-bold text-purple-400">
             المحفوظ: {visiblePackages.length} إعدادات — حفظ إعداد جديد لا يحذف الإعدادات السابقة
           </p>
          {visiblePackages.length === 0 ? (
             <div className="rounded-3xl border-2 border-dashed border-purple-200 bg-white p-5 text-center font-bold text-purple-400 sm:p-12">
               لا توجد إعدادات لهذا الدور. أنشئ أول إعداد الآن.
            </div>
          ) : visiblePackages.map(pkg => (
            <div key={pkg.id} className="rounded-3xl border border-purple-100 bg-white p-5 shadow-sm">
              <div className="flex items-start justify-between gap-3">
                <div>
                  <h3 className="text-lg font-black text-purple-900">{pkg.name}</h3>
                  <p className="mt-1 text-sm font-bold text-slate-500">{pkg.description || 'بدون وصف'}</p>
                </div>
                <span className="rounded-full bg-purple-100 px-3 py-1 text-xs font-black text-purple-700">
                  {Object.values(pkg.permissions as Record<string, unknown>).filter(value => value === true).length} صلاحيات
                </span>
              </div>
              <div className="mt-4 flex gap-2">
                <button onClick={() => handleEdit(pkg)} className="flex-1 rounded-xl bg-blue-50 py-2 font-black text-blue-700 hover:bg-blue-100">✏️ تعديل</button>
                <button onClick={() => handleDelete(pkg)} className="rounded-xl bg-red-50 px-5 py-2 font-black text-red-600 hover:bg-red-100">🗑️ حذف</button>
              </div>
            </div>
          ))}
        </div>

        <form onSubmit={handleSave} className="dashboard-surface min-w-0 border-2 border-purple-100 shadow-lg">
          <h2 className="text-xl font-black text-purple-900">
             {editingPackage ? '✏️ تعديل إعداد الصلاحيات' : '✨ إنشاء إعداد صلاحيات'}
          </h2>
          <div className="mt-5 space-y-4">
             <input value={name} onChange={event => setName(event.target.value)} placeholder="اسم إعداد الصلاحيات، مثال: معلم متقدم" className="w-full rounded-xl border-2 border-purple-100 p-3 font-bold outline-none focus:border-purple-400" required />
             <textarea value={description} onChange={event => setDescription(event.target.value)} placeholder="وصف مختصر لإعداد الصلاحيات (اختياري)" className="min-h-20 w-full rounded-xl border-2 border-purple-100 p-3 font-bold outline-none focus:border-purple-400" />
          </div>

          <div className="mt-6 space-y-3">
            <h3 className="font-black text-slate-800">الصلاحيات</h3>
            {Object.entries(draft).filter(([, value]) => typeof value === 'boolean').map(([key, value]) => (
              <label key={key} className="flex min-w-0 flex-wrap cursor-pointer items-center justify-between gap-3 rounded-xl bg-slate-50 p-3 font-bold text-slate-700">
                <span className="min-w-0 flex-1 break-words">{permissionLabels[key] || key}</span>
                <input type="checkbox" checked={Boolean(value)} onChange={() => togglePermission(key)} className="h-5 w-5 shrink-0 accent-purple-600" />
              </label>
            ))}
          </div>

          {roleLimitKeys[activeRole].length > 0 && (
            <div className="mt-6 space-y-3">
              <h3 className="font-black text-slate-800">الحدود — استخدم -1 لغير محدود</h3>
              {roleLimitKeys[activeRole].map(key => (
                <label key={key} className="block text-sm font-black text-slate-700">
                  {limitLabels[key]}
                  <input
                    type="number"
                    min="-1"
                    value={Number(draft[key] ?? -1)}
                    onChange={event => setDraft(previous => ({ ...previous, [key]: Math.max(-1, Number(event.target.value)) }))}
                    className="mt-1 w-full rounded-xl border-2 border-slate-200 p-3 font-black outline-none focus:border-purple-400"
                  />
                </label>
              ))}
            </div>
          )}

          <div className="mt-6 flex gap-3">
            <button type="submit" className="flex-1 rounded-xl py-3 font-black text-white shadow-md hover:brightness-110" style={{ backgroundColor: COLORS.success }}>
               💾 حفظ إعداد الصلاحيات
            </button>
            <button type="button" onClick={() => startNew(activeRole)} className="rounded-xl bg-slate-100 px-5 py-3 font-black text-slate-700 hover:bg-slate-200">
              تفريغ
            </button>
          </div>
        </form>
      </div>
    </div>
  );
};

export default PermissionPackages;