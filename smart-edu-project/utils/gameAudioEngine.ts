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

// أصوات الواجهة والتعلم والمكافآت — يتم تحميلها عند التشغيل فقط.
export const gameSounds = {
  roleHover: new Howl({
    src: ['https://assets.mixkit.co/active_storage/sfx/2571/2571-preview.mp3'],
    volume: 0.2,
    preload: false,
  }),
  roleSelect: new Howl({
    src: ['https://assets.mixkit.co/active_storage/sfx/2568/2568-preview.mp3'],
    volume: 0.4,
    preload: false,
  }),
  correctAnswer: new Howl({
    src: ['https://assets.mixkit.co/active_storage/sfx/1435/1435-preview.mp3'],
    volume: 0.5,
    preload: false,
  }),
  wrongAnswer: new Howl({
    src: ['https://assets.mixkit.co/active_storage/sfx/2572/2572-preview.mp3'],
    volume: 0.3,
    preload: false,
  }),
  collectGem: new Howl({
    src: ['https://assets.mixkit.co/active_storage/sfx/2019/2019-preview.mp3'],
    volume: 0.6,
    preload: false,
  }),
  levelUp: new Howl({
    src: ['https://assets.mixkit.co/active_storage/sfx/1435/1435-preview.mp3'],
    volume: 0.8,
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