// 🎮 Game Engine - محرك ألعاب منارة المعرفة
// أصوات وتأثيرات تفاعلية مشتركة عبر جميع شاشات الطالب

import { Platform } from 'react-native';
import * as Haptics from 'expo-haptics';

// Sound engine using Web Audio API (works on web/mobile via expo-av)
let audioCtx: AudioContext | null = null;

const getAudioCtx = () => {
  if (!audioCtx && typeof window !== 'undefined') {
    audioCtx = new AudioContext();
  }
  return audioCtx;
};

export const playSound = (type: 'click' | 'pop' | 'success' | 'error' | 'magic' | 'win' | 'levelUp') => {
  try {
    const ctx = getAudioCtx();
    if (!ctx) return;
    const now = ctx.currentTime;
    const playTone = (freq: number, start: number, dur: number, vol = 0.12, oscType: OscillatorType = 'sine') => {
      const osc = ctx.createOscillator();
      const gain = ctx.createGain();
      osc.type = oscType;
      osc.frequency.setValueAtTime(freq, now + start);
      gain.gain.setValueAtTime(vol, now + start);
      gain.gain.exponentialRampToValueAtTime(0.001, now + start + dur);
      osc.connect(gain);
      gain.connect(ctx.destination);
      osc.start(now + start);
      osc.stop(now + start + dur);
    };

    switch (type) {
      case 'click':
        playTone(880, 0, 0.06, 0.08);
        break;
      case 'pop':
        playTone(600, 0, 0.08, 0.1);
        playTone(900, 0.04, 0.06, 0.08);
        break;
      case 'success':
        playTone(523, 0, 0.12, 0.14);
        playTone(659, 0.1, 0.12, 0.14);
        playTone(784, 0.2, 0.18, 0.16);
        break;
      case 'error':
        playTone(200, 0, 0.18, 0.08, 'sawtooth');
        playTone(150, 0.12, 0.2, 0.08, 'sawtooth');
        break;
      case 'magic':
        playTone(800, 0, 0.15, 0.1);
        playTone(600, 0.08, 0.15, 0.1);
        playTone(1000, 0.16, 0.2, 0.1);
        break;
      case 'win':
        [523, 659, 784, 1047, 1318].forEach((f, i) => playTone(f, i * 0.15, 0.25, 0.14));
        break;
      case 'levelUp':
        [392, 523, 659, 784, 1047].forEach((f, i) => playTone(f, i * 0.1, 0.3, 0.16));
        break;
    }
  } catch {}
};

// Haptic feedback helpers
export const hapticClick = () => Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Light);
export const hapticSuccess = () => Haptics.notificationAsync(Haptics.NotificationFeedbackType.Success);
export const hapticError = () => Haptics.notificationAsync(Haptics.NotificationFeedbackType.Error);
export const hapticHeavy = () => Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Heavy);

// Level system
export const calculateLevel = (xp: number): { level: number; progress: number; nextLevelXP: number } => {
  // XP curve: each level needs 500 more than previous
  // Level 1: 0-500, Level 2: 500-1200, Level 3: 1200-2100, etc.
  let level = 1;
  let totalNeeded = 0;
  while (xp >= totalNeeded + level * 500) {
    totalNeeded += level * 500;
    level++;
  }
  const currentLevelXP = level * 500;
  const progress = ((xp - totalNeeded) / currentLevelXP) * 100;
  return { level, progress: Math.max(0, Math.min(100, progress)), nextLevelXP: totalNeeded + currentLevelXP };
};

// Game rewards
export const REWARDS = {
  LESSON_COMPLETE: { xp: 50, gems: 2 },
  QUIZ_CORRECT: { xp: 10, gems: 1 },
  PERFECT_QUIZ: { xp: 100, gems: 10 },
  GAME_WIN: { xp: 30, gems: 3 },
  CHAT_MESSAGE: { xp: 5, gems: 0 },
  DAILY_LOGIN: { xp: 20, gems: 5 },
  STREAK_BONUS: { xp: 15, gems: 2 },
  AVATAR_INTERACT: { xp: 10, gems: 1 },
};

// Quest / Mission system
export interface Quest {
  id: string;
  title: string;
  description: string;
  icon: string;
  target: number;
  current: number;
  rewardXP: number;
  rewardGems: number;
  completed: boolean;
  claimed: boolean;
}

export const DEFAULT_QUESTS: Quest[] = [
  { id: 'q1', title: 'بطل اليوم', description: 'ادخل للتطبيق', icon: '🔑', target: 1, current: 0, rewardXP: 20, rewardGems: 5, completed: false, claimed: false },
  { id: 'q2', title: 'قارئ الدروس', description: 'أكمل 2 دروس', icon: '📖', target: 2, current: 0, rewardXP: 50, rewardGems: 3, completed: false, claimed: false },
  { id: 'q3', title: 'اللاعب الذكي', description: 'العب لعبة واحدة', icon: '🎮', target: 1, current: 0, rewardXP: 30, rewardGems: 3, completed: false, claimed: false },
  { id: 'q4', title: 'الإجابات الصحيحة', description: 'أجب على 5 أسئلة', icon: '✅', target: 5, current: 0, rewardXP: 40, rewardGems: 2, completed: false, claimed: false },
  { id: 'q5', title: 'تحدي الرياضيات', description: 'حل مسألة رياضية', icon: '🔢', target: 1, current: 0, rewardXP: 25, rewardGems: 2, completed: false, claimed: false },
  { id: 'q6', title: 'التواصل مع الصديق', description: 'تكلم مع الأفاتار', icon: '🤖', target: 1, current: 0, rewardXP: 15, rewardGems: 1, completed: false, claimed: false },
];

// Leaderboard simulation
export const getLeaderboard = () => [
  { rank: 1, name: 'محمد البطل', avatar: '👦', xp: 2840, level: 6, streak: 12 },
  { rank: 2, name: 'فاطمة المجد', avatar: '👧', xp: 2510, level: 5, streak: 8 },
  { rank: 3, name: 'أنت', avatar: '🤖', xp: 0, level: 1, streak: 0 },
  { rank: 4, name: 'عبدالله الذكي', avatar: '🧒', xp: 1890, level: 4, streak: 5 },
  { rank: 5, name: 'نورا النجمة', avatar: '👩', xp: 1560, level: 4, streak: 3 },
];
