import React, { useEffect, useMemo, useState } from 'react';
import { ParentInfo, PermissionPackage, PermissionPackageRole, StudentInfo } from '../../types';
import { DEFAULT_PERMISSIONS, STORAGE_KEYS } from '../../constants';
import {
  getEffectiveParentPermissions,
  getPermissionPackages,
  getPermissions,
  getStudentPermissions,
  getTeacherPermissions,
} from '../../permissions';
import {
  getParentChildren,
  getTeacherParents,
  getTeacherStudents,
} from '../../utils/scope';
import { writeActiveSession } from '../../utils/storage';

type ManagerRole = 'teacher' | 'parent';
type TargetRole = 'parent' | 'student';
type PackageDraft = Record<string, boolean | number>;

interface PermissionPackageManagementProps {
  managerRole: ManagerRole;
  teacherId?: string;
  teacherName?: string;
  teacherPermissionPackageId?: string;
  parent?: ParentInfo | null;
}

const targetLabels: Record<TargetRole, string> = {
  parent: 'أولياء الأمور',
  student: 'الطلاب',
};

const roleLabels: Record<PermissionPackageRole, string> = {
  teacher: 'إدارة صلاحيات المعلم',
  parent: 'إدارة صلاحيات ولي الأمر',
  student: 'إدارة صلاحيات الطالب',
};

