import React, { useEffect, useMemo, useRef, useState } from 'react';
import { motion } from 'framer-motion';
import { getGamificationStats } from '../../utils/gamification';
import { playLamsaSound } from '../../utils/sounds';
import { GameAudioEngine } from '../../utils/gameAudioEngine';
import EducationalCardEffects from '../../components/effects/EducationalCardEffects';
import TouchCarousel from '../../components/TouchCarousel';
import PixiArcadeGame from './games/PixiArcadeGame';

interface EntertainmentGamesProps {
  grade: string;
  subject: string;
  term: string;
  unit: string;
  lessonContent?: string;
}

type GameType = 'embedded' | 'embedded2' | 'embedded3' | 'embedded4';

const EMBEDDED_GAME_URL =
  '/api/game-embed/d4a3629101574bc39bd8f9d1888ca58e/index.html';
const EMBEDDED_GAME_2_URL =
  '/api/game-embed/172e0bd0c40442dbae3d4adb42a98433/index.html';
const EMBEDDED_GAME_4_URL =
  'https://html5.gamedistribution.com/rvvASMiM/2618b45729854f8cbdf0616f8f175702/index.html';
/**
 * Keep the official GameDistribution referrer query when it is valid. The
 * provider uses it to initialize the SDK and serve the embedded game.
 */
export function sanitizeGameIframeUrl(value: string): string {
  const raw = String(value || '').trim();
  if (!raw) return '';

  try {
    const url = new URL(raw, 'https://manara-game.local');
    if (url.hostname.toLowerCase() !== 'html5.gamedistribution.com') {
      return raw;
    }

    const pathname = decodeURIComponent(url.pathname);
    const directGamePath = pathname.match(/\/(rvv[^/]+)\/([a-f0-9]{32})\/index\.html$/i);
    if (directGamePath) {
      return `https://html5.gamedistribution.com/${directGamePath[1]}/${directGamePath[2]}/index.html`;
    }

    const officialReferrer = url.searchParams.get('gd_sdk_referrer_url');
    if (officialReferrer && !officialReferrer.includes('{game-path}')) {
      return raw;
    }

    const gameId = pathname.match(/\/([a-f0-9]{32})(?:\/|$)/i)?.[1];
    if (!gameId) return raw;
    return `https://html5.gamedistribution.com/${gameId}/`;
  } catch {
    return raw;
  }
}

const GAME_CARDS: Array<{
  type: GameType;
  title: string;
  subtitle: string;
  icon: string;
  accent: string;
  gradient: string;
  requiredLevel: number;
}> = [
  {
    type: 'embedded',
    title: 'المغامرة الأولى',
    subtitle: 'لعبة مضمنة داخل منصة منارة',
    icon: '🕹️',
    accent: '#f59e0b',
    gradient: 'from-amber-400 via-orange-500 to-red-600',
    requiredLevel: 0,
  },
  {
    type: 'embedded2',
    title: 'التحدي الثاني',
    subtitle: 'لعبة HTML5 مليئة بالمفاجآت',
    icon: '🎯',
    accent: '#e879f9',
    gradient: 'from-fuchsia-500 via-pink-500 to-rose-700',
    requiredLevel: 2,
  },
  {
    type: 'embedded3',
    title: 'صيد الأهداف',
    subtitle: 'التقط الأهداف الخضراء وتجنب الحمراء',
    icon: '🎯',
    accent: '#34d399',
    gradient: 'from-emerald-400 via-teal-500 to-cyan-700',
    requiredLevel: 0,
  },
  {
    type: 'embedded4',
    title: 'Cute Animal World',
    subtitle: 'ابنِ عالمًا لطيفًا للحيوانات بالنقر والسحب',
    icon: '🐾',
    accent: '#f59e0b',
    gradient: 'from-lime-400 via-emerald-500 to-teal-700',
    requiredLevel: 0,
  },
];

// Keep ordinary embedded games inside the current card. The GameDistribution
// title gets a narrowly scoped permission set because its runtime uses those
// browser capabilities while starting the game.
const GAME_FRAME_SANDBOX =
  'allow-scripts allow-same-origin allow-forms allow-pointer-lock';
const GAME_4_SANDBOX =
  `${GAME_FRAME_SANDBOX} allow-popups allow-modals allow-top-navigation-by-user-activation`;
const GAME_FRAME_ALLOW =
  'autoplay; fullscreen; gamepad; geolocation; microphone; camera';

type GameIframeProps = Omit<React.IframeHTMLAttributes<HTMLIFrameElement>, 'src'> & {
  src: string;
  frameKey: string;
  sandbox?: string;
};

