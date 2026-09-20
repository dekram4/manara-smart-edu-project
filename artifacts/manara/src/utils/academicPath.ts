import { CreatedQuiz, QuizResult } from '../types';

/**
 * المسار الأكاديمي الموحّد، بترتيبه الواحد في كل بوابة:
 * الصف ◂ المادة ◂ الفصل الدراسي ◂ الوحدة ◂ الدرس.
 *
 * الترتيب نفسه في كل جدول وبطاقة وتقرير، فيقرأ المشرف والمعلم ووليّ الأمر
 * والطالب المسار بالعين ذاتها ولا يحتاج أحدهم أن يعيد ترتيبه في ذهنه.
 */
export type AcademicPath = {
  grade: string;
  subject: string;
  term: string;
  unit: string;
  lesson: string;
};

/** ترتيب المستويات للعرض: يُستعمل لرؤوس الجداول فلا تختلف من شاشة لأخرى. */
export const ACADEMIC_PATH_LABELS: ReadonlyArray<{ key: keyof AcademicPath; label: string }> = [
  { key: 'grade', label: 'الصف' },
  { key: 'subject', label: 'المادة' },
  { key: 'term', label: 'الفصل الدراسي' },
  { key: 'unit', label: 'الوحدة' },
  { key: 'lesson', label: 'الدرس' },
];

const text = (value: unknown): string =>
  typeof value === 'string' ? value.trim() : value == null ? '' : String(value).trim();

/**
 * مسار نتيجة اختبار، مكتملاً من الاختبار الذي أنتجها.
 *
 * `QuizResult` يحمل الصف والمادة والوحدة ولا يحمل الفصل الدراسي ولا الدرس،
 * بينما `CreatedQuiz` يحملهما. فكانت تقارير وليّ الأمر والمعلم تعرض مساراً
 * ناقصاً — وحدةً بلا فصل ولا درس — ولا سبيل لمعرفة أي درس يخصّ النتيجة.
 *
 * الوصل هنا بـ `quizId`، وما لم يُعرَف يبقى فارغاً ليُعرض شَرطةً لا فراغاً
 * مبهماً. والاختبارات التي أُنشئت قبل مستوى الدرس تبقى صالحة على مستوى
 * وحدتها كما كانت.
 */
export function quizResultPath(result: QuizResult, quizzes: CreatedQuiz[] = []): AcademicPath {
  const source = quizzes.find(quiz => text(quiz?.id) === text(result?.quizId));
  return {
    grade: text(result?.grade) || text(source?.grade),
    subject: text(result?.subject) || text(source?.subject),
    term: text(source?.term),
    unit: text(result?.unit) || text(source?.unit),
    lesson: text(source?.lesson),
  };
}

/** المسار مكتوباً في سطر واحد، بالترتيب نفسه، لبطاقة لا تتسع لجدول. */
export function formatAcademicPath(path: Partial<AcademicPath>, separator = ' ◂ '): string {
  return ACADEMIC_PATH_LABELS
    .map(({ key }) => text(path[key]))
    .filter(Boolean)
    .join(separator);
}

/** قيمة الخلية، وشَرطةٌ مكان ما لا يُعرف — فلا تبقى خانة فارغة بلا معنى. */
export const pathCell = (value: string): string => value || '—';
