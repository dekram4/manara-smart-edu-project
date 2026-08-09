import React, { useEffect, useMemo, useState } from 'react';
import { ParentInfo, PermissionPackage, StudentInfo } from '../../types';
import { STORAGE_KEYS } from '../../constants';
import {
  getEffectiveParentPermissions,
  getPermissionPackages,
  getTeacherPermissions,
} from '../../permissions';
import {
  getParentChildren,
  getTeacherParents,
  getTeacherStudents,
} from '../../utils/scope';

type ManagerRole = 'teacher' | 'parent';
type TargetRole = 'parent' | 'student';

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

const packagePermissionCount = (pkg: PermissionPackage) =>
  Object.values(pkg.permissions as Record<string, unknown>).filter(value => value === true).length;

const getTargetName = (target: ParentInfo | StudentInfo) => target.name;

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
    () => packages.filter(pkg => pkg.role === activeTargetRole),
    [packages, activeTargetRole],
  );

  const canManageTarget = (role: TargetRole) => {
    if (managerRole === 'teacher') {
      if (role === 'parent') return Boolean(teacherPermissions?.canManageParentPermissions);
      return Boolean(teacherPermissions?.canEditStudents);
    }
    return role === 'student' && Boolean(parentPermissions?.canEditStudents);
  };

  const getAssignedPackageId = (target: ParentInfo | StudentInfo) =>
    target.permissionPackageId || '';

  const assignPackage = (target: ParentInfo | StudentInfo, role: TargetRole, packageId: string) => {
    if (!canManageTarget(role)) {
      alert('⚠️ لا تملك الصلاحية لإسناد بكج لهذا الدور');
      return;
    }

    if (packageId && !visiblePackages.some(pkg => pkg.id === packageId)) {
      alert('⚠️ البكج المختار غير متاح لهذا الدور');
      return;
    }

    const nextPackageId = packageId || undefined;
    const allParents: ParentInfo[] = JSON.parse(
      localStorage.getItem(STORAGE_KEYS.PARENTS) || '[]',
    );
    const allStudents: StudentInfo[] = JSON.parse(
      localStorage.getItem(STORAGE_KEYS.STUDENTS) || '[]',
    );

    if (role === 'parent') {
      const updatedParents = allParents.map(item =>
        item.id === target.id
          ? { ...item, permissionPackageId: nextPackageId }
          : item,
      );
      localStorage.setItem(STORAGE_KEYS.PARENTS, JSON.stringify(updatedParents));
    } else {
      const updatedStudents = allStudents.map(item =>
        item.id === target.id
          ? { ...item, permissionPackageId: nextPackageId }
          : item,
      );
      localStorage.setItem(STORAGE_KEYS.STUDENTS, JSON.stringify(updatedStudents));

      // Keep the embedded child copy in the parent record in sync with the
      // canonical student record used by dashboards and login hydration.
      const updatedParents = allParents.map(item => ({
        ...item,
        children: (item.children || []).map(child =>
          child.id === target.id
            ? { ...child, permissionPackageId: nextPackageId }
            : child,
        ),
      }));
      localStorage.setItem(STORAGE_KEYS.PARENTS, JSON.stringify(updatedParents));

      if (managerRole === 'parent' && parent) {
        localStorage.setItem(
          STORAGE_KEYS.ACTIVE_PARENT,
          JSON.stringify(updatedParents.find(item => item.id === parent.id) || parent),
        );
      }
    }

    loadData();
    const selectedPackage = visiblePackages.find(pkg => pkg.id === packageId);
    alert(
      selectedPackage
        ? `✅ تم إسناد بكج «${selectedPackage.name}» إلى ${getTargetName(target)}`
        : `✅ تمت إعادة ${getTargetName(target)} إلى الصلاحيات العامة`,
    );
  };

  const managerDescription = managerRole === 'teacher'
    ? 'اختر بكج ولي الأمر أو الطالب من البكجات التي أنشأها المشرف.'
    : 'اختر بكج الصلاحيات المناسب لكل ابن من البكجات المخصصة للطلاب.';

  return (
    <div className="space-y-6 animate-fadeIn" dir="rtl">
      <div className={`rounded-3xl p-6 text-white shadow-xl ${
        managerRole === 'teacher'
          ? 'bg-gradient-to-r from-amber-500 to-orange-500'
          : 'bg-gradient-to-r from-rose-500 to-pink-600'
      }`}>
        <h1 className="text-2xl font-black">📦 بكجات وصلاحيات الحسابات</h1>
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
                ? managerRole === 'teacher'
                  ? 'bg-amber-600 text-white shadow-lg'
                  : 'bg-rose-600 text-white shadow-lg'
                : 'bg-white text-slate-600 shadow-sm'
            }`}
          >
            {role === 'parent' ? '👨‍👩‍👧‍👦' : '🎓'} {targetLabels[role]}
            <span className="mr-2 text-xs opacity-75">
              ({role === 'parent' ? parents.length : students.length})
            </span>
          </button>
        ))}
      </div>

      {!canManageTarget(activeTargetRole) && (
        <div className="rounded-2xl border-2 border-amber-200 bg-amber-50 p-4 font-bold text-amber-800">
          🔒 لا توجد لديك صلاحية لإسناد بكجات لهذا الدور. اطلب من المشرف تفعيل صلاحية الإدارة المناسبة.
        </div>
      )}

      {visiblePackages.length === 0 && (
        <div className="rounded-3xl border-2 border-dashed border-slate-200 bg-white p-10 text-center font-bold text-slate-500">
          لا توجد بكجات مخصصة لـ {targetLabels[activeTargetRole]} حاليًا. يمكن للمشرف إنشاء بكجات من لوحة المشرف.
        </div>
      )}

      <div className="grid grid-cols-1 gap-4 lg:grid-cols-2">
        {visibleTargets.map(target => {
          const assignedPackageId = getAssignedPackageId(target);
          const assignedPackage = visiblePackages.find(pkg => pkg.id === assignedPackageId);
          return (
            <div key={target.id} className="rounded-3xl border border-slate-200 bg-white p-5 shadow-sm">
              <div className="flex items-start justify-between gap-3">
                <div>
                  <h2 className="text-lg font-black text-slate-800">{getTargetName(target)}</h2>
                  <p className="mt-1 text-sm font-bold text-slate-500">
                    {assignedPackage ? `البكج الحالي: ${assignedPackage.name}` : 'يستخدم الصلاحيات العامة'}
                  </p>
                </div>
                <span className="rounded-full bg-slate-100 px-3 py-1 text-xs font-black text-slate-600">
                  {activeTargetRole === 'parent' ? 'ولي أمر' : 'طالب'}
                </span>
              </div>

              <label className="mt-4 block text-sm font-black text-slate-700">
                اختر البكج
                <select
                  value={assignedPackageId}
                  disabled={!canManageTarget(activeTargetRole)}
                  onChange={event => assignPackage(target, activeTargetRole, event.target.value)}
                  className="mt-2 w-full rounded-xl border-2 border-slate-200 bg-white p-3 font-bold outline-none focus:border-indigo-400 disabled:cursor-not-allowed disabled:bg-slate-100"
                >
                  <option value="">الصلاحيات العامة</option>
                  {visiblePackages.map(pkg => (
                    <option key={pkg.id} value={pkg.id}>
                      {pkg.name} — {packagePermissionCount(pkg)} صلاحيات
                    </option>
                  ))}
                </select>
              </label>
            </div>
          );
        })}
      </div>

      {visibleTargets.length === 0 && visiblePackages.length > 0 && (
        <div className="rounded-3xl border-2 border-dashed border-slate-200 bg-white p-10 text-center font-bold text-slate-500">
          لا توجد حسابات تابعة لهذا الدور حاليًا.
        </div>
      )}
    </div>
  );
};

export default PermissionPackageManagement;