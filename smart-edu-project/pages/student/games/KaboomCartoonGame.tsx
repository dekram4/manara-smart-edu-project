import React, { useEffect, useRef, useState } from 'react';
import kaboom from 'kaboom';
import { rewardGamePerformanceWithId } from '../../../utils/gamification';
import { playLamsaSound } from '../../../utils/sounds';
import GameHud from './shared/GameHud';

type Difficulty = 'easy' | 'medium' | 'hard';

const DIFFICULTY_CONFIG: Record<Difficulty, { seconds: number; bombs: number; maxScore: number }> = {
  easy: { seconds: 55, bombs: 1, maxScore: 26 },
  medium: { seconds: 45, bombs: 2, maxScore: 30 },
  hard: { seconds: 38, bombs: 3, maxScore: 34 },
};

type RewardResult = {
  xp: number;
  gems: number;
  percentage: number;
  alreadyRewarded: boolean;
};

const KaboomCartoonGame: React.FC = () => {
  const [difficulty, setDifficulty] = useState<Difficulty>('medium');
  const [started, setStarted] = useState(false);
  const canvasRef = useRef<HTMLCanvasElement | null>(null);
  const [stars, setStars] = useState(0);
  const [damage, setDamage] = useState(0);
  const [timeLeft, setTimeLeft] = useState(DIFFICULTY_CONFIG.medium.seconds);
  const [finished, setFinished] = useState(false);
  const [reward, setReward] = useState<RewardResult | null>(null);
  const finalizedRef = useRef(false);
  const config = DIFFICULTY_CONFIG[difficulty];

  useEffect(() => {
    if (!canvasRef.current || finished || !started) return;

    const k = kaboom({
      global: false,
      canvas: canvasRef.current,
      width: 640,
      height: 300,
      background: [252, 243, 214],
    });

    const player = k.add([
      k.rect(34, 34),
      k.pos(70, 230),
      k.color(66, 153, 225),
      k.area(),
      'player',
    ]);

    const addStar = () => k.add([
      k.circle(12),
      k.pos(k.rand(120, 600), k.rand(40, 240)),
      k.color(250, 204, 21),
      k.area(),
      'star',
    ]);

    const addBomb = () => k.add([
      k.circle(10),
      k.pos(k.rand(120, 600), k.rand(40, 240)),
      k.color(244, 63, 94),
      k.area(),
      'bomb',
    ]);

    addStar();
    for (let i = 0; i < config.bombs; i += 1) {
      addBomb();
    }

    k.onKeyDown('left', () => player.move(-240, 0));
    k.onKeyDown('right', () => player.move(240, 0));
    k.onKeyDown('up', () => player.move(0, -240));
    k.onKeyDown('down', () => player.move(0, 240));

    player.onCollide('star', (star) => {
      k.destroy(star);
      addStar();
      setStars((prev) => prev + 1);
    });

    player.onCollide('bomb', (bomb) => {
      k.destroy(bomb);
      addBomb();
      setDamage((prev) => prev + 1);
    });

    return () => {
      k.quit();
    };
  }, [finished, started, config.bombs]);

  useEffect(() => {
    if (finished || !started) return;
    const timer = window.setInterval(() => {
      setTimeLeft((prev) => {
        if (prev <= 1) {
          window.clearInterval(timer);
          setFinished(true);
          return 0;
        }
        return prev - 1;
      });
    }, 1000);
    return () => {
      window.clearInterval(timer);
    };
  }, [finished, started]);

  useEffect(() => {
    if (!finished || finalizedRef.current) return;
    finalizedRef.current = true;

    const score = Math.max(0, stars * 2 - damage * 3);
    const normalized = Math.min(score, config.maxScore);
    const dailyId = new Date().toISOString().slice(0, 10);
    const result = rewardGamePerformanceWithId('memory', normalized, config.maxScore, `kaboom-cartoon-${difficulty}-${dailyId}`);
    setReward(result);
    playLamsaSound(result.alreadyRewarded ? 'notification' : 'success');
  }, [finished, stars, damage, config.maxScore, difficulty]);

  const restart = () => {
    finalizedRef.current = false;
    setStars(0);
    setDamage(0);
    setTimeLeft(config.seconds);
    setFinished(false);
    setReward(null);
    setStarted(true);
  };

  const startGame = () => {
    finalizedRef.current = false;
    setStars(0);
    setDamage(0);
    setTimeLeft(config.seconds);
    setFinished(false);
    setReward(null);
    setStarted(true);
  };

  const score = Math.max(0, stars * 2 - damage * 3);

  return (
    <div className="space-y-4">
      <GameHud
        title="🐱 Kaboom Arcade"
        subtitle="اجمع النجوم وتجنب القنابل"
        accentClassName="border-orange-200 bg-orange-50 text-orange-700"
        metrics={[
          { label: 'الصعوبة', value: difficulty },
          { label: 'نجوم', value: stars },
          { label: 'أضرار', value: damage },
          { label: 'الوقت', value: `${timeLeft}s` },
        ]}
      />

      {!started && (
        <div className="space-y-3 rounded-2xl border border-slate-200 bg-white p-4">
          <div className="flex flex-wrap gap-2">
            {(['easy', 'medium', 'hard'] as Difficulty[]).map((mode) => (
              <button
                key={mode}
                onClick={() => setDifficulty(mode)}
                className={`rounded-xl px-4 py-2 text-sm font-black ${difficulty === mode ? 'bg-orange-700 text-white' : 'bg-slate-200 text-slate-700'}`}
              >
                {mode === 'easy' ? 'سهل' : mode === 'medium' ? 'متوسط' : 'صعب'}
              </button>
            ))}
          </div>
          <button onClick={startGame} className="rounded-xl bg-orange-700 px-4 py-2 text-sm font-black text-white">بدء الجولة</button>
        </div>
      )}

      {started && !finished && (
        <canvas ref={canvasRef} className="w-full overflow-hidden rounded-2xl border-2 border-orange-300 shadow-xl" />
      )}

      {started && finished && (
        <div className="space-y-3 rounded-2xl border border-emerald-200 bg-emerald-50 p-4">
          <h3 className="text-xl font-black text-emerald-800">نتيجة التحدي الكرتوني</h3>
          <p className="font-bold text-emerald-700">النقاط: {Math.min(score, config.maxScore)} / {config.maxScore}</p>
          {reward && (
            <p className="font-bold text-emerald-700">
              {reward.alreadyRewarded
                ? 'تم صرف مكافأة هذا التحدي مسبقًا اليوم.'
                : `المكافأة: +${reward.gems} جواهر | +${reward.xp} XP`}
            </p>
          )}
          <button
            onClick={restart}
            className="rounded-xl bg-orange-700 px-4 py-2 text-sm font-black text-white"
          >
            إعادة الجولة
          </button>
          <button
            onClick={() => {
              setStarted(false);
              setFinished(false);
            }}
            className="rounded-xl bg-slate-700 px-4 py-2 text-sm font-black text-white"
          >
            تغيير الصعوبة
          </button>
        </div>
      )}
    </div>
  );
};

export default KaboomCartoonGame;
