import { CreatedQuiz, QuizQuestion, QuizType } from '../types';

/**
 * The product now has only two assessment modes. Older saved quizzes used
 * unit/term/final values; those are intentionally treated as periodic quizzes
 * so existing content remains available.
 */
export const normalizeQuizType = (value: unknown): QuizType => {
  const normalized = String(value ?? '').trim().toLowerCase();
  if (
    normalized === QuizType.TEACHER ||
    normalized.includes('teacher') ||
    normalized.includes('معلم')
  ) {
    return QuizType.TEACHER;
  }
  return QuizType.PERIODIC;
};

export const getQuizTypeLabel = (value: unknown): string =>
  normalizeQuizType(value) === QuizType.TEACHER
    ? 'اختبار المعلم'
    : 'الاختبار الدوري';

export const getPeriodicQuizLabel = (quiz: Pick<CreatedQuiz, 'quizType' | 'periodicNumber' | 'creationMode' | 'questions'>): string => {
  if (normalizeQuizType(quiz.quizType) !== QuizType.PERIODIC) {
    return 'الاختبار الدوري';
  }

  const number = Number(quiz.periodicNumber);
  if (!Number.isFinite(number) || number < 1) {
    return 'الاختبار الدوري';
  }

  const labels = ['الأول', 'الثاني', 'الثالث', 'الرابع', 'الخامس', 'السادس', 'السابع', 'الثامن', 'التاسع', 'العاشر'];
  return `الاختبار الدوري ${labels[number - 1] || number}`;
};

export const normalizeQuizQuestion = (question: QuizQuestion): QuizQuestion => ({
  ...question,
  quizType: normalizeQuizType(question.quizType),
});

export const normalizeCreatedQuiz = (quiz: CreatedQuiz): CreatedQuiz => ({
  ...quiz,
  quizType: normalizeQuizType(quiz.quizType),
  creationMode: quiz.creationMode || ((quiz.questions || []).some((question) => question.source === 'ai-generated') ? 'ai' : 'manual'),
  periodicNumber: Number.isFinite(Number(quiz.periodicNumber)) ? Number(quiz.periodicNumber) : undefined,
  questionsPerAttempt: Number.isFinite(Number(quiz.questionsPerAttempt))
    ? Number(quiz.questionsPerAttempt)
    : quiz.questionCount,
  deleted: quiz.deleted === true,
  deletedAt: quiz.deletedAt,
  questions: (quiz.questions || []).map((question) => ({
    ...normalizeQuizQuestion(question),
    quizId: question.quizId || quiz.id,
  })),
});