const permissionLabels: Record<string, string> = {
  canManageAcademicSettings: 'إدارة الإعدادات الأكاديمية',
  canEditGeneralSettings: 'تعديل الإعدادات العامة',
  canManageContent: 'إدارة المحتوى',
  canManageVideos: 'إدارة الفيديوهات',
  canCreateParents: 'إنشاء أولياء أمور',
  canEditParents: 'تعديل أولياء أمور',
  canDeleteParents: 'حذف أولياء أمور',
  canManageParentPermissions: 'إدارة صلاحيات أولياء الأمور',
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

const packagePermissionCount = (pkg: PermissionPackage) =>
  Object.values(pkg.permissions as Record<string, unknown>).filter(value => value === true).length;

const getTargetName = (target: ParentInfo | StudentInfo) => target.name;

const getManagerId = (
  managerRole: ManagerRole,
  teacherId?: string,
  parent?: ParentInfo | null,
) => managerRole === 'teacher' ? teacherId : parent?.id;

const packageBelongsToManager = (
  pkg: PermissionPackage,
  managerRole: ManagerRole,
  managerId?: string,
) => pkg.ownerRole === managerRole && Boolean(managerId) && pkg.ownerId === managerId;

const PermissionPackageManagement: React.FC<PermissionPackageManagementProps> = ({
  managerRole,
  teacherId,
  teacherName,
  teacherPermissionPackageId,
  parent,
}) => {
  const [packages, setPackages] = useState<PermissionPackage[]>([]);
  const [parents, setParents] = useState<ParentInfo[]>([]);
  const [students, setStudents] = useState<StudentInfo[]>([]);
  const [activeTargetRole, setActiveTargetRole] = useState<TargetRole>(
    managerRole === 'teacher' ? 'parent' : 'student',
  );
  const [showEditor, setShowEditor] = useState(false);
  const [editingPackage, setEditingPackage] = useState<PermissionPackage | null>(null);
  const [editorRole, setEditorRole] = useState<PermissionPackageRole>(
    managerRole === 'teacher' ? 'parent' : 'student',
  );
  const [packageName, setPackageName] = useState('');
  const [packageDescription, setPackageDescription] = useState('');
  const [packageDraft, setPackageDraft] = useState<PackageDraft>({});

  const managerId = getManagerId(managerRole, teacherId, parent);
  const teacherPermissions = managerRole === 'teacher'
    ? getTeacherPermissions({ permissionPackageId: teacherPermissionPackageId })
    : null;
  const parentPermissions = managerRole === 'parent'
    ? getEffectiveParentPermissions(parent)
    : null;

  const loadData = () => {
    setPackages(getPermissionPackages());

    const allParents: ParentInfo[] = JSON.parse(
      localStorage.getItem(STORAGE_KEYS.PARENTS) || '[]',
    );
    const allStudents: StudentInfo[] = JSON.parse(
      localStorage.getItem(STORAGE_KEYS.STUDENTS) || '[]',
    );

    if (managerRole === 'teacher' && teacherId) {
      const ownedParents = getTeacherParents(allParents, teacherId);
      setParents(ownedParents);
      setStudents(getTeacherStudents(allStudents, teacherId, ownedParents));
      return;
    }

    if (managerRole === 'parent' && parent) {
      setParents([]);
      setStudents(getParentChildren(allStudents, parent));
      return;
    }

    setParents([]);
    setStudents([]);
  };

  useEffect(() => {
    loadData();
  }, [managerRole, teacherId, parent?.id]);

  const visibleTargets = useMemo(
    () => activeTargetRole === 'parent' ? parents : students,
    [activeTargetRole, parents, students],
  );

  const visiblePackages = useMemo(
    () => packages.filter(pkg =>
      pkg.role === activeTargetRole
      && (
        !pkg.ownerRole
        || pkg.ownerRole === 'admin'
        || packageBelongsToManager(pkg, managerRole, managerId)
        || (
          managerRole === 'parent'
          && activeTargetRole === 'student'
          && students.some(student => student.permissionPackageId === pkg.id)
        )
      ),
    ),
    [packages, activeTargetRole, managerRole, managerId, students],
  );

  const canManageTarget = (role: TargetRole) => {
    if (managerRole === 'teacher' && !teacherPermissions?.canCreatePermissionPackages) return false;
    if (managerRole === 'parent' && !parentPermissions?.canCreatePermissionPackages) return false;
    if (managerRole === 'teacher') {
      if (role === 'parent') return Boolean(teacherPermissions?.canManageParentPermissions);
      return Boolean(teacherPermissions?.canEditStudents);
    }
    return role === 'student' && Boolean(parentPermissions?.canEditStudents);
  };

  const canCreateOrEditPackage = (role: PermissionPackageRole) => {
    // A manager can create packages only for delegated accounts, never for
    // their own role. Teachers manage parent/student packages; parents manage
    // student packages.
    const canCreatePackages = managerRole === 'teacher'
      ? Boolean(teacherPermissions?.canCreatePermissionPackages)
      : Boolean(parentPermissions?.canCreatePermissionPackages);
    return canCreatePackages && role !== managerRole && role !== 'teacher' && canManageTarget(role);
  };

  const startNewPackage = (role: PermissionPackageRole = activeTargetRole) => {
    const globalRolePermissions = (getPermissions()[role] || DEFAULT_PERMISSIONS[role]) as PackageDraft;
    setEditorRole(role);
    setEditingPackage(null);
    setPackageName('');
    setPackageDescription('');
    setPackageDraft(clone(globalRolePermissions));
    setShowEditor(true);
  };

  const startEditPackage = (pkg: PermissionPackage) => {
    if (!packageBelongsToManager(pkg, managerRole, managerId)) {
      alert('🔒 هذا الإعداد مملوك للمشرف أو لحساب آخر ولا يمكن تعديله من هنا');
      return;
    }
    if (!canCreateOrEditPackage(pkg.role)) {
      alert('⚠️ لا تملك صلاحية تعديل إعدادات الصلاحيات لهذا الدور');
      return;
    }
    setEditorRole(pkg.role);
    setEditingPackage(pkg);
    setPackageName(pkg.name);
    setPackageDescription(pkg.description || '');
    setPackageDraft(clone(pkg.permissions as PackageDraft));
    setShowEditor(true);
  };

  const closeEditor = () => {
    setShowEditor(false);
    setEditingPackage(null);
  };

  const savePackage = (event: React.FormEvent) => {
    event.preventDefault();
    if (editorRole === managerRole) {
      alert('⚠️ لا يمكنك إنشاء أو تعديل إعداد صلاحيات لدورك الشخصي');
      return;
    }
    if (!managerId || !canCreateOrEditPackage(editorRole)) {
      alert('⚠️ لا تملك صلاحية إنشاء أو تعديل إعدادات الصلاحيات لهذا الدور');
      return;
    }
    if (!packageName.trim()) {
      alert('يرجى كتابة اسم إعداد الصلاحيات');
      return;
    }

    const globalRolePermissions = (getPermissions()[editorRole] || DEFAULT_PERMISSIONS[editorRole]) as PackageDraft;
    const safePermissions: PackageDraft = {};
    Object.keys(globalRolePermissions).forEach(key => {
      const globalValue = globalRolePermissions[key];
      const requestedValue = packageDraft[key];
      if (typeof globalValue === 'boolean') {
        safePermissions[key] = globalValue && requestedValue !== false;
      } else {
        const globalLimit = Number.isFinite(Number(globalValue)) ? Math.max(-1, Number(globalValue)) : -1;
        const requestedLimit = Number.isFinite(Number(requestedValue))
          ? Math.max(-1, Number(requestedValue))
          : globalLimit;
        safePermissions[key] = globalLimit < 0
          ? requestedLimit
          : requestedLimit < 0
            ? globalLimit
            : Math.min(globalLimit, requestedLimit);
      }
    });

    const now = new Date().toISOString();
    const latestPackages = getPermissionPackages();
    const nextPackage: PermissionPackage = {
      id: editingPackage?.id || `permission_package_${Date.now()}_${Math.random().toString(36).slice(2)}`,
      name: packageName.trim(),
      description: packageDescription.trim(),
      role: editorRole as PermissionPackageRole,
      permissions: safePermissions as PermissionPackage['permissions'],
      createdAt: editingPackage?.createdAt || now,
      updatedAt: now,
      ownerRole: managerRole,
      ownerId: managerId,
      ownerName: managerRole === 'teacher' ? teacherName : parent?.name,
    };
    const updated = editingPackage
      ? latestPackages.map(pkg => pkg.id === editingPackage.id ? nextPackage : pkg)
      : [...latestPackages, nextPackage];

    localStorage.setItem(STORAGE_KEYS.PERMISSION_PACKAGES, JSON.stringify(updated));
    setPackages(updated);
    closeEditor();
    alert(`✅ تم ${editingPackage ? 'تعديل' : 'إنشاء'} ${nextPackage.name} بنجاح`);
  };

  const deletePackage = (pkg: PermissionPackage) => {
    if (!packageBelongsToManager(pkg, managerRole, managerId)) {
      alert('🔒 لا يمكن حذف إعداد المشرف أو إعداد حساب آخر');
      return;
    }
    if (!confirm(`حذف إعداد الصلاحيات «${pkg.name}»؟`)) return;

    const teachers: any[] = JSON.parse(localStorage.getItem(STORAGE_KEYS.TEACHERS) || '[]');
    const allParents: ParentInfo[] = JSON.parse(localStorage.getItem(STORAGE_KEYS.PARENTS) || '[]');
    const allStudents: StudentInfo[] = JSON.parse(localStorage.getItem(STORAGE_KEYS.STUDENTS) || '[]');
    const used = teachers.some(item => item.permissionPackageId === pkg.id)
      || allParents.some(item => item.permissionPackageId === pkg.id)
      || allStudents.some(item => item.permissionPackageId === pkg.id);
    if (used) {
      alert('⚠️ لا يمكن حذف إعداد مستخدم حاليًا. غيّر الإعداد المرتبط بالحسابات أولًا.');
      return;
    }

    const updated = packages.filter(item => item.id !== pkg.id);
    localStorage.setItem(STORAGE_KEYS.PERMISSION_PACKAGES, JSON.stringify(updated));
    setPackages(updated);
  };

  const assignPackage = (target: ParentInfo | StudentInfo, role: TargetRole, packageId: string) => {
    if (!canManageTarget(role)) {
      alert('⚠️ لا تملك الصلاحية لإسناد إعداد صلاحيات لهذا الدور');
      return;
    }
    if (packageId && !visiblePackages.some(pkg => pkg.id === packageId && pkg.role === role)) {
      alert('⚠️ إعداد الصلاحيات المختار غير متاح لهذا الدور');
      return;
    }

    const nextPackageId = packageId || undefined;
    const allParents: ParentInfo[] = JSON.parse(localStorage.getItem(STORAGE_KEYS.PARENTS) || '[]');
    const allStudents: StudentInfo[] = JSON.parse(localStorage.getItem(STORAGE_KEYS.STUDENTS) || '[]');

    if (role === 'parent') {
      localStorage.setItem(STORAGE_KEYS.PARENTS, JSON.stringify(allParents.map(item =>
        item.id === target.id ? { ...item, permissionPackageId: nextPackageId } : item,
      )));
    } else {
      localStorage.setItem(STORAGE_KEYS.STUDENTS, JSON.stringify(allStudents.map(item =>
        item.id === target.id ? { ...item, permissionPackageId: nextPackageId } : item,
      )));
      const updatedParents = allParents.map(item => ({
        ...item,
        children: (item.children || []).map(child =>
          child.id === target.id ? { ...child, permissionPackageId: nextPackageId } : child,
        ),
      }));
      localStorage.setItem(STORAGE_KEYS.PARENTS, JSON.stringify(updatedParents));
      if (managerRole === 'parent' && parent) {
        writeActiveSession(
          STORAGE_KEYS.ACTIVE_PARENT,
          updatedParents.find(item => item.id === parent.id) || parent,
        );
      }
    }

    loadData();
    const selectedPackage = packages.find(pkg => pkg.id === packageId);
    alert(selectedPackage
      ? `✅ تم إسناد إعداد الصلاحيات «${selectedPackage.name}» إلى ${getTargetName(target)}`
      : `✅ تمت إعادة ${getTargetName(target)} إلى الصلاحيات العامة`);
  };

  const managerDescription = managerRole === 'teacher'
     ? 'أنشئ وعدّل إعدادات صلاحيات أولياء الأمور والطلاب التابعين لك، ثم أسندها للحساب المناسب.'
     : 'أنشئ وعدّل إعدادات صلاحيات الطلاب، ثم أسندها لأبنائك فقط.';

  return (
    <div className="space-y-6 animate-fadeIn" dir="rtl">
      <div className={`dashboard-page-banner ${
        managerRole === 'teacher'
          ? 'bg-gradient-to-r from-amber-500 to-orange-500'
          : 'bg-gradient-to-r from-rose-500 to-pink-600'
      }`}>
         <h1 className="text-2xl font-black">🔐 إدارة الصلاحيات</h1>
        <p className="mt-2 font-bold text-white/80">{managerDescription}</p>
        <p className="mt-1 text-sm font-bold text-white/70">
           سياسة المشرف هي الحد الأعلى، ولا يمكن لأي دور منح صلاحية غير مسموحة بها.
        </p>
      </div>

      <div className="flex flex-wrap gap-3">
        {(managerRole === 'teacher' ? (['parent', 'student'] as TargetRole[]) : (['student'] as TargetRole[])).map(role => (
          <button
            key={role}
            onClick={() => setActiveTargetRole(role)}
            className={`rounded-2xl px-5 py-3 font-black transition-all ${
              activeTargetRole === role
                ? managerRole === 'teacher' ? 'bg-amber-600 text-white shadow-lg' : 'bg-rose-600 text-white shadow-lg'
                : 'bg-white text-slate-600 shadow-sm'
            }`}
          >
            {role === 'parent' ? '👨‍👩‍👧‍👦' : '🎓'} {targetLabels[role]}
            <span className="mr-2 text-xs opacity-75">({role === 'parent' ? parents.length : students.length})</span>
          </button>
        ))}
        {canCreateOrEditPackage(activeTargetRole) && (
          <button
            onClick={() => startNewPackage(activeTargetRole)}
            className="rounded-2xl bg-emerald-600 px-5 py-3 font-black text-white shadow-lg hover:bg-emerald-700"
          >
            ➕ إنشاء {roleLabels[activeTargetRole]}
          </button>
        )}
      </div>

      {showEditor && (
        <form onSubmit={savePackage} className="rounded-3xl border-2 border-indigo-100 bg-white p-6 shadow-lg">
          <div className="flex flex-wrap items-center justify-between gap-3">
            <div>
              <h2 className="text-xl font-black text-indigo-900">
                {editingPackage ? '✏️ تعديل إعداد الصلاحيات' : '✨ إنشاء إعداد صلاحيات جديد'}
              </h2>
              <p className="mt-1 text-sm font-bold text-slate-500">{roleLabels[editorRole]}</p>
            </div>
            <button type="button" onClick={closeEditor} className="rounded-xl bg-slate-100 px-4 py-2 font-black text-slate-600">
              إلغاء
            </button>
          </div>
          <div className="mt-5 grid grid-cols-1 gap-4 md:grid-cols-2">
            <input
              value={packageName}
              onChange={event => setPackageName(event.target.value)}
              placeholder="اسم إعداد الصلاحيات"
              className="w-full rounded-xl border-2 border-indigo-100 p-3 font-bold outline-none focus:border-indigo-400"
              required
            />
            <input
              value={packageDescription}
              onChange={event => setPackageDescription(event.target.value)}
              placeholder="وصف إعداد الصلاحيات (اختياري)"
              className="w-full rounded-xl border-2 border-indigo-100 p-3 font-bold outline-none focus:border-indigo-400"
            />
          </div>
          <div className="mt-5 grid grid-cols-1 gap-3 md:grid-cols-2">
            {Object.entries(packageDraft).filter(([, value]) => typeof value === 'boolean').map(([key, value]) => (
              <label key={key} className="flex min-w-0 flex-wrap items-center justify-between gap-3 rounded-xl bg-slate-50 p-3 font-bold text-slate-700">
                <span className="min-w-0 flex-1 break-words">{permissionLabels[key] || key}</span>
                <input
                  type="checkbox"
                  checked={Boolean(value)}
                  onChange={() => setPackageDraft(previous => ({ ...previous, [key]: !previous[key] }))}
                  className="h-5 w-5 shrink-0 accent-indigo-600"
                />
              </label>
            ))}
          </div>
          {roleLimitKeys[editorRole].length > 0 && (
            <div className="mt-5 grid grid-cols-1 gap-3 md:grid-cols-2">
              {roleLimitKeys[editorRole].map(key => (
                <label key={key} className="text-sm font-black text-slate-700">
                  {limitLabels[key]} <span className="text-xs text-slate-400">(-1 غير محدود)</span>
                  <input
                    type="number"
                    min="-1"
                    value={Number(packageDraft[key] ?? -1)}
                    onChange={event => setPackageDraft(previous => ({ ...previous, [key]: Math.max(-1, Number(event.target.value)) }))}
                    className="mt-1 w-full rounded-xl border-2 border-slate-200 p-3 font-black outline-none focus:border-indigo-400"
                  />
                </label>
              ))}
            </div>
          )}
          <button type="submit" className="mt-5 w-full rounded-xl bg-indigo-600 py-3 font-black text-white hover:bg-indigo-700">
            💾 حفظ إعداد الصلاحيات
          </button>
        </form>
      )}

      {!canManageTarget(activeTargetRole) && (
        <div className="rounded-2xl border-2 border-amber-200 bg-amber-50 p-4 font-bold text-amber-800">
          🔒 لا توجد لديك صلاحية لإدارة الصلاحيات لهذا الدور. اطلب من المشرف تفعيل الصلاحية المناسبة.
        </div>
      )}

      <div className="dashboard-surface space-y-3">
        <h2 className="text-xl font-black text-slate-800">إعدادات الصلاحيات المتاحة — {targetLabels[activeTargetRole]}</h2>
        {visiblePackages.length === 0 && (
           <div className="rounded-3xl border-2 border-dashed border-slate-200 bg-white p-5 text-center font-bold text-slate-500 sm:p-10">
            لا توجد إعدادات صلاحيات لهذا الدور حاليًا.
          </div>
        )}
        <div className="grid grid-cols-1 gap-3 md:grid-cols-2">
          {visiblePackages.map(pkg => {
            const isOwner = packageBelongsToManager(pkg, managerRole, managerId);
            return (
              <div key={pkg.id} className="rounded-3xl border border-slate-200 bg-white p-5 shadow-sm">
                <div className="flex items-start justify-between gap-3">
                  <div>
                    <h3 className="text-lg font-black text-slate-800">{pkg.name}</h3>
                    <p className="mt-1 text-sm font-bold text-slate-500">{pkg.description || 'بدون وصف'}</p>
                  </div>
                  <span className={`rounded-full px-3 py-1 text-xs font-black ${isOwner ? 'bg-emerald-100 text-emerald-700' : 'bg-slate-100 text-slate-600'}`}>
                    {isOwner ? 'إعدادي' : 'إعداد مشرف'}
                  </span>
                </div>
                <p className="mt-3 text-xs font-bold text-slate-400">{packagePermissionCount(pkg)} صلاحيات مفعلة</p>
              </div>
            );
          })}
        </div>
      </div>

      <div className="dashboard-surface space-y-3">
         <h2 className="text-xl font-black text-slate-800">إسناد إعدادات الصلاحيات</h2>
        {visibleTargets.map(target => {
          const assignedPackageId = target.permissionPackageId || '';
           const assignedPackage = packages.find(pkg => pkg.id === assignedPackageId && pkg.role === activeTargetRole);
           const effectiveStudentPermissions = activeTargetRole === 'student'
             ? getStudentPermissions(target as StudentInfo)
             : null;
           const activePermissionLabels = effectiveStudentPermissions
             ? Object.entries(effectiveStudentPermissions)
               .filter(([, value]) => value === true)
               .map(([key]) => permissionLabels[key] || key)
             : [];
          return (
            <div key={target.id} className="rounded-3xl border border-slate-200 bg-white p-5 shadow-sm">
              <div className="flex flex-wrap items-center justify-between gap-3">
                <div>
                  <h3 className="text-lg font-black text-slate-800">{getTargetName(target)}</h3>
                  <p className="mt-1 text-sm font-bold text-slate-500">
                     {assignedPackage ? `الإعداد الحالي: ${assignedPackage.name}` : 'يستخدم الصلاحيات العامة'}
                  </p>
                   {effectiveStudentPermissions && (
                     <div className="mt-2 flex flex-wrap gap-1.5">
                       {activePermissionLabels.length > 0 ? activePermissionLabels.map(label => (
                         <span key={label} className="rounded-full bg-indigo-50 px-2 py-1 text-[11px] font-black text-indigo-700">
                           ✓ {label}
                         </span>
                       )) : (
                         <span className="text-xs font-bold text-slate-400">لا توجد صلاحيات إضافية مفعلة</span>
                       )}
                     </div>
                   )}
                </div>
                <select
                  value={assignedPackageId}
                  disabled={!canManageTarget(activeTargetRole)}
                  onChange={event => assignPackage(target, activeTargetRole, event.target.value)}
                   className="w-full min-w-0 rounded-xl border-2 border-slate-200 bg-white p-3 font-bold outline-none focus:border-indigo-400 disabled:cursor-not-allowed disabled:bg-slate-100 sm:w-auto sm:min-w-64"
                >
                  <option value="">الصلاحيات العامة</option>
                   {visiblePackages.map(pkg => (
                    <option key={pkg.id} value={pkg.id}>{pkg.name}</option>
                  ))}
                </select>
              </div>
            </div>
          );
        })}
        {visibleTargets.length === 0 && (
           <div className="rounded-3xl border-2 border-dashed border-slate-200 bg-white p-5 text-center font-bold text-slate-500 sm:p-10">
            لا توجد حسابات تابعة لهذا الدور حاليًا.
          </div>
        )}
      </div>
    </div>
  );
};

export default PermissionPackageManagement;