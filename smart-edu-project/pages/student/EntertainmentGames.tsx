import React, { useEffect, useMemo, useRef, useState } from 'react';
import { motion } from 'framer-motion';
import { getGamificationStats } from '../../utils/gamification';
import { playLamsaSound } from '../../utils/sounds';
import { GameAudioEngine } from '../../utils/gameAudioEngine';
import EducationalCardEffects from '../../src/components/effects/EducationalCardEffects';
import TouchCarousel from '../../src/components/TouchCarousel';

interface EntertainmentGamesProps {
  grade: string;
  subject: string;
  term: string;
  unit: string;
  lessonContent?: string;
}

type GameType = 'embedded' | 'embedded2' | 'embedded3';

const EMBEDDED_GAME_URL =
  '/api/game-embed/d4a3629101574bc39bd8f9d1888ca58e/index.html';
const EMBEDDED_GAME_2_URL =
  '/api/game-embed/172e0bd0c40442dbae3d4adb42a98433/index.html';
const EMBEDDED_GAME_3_URL =
  '/api/game-embed/be797a3996324c03b20bad496a82819f/index.html?v=2';

// Local Unity games need same-origin access to load their own assets. Keep
// provider popup and top-navigation privileges disabled for those games.
const GAME_FRAME_SANDBOX =
  'allow-scripts allow-same-origin allow-pointer-lock allow-orientation-lock';

