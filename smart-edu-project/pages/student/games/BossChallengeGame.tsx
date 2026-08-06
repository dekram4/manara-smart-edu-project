import React, { useEffect, useMemo, useRef, useState } from 'react';
import { Application, Graphics, Text } from 'pixi.js';
import { rewardWeeklyBossWithId } from '../../../utils/gamification';
import { playLamsaSound } from '../../../utils/sounds';
import GameHud from './shared/GameHud';

type Difficulty = 'easy' | 'medium' | 'hard';

type RewardResult = {
  xp: number;
  gems: number;
  percentage: number;
  alreadyRewarded: boolean;
};

const DIFFICULTY_CONFIG: Record<Difficulty, { bossHp: number; roundSeconds: number; weakPointTTL: number; maxScore: number }> = {
  easy: { bossHp: 14, roundSeconds: 70, weakPointTTL: 2200, maxScore: 120 },
  medium: { bossHp: 18, roundSeconds: 60, weakPointTTL: 1800, maxScore: 140 },
  hard: { bossHp: 24, roundSeconds: 52, weakPointTTL: 1450, maxScore: 170 },
};

const WIDTH = 760;
const HEIGHT = 420;

const getIsoWeekKey = () => {
  const date = new Date();
  const tmp = new Date(Date.UTC(date.getFullYear(), date.getMonth(), date.getDate()));
  const dayNum = tmp.getUTCDay() || 7;
  tmp.setUTCDate(tmp.getUTCDate() + 4 - dayNum);
  const yearStart = new Date(Date.UTC(tmp.getUTCFullYear(), 0, 1));
  const week = Math.ceil((((tmp.getTime() - yearStart.getTime()) / 86400000) + 1) / 7);
  return `${tmp.getUTCFullYear()}-W${String(week).padStart(2, '0')}`;
};

