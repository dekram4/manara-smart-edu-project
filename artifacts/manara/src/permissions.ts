import { ParentInfo, PermissionPackage, PermissionPackageRole, Permissions, StudentInfo, TeacherInfo } from './types';
import { STORAGE_KEYS, DEFAULT_PERMISSIONS } from './constants';
import { readActiveSession } from './utils/storage';

const numericLimit = (value: unknown, fallback: number) => {
  const parsed = Number(value);
  return Number.isFinite(parsed) ? Math.max(-1, Math.floor(parsed)) : fallback;
};

export const getPermissionPackages = (): PermissionPackage[] => {
  try {
    const saved = JSON.parse(localStorage.getItem(STORAGE_KEYS.PERMISSION_PACKAGES) || '[]');
    return Array.isArray(saved) ? saved : [];
  } catch {
    return [];
  }
};

export const getPermissionPackage = (
  role: PermissionPackageRole,
  packageId?: string,
): PermissionPackage | null => {
  const normalizedPackageId = String(packageId ?? '').trim();
  if (!normalizedPackageId) return null;
  return getPermissionPackages().find(pkg =>
    String(pkg.id ?? '').trim() === normalizedPackageId && pkg.role === role,
  ) || null;
};

const capRolePermissions = <T extends Record<string, unknown>>(global: T, packagePermissions?: Partial<T>): T => {
  if (!packagePermissions) return global;
  const result: Record<string, unknown> = { ...global };
  Object.keys(global).forEach(key => {
    const globalValue = global[key];
    const packageValue = packagePermissions[key];
    if (typeof globalValue === 'boolean') {
      result[key] = globalValue && packageValue !== false;
    } else if (typeof globalValue === 'number') {
      const globalLimit = numericLimit(globalValue, -1);
      const packageLimit = numericLimit(packageValue, globalLimit);
      result[key] = (
        globalLimit < 0
          ? packageLimit
          : packageLimit < 0
            ? globalLimit
            : Math.min(globalLimit, packageLimit)
      );
    }
  });
  return result as T;
};

/**
 * Admin-owned packages are the explicit policy chosen by the administrator.
 * Legacy global permissions still provide values for fields omitted by an old
 * package, while a checked admin-package permission must not be blocked by a
 * stale hidden global setting.
 */
const applyPermissionPackage = <T extends Record<string, unknown>>(
  global: T,
  packageValue: Partial<T> | undefined,
  isAdminOwned: boolean,
): T => {
  if (!packageValue) return global;
  if (!isAdminOwned) return capRolePermissions(global, packageValue);

  const result: Record<string, unknown> = { ...global };
  Object.keys(global).forEach(key => {
    if (packageValue[key] !== undefined) {
      result[key] = packageValue[key];
    }
  });
  return result as T;
};

const mergePermissions = (saved: Partial<Permissions> | null): Permissions => ({
  teacher: {
    ...DEFAULT_PERMISSIONS.teacher,
    ...(saved?.teacher || {}),
    maxParents: numericLimit(saved?.teacher?.maxParents, DEFAULT_PERMISSIONS.teacher.maxParents),
    maxStudents: numericLimit(saved?.teacher?.maxStudents, DEFAULT_PERMISSIONS.teacher.maxStudents),
    maxContent: numericLimit(saved?.teacher?.maxContent, DEFAULT_PERMISSIONS.teacher.maxContent),
    maxVideos: numericLimit(saved?.teacher?.maxVideos, DEFAULT_PERMISSIONS.teacher.maxVideos),
    maxStorageMb: numericLimit(saved?.teacher?.maxStorageMb, DEFAULT_PERMISSIONS.teacher.maxStorageMb),
  },
  parent: {
    ...DEFAULT_PERMISSIONS.parent,
    ...(saved?.parent || {}),
    maxStudents: numericLimit(saved?.parent?.maxStudents, DEFAULT_PERMISSIONS.parent.maxStudents),
  },
  student: {
    ...DEFAULT_PERMISSIONS.student,
    ...(saved?.student || {}),
  },
});

/**
 * الحصول على الصلاحيات الحالية من localStorage
 */
export const getPermissions = (): Permissions => {
  try {
    const saved = localStorage.getItem(STORAGE_KEYS.PERMISSIONS);
    return mergePermissions(saved ? JSON.parse(saved) : null);
  } catch {
    return mergePermissions(null);
  }
};

/**
 * فحص صلاحية معينة للمعلم
 */
export const hasTeacherPermission = (permission: keyof Permissions['teacher']): boolean => {
  const permissions = getPermissions();
  return Boolean(permissions.teacher[permission]);
};

/**
 * فحص صلاحية معينة لولي الأمر
 */
