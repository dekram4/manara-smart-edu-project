import { STORAGE_KEYS } from '../constants';
import type { StudentGamification, StudentInfo } from '../types';
import { getQuizResultPercentage } from './quizScoring';
import { readActiveSession, readStorageArray } from './storage';
import { writeActiveSession } from './storage';

// 🎮 محرك الإنجاز (Gamification Engine) لمنصة منارة
// نظام XP, Gems, Streak, Achievements مربوط بالمحتوى الحقيقي

const GAMIFICATION_KEYS = {
  XP: 'manara_xp',
  GEMS: 'manara_gems',
  LEVEL: 'manara_level',
  STREAK: 'manara_streak',
  LAST_LOGIN: 'manara_last_login',
  ACHIEVEMENTS: 'manara_achievements',
  TOTAL_QUIZZES: 'manara_total_quizzes',
  TOTAL_LESSONS: 'manara_total_lessons',
  TOTAL_GAMES: 'manara_total_games',
  STREAK_HISTORY: 'manara_streak_history',
  COMPLETED_LESSONS: 'manara_completed_lessons',
  COMPLETED_VIDEOS: 'manara_completed_videos',
  COMPLETED_QUIZ_REWARDS: 'manara_completed_quiz_rewards',
  COMPLETED_GAME_REWARDS: 'manara_completed_game_rewards',
  COMPLETED_BOSS_REWARDS: 'manara_completed_boss_rewards',
};

const XP_PER_GEM = 5;
const XP_PER_LEVEL = 100;

type ActivityType = 'lesson' | 'video';

type StudentIdentity = {
  id?: string;
  studentIdNumber?: string;
  username?: string;
};

function getStudentSuffix(studentInfo: StudentIdentity) {
  const identity = studentInfo.id || studentInfo.studentIdNumber || studentInfo.username || 'anonymous';
  return String(identity).replace(/[^a-zA-Z0-9_-]/g, '_');
}

function getScopedKey(key: string) {
  const active = readActiveSession<StudentIdentity>(STORAGE_KEYS.ACTIVE_STUDENT);
  const identity = active?.id || active?.studentIdNumber || active?.username;
  const suffix = identity
    ? String(identity).replace(/[^a-zA-Z0-9_-]/g, '_')
    : 'anonymous';
  return `${key}_${suffix}`;
}

// المكافآت
export const REWARDS = {
  QUIZ_CORRECT: { xp: 5, gems: 1 },
  QUIZ_COMPLETE: { xp: 10, gems: 2 },
  PERFECT_QUIZ: { xp: 50, gems: 10 },
  LESSON_COMPLETE: { xp: 25, gems: 5 },
  GAME_WIN: { xp: 15, gems: 3 },
  GAME_PERFECT: { xp: 25, gems: 5 },
  STREAK_BONUS: { xp: 0, gems: 0 },
  DAILY_LOGIN: { xp: 0, gems: 0 },
  CHAT_MESSAGE: { xp: 0, gems: 0 },
  PROBLEM_SOLVED: { xp: 5, gems: 1 },
  VIDEO_COMPLETE: { xp: 5, gems: 1 },
};

