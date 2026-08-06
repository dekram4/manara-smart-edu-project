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

type GameType = 'heroarcade';

const EntertainmentGames: React.FC<EntertainmentGamesProps> = ({ grade, subject, term, unit }) => {
  const [activeGame, setActiveGame] = useState<GameType | null>(null);
  const [refreshKey, setRefreshKey] = useState(0);
  const [rewardMessage, setRewardMessage] = useState('');
  const stats = useMemo(() => getGamificationStats(), [activeGame, refreshKey]);

  const openGame = () => {
    if (stats.level < 1) {
      playLamsaSound('error');
      return;
    }
    GameAudioEngine.play('portalTransition');
    setRewardMessage('');
    setActiveGame('heroarcade');
  };

  const closeGame = () => {
    setActiveGame(null);
  };

  const handleArcadeComplete = (earnedScore: number) => {
    const dayKey = new Date().toISOString().slice(0, 10);
    const reward = rewardGamePerformanceWithId('speed', earnedScore, 100, `entertainment-hero-${dayKey}`);
    setRefreshKey((prev) => prev + 1);
    if (!reward.alreadyRewarded) {
      GameAudioEngine.play(reward.xp >= 100 ? 'levelUp' : 'collectGem');
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

      <div className="grid grid-cols-1 gap-5">
        <button
          onClick={openGame}
          className="relative overflow-hidden rounded-[30px] border border-white/15 bg-gradient-to-br from-amber-500 to-red-700 p-7 text-right shadow-2xl transition-all hover:-translate-y-1 hover:scale-[1.01]"
        >
          <EducationalCardEffects accent="#f59e0b" />
          <div className="text-5xl">🕹️</div>
          <h3 className="mt-4 text-2xl font-black text-white">أركيد البطل</h3>
          <p className="mt-2 text-sm font-bold text-white/90">منصات احترافية: حركة، قفز، أعداء، وجواهر.</p>
          <div className="mt-4 text-xs font-black text-white/95">اضغط لبدء اللعبة</div>
        </button>
      </div>

      {activeGame === 'heroarcade' && <StudentGameCanvas onGameComplete={handleArcadeComplete} onClose={closeGame} />}
    </motion.div>
  );
};

export default EntertainmentGames;
