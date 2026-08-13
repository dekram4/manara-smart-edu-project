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
/**
 * Remove provider tracking/query placeholders before an iframe is mounted.
 * GameDistribution accepts the explicit 32-character player id path; the
 * generated SDK referrer query is not part of the game URL and can trigger
 * a reload loop when it contains an unresolved `{game-path}` token.
 */
export function sanitizeGameIframeUrl(value: string): string {
  const raw = String(value || '').trim();
  if (!raw) return '';

  try {
    const url = new URL(raw, 'https://manara-game.local');
    if (url.hostname.toLowerCase() !== 'html5.gamedistribution.com') {
      return raw;
    }

    const gameId = decodeURIComponent(url.pathname).match(/\/([a-f0-9]{32})(?:\/|$)/i)?.[1];
    if (!gameId) return raw;
    return `https://html5.gamedistribution.com/${gameId}/`;
  } catch {
    return raw;
  }
}

// Keep the third game self-hosted so it cannot be blocked by GameDistribution,
// CrazyGames, or a Replit dev-domain allowlist. It starts immediately in-card.
const EMBEDDED_GAME_3_URL = '/games/drift-dash/index.html';

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
    title: 'سباق السيارات',
    subtitle: 'تحكم بالسيارة ونفّذ الانعطافات بدقة',
    icon: '🏎️',
    accent: '#22d3ee',
    gradient: 'from-cyan-400 via-sky-500 to-blue-700',
    requiredLevel: 3,
  },
];

// Keep the player inside the current card. In particular, do not grant popup
// privileges: GameDistribution must not navigate the student to a new tab.
const GAME_FRAME_SANDBOX =
  'allow-scripts allow-same-origin allow-forms allow-pointer-lock';
const GAME_FRAME_ALLOW =
  'autoplay; fullscreen; geolocation; microphone; camera';

type GameIframeProps = Omit<React.IframeHTMLAttributes<HTMLIFrameElement>, 'src'> & {
  src: string;
  frameKey: string;
};

