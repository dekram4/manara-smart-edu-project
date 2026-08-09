import type { QuizResult, StudentInfo, StudentGamification } from '../types';
import { QuizType } from '../types';
import { normalizeQuizType } from './quizTypes';

export interface StudentProgressSummary {
  gems: number;
  xp: number;
  level: number;
  levelProgress: number;
  streak: number;
  totalQuizzes: number;
  totalLessons: number;
  totalGames: number;
  achievementsCount: number;
  averageScore: number;
  lastQuiz: QuizResult | null;
  updatedAt?: string;
}

export function getStudentProgressSummary(
  student: StudentInfo,
  results: QuizResult[] = [],
): StudentProgressSummary {
  const snapshot: Partial<StudentGamification> = student.gamification || {};
  const studentResults = results.filter((result) => result.studentId === student.id);
  const legacyResults = student.quizResults || [];
  const effectiveResults = studentResults.length > 0 ? studentResults : legacyResults;
  // Repeated periodic attempts remain visible in history, but progress is
  // summarized by the latest attempt for each periodic quiz.
  const latestByQuiz = new Map<string, QuizResult>();
  effectiveResults.forEach((result) => {
    const key = normalizeQuizType(result.quizType) === QuizType.PERIODIC
      ? result.quizId
      : `${result.quizId}:${result.id}`;
    const previous = latestByQuiz.get(key);
    if (!previous || new Date(result.createdAt).getTime() > new Date(previous.createdAt).getTime()) {
      latestByQuiz.set(key, result);
    }
  });
  const progressResults = Array.from(latestByQuiz.values());
  const averageScore = progressResults.length
    ? Math.round(progressResults.reduce((sum, result) => sum + Number(result.percentage || 0), 0) / progressResults.length)
    : 0;
  const lastQuiz = [...progressResults].sort(
    (a, b) => new Date(b.createdAt).getTime() - new Date(a.createdAt).getTime(),
  )[0] || null;

  return {
    gems: Number(snapshot.gems || 0),
    xp: Number(snapshot.xp || 0),
    level: Number(snapshot.level || 0),
    levelProgress: Number(snapshot.levelProgress || 0),
    streak: Number(snapshot.streak || 0),
    totalQuizzes: Number(snapshot.totalQuizzes ?? progressResults.length),
    totalLessons: Number(snapshot.totalLessons || 0),
    totalGames: Number(snapshot.totalGames || 0),
    achievementsCount: Number(snapshot.achievementsCount || 0),
    averageScore: Number(snapshot.averageScore ?? averageScore),
    lastQuiz,
    updatedAt: snapshot.updatedAt,
  };
}