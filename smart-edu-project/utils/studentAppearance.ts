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

export const STUDENT_TOP_OPTIONS = [
  { value: '👕', label: 'قميص مرح' },
  { value: '🧥', label: 'معطف دافئ' },
  { value: '🦺', label: 'سترة مستكشف' },
  { value: '🥋', label: 'زي البطل' },
  { value: '🧑‍🚀', label: 'بدلة الفضاء' },
  { value: '👔', label: 'زي رسمي' },
  { value: '🥼', label: 'معطف المختبر' },
  { value: '🎓', label: 'زي التخرج' },
] as const;

export const STUDENT_BOTTOM_OPTIONS = [
  { value: '👖', label: 'بنطال أزرق' },
  { value: '🩳', label: 'شورت رياضي' },
  { value: '🥋', label: 'بنطال الكاراتيه' },
  { value: '🩲', label: 'بنطال مريح' },
  { value: '🦿', label: 'ساق آلية' },
  { value: '🧵', label: 'زي المخترع' },
] as const;

export const STUDENT_SHOES_OPTIONS = [
  { value: '👟', label: 'حذاء رياضي' },
  { value: '🥾', label: 'حذاء المغامر' },
  { value: '🥿', label: 'حذاء أنيق' },
  { value: '🛼', label: 'حذاء التزلج' },
  { value: '⛸️', label: 'حذاء الجليد' },
  { value: '🩴', label: 'صندل خفيف' },
] as const;

export const STUDENT_HAIR_OPTIONS = [
  { value: '🦱', label: 'شعر مجعد' },
  { value: '🦰', label: 'شعر أحمر' },
  { value: '🦳', label: 'شعر فضي' },
  { value: '🦲', label: 'ستايل عصري' },
  { value: '🧢', label: 'قبعة رياضية' },
  { value: '🎩', label: 'قبعة أنيقة' },
  { value: '👒', label: 'قبعة صيفية' },
  { value: '🎓', label: 'قبعة التخرج' },
] as const;

export const STUDENT_HAIR_COLOR_OPTIONS = [
  { value: '#3f2b24', label: 'بني كلاسيكي', swatch: '#3f2b24' },
  { value: '#1f2937', label: 'أسود ليلي', swatch: '#1f2937' },
  { value: '#8b5e3c', label: 'بني عسلي', swatch: '#8b5e3c' },
  { value: '#d97706', label: 'ذهبي مشمس', swatch: '#d97706' },
  { value: '#e5e7eb', label: 'فضي لامع', swatch: '#e5e7eb' },
  { value: '#ec4899', label: 'وردي مرح', swatch: '#ec4899' },
  { value: '#7c3aed', label: 'بنفسجي خيالي', swatch: '#7c3aed' },
] as const;

export const STUDENT_SKIN_OPTIONS = [
  { value: '#f8d7c0', label: 'قمحي فاتح', swatch: '#f8d7c0' },
  { value: '#edb891', label: 'ذهبي دافئ', swatch: '#edb891' },
  { value: '#c9825b', label: 'برونزي', swatch: '#c9825b' },
  { value: '#9b5d3f', label: 'بني دافئ', swatch: '#9b5d3f' },
  { value: '#633d2c', label: 'بني عميق', swatch: '#633d2c' },
] as const;

export const STUDENT_ACCESSORY_OPTIONS = [
  { value: '👓', label: 'نظارة ذكية' },
  { value: '🕶️', label: 'نظارة شمسية' },
  { value: '🎧', label: 'سماعات' },
  { value: '🎒', label: 'حقيبة مغامر' },
  { value: '🛡️', label: 'درع الحماية' },
  { value: '🪄', label: 'عصا سحرية' },
  { value: '🏹', label: 'قوس المستكشف' },
  { value: '📚', label: 'كتب المعرفة' },
  { value: '✨', label: 'لمعة النجوم' },
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
  const legacyOutfit = isOptionValue(saved?.outfit, STUDENT_TOP_OPTIONS)
    ? saved!.outfit
    : '🎓';
  return {
    shape: isOptionValue(saved?.shape, STUDENT_SHAPE_OPTIONS) ? saved!.shape : genderShape,
    color: isOptionValue(saved?.color, STUDENT_COLOR_OPTIONS) ? saved!.color : '#38bdf8',
    outfit: isOptionValue(saved?.outfit, STUDENT_OUTFIT_OPTIONS) ? saved!.outfit : legacyOutfit,
    top: isOptionValue(saved?.top, STUDENT_TOP_OPTIONS) ? saved!.top : legacyOutfit,
    bottom: isOptionValue(saved?.bottom, STUDENT_BOTTOM_OPTIONS) ? saved!.bottom : '👖',
    shoes: isOptionValue(saved?.shoes, STUDENT_SHOES_OPTIONS) ? saved!.shoes : '👟',
    hair: isOptionValue(saved?.hair, STUDENT_HAIR_OPTIONS) ? saved!.hair : '🦱',
    hairColor: isOptionValue(saved?.hairColor, STUDENT_HAIR_COLOR_OPTIONS) ? saved!.hairColor : '#3f2b24',
    skinTone: isOptionValue(saved?.skinTone, STUDENT_SKIN_OPTIONS) ? saved!.skinTone : '#edb891',
    accessory: isOptionValue(saved?.accessory, STUDENT_ACCESSORY_OPTIONS) ? saved!.accessory : '✨',
  };
};

export const getStudentEmoji = (student?: Pick<StudentInfo, 'gender' | 'appearance'> | null): string =>
  getStudentAppearance(student).shape;
