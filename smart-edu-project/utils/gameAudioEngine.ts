import { Howl } from 'howler';

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

// أصوات أصلية محلية للواجهة والتعلم والمكافآت — يتم تحميلها عند الحاجة فقط.
export const gameSounds = {
  uiHover: new Howl({
    src: ['/audio/manara-soft-hover.mp3'],
    volume: 0.16,
    preload: false,
  }),
  uiSelect: new Howl({
    src: ['/audio/manara-portal-transition.mp3'],
    volume: 0.28,
    preload: false,
  }),
  portalTransition: new Howl({
    src: ['/audio/manara-portal-transition.mp3'],
    volume: 0.24,
    preload: false,
  }),
  correctAnswer: new Howl({
    src: ['/audio/manara-victory-applause.mp3'],
    volume: 0.34,
    preload: false,
  }),
  wrongAnswer: new Howl({
    src: ['/audio/manara-soft-hover.mp3'],
    volume: 0.08,
    preload: false,
  }),
  collectGem: new Howl({
    src: ['/audio/manara-victory-applause.mp3'],
    volume: 0.28,
    preload: false,
  }),
  levelUp: new Howl({
    src: ['/audio/manara-victory-applause.mp3'],
    volume: 0.42,
    preload: false,
  }),
};

export type GameSoundName = keyof typeof gameSounds;

export class GameAudioEngine {
  static play(soundName: GameSoundName) {
    if (!isSoundEnabled()) return;

    const sound = gameSounds[soundName];
    sound.stop();
    sound.play();
  }

  static setGlobalVolume(volume: number) {
    const safeVolume = Math.max(0, Math.min(1, volume));
    Object.values(gameSounds).forEach(sound => sound.volume(safeVolume));
  }
}