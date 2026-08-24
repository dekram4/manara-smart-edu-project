/* Welcome voice helpers for MANARA SYSTEM — role-specific greetings */

import * as Tone from 'tone';
import { GameAudioEngine } from './gameAudioEngine';

type HowlerGlobal = {
  Howl?: new (options: { src: string[]; volume?: number; autoplay?: boolean }) => {
    play: () => void;
  };
};

const readSoundPreference = () => {
  if (typeof window === 'undefined') return true;
  try {
    const raw = window.localStorage.getItem('manara_game_controls');
    if (!raw) return true;
    const parsed = JSON.parse(raw);
    return parsed.soundEnabled ?? true;
  } catch {
    return true;
  }
};

const playAudioWithGain = (src: string, gain: number, label: string) => {
  if (!readSoundPreference()) return;

  const howlerGlobal = (window as Window & HowlerGlobal).Howl;
  if (typeof howlerGlobal === 'function') {
    try {
      const sound = new howlerGlobal({ src: [src], volume: Math.min(1.4, gain), autoplay: true });
      sound.play();
      return;
    } catch {
      // Fall back to the local Web Audio path below
    }
  }

  try {
    const ctx = new AudioContext();
    const audio = new Audio(src);
    audio.preload = 'auto';
    audio.volume = Math.min(1, gain);
    const source = ctx.createMediaElementSource(audio);
    const gainNode = ctx.createGain();
    gainNode.gain.value = Math.min(2.2, gain);
    source.connect(gainNode);
    gainNode.connect(ctx.destination);
    audio.addEventListener('canplaythrough', () => {
      const playPromise = audio.play();
      if (playPromise !== undefined) {
        playPromise.catch((err) => {
          console.warn(`[${label}] Autoplay blocked:`, err.message);
        });
      }
    }, { once: true });
    audio.addEventListener('error', (e) => {
      console.warn(`[${label}] Audio load error:`, e);
    }, { once: true });
    audio.load();
  } catch {
    /* Audio playback not supported */
  }
};

const playToneJsPattern = (
  sequence: Array<{ note: string; duration?: string; velocity?: number }>,
  options: { type?: Tone.ToneOscillatorType; volume?: number } = {}
) => {
  if (!readSoundPreference()) return;
  try {
    Tone.start();
    const synth = new Tone.PolySynth(Tone.Synth, {
      oscillator: { type: options.type ?? 'triangle' },
      envelope: { attack: 0.01, decay: 0.15, sustain: 0.6, release: 0.25 },
    }).toDestination();
    synth.volume.value = options.volume ?? -8;
    const now = Tone.now();
    sequence.forEach((step, index) => {
      synth.triggerAttackRelease(step.note, step.duration ?? '8n', now + index * 0.08, step.velocity ?? 0.8);
    });
  } catch {
    // fallback silently
  }
};

const playToneJsChime = (type: 'welcome' | 'success') => {
  if (type === 'welcome') {
    playToneJsPattern([
      { note: 'C5', duration: '8n', velocity: 0.7 },
      { note: 'E5', duration: '8n', velocity: 0.75 },
      { note: 'G5', duration: '8n', velocity: 0.8 },
    ], { type: 'triangle', volume: -10 });
  } else {
    playToneJsPattern([
      { note: 'G4', duration: '8n', velocity: 0.75 },
      { note: 'B4', duration: '8n', velocity: 0.8 },
      { note: 'D5', duration: '8n', velocity: 0.85 },
      { note: 'G5', duration: '8n', velocity: 0.9 },
    ], { type: 'sine', volume: -8 });
  }
};

let pendingStudentRefreshWelcome = false;
let studentRefreshWelcomeAudio: HTMLAudioElement | null = null;
let studentRefreshWelcomeAttempted = false;

const retryStudentRefreshWelcome = () => {
  if (!pendingStudentRefreshWelcome || !studentRefreshWelcomeAudio) return;
  void studentRefreshWelcomeAudio.play().then(() => {
    pendingStudentRefreshWelcome = false;
    studentRefreshWelcomeAudio = null;
  }).catch(() => {
    // Keep the one-shot retry armed until a real user gesture unlocks audio.
  });
};

