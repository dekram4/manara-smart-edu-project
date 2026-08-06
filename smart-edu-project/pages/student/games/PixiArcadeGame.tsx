import React, { useEffect, useRef, useState } from 'react';
import { Application, Graphics, Text } from 'pixi.js';
import { rewardGamePerformanceWithId } from '../../../utils/gamification';
import { GameAudioEngine } from '../../../utils/gameAudioEngine';
import { playLamsaSound } from '../../../utils/sounds';
import GameHud from './shared/GameHud';

type Difficulty = 'easy' | 'medium' | 'hard';

type RewardResult = {
  xp: number;
  gems: number;
  percentage: number;
  alreadyRewarded: boolean;
};

type OrbState = {
  gfx: Graphics;
  vx: number;
  vy: number;
  isGood: boolean;
};

const WIDTH = 760;
const HEIGHT = 380;

const DIFFICULTY_CONFIG: Record<Difficulty, { seconds: number; goodOrbs: number; badOrbs: number; maxScore: number }> = {
  easy: { seconds: 52, goodOrbs: 5, badOrbs: 2, maxScore: 34 },
  medium: { seconds: 45, goodOrbs: 5, badOrbs: 3, maxScore: 35 },
  hard: { seconds: 40, goodOrbs: 6, badOrbs: 4, maxScore: 44 },
};

