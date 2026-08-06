import { Howl, Howler } from 'howler';

const SOUND_PREFERENCE_KEY = 'manara_game_controls';

const isSoundEnabled = () => {
  if (typeof window === 'undefined') return true;
  try {
    const raw = window.localStorage.getItem(SOUND_PREFERENCE_KEY);
    if (!raw) return true;
    return JSON.parse(raw).soundEnabled ?? true;
  } catch {
    return true;
  }
};

let audioUnlocked = false;
let lastHoverAt = 0;

const unlockAudio = () => {
  if (typeof window === 'undefined') return;
  try {
    const context = Howler.ctx;
    if (context?.state === 'suspended') {
      void context.resume();
    }
    audioUnlocked = true;
  } catch {
    // The browser will retry unlocking on the next interaction.
    audioUnlocked = false;
  }
};

if (typeof window !== 'undefined') {
  const unlockEvents = ['pointerdown', 'touchstart', 'keydown'];
  unlockEvents.forEach((eventName) => {
    window.addEventListener(eventName, unlockAudio, { once: true, passive: true });
  });
}

// أصوات أصلية محلية للواجهة والتعلم والمكافآت — يتم تحميلها مسبقًا حتى تستجيب فورًا.
export const gameSounds = {
  uiHover: new Howl({
    src: ['/audio/manara-soft-hover.mp3'],
    volume: 0.48,
    preload: true,
  }),
  uiSelect: new Howl({
    src: ['/audio/manara-portal-transition.mp3'],
    volume: 0.58,
    preload: true,
  }),
  portalTransition: new Howl({
    src: ['/audio/manara-portal-transition.mp3'],
    volume: 0.52,
    preload: true,
  }),
  loginChime: new Howl({
    src: ['/audio/manara-login-chime.mp3'],
    volume: 0.62,
    preload: true,
  }),
  studentWelcome: new Howl({
    src: ['/audio/manara-arabic-student-welcome.mp3'],
    volume: 0.92,
    preload: true,
  }),
  correctAnswer: new Howl({
    src: ['/audio/manara-victory-applause.mp3'],
    volume: 0.64,
    preload: true,
  }),
  wrongAnswer: new Howl({
    src: ['/audio/manara-soft-hover.mp3'],
    volume: 0.2,
    preload: true,
  }),
  collectGem: new Howl({
    src: ['/audio/manara-gem-reward.mp3'],
    volume: 0.7,
    preload: true,
  }),
  levelUp: new Howl({
    src: ['/audio/manara-victory-applause.mp3'],
    volume: 0.72,
    preload: true,
  }),
};

export type GameSoundName = keyof typeof gameSounds;

export class GameAudioEngine {
  static play(soundName: GameSoundName) {
    if (!isSoundEnabled()) return;

    if (soundName === 'uiHover') {
      const now = Date.now();
      if (now - lastHoverAt < 180) return;
      lastHoverAt = now;
    }

    unlockAudio();
    const sound = gameSounds[soundName];
    const start = () => {
      sound.stop();
      sound.play();
    };
    const context = Howler.ctx;
    if (context?.state === 'suspended') {
      void context.resume().then(start).catch(start);
      return;
    }
    start();
  }

  static setGlobalVolume(volume: number) {
    const safeVolume = Math.max(0, Math.min(1, volume));
    Object.values(gameSounds).forEach(sound => sound.volume(safeVolume));
  }
}