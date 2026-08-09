import { ParentInfo, Permissions } from './types';
import { STORAGE_KEYS, DEFAULT_PERMISSIONS } from './constants';

const numericLimit = (value: unknown, fallback: number) => {
  const parsed = Number(value);
  return Number.isFinite(parsed) ? Math.max(-1, Math.floor(parsed)) : fallback;
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
export const getTeacherPermissions = () => {
  return getPermissions().teacher;
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
  const custom = parent?.parentPermissions || {};
  const booleanKeys: (keyof Permissions['parent'])[] = [
    'canCreateStudents',
    'canEditStudents',
    'canDeleteStudents',
    'canResetStudentPassword',
    'canViewReports',
    'canChangeGrade',
    'canChatWithSupport',
  ];
  const effectiveBooleans = booleanKeys.reduce((result, key) => {
    result[key] = custom[key] === undefined
      ? defaults[key]
      : Boolean(defaults[key]) && Boolean(custom[key]);
    return result;
  }, {} as Pick<Permissions['parent'], typeof booleanKeys[number]>);
  const customLimit = numericLimit(custom.maxStudents, defaults.maxStudents);
  return {
    ...defaults,
    ...effectiveBooleans,
    maxStudents: defaults.maxStudents < 0
      ? customLimit
      : customLimit < 0
        ? defaults.maxStudents
        : Math.min(defaults.maxStudents, customLimit),
  };
};

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
export const getStudentPermissions = () => {
  return getPermissions().student;
};