// الإنجازات
const ACHIEVEMENTS_LIST = [
  { id: 'first_quiz', title: 'أول اختبار', desc: 'أكمل أول اختبار', icon: '🎯', threshold: 1, type: 'quiz' },
  { id: 'quiz_warrior', title: 'مقاتل الاختبارات', desc: 'أكمل 10 اختبارات', icon: '⚔️', threshold: 10, type: 'quiz' },
  { id: 'perfect_quiz', title: 'نتيجة مثالية', desc: 'حصل على 100% في اختبار', icon: '⭐', threshold: 1, type: 'perfect' },
  { id: 'first_lesson', title: 'أول درس', desc: 'أكمل أول درس', icon: '📚', threshold: 1, type: 'lesson' },
  { id: 'lesson_master', title: 'سيد الدروس', desc: 'أكمل 10 دروس', icon: '🏆', threshold: 10, type: 'lesson' },
  { id: 'math_solver', title: 'حلال الرياضيات', desc: 'حل أول مسألة رياضية', icon: '🔢', threshold: 1, type: 'math' },
  { id: 'game_master', title: 'سيد الألعاب', desc: 'العب 5 ألعاب', icon: '🎮', threshold: 5, type: 'game' },
  { id: 'memory_master', title: 'سيد الذاكرة', desc: 'انتصر في لعبة الذاكرة', icon: '🧠', threshold: 1, type: 'memory' },
  { id: 'speed_demon', title: 'سريع كالبرق', desc: 'فوز في الاختبار السريع', icon: '⚡', threshold: 1, type: 'speed' },
  { id: 'streak_3', title: '3 أيام متواصل', desc: 'تعلم 3 أيام متتالية', icon: '🔥', threshold: 3, type: 'streak' },
  { id: 'streak_7', title: 'أسبوع متواصل', desc: 'تعلم 7 أيام متتالية', icon: '🔥', threshold: 7, type: 'streak' },
  { id: 'level_5', title: 'المستوى 5', desc: 'اوصل إلى المستوى 5', icon: '💪', threshold: 5, type: 'level' },
  { id: 'gem_collector', title: 'جامع الجواهر', desc: 'اجمع 50 جوهرة', icon: '💎', threshold: 50, type: 'gems' },
];

function getStorage(key: string, defaultValue: any = 0) {
  try {
    const val = localStorage.getItem(getScopedKey(key));
    if (val === null) return defaultValue;
    return JSON.parse(val);
  } catch { return defaultValue; }
}

function setStorage(key: string, value: any) {
  localStorage.setItem(getScopedKey(key), JSON.stringify(value));
}

/**
 * Restore the shared student snapshot into the student's scoped local keys.
 * This is intentionally additive/defensive so an offline local score is not
 * replaced by an older remote snapshot.
 */
export function hydrateGamificationFromStudent(studentInfo?: StudentInfo | null): void {
  if (!studentInfo?.gamification) return;
  const snapshot = studentInfo.gamification;
  const currentXP = getXP();
  const currentGems = getGems();
  const currentLevel = getStorage(GAMIFICATION_KEYS.LEVEL, 0);
  const currentStreak = getStreak();
  const currentAchievements = getAchievements();

  if (Number(snapshot.xp || 0) > currentXP) setStorage(GAMIFICATION_KEYS.XP, Number(snapshot.xp));
  if (Number(snapshot.gems || 0) > currentGems) setStorage(GAMIFICATION_KEYS.GEMS, Number(snapshot.gems));
  if (Number(snapshot.level || 0) > currentLevel) setStorage(GAMIFICATION_KEYS.LEVEL, Number(snapshot.level));
  if (Number(snapshot.streak || 0) > currentStreak) setStorage(GAMIFICATION_KEYS.STREAK, Number(snapshot.streak));
  if (currentAchievements.length < Number(snapshot.achievementsCount || 0)) {
    setStorage(GAMIFICATION_KEYS.ACHIEVEMENTS, [
      ...currentAchievements,
      ...Array.from(
        { length: Number(snapshot.achievementsCount || 0) - currentAchievements.length },
        (_, index) => ({ id: `remote-achievement-${index + 1}`, title: 'إنجاز سابق' }),
      ),
    ]);
  }
  if (Number(snapshot.totalQuizzes || 0) > Number(getStorage(GAMIFICATION_KEYS.TOTAL_QUIZZES, 0))) {
    setStorage(GAMIFICATION_KEYS.TOTAL_QUIZZES, Number(snapshot.totalQuizzes));
  }
  if (Number(snapshot.totalLessons || 0) > Number(getStorage(GAMIFICATION_KEYS.TOTAL_LESSONS, 0))) {
    setStorage(GAMIFICATION_KEYS.TOTAL_LESSONS, Number(snapshot.totalLessons));
  }
  if (Number(snapshot.totalGames || 0) > Number(getStorage(GAMIFICATION_KEYS.TOTAL_GAMES, 0))) {
    setStorage(GAMIFICATION_KEYS.TOTAL_GAMES, Number(snapshot.totalGames));
  }
}