export const hasParentPermission = (permission: keyof Permissions['parent']): boolean => {
  const permissions = getPermissions();
  return Boolean(permissions.parent[permission]);
};

/**
 * فحص صلاحية معينة للطالب
 */
export const hasStudentPermission = (permission: keyof Permissions['student']): boolean => {
  const permissions = getPermissions();
  return permissions.student[permission];
};

/**
 * الحصول على جميع صلاحيات المعلم
 */
export const getTeacherPermissions = (teacher?: Pick<TeacherInfo, 'permissionPackageId'> | null) => {
  return getTeacherPermissionDetails(teacher).effective;
};

export const getTeacherPermissionDetails = (
  teacher?: Pick<TeacherInfo, 'permissionPackageId'> | null,
) => {
  const activeTeacher = teacher || (() => {
    try {
      return readActiveSession<TeacherInfo>(STORAGE_KEYS.CURRENT_TEACHER);
    } catch {
      return null;
    }
  })();
  const global = getPermissions().teacher;
  const permissionPackage = getPermissionPackage('teacher', activeTeacher?.permissionPackageId);
  const effective = applyPermissionPackage(
    global as unknown as Record<string, unknown>,
    permissionPackage?.permissions as Partial<Record<string, unknown>> | undefined,
    !permissionPackage?.ownerRole || permissionPackage.ownerRole === 'admin',
  ) as unknown as typeof global;
  return { global, permissionPackage, effective };
};

/**
 * الحصول على جميع صلاحيات ولي الأمر
 */
export const getParentPermissions = () => {
  return getPermissions().parent;
};

/**
 * صلاحيات ولي الأمر بعد تطبيق أي تخصيص يمنحه المعلم لهذا الحساب.
 */
export const getEffectiveParentPermissions = (parent?: ParentInfo | null) => {
  const defaults = getPermissions().parent;
  const permissionPackage = getPermissionPackage('parent', parent?.permissionPackageId);
  const packaged = applyPermissionPackage(
    defaults as unknown as Record<string, unknown>,
    permissionPackage?.permissions as Partial<Record<string, unknown>> | undefined,
    !permissionPackage?.ownerRole || permissionPackage.ownerRole === 'admin',
  ) as unknown as typeof defaults;
  const custom = parent?.parentPermissions || {};
  const booleanKeys: Exclude<keyof Permissions['parent'], 'maxStudents'>[] = [
    'canCreateStudents',
    'canEditStudents',
    'canDeleteStudents',
    'canResetStudentPassword',
    'canViewReports',
    'canChangeGrade',
    'canChatWithSupport',
    'canCreatePermissionPackages',
  ];
  const effectiveBooleans: Partial<Permissions['parent']> = {};
  booleanKeys.forEach(key => {
    effectiveBooleans[key] = custom[key] === undefined
      ? packaged[key]
      : Boolean(packaged[key]) && Boolean(custom[key]);
  });
  const customLimit = numericLimit(custom.maxStudents, packaged.maxStudents);
  return {
    ...packaged,
    ...effectiveBooleans,
    maxStudents: packaged.maxStudents < 0
      ? customLimit
      : customLimit < 0
        ? packaged.maxStudents
        : Math.min(packaged.maxStudents, customLimit),
  };
};

export const getPermissionPackageLabel = (pkg: PermissionPackage | null | undefined) =>
  pkg ? pkg.name : 'الصلاحيات العامة';

export const isLimitReached = (current: number, limit: number) =>
  limit >= 0 && current >= limit;

export const getTeacherVideoUsageBytes = (videos: unknown[]) => {
  try {
    return new TextEncoder().encode(JSON.stringify(videos || [])).length;
  } catch {
    return JSON.stringify(videos || []).length;
  }
};

export const getTeacherVideoUsageMb = (videos: unknown[]) =>
  getTeacherVideoUsageBytes(videos) / (1024 * 1024);

/**
 * الحصول على جميع صلاحيات الطالب
 */
export const getStudentPermissions = (student?: Pick<StudentInfo, 'permissionPackageId'> | null) => {
  const activeStudent = student || (() => {
    try {
      return readActiveSession<StudentInfo>(STORAGE_KEYS.ACTIVE_STUDENT);
    } catch {
      return null;
    }
  })();
  const global = getPermissions().student;
  const permissionPackage = getPermissionPackage('student', activeStudent?.permissionPackageId);
  return applyPermissionPackage(
    global as unknown as Record<string, unknown>,
    permissionPackage?.permissions as Partial<Record<string, unknown>> | undefined,
    !permissionPackage?.ownerRole || permissionPackage.ownerRole === 'admin',
  ) as typeof global;
};
