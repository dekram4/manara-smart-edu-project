import { playLamsaSound } from './sounds';

// نظام تشغيل أصوات محاكاة الألعاب
export const sounds = {
  click: 'click',
  correct: 'success',
  wrong: 'error',
  streak: 'star',
  pop: 'pop',
} as const;

export const playSound = (soundName: keyof typeof sounds) => {
  const tone = sounds[soundName];
  if (tone) {
    playLamsaSound(tone);
  }
};