const GameIframe = React.forwardRef<HTMLIFrameElement, GameIframeProps>(
  ({ frameKey, src, ...props }, ref) => (
    <iframe
      {...props}
      src={sanitizeGameIframeUrl(src)}
      key={frameKey}
      ref={ref}
      sandbox={GAME_FRAME_SANDBOX}
      allow={GAME_FRAME_ALLOW}
      referrerPolicy="no-referrer"
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
  const [embeddedGameEscaped, setEmbeddedGameEscaped] = useState(false);
  const [lockedMessage, setLockedMessage] = useState('');
  const gamePanelRef = useRef<HTMLDivElement>(null);
  const embeddedGameFrameRef = useRef<HTMLIFrameElement>(null);
  const embeddedGameFrameErrorHandledRef = useRef(false);
  const [embeddedGameFrameKey, setEmbeddedGameFrameKey] = useState('game-3-initial');
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
    setEmbeddedGameEscaped(false);
    embeddedGameFrameErrorHandledRef.current = false;
    setActiveGame(game);
  };

  const closeGame = () => {
    if (document.fullscreenElement) {
      void document.exitFullscreen().catch(() => undefined);
    }
    setActiveGame(null);
    setGameLoading(false);
    setIsFullscreen(false);
    setEmbeddedGameEscaped(false);
  };

  const handleEmbeddedGameLoad = () => {
    setGameLoading(false);
  };

  const restartEmbeddedGame = () => {
    embeddedGameFrameErrorHandledRef.current = false;
    setEmbeddedGameEscaped(false);
    setGameLoading(true);
    setEmbeddedGameFrameKey((previous) => `${previous}-manual-retry`);
  };

  const handleEmbeddedGameError = () => {
    // iframe errors can be emitted more than once by blocked ad/SDK assets.
    // Handle the first one only, then replace the frame with a manual-retry
    // state so React cannot enter an automatic reload loop.
    if (embeddedGameFrameErrorHandledRef.current) return;
    embeddedGameFrameErrorHandledRef.current = true;
    setGameLoading(false);
    setEmbeddedGameFrameKey((previous) => `${previous}-failed`);
    setEmbeddedGameEscaped(true);
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
              className={`group relative min-h-[260px] overflow-hidden rounded-[26px] border-2 p-3 text-right shadow-2xl transition-all duration-300 ${
                unlocked
                  ? 'border-white/20 bg-slate-950/90 hover:-translate-y-1 hover:border-white/50'
                  : 'cursor-pointer border-white/10 bg-slate-900/85 opacity-80 hover:opacity-95'
              }`}
            >
              <div className={`relative aspect-[1.55] overflow-hidden rounded-[20px] bg-gradient-to-br ${game.gradient} p-4`}>
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
                <div className="relative z-10 mt-7 flex items-center gap-2">
                  <span className="flex h-9 w-9 items-center justify-center rounded-full bg-white/90 text-slate-950 shadow-lg">▶</span>
                  <span className="text-xs font-black text-white/90">{unlocked ? 'جاهزة للعب' : 'تفتح مع تقدمك'}</span>
                </div>
              </div>
              <div className="px-2 pb-1 pt-4">
                <div className="flex items-start justify-between gap-3">
                  <div>
                    <h3 className="text-xl font-black text-white">{game.title}</h3>
                    <p className="mt-1 text-xs font-bold leading-5 text-slate-400">{game.subtitle}</p>
                  </div>
                  <span className="mt-1 text-xs font-black text-slate-500">{index + 1}/3</span>
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
        <div ref={gamePanelRef} className={`game-viewport-shell scroll-mt-6 overflow-hidden rounded-3xl border border-amber-300/30 bg-black shadow-2xl ${isFullscreen ? 'is-game-fullscreen' : ''}`}>
          <div className="flex flex-wrap items-center justify-between gap-2 bg-slate-900 px-4 py-3">
            <h3 className="font-black text-white">اللعبة الأولى</h3>
            <div className="flex items-center gap-2">
              <button type="button" onClick={toggleFullscreen} className="rounded-xl bg-white/10 px-3 py-2 text-sm font-black text-white hover:bg-white/20">
                {isFullscreen ? '↙ تصغير' : '⛶ ملء الشاشة'}
              </button>
              <button type="button" onClick={closeGame} className="rounded-xl bg-rose-500/80 px-3 py-2 text-sm font-black text-white hover:bg-rose-500">
                ✕ إغلاق اللعبة والعودة للألعاب
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
        <div ref={gamePanelRef} className={`game-viewport-shell scroll-mt-6 overflow-hidden rounded-3xl border border-fuchsia-300/30 bg-black shadow-2xl ${isFullscreen ? 'is-game-fullscreen' : ''}`}>
          <div className="flex flex-wrap items-center justify-between gap-2 bg-slate-900 px-4 py-3">
            <h3 className="font-black text-white">اللعبة الثانية</h3>
            <div className="flex items-center gap-2">
              <button type="button" onClick={toggleFullscreen} className="rounded-xl bg-white/10 px-3 py-2 text-sm font-black text-white hover:bg-white/20">
                {isFullscreen ? '↙ تصغير' : '⛶ ملء الشاشة'}
              </button>
              <button type="button" onClick={closeGame} className="rounded-xl bg-rose-500/80 px-3 py-2 text-sm font-black text-white hover:bg-rose-500">
                ✕ إغلاق اللعبة والعودة للألعاب
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
        <div ref={gamePanelRef} className={`game-viewport-shell scroll-mt-6 overflow-hidden rounded-3xl border border-cyan-300/30 bg-black shadow-2xl ${isFullscreen ? 'is-game-fullscreen' : ''}`}>
          <div className="flex flex-wrap items-center justify-between gap-2 bg-slate-900 px-4 py-3">
            <h3 className="font-black text-white">سباق السيارات</h3>
            <div className="flex items-center gap-2">
              <button type="button" onClick={toggleFullscreen} className="rounded-xl bg-white/10 px-3 py-2 text-sm font-black text-white hover:bg-white/20">
                {isFullscreen ? '↙ تصغير' : '⛶ ملء الشاشة'}
              </button>
              <button type="button" onClick={closeGame} className="rounded-xl bg-rose-500/80 px-3 py-2 text-sm font-black text-white hover:bg-rose-500">
                ✕ إغلاق اللعبة والعودة للألعاب
              </button>
            </div>
          </div>
          <div className="game-frame-surface relative mx-auto aspect-[4/3] w-full max-w-[800px] bg-black" data-swiper-no-swiping="true" onTouchStart={(event) => event.stopPropagation()} onTouchMove={(event) => event.stopPropagation()}>
            {gameLoading && (
              <div className="pointer-events-none absolute inset-0 z-10 flex items-center justify-center bg-slate-950/80">
                <span className="rounded-xl bg-slate-900 px-4 py-3 text-sm font-black text-white">
                  جارٍ تشغيل اللعبة داخل الصفحة...
                </span>
              </div>
            )}
            {embeddedGameEscaped ? (
              <div className="flex h-full min-h-80 flex-col items-center justify-center gap-4 bg-slate-950 px-6 text-center">
                <p className="text-sm font-black text-white">
                  تعذر تحميل اللعبة أو خدمة الإعلانات، ولم تتم إعادة تحميلها تلقائيًا.
                </p>
                <button
                  type="button"
                  onClick={restartEmbeddedGame}
                  className="rounded-xl bg-cyan-500 px-5 py-3 text-sm font-black text-slate-950 hover:bg-cyan-400"
                >
                  إعادة تشغيل اللعبة
                </button>
              </div>
            ) : (
              <GameIframe
                src={EMBEDDED_GAME_3_URL}
                title="سباق السيارات"
                frameKey={embeddedGameFrameKey}
                ref={embeddedGameFrameRef}
                className="h-full w-full border-0"
                scrolling="no"
                allowFullScreen
                onLoad={handleEmbeddedGameLoad}
                onError={handleEmbeddedGameError}
              />
            )}
          </div>
        </div>
      )}

    </motion.div>
  );
};

export default EntertainmentGames;
