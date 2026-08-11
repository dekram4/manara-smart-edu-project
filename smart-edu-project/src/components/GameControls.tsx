import React, { useEffect, useState } from 'react';

interface GameControlsProps {
  className?: string;
}

const STORAGE_KEY = 'manara_game_controls';

const readState = () => {
  if (typeof window === 'undefined') return { soundEnabled: true, hapticsEnabled: true };
  try {
    const raw = window.localStorage.getItem(STORAGE_KEY);
    if (!raw) return { soundEnabled: true, hapticsEnabled: true };
    const parsed = JSON.parse(raw);
    return {
      soundEnabled: parsed.soundEnabled ?? true,
      hapticsEnabled: parsed.hapticsEnabled ?? true,
    };
  } catch {
    return { soundEnabled: true, hapticsEnabled: true };
  }
};

const persistState = (next: { soundEnabled: boolean; hapticsEnabled: boolean }) => {
  if (typeof window !== 'undefined') {
    window.localStorage.setItem(STORAGE_KEY, JSON.stringify(next));
  }
};

export const GameControls: React.FC<GameControlsProps> = ({ className = '' }) => {
  const [soundEnabled, setSoundEnabled] = useState(readState().soundEnabled);
  const [hapticsEnabled, setHapticsEnabled] = useState(readState().hapticsEnabled);

  useEffect(() => {
    const state = { soundEnabled, hapticsEnabled };
    persistState(state);
    window.dispatchEvent(new CustomEvent('manara:controls', { detail: state }));
  }, [soundEnabled, hapticsEnabled]);

  const toggleHaptics = () => {
    if (typeof navigator !== 'undefined' && 'vibrate' in navigator && hapticsEnabled) {
      try {
        navigator.vibrate(20);
      } catch {
        // Ignore unsupported vibration errors
      }
    }
    setHapticsEnabled((value) => !value);
  };

  const toggleSound = () => {
    if (typeof navigator !== 'undefined' && 'vibrate' in navigator && hapticsEnabled) {
      try {
        navigator.vibrate(12);
      } catch {
        // Ignore unsupported vibration errors
      }
    }
    setSoundEnabled((value) => !value);
  };

  return (
    <div className={`fixed right-3 z-50 flex gap-2 sm:right-4 ${className}`} style={{ top: 'calc(0.75rem + env(safe-area-inset-top))' }}>
      <button
        onClick={toggleSound}
        className={`rounded-full border px-3 py-2 text-sm font-black shadow-lg backdrop-blur ${soundEnabled ? 'border-amber-300 bg-white/90 text-slate-900' : 'border-slate-600 bg-slate-900/90 text-slate-100'}`}
        aria-label={soundEnabled ? 'إيقاف الصوت' : 'تشغيل الصوت'}
      >
        {soundEnabled ? '🔊' : '🔈'}
      </button>
      <button
        onClick={toggleHaptics}
        className={`rounded-full border px-3 py-2 text-sm font-black shadow-lg backdrop-blur ${hapticsEnabled ? 'border-cyan-300 bg-white/90 text-slate-900' : 'border-slate-600 bg-slate-900/90 text-slate-100'}`}
        aria-label={hapticsEnabled ? 'إيقاف الاهتزاز' : 'تشغيل الاهتزاز'}
      >
        {hapticsEnabled ? '📳' : '📴'}
      </button>
    </div>
  );
};
