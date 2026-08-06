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
let rewardTimer: ReturnType<typeof setTimeout> | null = null;

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

const audioOptions = (src: string[], volume: number) => ({
  src,
  volume,
  preload: true,
  html5: true,
  onloaderror: (_id: number, error: unknown) => {
    console.warn('[MANARA audio] Could not load sound:', src[0], error);
  },
  onplayerror: (_id: number, error: unknown) => {
    console.warn('[MANARA audio] Could not play sound:', src[0], error);
  },
});

// أصوات أصلية محلية للواجهة والتعلم والمكافآت — يتم تحميلها مسبقًا حتى تستجيب فورًا.
export const gameSounds = {
  uiHover: new Howl(audioOptions(['/audio/manara-soft-hover.mp3'], 0.62)),
  uiSelect: new Howl(audioOptions(['/audio/manara-portal-transition.mp3'], 0.64)),
  portalTransition: new Howl(audioOptions(['/audio/manara-portal-transition.mp3'], 0.6)),
  loginChime: new Howl(audioOptions(['/audio/manara-login-chime.mp3'], 0.72)),
  studentWelcome: new Howl(audioOptions(['/audio/manara-arabic-student-welcome.mp3'], 1)),
  correctAnswer: new Howl(audioOptions(['/audio/manara-applause-clarity.mp3'], 0.82)),
  wrongAnswer: new Howl(audioOptions(['/audio/manara-hover-clarity.mp3'], 0.24)),
  collectGem: new Howl(audioOptions(['/audio/manara-gem-clarity.mp3'], 0.95)),
  levelUp: new Howl(audioOptions(['/audio/manara-applause-clarity.mp3'], 0.9)),
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

  static playRewardSequence({ celebrate = false, gems = 0 }: { celebrate?: boolean; gems?: number } = {}) {
    if (!isSoundEnabled()) return;
    if (rewardTimer) {
      clearTimeout(rewardTimer);
      rewardTimer = null;
    }

    if (celebrate) {
      GameAudioEngine.play('correctAnswer');
    }

    if (gems > 0) {
      rewardTimer = setTimeout(() => {
        rewardTimer = null;
        GameAudioEngine.play('collectGem');
      }, celebrate ? 2300 : 80);
    }
  }

  static setGlobalVolume(volume: number) {
    const safeVolume = Math.max(0, Math.min(1, volume));
    Object.values(gameSounds).forEach(sound => sound.volume(safeVolume));
  }
}