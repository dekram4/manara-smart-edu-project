import React, { useMemo, useState } from 'react';
import { motion } from 'framer-motion';
import { getGamificationStats, rewardGamePerformanceWithId } from '../../utils/gamification';
import { playLamsaSound } from '../../utils/sounds';
import { GameAudioEngine } from '../../utils/gameAudioEngine';
import StudentGameCanvas from '../../components/StudentGameCanvas';
import EducationalCardEffects from '../../components/effects/EducationalCardEffects';

interface EntertainmentGamesProps {
  grade: string;
  subject: string;
  term: string;
  unit: string;
  lessonContent?: string;
}

type GameType = 'embedded' | 'heroarcade' | 'embedded2';

const EMBEDDED_GAME_URL =
  'https://html5.gamedistribution.com/d4a3629101574bc39bd8f9d1888ca58e/?gd_sdk_referrer_url=https://www.example.com/games/{game-path}';
const EMBEDDED_GAME_2_URL =
  'https://html5.gamedistribution.com/172e0bd0c40442dbae3d4adb42a98433/?gd_sdk_referrer_url=https://www.example.com/games/{game-path}';

const EntertainmentGames: React.FC<EntertainmentGamesProps> = ({ grade, subject, term, unit }) => {
  const [activeGame, setActiveGame] = useState<GameType | null>(null);
  const [refreshKey, setRefreshKey] = useState(0);
  const [rewardMessage, setRewardMessage] = useState('');
  const stats = useMemo(() => getGamificationStats(), [activeGame, refreshKey]);

  const openGame = (game: GameType, requiredLevel: number) => {
    if (stats.level < requiredLevel) {
      playLamsaSound('error');
      return;
    }
    GameAudioEngine.play('portalTransition');
    setRewardMessage('');
    setActiveGame(game);
  };

  const closeGame = () => {
    setActiveGame(null);
  };

  const handleArcadeComplete = (earnedScore: number) => {
    const dayKey = new Date().toISOString().slice(0, 10);
    const reward = rewardGamePerformanceWithId('speed', earnedScore, 100, `entertainment-hero-${dayKey}`);
    setRefreshKey((prev) => prev + 1);
    if (!reward.alreadyRewarded) {
      GameAudioEngine.playRewardSequence({ celebrate: reward.xp >= 100, gems: reward.gems });
    }
    setRewardMessage(
      reward.alreadyRewarded
        ? 'تم صرف مكافأة لعبة اليوم مسبقاً ✅'
        : `أحسنت! +${reward.gems} جواهر و +${reward.xp} XP`,
    );
    setActiveGame(null);
  };

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
        {rewardMessage && (
          <div className="mt-3 rounded-xl border border-emerald-400/35 bg-emerald-500/10 px-3 py-2 text-sm font-black text-emerald-300">
            {rewardMessage}
          </div>
        )}
      </div>

      <div className="grid grid-cols-1 gap-5 md:grid-cols-2 xl:grid-cols-3">
        <button
          onClick={() => openGame('embedded', 1)}
          disabled={stats.level < 1}
          className={`relative overflow-hidden rounded-[30px] border border-white/15 p-7 text-right shadow-2xl transition-all ${
            stats.level >= 1
              ? 'bg-gradient-to-br from-amber-500 to-red-700 hover:-translate-y-1 hover:scale-[1.01]'
              : 'cursor-not-allowed bg-slate-700/80 opacity-70'
          }`}
        >
          <EducationalCardEffects accent="#f59e0b" />
          <div className="flex items-center justify-between">
            <div className="text-5xl">🕹️</div>
            {stats.level < 1 && <span className="text-3xl">🔒</span>}
          </div>
          <h3 className="mt-4 text-2xl font-black text-white">اللعبة الأولى</h3>
          <p className="mt-2 text-sm font-bold text-white/90">لعبة مضمنة داخل منصة منارة.</p>
          <div className="mt-4 text-xs font-black text-white/95">
            {stats.level >= 1 ? 'اضغط لبدء اللعبة' : 'تُفتح عند الوصول إلى المستوى 1'}
          </div>
        </button>

        <button
          onClick={() => openGame('heroarcade', 2)}
          disabled={stats.level < 2}
          className={`relative overflow-hidden rounded-[30px] border border-white/15 p-7 text-right shadow-2xl transition-all ${
            stats.level >= 2
              ? 'bg-gradient-to-br from-cyan-500 to-blue-700 hover:-translate-y-1 hover:scale-[1.01]'
              : 'cursor-not-allowed bg-slate-700/80 opacity-70'
          }`}
        >
          <EducationalCardEffects accent="#22d3ee" />
          <div className="flex items-center justify-between">
            <div className="text-5xl">🚀</div>
            {stats.level < 2 && <span className="text-3xl">🔒</span>}
          </div>
          <h3 className="mt-4 text-2xl font-black text-white">اللعبة الثانية</h3>
          <p className="mt-2 text-sm font-bold text-white/90">تحدي أركيد داخل المنصة: حركة، قفز، أعداء وجواهر.</p>
          <div className="mt-4 text-xs font-black text-white/95">
            {stats.level >= 2 ? 'اضغط لبدء اللعبة' : 'تُفتح عند الوصول إلى المستوى 2'}
          </div>
        </button>

        <button
          onClick={() => openGame('embedded2', 3)}
          disabled={stats.level < 3}
          className={`relative overflow-hidden rounded-[30px] border border-white/15 p-7 text-right shadow-2xl transition-all ${
            stats.level >= 3
              ? 'bg-gradient-to-br from-fuchsia-500 to-pink-700 hover:-translate-y-1 hover:scale-[1.01]'
              : 'cursor-not-allowed bg-slate-700/80 opacity-70'
          }`}
        >
          <EducationalCardEffects accent="#e879f9" />
          <div className="flex items-center justify-between">
            <div className="text-5xl">🎯</div>
            {stats.level < 3 && <span className="text-3xl">🔒</span>}
          </div>
          <h3 className="mt-4 text-2xl font-black text-white">اللعبة الثالثة</h3>
          <p className="mt-2 text-sm font-bold text-white/90">لعبة HTML5 جديدة مضمنة داخل منصة منارة.</p>
          <div className="mt-4 text-xs font-black text-white/95">
            {stats.level >= 3 ? 'اضغط لبدء اللعبة' : 'تُفتح عند الوصول إلى المستوى 3'}
          </div>
        </button>
      </div>

      {activeGame === 'embedded' && (
        <div className="overflow-hidden rounded-3xl border border-amber-300/30 bg-black shadow-2xl">
          <div className="flex items-center justify-between bg-slate-900 px-4 py-3">
            <h3 className="font-black text-white">اللعبة الأولى</h3>
            <button
              onClick={closeGame}
              className="rounded-xl bg-white/10 px-4 py-2 font-black text-white hover:bg-white/20"
            >
              إغلاق اللعبة
            </button>
          </div>
          <div className="aspect-video w-full bg-black">
            <iframe
              src={EMBEDDED_GAME_URL}
              title="اللعبة الأولى"
              className="h-full w-full border-0"
              scrolling="no"
              allow="fullscreen; autoplay; gamepad"
              allowFullScreen
            />
          </div>
        </div>
      )}

      {activeGame === 'embedded2' && (
        <div className="overflow-hidden rounded-3xl border border-fuchsia-300/30 bg-black shadow-2xl">
          <div className="flex items-center justify-between bg-slate-900 px-4 py-3">
            <h3 className="font-black text-white">اللعبة الثالثة</h3>
            <button
              onClick={closeGame}
              className="rounded-xl bg-white/10 px-4 py-2 font-black text-white hover:bg-white/20"
            >
              إغلاق اللعبة
            </button>
          </div>
          <div className="mx-auto aspect-[9/16] w-full max-w-[720px] bg-black">
            <iframe
              src={EMBEDDED_GAME_2_URL}
              title="اللعبة الثالثة"
              className="h-full w-full border-0"
              scrolling="no"
              allow="fullscreen; autoplay; gamepad"
              allowFullScreen
            />
          </div>
        </div>
      )}

      {activeGame === 'heroarcade' && (
        <StudentGameCanvas onGameComplete={handleArcadeComplete} onClose={closeGame} />
      )}
    </motion.div>
  );
};

export default EntertainmentGames;