export const playWelcomeStudentOnRefresh = () => {
  if (
    studentRefreshWelcomeAttempted
    || !readSoundPreference()
    || typeof window === 'undefined'
  ) return;
  studentRefreshWelcomeAttempted = true;
  const audio = new Audio('/audio/manara-arabic-student-welcome.mp3');
  audio.preload = 'auto';
  audio.volume = 1;
  studentRefreshWelcomeAudio = audio;
  pendingStudentRefreshWelcome = true;

  void audio.play().then(() => {
    pendingStudentRefreshWelcome = false;
    studentRefreshWelcomeAudio = null;
  }).catch(() => {
    const events = ['pointerdown', 'touchstart', 'keydown'];
    const retry = () => {
      retryStudentRefreshWelcome();
      if (!pendingStudentRefreshWelcome) {
        events.forEach(eventName => window.removeEventListener(eventName, retry));
      }
    };
    events.forEach(eventName => window.addEventListener(eventName, retry, { once: false, passive: true }));
  });
};

export const playWelcomeAdult = () => {
  playAudioWithGain('/audio/welcome-adult.mp3', 2.0, 'WelcomeAdult');
  playToneJsChime('welcome');
};

export const playCustomMp3Sound = (src: string, gain = 1.6, label = 'CustomMp3') => {
  playAudioWithGain(src, gain, label);
};

export const playSectionSound = (section: 'lessons' | 'games' | 'videos' | 'homework' | 'quiz' | 'portal') => {
  if (!readSoundPreference()) return;
  switch (section) {
    case 'lessons':
      playToneJsPattern([{ note: 'D5', duration: '8n', velocity: 0.7 }, { note: 'F5', duration: '8n', velocity: 0.75 }, { note: 'A5', duration: '8n', velocity: 0.8 }], { type: 'triangle', volume: -8 });
      break;
    case 'games':
      playToneJsPattern([{ note: 'E5', duration: '16n', velocity: 0.65 }, { note: 'G5', duration: '16n', velocity: 0.7 }, { note: 'B5', duration: '16n', velocity: 0.75 }], { type: 'sine', volume: -8 });
      break;
    case 'videos':
      playToneJsPattern([{ note: 'C5', duration: '8n', velocity: 0.65 }, { note: 'E5', duration: '8n', velocity: 0.7 }, { note: 'C6', duration: '8n', velocity: 0.75 }], { type: 'triangle', volume: -9 });
      break;
    case 'homework':
      playToneJsPattern([{ note: 'A4', duration: '8n', velocity: 0.6 }, { note: 'C5', duration: '8n', velocity: 0.65 }, { note: 'E5', duration: '8n', velocity: 0.7 }], { type: 'sine', volume: -9 });
      break;
    case 'quiz':
      playToneJsPattern([{ note: 'G4', duration: '8n', velocity: 0.7 }, { note: 'B4', duration: '8n', velocity: 0.75 }, { note: 'D5', duration: '8n', velocity: 0.8 }, { note: 'G5', duration: '8n', velocity: 0.9 }], { type: 'sine', volume: -7 });
      break;
    case 'portal':
      playToneJsPattern([{ note: 'A3', duration: '8n', velocity: 0.55 }, { note: 'C4', duration: '8n', velocity: 0.6 }, { note: 'E4', duration: '8n', velocity: 0.65 }, { note: 'A4', duration: '8n', velocity: 0.7 }], { type: 'triangle', volume: -10 });
      break;
  }
};

export const playNavigationSound = () => {
  if (!readSoundPreference()) return;
  playToneJsPattern([
    { note: 'C5', duration: '16n', velocity: 0.55 },
    { note: 'E5', duration: '16n', velocity: 0.6 },
    { note: 'G5', duration: '16n', velocity: 0.65 },
  ], { type: 'triangle', volume: -10 });
  try {
    const ctx = new AudioContext();
    const now = ctx.currentTime;
    const playTone = (freq: number, start: number, duration: number, vol: number = 0.08) => {
      const osc = ctx.createOscillator();
      const gain = ctx.createGain();
      osc.type = 'triangle';
      osc.frequency.setValueAtTime(freq, now + start);
      osc.frequency.exponentialRampToValueAtTime(freq * 1.08, now + start + duration);
      gain.gain.setValueAtTime(vol, now + start);
      gain.gain.exponentialRampToValueAtTime(0.001, now + start + duration);
      osc.connect(gain);
      gain.connect(ctx.destination);
      osc.start(now + start);
      osc.stop(now + start + duration);
    };
    playTone(720, 0, 0.08, 0.12);
    playTone(860, 0.05, 0.09, 0.1);
    playTone(1040, 0.1, 0.12, 0.08);
  } catch {
    /* Audio not supported */
  }
};

