import { ParentInfo, StudentInfo } from '../types';
import { STORAGE_KEYS } from '../constants';

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

export const getRecordTeacherId = (record: OwnedRecord) =>
  normalizeScopeValue(record.teacherId ?? record.createdBy);

export const getParentTeacherId = (
  parent: ParentInfo,
  students: StudentInfo[] = [],
) => {
  const direct = normalizeScopeValue(parent.createdBy);
  if (direct) return direct;

  const linked = students.find(student => {
    const studentParentId = normalizeScopeValue(student.parentId);
    const studentParentPhone = normalizeScopeValue(student.parentPhoneNumber);
    const parentId = normalizeScopeValue(parent.id);
    const parentPhone = normalizeScopeValue(parent.phoneNumber);
    return (studentParentId && studentParentId === parentId) || (studentParentPhone && studentParentPhone === parentPhone);
  });
  if (linked) return getStudentTeacherScope(linked).teacherId;

  const embedded = (parent.children || []).find(Boolean);
  return embedded ? getStudentTeacherScope(embedded).teacherId : '';
};

/**
 * A teacherId property is authoritative, including an explicitly empty value.
 * Records created before teacherId existed continue to use createdBy as the
 * legacy teacher assignment.
 */
function loadParentsFromStorage(): ParentInfo[] {
  try {
    return JSON.parse(localStorage.getItem(STORAGE_KEYS.PARENTS) || '[]');
  } catch {
    return [];
  }
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
    const parent = parents.find(p => {
      if (student.parentId && student.parentId.trim()) {
        return p.id === student.parentId;
      }
      return p.phoneNumber === student.parentPhoneNumber;
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
  const parent = parents.find(parentRecord => parentRecord.id === student.parentId);
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

  if (scope.explicit) {
    return scope.teacherId
      ? records.filter(record => getRecordTeacherId(record) === scope.teacherId)
      : [];
  }

  if (scope.teacherId) {
    return records.filter(record => getRecordTeacherId(record) === scope.teacherId);
  }

  return records;
};

export const matchesAcademicScope = (
  record: OwnedRecord,
  path: Pick<OwnedRecord, 'grade' | 'subject' | 'atram' | 'term' | 'unit'>,
) => {
  const fields: (keyof typeof path)[] = ['grade', 'subject', 'atram', 'term', 'unit'];
  return fields.every(field => {
    const expected = normalizeScopeValue(path[field]);
    if (!expected) return true;
    const actual = normalizeScopeValue(record[field]);
    return !actual || actual === expected;
  });
};