function getCompletedActivities(type: ActivityType): string[] {
  const key = type === 'lesson'
    ? GAMIFICATION_KEYS.COMPLETED_LESSONS
    : GAMIFICATION_KEYS.COMPLETED_VIDEOS;
  return getStorage(key, []);
}

export function hasCompletedActivity(type: ActivityType, id: string) {
  return getCompletedActivities(type).includes(id);
}

function markActivityComplete(type: ActivityType, id: string) {
  const key = type === 'lesson'
    ? GAMIFICATION_KEYS.COMPLETED_LESSONS
    : GAMIFICATION_KEYS.COMPLETED_VIDEOS;
  const completed = getCompletedActivities(type);
  if (completed.includes(id)) return false;
  setStorage(key, [...completed, id]);
  return true;
}

// XP
export function getXP(): number { return getStorage(GAMIFICATION_KEYS.XP, 0); }
export function addXP(amount: number): number {
  const current = getXP();
  const newXP = current + amount;
  setStorage(GAMIFICATION_KEYS.XP, newXP);
  // Check level up
  checkLevelUp();
  return newXP;
}

// Gems
export function getGems(): number { return getStorage(GAMIFICATION_KEYS.GEMS, 0); }
export function addGems(amount: number): number {
  const current = getGems();
  const newGems = current + amount;
  setStorage(GAMIFICATION_KEYS.GEMS, newGems);
  return newGems;
}

// Level
export function getLevel(): number {
  const xp = getXP();
  return Math.floor(xp / XP_PER_LEVEL);
}
export function getLevelProgress(): number {
  const xp = getXP();
  const level = getLevel();
  const base = level * XP_PER_LEVEL;
  const next = base + XP_PER_LEVEL;
  return Math.min(100, Math.max(0, ((xp - base) / (next - base)) * 100));
}
function checkLevelUp() {
  const oldLevel = getStorage(GAMIFICATION_KEYS.LEVEL, 0);
  const newLevel = getLevel();
  if (newLevel > oldLevel) {
    setStorage(GAMIFICATION_KEYS.LEVEL, newLevel);
    // Level up achievement
    if (newLevel >= 5) unlockAchievement('level_5');
    return newLevel;
  }
  return null;
}

// Streak
export function getStreak(): number { return getStorage(GAMIFICATION_KEYS.STREAK, 0); }
export function checkStreak(): { streak: number; continued: boolean; bonus: boolean } {
  const today = new Date().toDateString();
  const lastLogin = getStorage(GAMIFICATION_KEYS.LAST_LOGIN, '');
  const yesterday = new Date(Date.now() - 86400000).toDateString();
  let streak = getStreak();
  let continued = false;
  let bonus = false;

  if (lastLogin === today) {
    // Already logged in today
    return { streak, continued: false, bonus: false };
  }

  if (lastLogin === yesterday) {
    streak += 1;
    continued = true;
    // Streak bonus every 3 days
    if (streak % 3 === 0) {
      addXP(REWARDS.STREAK_BONUS.xp);
      addGems(REWARDS.STREAK_BONUS.gems);
      bonus = true;
    }
  } else if (lastLogin !== today) {
    streak = 1; // Reset or first login
  }

  setStorage(GAMIFICATION_KEYS.STREAK, streak);
  setStorage(GAMIFICATION_KEYS.LAST_LOGIN, today);

  // Streak achievements
  if (streak >= 3) unlockAchievement('streak_3');
  if (streak >= 7) unlockAchievement('streak_7');

  // Daily login bonus
  addXP(REWARDS.DAILY_LOGIN.xp);
  addGems(REWARDS.DAILY_LOGIN.gems);

  return { streak, continued, bonus };
}

// Achievements
export function getAchievements(): any[] {
  return getStorage(GAMIFICATION_KEYS.ACHIEVEMENTS, []);
}
export function unlockAchievement(id: string): boolean {
  const achievements = getAchievements();
  if (achievements.find((a: any) => a.id === id)) return false; // Already unlocked

  const achievementDef = ACHIEVEMENTS_LIST.find(a => a.id === id);
  if (!achievementDef) return false;

  const newAchievement = {
    ...achievementDef,
    unlockedAt: new Date().toISOString(),
  };
  achievements.push(newAchievement);
  setStorage(GAMIFICATION_KEYS.ACHIEVEMENTS, achievements);

  return true;
}