const GameIframe = React.forwardRef<HTMLIFrameElement, GameIframeProps>(
  ({ frameKey, src, sandbox = GAME_FRAME_SANDBOX, referrerPolicy = 'no-referrer', ...props }, ref) => (
    <iframe
      {...props}
      src={sanitizeGameIframeUrl(src)}
      key={frameKey}
      ref={ref}
      sandbox={sandbox}
      allow={GAME_FRAME_ALLOW}
      referrerPolicy={referrerPolicy}
      width="100%"
      height="100%"
      loading="lazy"
    />
  ),
);
GameIframe.displayName = 'GameIframe';

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
    setGameLoading(game !== 'embedded3');
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
    <motion.div initial={{ opacity: 0, y: 12 }} animate={{ opacity: 1, y: 0 }} className="entertainment-page-shell min-w-0 space-y-4 sm:space-y-6">
      <div className="min-w-0 rounded-3xl border border-white/15 bg-slate-900/60 p-3 backdrop-blur-lg sm:p-5">
        <EducationalCardEffects accent="#a78bfa" compact />
        <h2 className="break-words text-2xl font-black text-white sm:text-3xl">🎮 قائمة الترفيه والألعاب</h2>
        <p className="mt-1 break-words text-xs font-bold leading-6 text-cyan-200 sm:text-sm">{subject} • {grade} • {term} • {unit}</p>
        <div className="mt-3 grid grid-cols-3 gap-2 text-center text-xs font-black sm:flex sm:flex-wrap sm:gap-3 sm:text-sm">
          <span className="rounded-xl bg-slate-800 px-2 py-2 text-yellow-300 sm:px-3">XP: {stats.xp}</span>
          <span className="rounded-xl bg-slate-800 px-2 py-2 text-cyan-300 sm:px-3">جواهر: {stats.gems}</span>
          <span className="rounded-xl bg-slate-800 px-2 py-2 text-fuchsia-300 sm:px-3">المستوى: {stats.level}</span>
        </div>
        {lockedMessage && (
          <div role="status" className="mt-3 rounded-xl border border-amber-300/40 bg-amber-400/10 px-3 py-2 text-sm font-black text-amber-200">
            🔒 {lockedMessage}
          </div>
        )}
      </div>

      <TouchCarousel
        label="ألعاب عالم الترفيه"
        trackClassName="sm:grid sm:grid-cols-2 lg:grid-cols-3"
        nested
      >
        {GAME_CARDS.map((game, index) => {
          const unlocked = stats.level >= game.requiredLevel;
          return (
            <button
              key={game.type}
              type="button"
              onClick={() => openGame(game.type, game.requiredLevel)}
              aria-disabled={!unlocked}
               className={`group relative min-h-[220px] min-w-0 overflow-hidden rounded-[26px] border-2 p-2.5 text-right shadow-2xl transition-all duration-300 sm:min-h-[250px] sm:p-3 ${
                unlocked
                  ? 'border-white/20 bg-slate-950/90 hover:-translate-y-1 hover:border-white/50'
                  : 'cursor-pointer border-white/10 bg-slate-900/85 opacity-80 hover:opacity-95'
              }`}
            >
               <div className={`relative aspect-[1.45] overflow-hidden rounded-[20px] bg-gradient-to-br ${game.gradient} p-3 sm:aspect-[1.55] sm:p-4`}>
                <EducationalCardEffects accent={game.accent} compact />
                <div className="absolute inset-0 bg-[radial-gradient(circle_at_82%_18%,rgba(255,255,255,0.35),transparent_28%),linear-gradient(135deg,transparent,rgba(15,23,42,0.22))]" />
                <div className="relative z-10 flex items-start justify-between">
                  <span className="rounded-full bg-slate-950/45 px-2.5 py-1 text-[10px] font-black text-white">
                    {unlocked ? `المستوى ${game.requiredLevel || 'الأول'}` : `🔒 المستوى ${game.requiredLevel}`}
                  </span>
                  <span className="flex h-14 w-14 items-center justify-center rounded-2xl border border-white/30 bg-white/20 text-4xl shadow-xl backdrop-blur transition-transform duration-300 group-hover:scale-110 group-hover:rotate-3">
                    {game.icon}
                  </span>
                </div>
                 <div className="relative z-10 mt-5 flex items-center gap-2 sm:mt-7">
                   <span className="flex h-8 w-8 shrink-0 items-center justify-center rounded-full bg-white/90 text-sm text-slate-950 shadow-lg sm:h-9 sm:w-9">▶</span>
                  <span className="text-xs font-black text-white/90">{unlocked ? 'جاهزة للعب' : 'تفتح مع تقدمك'}</span>
                </div>
              </div>
              <div className="px-2 pb-1 pt-4">
                <div className="flex items-start justify-between gap-3">
                  <div>
                     <h3 className="break-words text-lg font-black text-white sm:text-xl">{game.title}</h3>
                     <p className="mt-1 break-words text-xs font-bold leading-5 text-slate-400">{game.subtitle}</p>
                  </div>
                   <span className="mt-1 text-xs font-black text-slate-500">{index + 1}/{GAME_CARDS.length}</span>
                </div>
                <span className={`mt-4 inline-flex w-full items-center justify-center rounded-2xl px-4 py-3 text-sm font-black ${
                  unlocked ? 'bg-white/10 text-white group-hover:bg-white/20' : 'bg-white/5 text-slate-400'
                }`}>
                   {unlocked ? '▶ العب الآن' : `🔒 تُفتح في المستوى ${game.requiredLevel}`}
                </span>
              </div>
            </button>
          );
        })}
      </TouchCarousel>

      {activeGame === 'embedded' && (
        <div ref={gamePanelRef} className={`game-viewport-shell scroll-mt-6 min-w-0 overflow-hidden rounded-3xl border border-amber-300/30 bg-black shadow-2xl ${isFullscreen ? 'is-game-fullscreen' : ''}`}>
          <div className="flex flex-col gap-2 bg-slate-900 p-3 sm:flex-row sm:flex-wrap sm:items-center sm:justify-between sm:px-4 sm:py-3">
            <h3 className="font-black text-white">اللعبة الأولى</h3>
            <div className="grid grid-cols-2 gap-2 sm:flex sm:items-center">
              <button type="button" onClick={toggleFullscreen} className="min-w-0 rounded-xl bg-white/10 px-2 py-2 text-xs font-black text-white hover:bg-white/20 sm:px-3 sm:text-sm">
                {isFullscreen ? '↙ تصغير' : '⛶ ملء الشاشة'}
              </button>
              <button type="button" onClick={closeGame} className="min-w-0 rounded-xl bg-rose-500/80 px-2 py-2 text-xs font-black text-white hover:bg-rose-500 sm:px-3 sm:text-sm">
                ✕ إغلاق اللعبة والعودة للألعاب
              </button>
            </div>
          </div>
          <div className="game-frame-surface relative aspect-[4/3] w-full bg-black sm:aspect-video" data-swiper-no-swiping="true" onTouchStart={(event) => event.stopPropagation()} onTouchMove={(event) => event.stopPropagation()}>
            {gameLoading && (
              <div className="pointer-events-none absolute inset-0 z-10 flex items-center justify-center bg-slate-950/80">
                <span className="rounded-xl bg-slate-900 px-4 py-3 text-sm font-black text-white">
                  جارٍ تشغيل اللعبة داخل الصفحة...
                </span>
              </div>
            )}
            <GameIframe
              src={EMBEDDED_GAME_URL}
              title="اللعبة الأولى"
              frameKey="game-1"
              className="h-full w-full border-0"
              scrolling="no"
              allowFullScreen
              onLoad={() => setGameLoading(false)}
              onError={() => setGameLoading(false)}
            />
          </div>
        </div>
      )}

      {activeGame === 'embedded2' && (
        <div ref={gamePanelRef} className={`game-viewport-shell scroll-mt-6 min-w-0 overflow-hidden rounded-3xl border border-fuchsia-300/30 bg-black shadow-2xl ${isFullscreen ? 'is-game-fullscreen' : ''}`}>
          <div className="flex flex-col gap-2 bg-slate-900 p-3 sm:flex-row sm:flex-wrap sm:items-center sm:justify-between sm:px-4 sm:py-3">
            <h3 className="font-black text-white">اللعبة الثانية</h3>
            <div className="grid grid-cols-2 gap-2 sm:flex sm:items-center">
              <button type="button" onClick={toggleFullscreen} className="min-w-0 rounded-xl bg-white/10 px-2 py-2 text-xs font-black text-white hover:bg-white/20 sm:px-3 sm:text-sm">
                {isFullscreen ? '↙ تصغير' : '⛶ ملء الشاشة'}
              </button>
              <button type="button" onClick={closeGame} className="min-w-0 rounded-xl bg-rose-500/80 px-2 py-2 text-xs font-black text-white hover:bg-rose-500 sm:px-3 sm:text-sm">
                ✕ إغلاق اللعبة والعودة للألعاب
              </button>
            </div>
          </div>
          <div className="game-frame-surface relative mx-auto aspect-[4/5] w-full max-w-[720px] bg-black sm:aspect-[9/16]" data-swiper-no-swiping="true" onTouchStart={(event) => event.stopPropagation()} onTouchMove={(event) => event.stopPropagation()}>
            {gameLoading && (
              <div className="pointer-events-none absolute inset-0 z-10 flex items-center justify-center bg-slate-950/80">
                <span className="rounded-xl bg-slate-900 px-4 py-3 text-sm font-black text-white">
                  جارٍ تشغيل اللعبة داخل الصفحة...
                </span>
              </div>
            )}
            <GameIframe
              src={EMBEDDED_GAME_2_URL}
              title="اللعبة الثانية"
              frameKey="game-2"
              className="h-full w-full border-0"
              scrolling="no"
              allowFullScreen
              onLoad={() => setGameLoading(false)}
              onError={() => setGameLoading(false)}
            />
          </div>
        </div>
      )}

      {activeGame === 'embedded3' && (
        <div ref={gamePanelRef} className={`game-viewport-shell scroll-mt-6 min-w-0 overflow-hidden rounded-3xl border border-emerald-300/30 bg-slate-950 shadow-2xl ${isFullscreen ? 'is-game-fullscreen' : ''}`}>
          <div className="flex flex-col gap-2 bg-slate-900 p-3 sm:flex-row sm:flex-wrap sm:items-center sm:justify-between sm:px-4 sm:py-3">
            <h3 className="font-black text-white">صيد الأهداف</h3>
            <div className="grid grid-cols-2 gap-2 sm:flex sm:items-center">
              <button type="button" onClick={toggleFullscreen} className="min-w-0 rounded-xl bg-white/10 px-2 py-2 text-xs font-black text-white hover:bg-white/20 sm:px-3 sm:text-sm">
                {isFullscreen ? '↙ تصغير' : '⛶ ملء الشاشة'}
              </button>
              <button type="button" onClick={closeGame} className="min-w-0 rounded-xl bg-rose-500/80 px-2 py-2 text-xs font-black text-white hover:bg-rose-500 sm:px-3 sm:text-sm">
                ✕ إغلاق اللعبة والعودة للألعاب
              </button>
            </div>
          </div>
          <div className="game-frame-surface mx-auto w-full max-w-[820px] p-3 sm:p-6" data-swiper-no-swiping="true" onTouchStart={(event) => event.stopPropagation()} onTouchMove={(event) => event.stopPropagation()}>
            <PixiArcadeGame />
          </div>
        </div>
      )}

      {activeGame === 'embedded4' && (
        <div ref={gamePanelRef} className={`game-viewport-shell scroll-mt-6 min-w-0 overflow-hidden rounded-3xl border border-orange-300/30 bg-black shadow-2xl ${isFullscreen ? 'is-game-fullscreen' : ''}`}>
          <div className="flex flex-col gap-2 bg-slate-900 p-3 sm:flex-row sm:flex-wrap sm:items-center sm:justify-between sm:px-4 sm:py-3">
            <h3 className="font-black text-white">Cute Animal World</h3>
            <div className="grid grid-cols-2 gap-2 sm:flex sm:items-center">
              <button type="button" onClick={toggleFullscreen} className="min-w-0 rounded-xl bg-white/10 px-2 py-2 text-xs font-black text-white hover:bg-white/20 sm:px-3 sm:text-sm">
                {isFullscreen ? '↙ تصغير' : '⛶ ملء الشاشة'}
              </button>
              <button type="button" onClick={closeGame} className="min-w-0 rounded-xl bg-rose-500/80 px-2 py-2 text-xs font-black text-white hover:bg-rose-500 sm:px-3 sm:text-sm">
                ✕ إغلاق اللعبة والعودة للألعاب
              </button>
            </div>
          </div>
          <div className="game-frame-surface relative mx-auto aspect-[4/5] w-full max-w-[640px] bg-black sm:aspect-[5/9]" data-swiper-no-swiping="true" onTouchStart={(event) => event.stopPropagation()} onTouchMove={(event) => event.stopPropagation()}>
            {gameLoading && (
              <div className="pointer-events-none absolute inset-0 z-10 flex items-center justify-center bg-slate-950/80">
                <span className="rounded-xl bg-slate-900 px-4 py-3 text-sm font-black text-white">
                  جارٍ تشغيل اللعبة داخل الصفحة...
                </span>
              </div>
            )}
            <GameIframe
              src={EMBEDDED_GAME_4_URL}
              title="Cute Animal World"
              frameKey="game-4"
              sandbox={GAME_4_SANDBOX}
              className="h-full w-full border-0"
              scrolling="no"
              allowFullScreen
              loading="eager"
              referrerPolicy="strict-origin-when-cross-origin"
              onLoad={() => setGameLoading(false)}
              onError={() => setGameLoading(false)}
            />
          </div>
        </div>
      )}

    </motion.div>
  );
};

export default EntertainmentGames;