export const playEncouragementSound = () => {
  if (!readSoundPreference()) return;
  playToneJsPattern([
    { note: 'C5', duration: '8n', velocity: 0.7 },
    { note: 'E5', duration: '8n', velocity: 0.75 },
    { note: 'G5', duration: '8n', velocity: 0.8 },
    { note: 'C6', duration: '8n', velocity: 0.85 },
  ], { type: 'sine', volume: -7 });
  try {
    const ctx = new AudioContext();
    const now = ctx.currentTime;
    const playTone = (freq: number, start: number, duration: number, vol: number = 0.12) => {
      const osc = ctx.createOscillator();
      const gain = ctx.createGain();
      osc.type = 'sine';
      osc.frequency.setValueAtTime(freq, now + start);
      gain.gain.setValueAtTime(vol, now + start);
      gain.gain.exponentialRampToValueAtTime(0.001, now + start + duration);
      osc.connect(gain);
      gain.connect(ctx.destination);
      osc.start(now + start);
      osc.stop(now + start + duration);
    };
    playTone(523, 0, 0.16, 0.16);
    playTone(659, 0.08, 0.16, 0.16);
    playTone(784, 0.16, 0.22, 0.16);
    playTone(1047, 0.28, 0.26, 0.14);
  } catch {
    /* Audio not supported */
  }
};

export const playPortalEntranceSound = () => {
  if (!readSoundPreference()) return;
  playToneJsPattern([
    { note: 'E4', duration: '8n', velocity: 0.6 },
    { note: 'A4', duration: '8n', velocity: 0.65 },
    { note: 'C5', duration: '8n', velocity: 0.7 },
    { note: 'E5', duration: '8n', velocity: 0.75 },
  ], { type: 'triangle', volume: -9 });
  try {
    const ctx = new AudioContext();
    const now = ctx.currentTime;
    const playTone = (freq: number, start: number, duration: number, vol: number = 0.08, type: OscillatorType = 'sine') => {
      const osc = ctx.createOscillator();
      const gain = ctx.createGain();
      osc.type = type;
      osc.frequency.setValueAtTime(freq, now + start);
      gain.gain.setValueAtTime(vol, now + start);
      gain.gain.exponentialRampToValueAtTime(0.001, now + start + duration);
      osc.connect(gain);
      gain.connect(ctx.destination);
      osc.start(now + start);
      osc.stop(now + start + duration);
    };
    playTone(523, 0, 0.12, 0.12, 'triangle');
    playTone(659, 0.05, 0.14, 0.1, 'sine');
    playTone(784, 0.1, 0.18, 0.09, 'triangle');
    playTone(1047, 0.16, 0.22, 0.08, 'sine');
  } catch {
    /* Audio not supported */
  }
};

export const playSuccessSound = () => {
  playEncouragementSound();
  playToneJsChime('success');
};

export const playErrorSound = () => {
  if (!readSoundPreference()) return;
  playToneJsPattern([
    { note: 'C3', duration: '1n', velocity: 0.45 },
    { note: 'A2', duration: '1n', velocity: 0.4 },
  ], { type: 'sawtooth', volume: -12 });
  try {
    const ctx = new AudioContext();
    const osc = ctx.createOscillator();
    const gain = ctx.createGain();
    osc.type = 'triangle';
    osc.frequency.setValueAtTime(150, ctx.currentTime);
    osc.frequency.linearRampToValueAtTime(100, ctx.currentTime + 0.3);
    gain.gain.setValueAtTime(0.16, ctx.currentTime);
    gain.gain.exponentialRampToValueAtTime(0.001, ctx.currentTime + 0.3);
    osc.connect(gain);
    gain.connect(ctx.destination);
    osc.start(ctx.currentTime);
    osc.stop(ctx.currentTime + 0.3);
  } catch {
    /* Audio not supported */
  }
};

