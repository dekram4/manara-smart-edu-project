import React, { useEffect, useRef, useState } from 'react';
import confetti from 'canvas-confetti';

interface AnimatedCelebrationProps {
  visible: boolean;
  title?: string;
  subtitle?: string;
  emoji?: string;
}

export const AnimatedCelebration: React.FC<AnimatedCelebrationProps> = ({
  visible,
  title = 'مبروك!',
  subtitle = 'لقد حققت إنجازًا رائعًا',
  emoji = '🎉',
}) => {
  const [show, setShow] = useState(visible);
  const containerRef = useRef<HTMLDivElement | null>(null);

  useEffect(() => {
    if (visible) {
      setShow(true);
      const timer = window.setTimeout(() => setShow(false), 2200);
      return () => window.clearTimeout(timer);
    }
    setShow(false);
    return undefined;
  }, [visible]);

  useEffect(() => {
    if (!show) return;

    confetti({
      particleCount: 120,
      spread: 70,
      origin: { y: 0.6 },
      colors: ['#38bdf8', '#f59e0b', '#ec4899', '#8b5cf6'],
    });
  }, [show]);

  useEffect(() => {
    if (!show || !containerRef.current) return;

    const lottieGlobal = (window as Window & { lottie?: { loadAnimation: (options: any) => { destroy: () => void } } }).lottie;
    if (!lottieGlobal?.loadAnimation) return;

    const animation = lottieGlobal.loadAnimation({
      container: containerRef.current,
      renderer: 'svg',
      loop: true,
      autoplay: true,
      path: 'https://assets2.lottiefiles.com/packages/lf20_j1adxtyb.json',
    });

    return () => animation.destroy();
  }, [show]);

  if (!show) return null;

  return (
    <div className="fixed inset-0 z-[60] flex items-center justify-center bg-slate-950/40 p-3 sm:p-4 backdrop-blur-sm safe-area-x safe-area-top safe-area-bottom">
      <div className="mobile-modal-panel relative w-full max-w-lg overflow-hidden rounded-[32px] border border-white/20 bg-white/90 px-5 py-6 sm:px-8 sm:py-8 text-center shadow-2xl">
        <div className="absolute inset-0 bg-[radial-gradient(circle,_rgba(251,191,36,0.25),_transparent_60%)]" />
        <div className="relative">
          <div ref={containerRef} className="mx-auto mb-3 h-28 w-28" />
          <div className="mb-3 text-6xl animate-bounce">{emoji}</div>
          <h3 className="text-3xl font-black text-slate-900">{title}</h3>
          <p className="mt-2 text-base font-semibold text-slate-600">{subtitle}</p>
          <div className="mt-4 flex justify-center gap-2">
            {['⭐', '✨', '🎈', '💫'].map((icon, idx) => (
              <span
                key={icon + idx}
                className="inline-block text-2xl animate-[spin_1.2s_linear_infinite]"
                style={{ animationDelay: `${idx * 120}ms` }}
              >
                {icon}
              </span>
            ))}
          </div>
        </div>
      </div>
    </div>
  );
};