// Stats tracking
export function incrementStat(type: 'quiz' | 'lesson' | 'game' | 'math') {
  const key = {
    quiz: GAMIFICATION_KEYS.TOTAL_QUIZZES,
    lesson: GAMIFICATION_KEYS.TOTAL_LESSONS,
    game: GAMIFICATION_KEYS.TOTAL_GAMES,
    math: GAMIFICATION_KEYS.TOTAL_QUIZZES,
  }[type];
  const current = getStorage(key, 0);
  setStorage(key, current + 1);

  // Check achievements
  if (type === 'quiz' && current + 1 >= 1) unlockAchievement('first_quiz');
  if (type === 'quiz' && current + 1 >= 10) unlockAchievement('quiz_warrior');
  if (type === 'lesson' && current + 1 >= 1) unlockAchievement('first_lesson');
  if (type === 'lesson' && current + 1 >= 10) unlockAchievement('lesson_master');
  if (type === 'game' && current + 1 >= 5) unlockAchievement('game_master');
  if (type === 'math' && current + 1 >= 1) unlockAchievement('math_solver');
}

// Reward helpers
export function rewardQuizComplete(score: number, total: number) {
  return rewardQuizCompleteWithId(score, total);
}

export function rewardQuizCompleteWithId(score: number, total: number, rewardId?: string) {
  if (rewardId) {
    const completedRewards = getStorage(GAMIFICATION_KEYS.COMPLETED_QUIZ_REWARDS, []);
    if (completedRewards.includes(rewardId)) {
      return { xp: 0, gems: 0, percentage: (score / total) * 100, alreadyRewarded: true };
    }
    setStorage(GAMIFICATION_KEYS.COMPLETED_QUIZ_REWARDS, [...completedRewards, rewardId]);
  }

  const percentage = (score / total) * 100;
  const gems = score; // Gem-per-correct-answer rule
  const xp = gems * XP_PER_GEM;

  if (percentage === 100) {
    unlockAchievement('perfect_quiz');
  } else if (percentage >= 60) {
    unlockAchievement('first_quiz');
  }

  addXP(xp);
  addGems(gems);
  incrementStat('quiz');

  return { xp, gems, percentage, alreadyRewarded: false };
}

export function rewardLessonComplete(lessonId = 'lesson') {
  if (!markActivityComplete('lesson', lessonId)) {
    return { ...REWARDS.LESSON_COMPLETE, alreadyRewarded: true };
  }
  addXP(REWARDS.LESSON_COMPLETE.xp);
  addGems(REWARDS.LESSON_COMPLETE.gems);
  incrementStat('lesson');
  return { ...REWARDS.LESSON_COMPLETE, alreadyRewarded: false };
}

export function rewardVideoComplete(videoId: string) {
  if (!markActivityComplete('video', videoId)) {
    return { ...REWARDS.VIDEO_COMPLETE, alreadyRewarded: true };
  }
  addXP(REWARDS.VIDEO_COMPLETE.xp);
  addGems(REWARDS.VIDEO_COMPLETE.gems);
  return { ...REWARDS.VIDEO_COMPLETE, alreadyRewarded: false };
}

export function rewardGameWin(gameType: 'memory' | 'truefalse' | 'speed') {
  addXP(REWARDS.GAME_WIN.xp);
  addGems(REWARDS.GAME_WIN.gems);
  incrementStat('game');
  if (gameType === 'memory') unlockAchievement('memory_master');
  if (gameType === 'speed') unlockAchievement('speed_demon');
  return REWARDS.GAME_WIN;
}