// 🎵 نظام محرك الأصوات التفاعلي للأطفال (مستوحى من تطبيق لمسة)
export const playLamsaSound = (type: 'click' | 'pop' | 'success' | 'magic' | 'send' | 'error' | 'star') => {
  if (!readSoundPreference()) return;
  switch (type) {
    case 'click':
      playToneJsPattern([{ note: 'A4', duration: '16n', velocity: 0.6 }], { type: 'sine', volume: -10 });
      break;
    case 'pop':
      playToneJsPattern([{ note: 'C5', duration: '16n', velocity: 0.65 }, { note: 'E5', duration: '16n', velocity: 0.7 }], { type: 'triangle', volume: -9 });
      break;
    case 'success':
      playToneJsPattern([{ note: 'G4', duration: '8n', velocity: 0.7 }, { note: 'B4', duration: '8n', velocity: 0.75 }, { note: 'D5', duration: '8n', velocity: 0.8 }, { note: 'G5', duration: '8n', velocity: 0.85 }], { type: 'sine', volume: -8 });
      break;
    case 'magic':
      playToneJsPattern([{ note: 'C5', duration: '8n', velocity: 0.7 }, { note: 'A4', duration: '8n', velocity: 0.75 }, { note: 'E5', duration: '8n', velocity: 0.8 }, { note: 'C6', duration: '8n', velocity: 0.85 }], { type: 'triangle', volume: -8 });
      break;
    case 'send':
      playToneJsPattern([{ note: 'E5', duration: '16n', velocity: 0.6 }, { note: 'G5', duration: '16n', velocity: 0.65 }, { note: 'B5', duration: '16n', velocity: 0.7 }], { type: 'sine', volume: -9 });
      break;
    case 'error':
      playToneJsPattern([{ note: 'C3', duration: '8n', velocity: 0.45 }, { note: 'A2', duration: '8n', velocity: 0.4 }], { type: 'sawtooth', volume: -12 });
      break;
    case 'star':
      playToneJsPattern([{ note: 'A5', duration: '16n', velocity: 0.7 }, { note: 'C6', duration: '16n', velocity: 0.75 }, { note: 'E6', duration: '16n', velocity: 0.8 }], { type: 'sine', volume: -8 });
      break;
  }
  try {
    const ctx = new AudioContext();
    const now = ctx.currentTime;
    const playTone = (freq: number, start: number, duration: number, vol: number = 0.15) => {
      const osc = ctx.createOscillator();
      const gain = ctx.createGain();
      osc.type = 'sine';
      osc.frequency.setValueAtTime(freq, now + start);
      gain.gain.setValueAtTime(vol, now + start);
      gain.gain.exponentialRampToValueAtTime(0.001, now + start + duration);
      osc.connect(gain);
      gain.connect(ctx.destination);
      osc.start(now + start);
      osc.stop(now + start + duration);
    };
    switch (type) {
      case 'click':
        playTone(880, 0, 0.08, 0.16);
        break;
      case 'pop':
        playTone(600, 0, 0.1, 0.16);
        playTone(900, 0.05, 0.08, 0.12);
        break;
      case 'success':
        playTone(523, 0, 0.15, 0.18);
        playTone(659, 0.12, 0.15, 0.18);
        playTone(784, 0.24, 0.2, 0.18);
        playTone(1047, 0.4, 0.3, 0.16);
        break;
      case 'magic':
        playTone(800, 0, 0.2, 0.14);
        playTone(600, 0.1, 0.2, 0.14);
        playTone(1000, 0.2, 0.3, 0.14);
        break;
      case 'send':
        playTone(700, 0, 0.1, 0.16);
        playTone(1000, 0.1, 0.15, 0.14);
        break;
      case 'error':
        playTone(200, 0, 0.15, 0.16);
        playTone(150, 0.12, 0.2, 0.14);
        break;
      case 'star':
        playTone(1000, 0, 0.08, 0.14);
        playTone(1200, 0.06, 0.1, 0.12);
        playTone(1500, 0.12, 0.15, 0.1);
        break;
    }
  } catch {
    /* Audio not supported */
  }
};
