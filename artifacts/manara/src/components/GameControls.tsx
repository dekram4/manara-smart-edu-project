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
  const [soundEnabled, setSoundEnabled] = useState<boolean>(readState().soundEnabled);
  const [hapticsEnabled, setHapticsEnabled] = useState<boolean>(readState().hapticsEnabled);
  const [mobileOpen, setMobileOpen] = useState(false);

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
    <div className={className}>
      {/* ‏زرٌّ واحدٌ يُطوى، أسفلَ اليسار، في كل المقاسات: بعيداً عن القائمة الجانبية
          ‏والأدراج اليمنى وشريط المزامنة. كان على الشاشات الكبيرة زرّان مثبَّتان في
          ‏الزاوية العليا اليمنى — فوق رأس القائمة الجانبية وزرّ القائمة مباشرةً. */}
      <div
        className="fixed left-3 z-[70] flex flex-col-reverse items-start gap-2"
        style={{ bottom: 'calc(1rem + 4.5rem + env(safe-area-inset-bottom))' }}
      >
        {mobileOpen && (
          <div
            className="flex flex-col gap-2 rounded-2xl border border-white/30 bg-slate-950/90 p-2 shadow-2xl backdrop-blur-xl"
            role="group"
            aria-label="إعدادات الصوت والاهتزاز"
          >
            <button
              onClick={toggleSound}
              className={`min-h-11 min-w-11 rounded-xl border px-3 py-2 text-sm font-black shadow-lg ${soundEnabled ? 'border-amber-300 bg-white/95 text-slate-900' : 'border-slate-600 bg-slate-900 text-slate-100'}`}
              aria-label={soundEnabled ? 'إيقاف الصوت' : 'تشغيل الصوت'}
            >
              {soundEnabled ? '🔊' : '🔈'}
            </button>
            <button
              onClick={toggleHaptics}
              className={`min-h-11 min-w-11 rounded-xl border px-3 py-2 text-sm font-black shadow-lg ${hapticsEnabled ? 'border-cyan-300 bg-white/95 text-slate-900' : 'border-slate-600 bg-slate-900 text-slate-100'}`}
              aria-label={hapticsEnabled ? 'إيقاف الاهتزاز' : 'تشغيل الاهتزاز'}
            >
              {hapticsEnabled ? '📳' : '📴'}
            </button>
          </div>
        )}
        <button
          onClick={() => setMobileOpen((value) => !value)}
          className="min-h-11 min-w-11 rounded-full border border-white/30 bg-slate-950/90 px-3 py-2 text-base font-black text-white shadow-2xl backdrop-blur-xl"
          aria-expanded={mobileOpen}
          aria-label={mobileOpen ? 'إغلاق إعدادات الصوت والاهتزاز' : 'فتح إعدادات الصوت والاهتزاز'}
        >
          {mobileOpen ? '✕' : soundEnabled && hapticsEnabled ? '🎛️' : '🔕'}
        </button>
      </div>

    </div>
  );
};
