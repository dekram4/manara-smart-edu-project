import type { QuizQuestion, QuizResult } from '../types';

const LATIN_LABELS = ['a', 'b', 'c', 'd'];
const ARABIC_LABELS = ['أ', 'ب', 'ج', 'د'];

const normalizeAnswer = (value: unknown): string =>
  String(value ?? '')
    .normalize('NFKC')
    .trim()
    .toLocaleLowerCase()
    .replace(/\s+/g, ' ');

const getAnswerIndex = (value: unknown, optionCount: number): number | null => {
  const normalized = normalizeAnswer(value).replace(/[()[\]{}:،,.\-]/g, '').trim();
  const latinIndex = LATIN_LABELS.indexOf(normalized);
  if (latinIndex >= 0 && latinIndex < optionCount) return latinIndex;
  const arabicIndex = ARABIC_LABELS.indexOf(normalized);
  if (arabicIndex >= 0 && arabicIndex < optionCount) return arabicIndex;

  const numeric = Number(normalized);
  if (Number.isInteger(numeric)) {
    if (numeric >= 1 && numeric <= optionCount) return numeric - 1;
    if (numeric >= 0 && numeric < optionCount) return numeric;
  }

  return null;
};

/**
 * Created AI questions historically store the correct answer as A/B/C/D,
 * while the student UI stores the selected option text. Manual questions
 * usually store the text itself. Always compare the same representation.
 */
export const getCorrectAnswerText = (question: QuizQuestion): string => {
  const options = Array.isArray(question.options) ? question.options : [];
  const rawAnswer = String(question.correctAnswer ?? '');
  const answerIndex = getAnswerIndex(rawAnswer, options.length);
  if (answerIndex !== null) return String(options[answerIndex] ?? '');

  const normalizedRaw = normalizeAnswer(rawAnswer);
  const matchingOption = options.find((option) => normalizeAnswer(option) === normalizedRaw);
  return matchingOption !== undefined ? String(matchingOption) : rawAnswer;
};

export const isQuizAnswerCorrect = (
  question: QuizQuestion,
  userAnswer: unknown,
): boolean => {
  const options = Array.isArray(question.options) ? question.options : [];
  const selectedIndex = getAnswerIndex(userAnswer, options.length);
  const correctIndex = getAnswerIndex(question.correctAnswer, options.length);
  if (selectedIndex !== null && correctIndex !== null) {
    return selectedIndex === correctIndex;
  }

  return normalizeAnswer(userAnswer) === normalizeAnswer(getCorrectAnswerText(question));
};

/**
 * Read old and new result shapes consistently. If a legacy record has a
 * missing/stale percentage but contains a score or correct detail flags,
 * derive the percentage from the reliable values.
 */
export const getQuizResultPercentage = (result: Partial<QuizResult>): number => {
  const total = Number(result.total);
  const score = Number(result.score);
  const detailsScore = Array.isArray(result.details)
    ? result.details.filter((detail) => detail?.isCorrect === true).length
    : 0;

  const reliableScore = detailsScore > 0 && (!Number.isFinite(score) || score <= 0)
    ? detailsScore
    : score;
  if (Number.isFinite(total) && total > 0 && Number.isFinite(reliableScore)) {
    return Math.round(Math.max(0, Math.min(100, (reliableScore / total) * 100)));
  }

  const percentage = Number(result.percentage);
  return Number.isFinite(percentage)
    ? Math.round(Math.max(0, Math.min(100, percentage)))
    : 0;
};

export const getQuizResultScore = (result: Partial<QuizResult>): number => {
  const score = Number(result.score);
  if (Number.isFinite(score) && score >= 0) return score;
  return Array.isArray(result.details)
    ? result.details.filter((detail) => detail?.isCorrect === true).length
    : 0;
};