const PixiArcadeGame: React.FC = () => {
  const [difficulty, setDifficulty] = useState<Difficulty>('medium');
  const [started, setStarted] = useState(false);
  const mountRef = useRef<HTMLDivElement | null>(null);
  const [goodHits, setGoodHits] = useState(0);
  const [badHits, setBadHits] = useState(0);
  const [timeLeft, setTimeLeft] = useState(DIFFICULTY_CONFIG.medium.seconds);
  const [finished, setFinished] = useState(false);
  const [sessionKey, setSessionKey] = useState(0);
  const [reward, setReward] = useState<RewardResult | null>(null);
  const finalizedRef = useRef(false);
  const config = DIFFICULTY_CONFIG[difficulty];

  useEffect(() => {
    if (!mountRef.current || finished || !started) return;

    let mounted = true;
    const app = new Application();
    const orbs: OrbState[] = [];

    const setup = async () => {
      await app.init({
        width: WIDTH,
        height: HEIGHT,
        background: 0x0b132b,
        antialias: true,
      });

      if (!mounted || !mountRef.current) return;
      mountRef.current.appendChild(app.canvas);

      const title = new Text({
        text: 'Pixi Arcade: اضغط الأهداف الخضراء وتجنب الحمراء',
        style: {
          fill: '#dbeafe',
          fontFamily: 'Tahoma',
          fontSize: 18,
          fontWeight: '700',
        },
      });
      title.x = 12;
      title.y = 10;
      app.stage.addChild(title);

      const createOrb = (x: number, y: number, isGood: boolean) => {
        const orb = new Graphics();
        orb.circle(0, 0, 18);
        orb.fill({ color: isGood ? 0x10b981 : 0xf43f5e });
        orb.x = x;
        orb.y = y;
        orb.eventMode = 'static';
        orb.cursor = 'pointer';
        orb.on('pointerdown', () => {
          if (finished) return;
          if (isGood) {
            setGoodHits((prev) => prev + 1);
            playLamsaSound('click');
          } else {
            setBadHits((prev) => prev + 1);
            playLamsaSound('error');
          }

          orb.x = 50 + Math.random() * (WIDTH - 100);
          orb.y = 60 + Math.random() * (HEIGHT - 110);
        });

        const item: OrbState = {
          gfx: orb,
          vx: (Math.random() * 2.2 + 0.8) * (Math.random() > 0.5 ? 1 : -1),
          vy: (Math.random() * 2.2 + 0.8) * (Math.random() > 0.5 ? 1 : -1),
          isGood,
        };

        app.stage.addChild(orb);
        orbs.push(item);
      };

      for (let i = 0; i < config.goodOrbs; i += 1) {
        createOrb(80 + i * 120, 120 + (i % 2) * 80, true);
      }

      for (let i = 0; i < config.badOrbs; i += 1) {
        createOrb(140 + i * 180, 270 - (i % 2) * 90, false);
      }

      app.ticker.add(() => {
        orbs.forEach((orb) => {
          const node = orb.gfx;
          node.x += orb.vx;
          node.y += orb.vy;

          if (node.x < 20 || node.x > WIDTH - 20) orb.vx *= -1;
          if (node.y < 50 || node.y > HEIGHT - 20) orb.vy *= -1;
        });
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
  }, [finished, sessionKey, started, config.goodOrbs, config.badOrbs]);

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
  }, [finished, sessionKey, started]);

  useEffect(() => {
    if (!finished || finalizedRef.current) return;
    finalizedRef.current = true;

    const score = Math.max(0, goodHits * 2 - badHits * 3);
    const normalized = Math.min(config.maxScore, score);
    const dailyId = new Date().toISOString().slice(0, 10);
    const result = rewardGamePerformanceWithId('speed', normalized, config.maxScore, `pixi-arcade-${difficulty}-${dailyId}`);
    setReward(result);
     if (result.alreadyRewarded) {
       playLamsaSound('notification');
     } else {
       GameAudioEngine.play(result.xp >= 100 ? 'levelUp' : 'collectGem');
     }
  }, [finished, goodHits, badHits, config.maxScore, difficulty]);

  const restart = () => {
    finalizedRef.current = false;
    setReward(null);
    setGoodHits(0);
    setBadHits(0);
    setTimeLeft(config.seconds);
    setFinished(false);
    setSessionKey((prev) => prev + 1);
    setStarted(true);
  };

  const startGame = () => {
    finalizedRef.current = false;
    setReward(null);
    setGoodHits(0);
    setBadHits(0);
    setTimeLeft(config.seconds);
    setFinished(false);
    setSessionKey((prev) => prev + 1);
    setStarted(true);
  };

  const score = Math.max(0, goodHits * 2 - badHits * 3);

  return (
    <div className="space-y-4">
      <GameHud
        title="🎯 Pixi Arcade"
        subtitle="التقط الأخضر وتجنب الأحمر"
        accentClassName="border-emerald-200 bg-emerald-50 text-emerald-700"
        metrics={[
          { label: 'الصعوبة', value: difficulty },
          { label: 'إصابات صحيحة', value: goodHits },
          { label: 'أخطاء', value: badHits },
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
                className={`rounded-xl px-4 py-2 text-sm font-black ${difficulty === mode ? 'bg-emerald-700 text-white' : 'bg-slate-200 text-slate-700'}`}
              >
                {mode === 'easy' ? 'سهل' : mode === 'medium' ? 'متوسط' : 'صعب'}
              </button>
            ))}
          </div>
          <button onClick={startGame} className="rounded-xl bg-emerald-700 px-4 py-2 text-sm font-black text-white">بدء الجولة</button>
        </div>
      )}

      {started && !finished && (
        <div ref={mountRef} className="overflow-hidden rounded-2xl border-2 border-emerald-300 shadow-xl" />
      )}

      {started && finished && (
        <div className="space-y-3 rounded-2xl border border-emerald-200 bg-emerald-50 p-4">
          <h3 className="text-xl font-black text-emerald-800">نتيجة Pixi Arcade</h3>
          <p className="font-bold text-emerald-700">النتيجة: {Math.min(score, config.maxScore)} / {config.maxScore}</p>
          {reward && (
            <p className="font-bold text-emerald-700">
              {reward.alreadyRewarded
                ? 'تم صرف مكافأة هذا التحدي مسبقًا اليوم.'
                : `المكافأة: +${reward.gems} جواهر | +${reward.xp} XP`}
            </p>
          )}
          <button
            onClick={restart}
            className="rounded-xl bg-emerald-700 px-4 py-2 text-sm font-black text-white"
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

export default PixiArcadeGame;
