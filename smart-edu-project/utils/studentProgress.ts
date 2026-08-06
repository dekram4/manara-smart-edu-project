import type { QuizResult, StudentInfo, StudentGamification } from '../types';

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
  const averageScore = effectiveResults.length
    ? Math.round(effectiveResults.reduce((sum, result) => sum + Number(result.percentage || 0), 0) / effectiveResults.length)
    : 0;
  const lastQuiz = [...effectiveResults].sort(
    (a, b) => new Date(b.createdAt).getTime() - new Date(a.createdAt).getTime(),
  )[0] || null;

  return {
    gems: Number(snapshot.gems || 0),
    xp: Number(snapshot.xp || 0),
    level: Number(snapshot.level || 0),
    levelProgress: Number(snapshot.levelProgress || 0),
    streak: Number(snapshot.streak || 0),
    totalQuizzes: Number(snapshot.totalQuizzes ?? effectiveResults.length),
    totalLessons: Number(snapshot.totalLessons || 0),
    totalGames: Number(snapshot.totalGames || 0),
    achievementsCount: Number(snapshot.achievementsCount || 0),
    averageScore: Number(snapshot.averageScore ?? averageScore),
    lastQuiz,
    updatedAt: snapshot.updatedAt,
  };
}