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

export const normalizeQuizQuestion = (question: QuizQuestion): QuizQuestion => ({
  ...question,
  quizType: normalizeQuizType(question.quizType),
});

export const normalizeCreatedQuiz = (quiz: CreatedQuiz): CreatedQuiz => ({
  ...quiz,
  quizType: normalizeQuizType(quiz.quizType),
  questions: (quiz.questions || []).map((question) => ({
    ...normalizeQuizQuestion(question),
    quizId: question.quizId || quiz.id,
  })),
});