export function rewardGamePerformanceWithId(
  gameType: 'memory' | 'truefalse' | 'speed',
  score: number,
  maxScore: number,
  rewardId: string,
) {
  const safeMax = Math.max(1, maxScore);
  const normalized = Math.max(0, Math.min(score, safeMax));
  const percentage = (normalized / safeMax) * 100;

  const completedRewards = getStorage(GAMIFICATION_KEYS.COMPLETED_GAME_REWARDS, []);
  if (completedRewards.includes(rewardId)) {
    return { xp: 0, gems: 0, percentage, alreadyRewarded: true };
  }

  // Reward tiers that keep the rule 1 gem = 5 XP.
  let gems = 1;
  if (percentage >= 95) gems = 8;
  else if (percentage >= 80) gems = 6;
  else if (percentage >= 60) gems = 4;
  else if (percentage >= 40) gems = 2;

  const xp = gems * XP_PER_GEM;
  addGems(gems);
  addXP(xp);
  incrementStat('game');

  if (gameType === 'memory') unlockAchievement('memory_master');
  if (gameType === 'speed') unlockAchievement('speed_demon');

  setStorage(GAMIFICATION_KEYS.COMPLETED_GAME_REWARDS, [...completedRewards, rewardId]);
  return { xp, gems, percentage, alreadyRewarded: false };
}

export function rewardWeeklyBossWithId(score: number, maxScore: number, rewardId: string) {
  const safeMax = Math.max(1, maxScore);
  const normalized = Math.max(0, Math.min(score, safeMax));
  const percentage = (normalized / safeMax) * 100;

  const completedRewards = getStorage(GAMIFICATION_KEYS.COMPLETED_BOSS_REWARDS, []);
  if (completedRewards.includes(rewardId)) {
    return { xp: 0, gems: 0, percentage, alreadyRewarded: true };
  }

  // Weekly boss challenge pays more than regular game rounds.
  let gems = 3;
  if (percentage >= 95) gems = 18;
  else if (percentage >= 85) gems = 14;
  else if (percentage >= 70) gems = 10;
  else if (percentage >= 55) gems = 7;
  else if (percentage >= 40) gems = 5;

  const xp = gems * XP_PER_GEM;
  addGems(gems);
  addXP(xp);
  incrementStat('game');
  unlockAchievement('game_master');

  setStorage(GAMIFICATION_KEYS.COMPLETED_BOSS_REWARDS, [...completedRewards, rewardId]);
  return { xp, gems, percentage, alreadyRewarded: false };
}

export function rewardProblemSolved() {
  addXP(REWARDS.PROBLEM_SOLVED.xp);
  addGems(REWARDS.PROBLEM_SOLVED.gems);
  incrementStat('math');
  return REWARDS.PROBLEM_SOLVED;
}

// Get full stats object
export function getGamificationStats() {
  const storedXP = getXP();
  const effectiveXP = storedXP;
  const effectiveLevel = Math.floor(effectiveXP / XP_PER_LEVEL);
  const levelBaseXP = effectiveLevel * XP_PER_LEVEL;
  const levelProgress = Math.min(100, Math.max(0, ((effectiveXP - levelBaseXP) / XP_PER_LEVEL) * 100));

  return {
    xp: effectiveXP,
    gems: getGems(),
    level: effectiveLevel,
    levelProgress,
    streak: getStreak(),
    achievements: getAchievements(),
    totalQuizzes: getStorage(GAMIFICATION_KEYS.TOTAL_QUIZZES, 0),
    totalLessons: getStorage(GAMIFICATION_KEYS.TOTAL_LESSONS, 0),
    totalGames: getStorage(GAMIFICATION_KEYS.TOTAL_GAMES, 0),
  };
}

/**
 * Copy the active student's scoped gamification values into the shared
 * student record. This keeps parents and teachers in sync without exposing
 * the scoped localStorage keys or duplicating the reward engine.
 */
