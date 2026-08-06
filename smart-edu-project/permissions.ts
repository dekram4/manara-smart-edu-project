import { Permissions } from './types';
import { STORAGE_KEYS, DEFAULT_PERMISSIONS } from './constants';

/**
 * الحصول على الصلاحيات الحالية من localStorage
 */
export const getPermissions = (): Permissions => {
  const saved = localStorage.getItem(STORAGE_KEYS.PERMISSIONS);
  if (saved) {
    return JSON.parse(saved);
  }
  return DEFAULT_PERMISSIONS;
};

/**
 * فحص صلاحية معينة للمعلم
 */
export const hasTeacherPermission = (permission: keyof Permissions['teacher']): boolean => {
  const permissions = getPermissions();
  return permissions.teacher[permission];
};

/**
 * فحص صلاحية معينة لولي الأمر
 */
export const hasParentPermission = (permission: keyof Permissions['parent']): boolean => {
  const permissions = getPermissions();
  return permissions.parent[permission];
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
 * الحصول على جميع صلاحيات الطالب
 */
export const getStudentPermissions = () => {
  return getPermissions().student;
};
