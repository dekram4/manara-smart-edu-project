import { ParentInfo, StudentInfo } from '../types';
import { STORAGE_KEYS } from '../constants';
import { readStorageArray } from './storage';

type OwnedRecord = {
  createdBy?: string;
  teacherId?: string;
  grade?: string;
  subject?: string;
  atram?: string;
  term?: string;
  unit?: string;
};

const hasOwn = (value: object, key: string) =>
  Object.prototype.hasOwnProperty.call(value, key);

export const normalizeScopeValue = (value: unknown) =>
  (value ?? '').toString().trim().toLowerCase();

export const getRecordTeacherId = (record: OwnedRecord | null | undefined) =>
  normalizeScopeValue(record?.teacherId ?? record?.createdBy);

export const getParentTeacherId = (
  parent: ParentInfo,
  students: StudentInfo[] = [],
) => {
  const direct = normalizeScopeValue(parent.createdBy);
  if (direct) return direct;

  const linked = students
    .filter((student): student is StudentInfo => Boolean(student && typeof student === 'object'))
    .find(student => {
      const studentParentId = normalizeScopeValue(student.parentId);
      const studentParentPhone = normalizeScopeValue(student.parentPhoneNumber);
      const parentId = normalizeScopeValue(parent.id);
      const parentPhone = normalizeScopeValue(parent.phoneNumber);
      return (studentParentId && studentParentId === parentId) || (studentParentPhone && studentParentPhone === parentPhone);
    });
  if (linked) return getStudentTeacherScope(linked).teacherId;

  const embedded = (Array.isArray(parent.children) ? parent.children : [])
    .find((child): child is StudentInfo => Boolean(child && typeof child === 'object'));
  return embedded ? getStudentTeacherScope(embedded).teacherId : '';
};

/**
 * A teacherId property is authoritative, including an explicitly empty value.
 * Records created before teacherId existed continue to use createdBy as the
 * legacy teacher assignment.
 */
function loadParentsFromStorage(): ParentInfo[] {
  return readStorageArray<ParentInfo>(STORAGE_KEYS.PARENTS)
    .filter((parent): parent is ParentInfo => Boolean(parent && typeof parent === 'object'));
}

export const getStudentTeacherScope = (
  student: StudentInfo,
  parents: ParentInfo[] = [],
  students: StudentInfo[] = [],
) => {
  const rawTeacherId = normalizeScopeValue(student.teacherId);
  const explicit = hasOwn(student, 'teacherId') && rawTeacherId !== '';
  let teacherId = rawTeacherId || normalizeScopeValue(student.createdBy);

  if (!teacherId && parents.length === 0) {
    parents = loadParentsFromStorage();
  }

  if (!teacherId && parents.length > 0) {
    const parent = parents
      .filter((candidate): candidate is ParentInfo => Boolean(candidate && typeof candidate === 'object'))
      .find(p => {
        const studentParentId = normalizeScopeValue(student.parentId);
        if (studentParentId) {
          return normalizeScopeValue(p.id) === studentParentId;
        }
        return normalizeScopeValue(p.phoneNumber) === normalizeScopeValue(student.parentPhoneNumber);
      });
    if (parent) {
      teacherId = getParentTeacherId(parent, students);
    }
  }

  return { explicit, teacherId };
};

export const studentBelongsToTeacher = (
  student: StudentInfo,
  teacherId: string,
  parents: ParentInfo[] = [],
) => {
  const requestedTeacher = normalizeScopeValue(teacherId);
  if (!requestedTeacher) return false;

  const scope = getStudentTeacherScope(student);
  if (scope.explicit) return scope.teacherId === requestedTeacher;
  if (scope.teacherId === requestedTeacher) return true;

  // Legacy students created through a teacher-owned parent may not have
  // createdBy on the student record.
  const parent = parents
    .filter((parentRecord): parentRecord is ParentInfo => Boolean(parentRecord && typeof parentRecord === 'object'))
    .find(parentRecord => normalizeScopeValue(parentRecord.id) === normalizeScopeValue(student.parentId));
  return normalizeScopeValue(parent?.createdBy) === requestedTeacher;
};

export const getTeacherParents = (parents: ParentInfo[], teacherId: string) => {
  const requestedTeacher = normalizeScopeValue(teacherId);
  return parents.filter(parent =>
    normalizeScopeValue(parent.createdBy) === requestedTeacher,
  );
};

export const getTeacherStudents = (
  students: StudentInfo[],
  teacherId: string,
  parents: ParentInfo[] = [],
) => students.filter(student => studentBelongsToTeacher(student, teacherId, parents));

export const getParentChildren = (students: StudentInfo[], parent: ParentInfo) =>
  students.filter(student => {
    if (student.parentId && student.parentId.trim()) {
      return student.parentId === parent.id;
    }
    return student.parentPhoneNumber === parent.phoneNumber;
  });

export const filterTeacherOwnedRecords = <T extends OwnedRecord>(
  records: T[],
  student: StudentInfo,
  parents: ParentInfo[] = [],
  students: StudentInfo[] = [],
) => {
  const scope = getStudentTeacherScope(student, parents, students);
  const validRecords = records.filter(
    (record): record is T => Boolean(record && typeof record === 'object'),
  );

  if (scope.explicit) {
    return scope.teacherId
      ? validRecords.filter(record => getRecordTeacherId(record) === scope.teacherId)
      : [];
  }

  if (scope.teacherId) {
    return validRecords.filter(record => getRecordTeacherId(record) === scope.teacherId);
  }

  return validRecords;
};

export const matchesAcademicScope = (
  record: OwnedRecord | null | undefined,
  path: Pick<OwnedRecord, 'grade' | 'subject' | 'atram' | 'term' | 'unit'>,
) => {
  if (!record) return false;
  const fields: (keyof typeof path)[] = ['grade', 'subject', 'atram', 'term', 'unit'];
  return fields.every(field => {
    const expected = normalizeScopeValue(path[field]);
    if (!expected) return true;
    const actual = normalizeScopeValue(record[field]);
    return !actual || actual === expected;
  });
};
