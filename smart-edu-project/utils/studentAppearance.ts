import { StudentInfo } from '../types';
import { StudentAppearance } from '../types';

export type StudentGender = 'male' | 'female';

export const STUDENT_SHAPE_OPTIONS = [
  { value: '👦', label: 'البطل الصغير' },
  { value: '👧', label: 'البطلة الصغيرة' },
  { value: '👨‍🎓', label: 'الطالب المجتهد' },
  { value: '👩‍🎓', label: 'الطالبة المجتهدة' },
  { value: '🧑‍🚀', label: 'رائد الفضاء' },
  { value: '🧙', label: 'الساحر الذكي' },
  { value: '🦸', label: 'البطل الخارق' },
  { value: '🧑‍🔬', label: 'العالِم الصغير' },
  { value: '👨‍🚀', label: 'قائد الفضاء' },
  { value: '👩‍🚀', label: 'قائدة الفضاء' },
  { value: '🧑‍💻', label: 'المبرمج المبدع' },
  { value: '👩‍💻', label: 'المبرمجة المبدعة' },
  { value: '🧑‍🎨', label: 'الفنان المبتكر' },
  { value: '👩‍🔬', label: 'العالِمة الصغيرة' },
  { value: '🧑‍🏫', label: 'المرشد الذكي' },
  { value: '🦸‍♀️', label: 'البطلة الخارقة' },
  { value: '🧝', label: 'حارس الخيال' },
  { value: '🧚', label: 'جنية النجوم' },
] as const;

export const STUDENT_COLOR_OPTIONS = [
  { value: '#38bdf8', label: 'أزرق سماوي', swatch: 'linear-gradient(135deg, #38bdf8, #2563eb)' },
  { value: '#f472b6', label: 'وردي مرح', swatch: 'linear-gradient(135deg, #f472b6, #db2777)' },
  { value: '#a78bfa', label: 'بنفسجي خيالي', swatch: 'linear-gradient(135deg, #a78bfa, #7c3aed)' },
  { value: '#34d399', label: 'أخضر مغامر', swatch: 'linear-gradient(135deg, #34d399, #059669)' },
  { value: '#fbbf24', label: 'ذهبي لامع', swatch: 'linear-gradient(135deg, #fbbf24, #f97316)' },
  { value: '#fb7185', label: 'أحمر شجاع', swatch: 'linear-gradient(135deg, #fb7185, #e11d48)' },
  { value: '#22d3ee', label: 'فيروزي نيون', swatch: 'linear-gradient(135deg, #67e8f9, #0891b2)' },
  { value: '#818cf8', label: 'نيلي ملكي', swatch: 'linear-gradient(135deg, #a5b4fc, #4f46e5)' },
  { value: '#c084fc', label: 'أرجواني نجمي', swatch: 'linear-gradient(135deg, #e9d5ff, #9333ea)' },
  { value: '#84cc16', label: 'ليموني حيوي', swatch: 'linear-gradient(135deg, #bef264, #65a30d)' },
] as const;

export const STUDENT_OUTFIT_OPTIONS = [
  { value: '🎓', label: 'زي التخرج' },
  { value: '🧥', label: 'المعطف الدافئ' },
  { value: '👕', label: 'القميص المرح' },
  { value: '🦺', label: 'سترة المستكشف' },
  { value: '🥋', label: 'زي البطل' },
  { value: '🧑‍🚀', label: 'بدلة الفضاء' },
  { value: '👔', label: 'الزي الرسمي' },
  { value: '🥼', label: 'معطف المختبر' },
  { value: '🎒', label: 'حقيبة المغامر' },
  { value: '🛡️', label: 'درع الحماية' },
  { value: '👑', label: 'تاج القائد' },
  { value: '🪄', label: 'عصا الساحر' },
  { value: '🧣', label: 'وشاح الأبطال' },
  { value: '🏹', label: 'قوس المستكشف' },
] as const;

export const STUDENT_GENDER_OPTIONS: Array<{ value: StudentGender; label: string; emoji: string }> = [
  { value: 'male', label: 'ذكر', emoji: '👨‍🎓' },
  { value: 'female', label: 'أنثى', emoji: '👩‍🎓' },
];

const isOptionValue = (value: string | undefined, options: readonly { value: string }[]) =>
  !!value && options.some(option => option.value === value);

export const getStudentAppearance = (
  student?: Pick<StudentInfo, 'gender' | 'appearance'> | null,
): StudentAppearance => {
  const saved = student?.appearance;
  const genderShape = student?.gender === 'female' ? '👩‍🎓' : '👨‍🎓';
  return {
    shape: isOptionValue(saved?.shape, STUDENT_SHAPE_OPTIONS) ? saved!.shape : genderShape,
    color: isOptionValue(saved?.color, STUDENT_COLOR_OPTIONS) ? saved!.color : '#38bdf8',
    outfit: isOptionValue(saved?.outfit, STUDENT_OUTFIT_OPTIONS) ? saved!.outfit : '🎓',
  };
};

export const getStudentEmoji = (student?: Pick<StudentInfo, 'gender' | 'appearance'> | null): string =>
  getStudentAppearance(student).shape;