const BossChallengeGame: React.FC = () => {
  const [difficulty, setDifficulty] = useState<Difficulty>('medium');
  const [started, setStarted] = useState(false);
  const [finished, setFinished] = useState(false);
  const [sessionKey, setSessionKey] = useState(0);
  const [timeLeft, setTimeLeft] = useState(DIFFICULTY_CONFIG.medium.roundSeconds);
  const [bossHp, setBossHp] = useState(DIFFICULTY_CONFIG.medium.bossHp);
  const [hits, setHits] = useState(0);
  const [misses, setMisses] = useState(0);
  const [combo, setCombo] = useState(0);
  const [bestCombo, setBestCombo] = useState(0);
  const [reward, setReward] = useState<RewardResult | null>(null);

  const mountRef = useRef<HTMLDivElement | null>(null);
  const finalizedRef = useRef(false);

  const config = DIFFICULTY_CONFIG[difficulty];

  useEffect(() => {
    if (!started) {
      setTimeLeft(config.roundSeconds);
      setBossHp(config.bossHp);
    }
  }, [started, config.roundSeconds, config.bossHp]);

  useEffect(() => {
    if (!started || finished) return;

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
  }, [started, finished, sessionKey]);

  useEffect(() => {
    if (bossHp <= 0) {
      setFinished(true);
    }
  }, [bossHp]);

  useEffect(() => {
    if (!started || finished || !mountRef.current) return;

    let mounted = true;
    const app = new Application();
    let weakPoint: Graphics | null = null;
    let weakTTL = config.weakPointTTL;

    const setup = async () => {
      await app.init({
        width: WIDTH,
        height: HEIGHT,
        background: 0x0f172a,
        antialias: true,
      });

      if (!mounted || !mountRef.current) return;
      mountRef.current.appendChild(app.canvas);

      const title = new Text({
        text: 'Boss Challenge: اضرب نقطة الضعف بسرعة قبل اختفائها',
        style: {
          fill: '#e2e8f0',
          fontFamily: 'Tahoma',
          fontSize: 18,
          fontWeight: '700',
        },
      });
      title.x = 12;
      title.y = 12;
      app.stage.addChild(title);

      const boss = new Graphics();
      boss.circle(0, 0, 90);
      boss.fill({ color: 0x1d4ed8 });
      boss.circle(0, 0, 62);
      boss.fill({ color: 0x1e293b });
      boss.x = WIDTH / 2;
      boss.y = HEIGHT / 2 + 16;
      app.stage.addChild(boss);

      const spawnWeakPoint = () => {
        if (weakPoint) {
          app.stage.removeChild(weakPoint);
          weakPoint.destroy();
        }

        const angle = Math.random() * Math.PI * 2;
        const radius = 110 + Math.random() * 35;
        const x = WIDTH / 2 + Math.cos(angle) * radius;
        const y = HEIGHT / 2 + 16 + Math.sin(angle) * radius;

        weakPoint = new Graphics();
        weakPoint.circle(0, 0, 20);
        weakPoint.fill({ color: 0x22c55e });
        weakPoint.stroke({ width: 4, color: 0xa7f3d0 });
        weakPoint.x = x;
        weakPoint.y = y;
        weakPoint.eventMode = 'static';
        weakPoint.cursor = 'pointer';

        weakPoint.on('pointerdown', () => {
          setHits((prev) => prev + 1);
          setCombo((prev) => {
            const next = prev + 1;
            setBestCombo((best) => Math.max(best, next));
            return next;
          });
          setBossHp((prev) => Math.max(0, prev - 1));
          playLamsaSound('click');
          weakTTL = Math.max(700, weakTTL * 0.94);
          spawnWeakPoint();
        });

        app.stage.addChild(weakPoint);
      };

      spawnWeakPoint();

      app.ticker.add((ticker) => {
        if (!weakPoint) return;

        weakTTL -= ticker.deltaMS;
        const remainRatio = Math.max(0, weakTTL / config.weakPointTTL);
        weakPoint.scale.set(Math.max(0.35, remainRatio));

        if (weakTTL <= 0) {
          setMisses((prev) => prev + 1);
          setCombo(0);
          playLamsaSound('error');
          weakTTL = config.weakPointTTL;
          spawnWeakPoint();
        }
      });
    };

    setup();

    return () => {
      mounted = false;
      app.destroy(true, { children: true });
      if (mountRef.current) {
        mountRef.current.innerHTML = '';
      }
    };
  }, [started, finished, config.weakPointTTL, sessionKey]);

  const finalScore = useMemo(() => {
    const base = hits * 4 + bestCombo * 2 + timeLeft - misses * 3 + (bossHp <= 0 ? 20 : 0);
    return Math.max(0, Math.min(config.maxScore, base));
  }, [hits, bestCombo, timeLeft, misses, bossHp, config.maxScore]);

  useEffect(() => {
    if (!finished || finalizedRef.current || !started) return;
    finalizedRef.current = true;

    const weekKey = getIsoWeekKey();
    const rewardId = `boss-weekly-${difficulty}-${weekKey}`;
    const result = rewardWeeklyBossWithId(finalScore, config.maxScore, rewardId);
    setReward(result);
    playLamsaSound(result.alreadyRewarded ? 'notification' : 'success');
  }, [finished, started, difficulty, finalScore, config.maxScore]);

  const startGame = () => {
    finalizedRef.current = false;
    setReward(null);
    setFinished(false);
    setStarted(true);
    setSessionKey((prev) => prev + 1);
    setTimeLeft(config.roundSeconds);
    setBossHp(config.bossHp);
    setHits(0);
    setMisses(0);
    setCombo(0);
    setBestCombo(0);
  };

  const restartGame = () => {
    setStarted(false);
    setFinished(false);
    setSessionKey((prev) => prev + 1);
    setReward(null);
    setTimeLeft(config.roundSeconds);
    setBossHp(config.bossHp);
    setHits(0);
    setMisses(0);
    setCombo(0);
    setBestCombo(0);
    finalizedRef.current = false;
  };

  return (
    <div className="space-y-4">
      <GameHud
        title="👑 Boss Challenge"
        subtitle={bossHp <= 0 ? 'تمت هزيمة الزعيم' : 'التحدي الأسبوعي المتقدم'}
        accentClassName="border-violet-200 bg-violet-50 text-violet-700"
        metrics={[
          { label: 'الصعوبة', value: difficulty },
          { label: 'HP الزعيم', value: `${bossHp}/${config.bossHp}` },
          { label: 'Combo', value: combo },
          { label: 'الوقت', value: `${timeLeft}s` },
        ]}
      />

      {!started && (
        <div className="space-y-3 rounded-2xl border border-slate-200 bg-white p-4">
          <p className="text-sm font-bold text-slate-700">اختر مستوى الصعوبة ثم ابدأ التحدي الأسبوعي (مكافأة أعلى، مرة واحدة أسبوعيًا لكل مستوى).</p>
          <div className="flex flex-wrap gap-2">
            {(['easy', 'medium', 'hard'] as Difficulty[]).map((mode) => (
              <button
                key={mode}
                onClick={() => setDifficulty(mode)}
                className={`rounded-xl px-4 py-2 text-sm font-black ${difficulty === mode ? 'bg-violet-700 text-white' : 'bg-slate-200 text-slate-700'}`}
              >
                {mode === 'easy' ? 'سهل' : mode === 'medium' ? 'متوسط' : 'صعب'}
              </button>
            ))}
          </div>
          <button
            onClick={startGame}
            className="rounded-xl bg-violet-700 px-4 py-2 text-sm font-black text-white"
          >
            بدء تحدي الزعيم
          </button>
        </div>
      )}

      {started && !finished && (
        <div ref={mountRef} className="overflow-hidden rounded-2xl border-2 border-violet-300 shadow-xl" />
      )}

      {started && finished && (
        <div className="space-y-3 rounded-2xl border border-emerald-200 bg-emerald-50 p-4">
          <h3 className="text-xl font-black text-emerald-800">نتيجة Boss Challenge</h3>
          <p className="font-bold text-emerald-700">النقاط: {finalScore} / {config.maxScore}</p>
          <p className="font-bold text-emerald-700">Hits: {hits} | Misses: {misses} | Best Combo: {bestCombo}</p>
          {reward && (
            <p className="font-bold text-emerald-700">
              {reward.alreadyRewarded
                ? 'تم صرف مكافأة هذا التحدي مسبقًا لهذا الأسبوع.'
                : `المكافأة الأسبوعية: +${reward.gems} جواهر | +${reward.xp} XP`}
            </p>
          )}
          <button
            onClick={restartGame}
            className="rounded-xl bg-violet-700 px-4 py-2 text-sm font-black text-white"
          >
            إعادة التحضير
          </button>
        </div>
      )}
    </div>
  );
};

export default BossChallengeGame;