export function syncGamificationToStudent(studentInfo?: StudentInfo | null): StudentGamification | null {
  const active = studentInfo || readActiveSession<StudentInfo>(STORAGE_KEYS.ACTIVE_STUDENT);
  if (!active?.id) return null;

  const stats = getGamificationStats();
  const quizResults = readStorageArray<any>(STORAGE_KEYS.QUIZ_RESULTS);
  const studentQuizResults = quizResults.filter((result) => result?.studentId === active!.id);
  const fallbackQuizResults = Array.isArray(active.quizResults) ? active.quizResults : [];
  const effectiveQuizResults = studentQuizResults.length > 0 ? studentQuizResults : fallbackQuizResults;
  const lastQuiz = [...effectiveQuizResults].sort(
    (a, b) => new Date(b.createdAt).getTime() - new Date(a.createdAt).getTime(),
  )[0];
  const averageScore = effectiveQuizResults.length > 0
    ? Math.round(effectiveQuizResults.reduce((sum, result) => sum + getQuizResultPercentage(result), 0) / effectiveQuizResults.length)
    : 0;
  const nextSnapshot: StudentGamification = {
    xp: stats.xp,
    gems: stats.gems,
    level: stats.level,
    levelProgress: stats.levelProgress,
    streak: stats.streak,
    totalQuizzes: stats.totalQuizzes,
    totalLessons: stats.totalLessons,
    totalGames: stats.totalGames,
    achievementsCount: stats.achievements.length,
    averageScore,
    lastQuizAt: lastQuiz?.createdAt,
    lastQuizPercentage: lastQuiz ? getQuizResultPercentage(lastQuiz) : undefined,
    xpBonus200GrantedAt: active.gamification?.xpBonus200GrantedAt,
    updatedAt: new Date().toISOString(),
  };

  const students = readStorageArray<StudentInfo>(STORAGE_KEYS.STUDENTS);
  const currentStudent = students.find((student) => student.id === active!.id);
  const previousSnapshot = currentStudent?.gamification;
  const progressChanged = !previousSnapshot || (
    previousSnapshot.xp !== nextSnapshot.xp ||
    previousSnapshot.gems !== nextSnapshot.gems ||
    previousSnapshot.level !== nextSnapshot.level ||
    previousSnapshot.levelProgress !== nextSnapshot.levelProgress ||
    previousSnapshot.streak !== nextSnapshot.streak ||
    previousSnapshot.totalQuizzes !== nextSnapshot.totalQuizzes ||
    previousSnapshot.totalLessons !== nextSnapshot.totalLessons ||
    previousSnapshot.totalGames !== nextSnapshot.totalGames ||
    previousSnapshot.achievementsCount !== nextSnapshot.achievementsCount ||
    previousSnapshot.averageScore !== nextSnapshot.averageScore ||
    previousSnapshot.lastQuizAt !== nextSnapshot.lastQuizAt ||
    previousSnapshot.lastQuizPercentage !== nextSnapshot.lastQuizPercentage
  );
  const snapshot = progressChanged
    ? nextSnapshot
    : { ...nextSnapshot, updatedAt: previousSnapshot.updatedAt };

  const updatedStudents = students.map((student) =>
    student.id === active!.id
      ? {
        // Preserve the newest quiz result and academic path from ACTIVE_STUDENT
        // while adding the shared gamification snapshot to the canonical record.
        ...student,
        ...active,
        gamification: snapshot,
        lastActivity: active!.lastActivity || student.lastActivity || snapshot.updatedAt,
      }
      : student,
  );
  if (JSON.stringify(updatedStudents) !== JSON.stringify(students)) {
    localStorage.setItem(STORAGE_KEYS.STUDENTS, JSON.stringify(updatedStudents));
  }

  const updatedActive = { ...active, gamification: snapshot };
  writeActiveSession(STORAGE_KEYS.ACTIVE_STUDENT, updatedActive);
  return snapshot;
}

// Reset (for testing)
export function resetGamification() {
  Object.values(GAMIFICATION_KEYS).forEach(k => localStorage.removeItem(getScopedKey(k)));
}

export function resetGamificationForStudent(studentInfo: StudentIdentity) {
  const suffix = getStudentSuffix(studentInfo);
  Object.values(GAMIFICATION_KEYS).forEach((key) => {
    localStorage.removeItem(`${key}_${suffix}`);
  });

  Object.keys(localStorage).forEach((key) => {
    if (key.startsWith('MANARA_GAMIFICATION_RESET_') && key.endsWith(`_${suffix}`)) {
      localStorage.removeItem(key);
    }
  });
}
