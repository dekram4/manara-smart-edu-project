import { StudentInfo } from '../types';

export type StudentGender = 'male' | 'female';

export const STUDENT_GENDER_OPTIONS: Array<{ value: StudentGender; label: string; emoji: string }> = [
  { value: 'male', label: 'ذكر', emoji: '👨‍🎓' },
  { value: 'female', label: 'أنثى', emoji: '👩‍🎓' },
];

export const getStudentEmoji = (student?: Pick<StudentInfo, 'gender'> | null): string =>
  student?.gender === 'female' ? '👩‍🎓' : '👨‍🎓';