const EntertainmentGames: React.FC<EntertainmentGamesProps> = ({ grade, subject, term, unit }) => {
  const [activeGame, setActiveGame] = useState<GameType | null>(null);
  const [gameLoading, setGameLoading] = useState(false);
  const [lockedMessage, setLockedMessage] = useState('');
  const gamePanelRef = useRef<HTMLDivElement>(null);
  const [isFullscreen, setIsFullscreen] = useState(false);
  const stats = useMemo(() => getGamificationStats(), [activeGame]);

  const openGame = (game: GameType, requiredLevel: number) => {
    if (stats.level < requiredLevel) {
      playLamsaSound('error');
      setLockedMessage(`هذه اللعبة تُفتح عند الوصول إلى المستوى ${requiredLevel}. مستواك الحالي: ${stats.level}`);
      return;
    }
    GameAudioEngine.play('portalTransition');
    setLockedMessage('');
    setGameLoading(true);
    setActiveGame(game);
  };

  const closeGame = () => {
    if (document.fullscreenElement) {
      void document.exitFullscreen().catch(() => undefined);
    }
    setActiveGame(null);
    setGameLoading(false);
    setIsFullscreen(false);
  };

  useEffect(() => {
    if (!isFullscreen) return;
    const previousOverflow = document.body.style.overflow;
    document.body.style.overflow = 'hidden';
    return () => {
      document.body.style.overflow = previousOverflow;
    };
  }, [isFullscreen]);

  const toggleFullscreen = async () => {
    const panel = gamePanelRef.current;
    if (!panel) return;
    try {
      if (document.fullscreenElement) {
        await document.exitFullscreen();
      } else {
        await panel.requestFullscreen();
      }
    } catch {
      // iOS Safari may not expose element.requestFullscreen(). Keep the
      // student in a fixed, app-level fullscreen viewport instead.
      setIsFullscreen(true);
    }
  };

  useEffect(() => {
    const handleFullscreenChange = () => {
      setIsFullscreen(document.fullscreenElement === gamePanelRef.current);
    };
    document.addEventListener('fullscreenchange', handleFullscreenChange);
    return () => document.removeEventListener('fullscreenchange', handleFullscreenChange);
  }, []);

  useEffect(() => {
    if (!activeGame) return;
    window.requestAnimationFrame(() => {
      gamePanelRef.current?.scrollIntoView({ behavior: 'smooth', block: 'start' });
    });
  }, [activeGame]);

  return (
    <motion.div initial={{ opacity: 0, y: 12 }} animate={{ opacity: 1, y: 0 }} className="space-y-6">
      <div className="rounded-3xl border border-white/15 bg-slate-900/60 p-5 backdrop-blur-lg">
        <EducationalCardEffects accent="#a78bfa" compact />
        <h2 className="text-3xl font-black text-white">🎮 قائمة الترفيه والألعاب</h2>
        <p className="mt-1 text-sm font-bold text-cyan-200">{subject} • {grade} • {term} • {unit}</p>
        <div className="mt-3 flex flex-wrap gap-3 text-sm font-black">
          <span className="rounded-xl bg-slate-800 px-3 py-2 text-yellow-300">XP: {stats.xp}</span>
          <span className="rounded-xl bg-slate-800 px-3 py-2 text-cyan-300">جواهر: {stats.gems}</span>
          <span className="rounded-xl bg-slate-800 px-3 py-2 text-fuchsia-300">المستوى: {stats.level}</span>
        </div>
        {lockedMessage && (
          <div role="status" className="mt-3 rounded-xl border border-amber-300/40 bg-amber-400/10 px-3 py-2 text-sm font-black text-amber-200">
            🔒 {lockedMessage}
          </div>
        )}
      </div>

      <TouchCarousel
        label="ألعاب عالم الترفيه"
        trackClassName="grid-cols-1 gap-5 md:grid-cols-2 xl:grid-cols-3"
        nested
      >
        <button
          type="button"
          onClick={() => openGame('embedded', 0)}
          aria-disabled={false}
          className={`relative overflow-hidden rounded-[30px] border border-white/15 p-7 text-right shadow-2xl transition-all ${
            stats.level >= 0
              ? 'bg-gradient-to-br from-amber-500 to-red-700 hover:-translate-y-1 hover:scale-[1.01]'
              : 'cursor-pointer bg-slate-700/80 opacity-70 hover:opacity-90'
          }`}
        >
          <EducationalCardEffects accent="#f59e0b" />
          <div className="flex items-center justify-between">
            <div className="text-5xl">🕹️</div>
            {stats.level < 0 && <span className="text-3xl">🔒</span>}
          </div>
          <h3 className="mt-4 text-2xl font-black text-white">اللعبة الأولى</h3>
          <p className="mt-2 text-sm font-bold text-white/90">لعبة مضمنة داخل منصة منارة.</p>
          <span className="mt-4 inline-flex w-full items-center justify-center rounded-2xl bg-white/20 px-4 py-3 text-sm font-black text-white">
            ▶ العب الآن
          </span>
        </button>

        <button
          type="button"
          onClick={() => openGame('embedded2', 2)}
          aria-disabled={stats.level < 2}
          className={`relative overflow-hidden rounded-[30px] border border-white/15 p-7 text-right shadow-2xl transition-all ${
            stats.level >= 2
              ? 'bg-gradient-to-br from-fuchsia-500 to-pink-700 hover:-translate-y-1 hover:scale-[1.01]'
              : 'cursor-pointer bg-slate-700/80 opacity-70 hover:opacity-90'
          }`}
        >
          <EducationalCardEffects accent="#e879f9" />
          <div className="flex items-center justify-between">
            <div className="text-5xl">🎯</div>
            {stats.level < 2 && <span className="text-3xl">🔒</span>}
          </div>
          <h3 className="mt-4 text-2xl font-black text-white">اللعبة الثانية</h3>
          <p className="mt-2 text-sm font-bold text-white/90">لعبة HTML5 مضمنة داخل منصة منارة.</p>
          <span className="mt-4 inline-flex w-full items-center justify-center rounded-2xl bg-white/20 px-4 py-3 text-sm font-black text-white">
            {stats.level >= 2 ? '▶ العب الآن' : '🔒 تُفتح في المستوى 2'}
          </span>
        </button>

        <button
          type="button"
          onClick={() => openGame('embedded3', 3)}
          aria-disabled={stats.level < 3}
          className={`relative overflow-hidden rounded-[30px] border border-white/15 p-7 text-right shadow-2xl transition-all ${
            stats.level >= 3
              ? 'bg-gradient-to-br from-cyan-500 to-blue-700 hover:-translate-y-1 hover:scale-[1.01]'
              : 'cursor-pointer bg-slate-700/80 opacity-70 hover:opacity-90'
          }`}
        >
          <EducationalCardEffects accent="#22d3ee" />
          <div className="flex items-center justify-between">
            <div className="text-5xl">🎲</div>
            {stats.level < 3 && <span className="text-3xl">🔒</span>}
          </div>
          <h3 className="mt-4 text-2xl font-black text-white">اللعبة الثالثة</h3>
          <p className="mt-2 text-sm font-bold text-white/90">لعبة HTML5 مضمنة داخل منصة منارة.</p>
          <span className="mt-4 inline-flex w-full items-center justify-center rounded-2xl bg-white/20 px-4 py-3 text-sm font-black text-white">
            {stats.level >= 3 ? '▶ العب الآن' : '🔒 تُفتح في المستوى 3'}
          </span>
        </button>
      </TouchCarousel>

      {activeGame === 'embedded' && (
        <div ref={gamePanelRef} className={`game-viewport-shell scroll-mt-6 overflow-hidden rounded-3xl border border-amber-300/30 bg-black shadow-2xl ${isFullscreen ? 'is-game-fullscreen' : ''}`}>
          <div className="flex flex-wrap items-center justify-between gap-2 bg-slate-900 px-4 py-3">
            <h3 className="font-black text-white">اللعبة الأولى</h3>
            <div className="flex items-center gap-2">
              <button type="button" onClick={toggleFullscreen} className="rounded-xl bg-white/10 px-3 py-2 text-sm font-black text-white hover:bg-white/20">
                {isFullscreen ? '↙ تصغير' : '⛶ ملء الشاشة'}
              </button>
              <button type="button" onClick={closeGame} className="rounded-xl bg-rose-500/80 px-3 py-2 text-sm font-black text-white hover:bg-rose-500">
                ✕ خروج
              </button>
            </div>
          </div>
          <div className="game-frame-surface relative aspect-video w-full bg-black" data-swiper-no-swiping="true" onTouchStart={(event) => event.stopPropagation()} onTouchMove={(event) => event.stopPropagation()}>
            {gameLoading && (
              <div className="pointer-events-none absolute inset-0 z-10 flex items-center justify-center bg-slate-950/80">
                <span className="rounded-xl bg-slate-900 px-4 py-3 text-sm font-black text-white">
                  جارٍ تشغيل اللعبة داخل الصفحة...
                </span>
              </div>
            )}
            <iframe
              src={EMBEDDED_GAME_URL}
              title="اللعبة الأولى"
              className="h-full w-full border-0"
              scrolling="no"
              sandbox={GAME_FRAME_SANDBOX}
              allow="fullscreen; autoplay; gamepad"
              allowFullScreen
              referrerPolicy="strict-origin-when-cross-origin"
              loading="eager"
              onLoad={() => setGameLoading(false)}
            />
          </div>
        </div>
      )}

      {activeGame === 'embedded2' && (
        <div ref={gamePanelRef} className={`game-viewport-shell scroll-mt-6 overflow-hidden rounded-3xl border border-fuchsia-300/30 bg-black shadow-2xl ${isFullscreen ? 'is-game-fullscreen' : ''}`}>
          <div className="flex flex-wrap items-center justify-between gap-2 bg-slate-900 px-4 py-3">
            <h3 className="font-black text-white">اللعبة الثانية</h3>
            <div className="flex items-center gap-2">
              <button type="button" onClick={toggleFullscreen} className="rounded-xl bg-white/10 px-3 py-2 text-sm font-black text-white hover:bg-white/20">
                {isFullscreen ? '↙ تصغير' : '⛶ ملء الشاشة'}
              </button>
              <button type="button" onClick={closeGame} className="rounded-xl bg-rose-500/80 px-3 py-2 text-sm font-black text-white hover:bg-rose-500">
                ✕ خروج
              </button>
            </div>
          </div>
          <div className="game-frame-surface relative mx-auto aspect-[9/16] w-full max-w-[720px] bg-black" data-swiper-no-swiping="true" onTouchStart={(event) => event.stopPropagation()} onTouchMove={(event) => event.stopPropagation()}>
            {gameLoading && (
              <div className="pointer-events-none absolute inset-0 z-10 flex items-center justify-center bg-slate-950/80">
                <span className="rounded-xl bg-slate-900 px-4 py-3 text-sm font-black text-white">
                  جارٍ تشغيل اللعبة داخل الصفحة...
                </span>
              </div>
            )}
            <iframe
              src={EMBEDDED_GAME_2_URL}
              title="اللعبة الثانية"
              className="h-full w-full border-0"
              scrolling="no"
              sandbox={GAME_FRAME_SANDBOX}
              allow="fullscreen; autoplay; gamepad"
              allowFullScreen
              referrerPolicy="no-referrer"
              loading="eager"
              onLoad={() => setGameLoading(false)}
            />
          </div>
        </div>
      )}

      {activeGame === 'embedded3' && (
        <div ref={gamePanelRef} className={`game-viewport-shell scroll-mt-6 overflow-hidden rounded-3xl border border-cyan-300/30 bg-black shadow-2xl ${isFullscreen ? 'is-game-fullscreen' : ''}`}>
          <div className="flex flex-wrap items-center justify-between gap-2 bg-slate-900 px-4 py-3">
            <h3 className="font-black text-white">اللعبة الثالثة</h3>
            <div className="flex items-center gap-2">
              <button type="button" onClick={toggleFullscreen} className="rounded-xl bg-white/10 px-3 py-2 text-sm font-black text-white hover:bg-white/20">
                {isFullscreen ? '↙ تصغير' : '⛶ ملء الشاشة'}
              </button>
              <button type="button" onClick={closeGame} className="rounded-xl bg-rose-500/80 px-3 py-2 text-sm font-black text-white hover:bg-rose-500">
                ✕ خروج
              </button>
            </div>
          </div>
          <div className="game-frame-surface relative mx-auto aspect-[8/5] w-full max-w-[958px] bg-black" data-swiper-no-swiping="true" onTouchStart={(event) => event.stopPropagation()} onTouchMove={(event) => event.stopPropagation()}>
            {gameLoading && (
              <div className="pointer-events-none absolute inset-0 z-10 flex items-center justify-center bg-slate-950/80">
                <span className="rounded-xl bg-slate-900 px-4 py-3 text-sm font-black text-white">
                  جارٍ تشغيل اللعبة داخل الصفحة...
                </span>
              </div>
            )}
            <iframe
              src={EMBEDDED_GAME_3_URL}
              title="اللعبة الثالثة"
              className="h-full w-full border-0"
              scrolling="no"
              sandbox={GAME_FRAME_SANDBOX}
              allow="fullscreen; autoplay; gamepad; pointer-lock"
              allowFullScreen
              referrerPolicy="no-referrer"
              loading="eager"
              onLoad={() => setGameLoading(false)}
            />
          </div>
        </div>
      )}

    </motion.div>
  );
};

export default EntertainmentGames;
