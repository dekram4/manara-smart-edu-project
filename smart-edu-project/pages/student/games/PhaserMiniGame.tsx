import React, { useEffect, useRef, useState } from 'react';
import Phaser from 'phaser';
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

const DIFFICULTY_CONFIG: Record<Difficulty, { goal: number; seconds: number; hazards: number }> = {
  easy: { goal: 10, seconds: 55, hazards: 2 },
  medium: { goal: 12, seconds: 45, hazards: 3 },
  hard: { goal: 16, seconds: 40, hazards: 4 },
};

const PhaserMiniGame: React.FC = () => {
  const [difficulty, setDifficulty] = useState<Difficulty>('medium');
  const [started, setStarted] = useState(false);
  const mountRef = useRef<HTMLDivElement | null>(null);
  const [score, setScore] = useState(0);
  const [hits, setHits] = useState(0);
  const [timeLeft, setTimeLeft] = useState(DIFFICULTY_CONFIG.medium.seconds);
  const [finished, setFinished] = useState(false);
  const [sessionKey, setSessionKey] = useState(0);
  const [reward, setReward] = useState<RewardResult | null>(null);
  const finalizedRef = useRef(false);

  const config = DIFFICULTY_CONFIG[difficulty];

  useEffect(() => {
    if (!mountRef.current || finished || !started) return;

    class MiniScene extends Phaser.Scene {
      player!: Phaser.GameObjects.Rectangle;
      star!: Phaser.GameObjects.Arc;
      hazards: Phaser.GameObjects.Arc[] = [];
      hazardVelocities: { x: number; y: number }[] = [];
      cursors!: Phaser.Types.Input.Keyboard.CursorKeys;
      lastHitAt = 0;

      create() {
        this.player = this.add.rectangle(80, 160, 34, 34, 0x38bdf8);
        this.star = this.add.circle(540, 160, 14, 0xfacc15);
        this.add.text(18, 12, 'اجمع النجوم وتجنب العوائق الحمراء', {
          color: '#ffffff',
          fontSize: '16px',
          fontFamily: 'Tahoma',
        });
        for (let i = 0; i < config.hazards; i += 1) {
          this.hazards.push(this.add.circle(180 + i * 160, 80 + i * 70, 14, 0xf43f5e));
          this.hazardVelocities.push({
            x: Phaser.Math.Between(-2, 2) || 1,
            y: Phaser.Math.Between(-2, 2) || -1,
          });
        }
        this.cursors = this.input.keyboard.createCursorKeys();
      }

      update() {
        const speed = 3.2;
        if (this.cursors.left?.isDown) this.player.x -= speed;
        if (this.cursors.right?.isDown) this.player.x += speed;
        if (this.cursors.up?.isDown) this.player.y -= speed;
        if (this.cursors.down?.isDown) this.player.y += speed;

        this.player.x = Phaser.Math.Clamp(this.player.x, 16, 624);
        this.player.y = Phaser.Math.Clamp(this.player.y, 16, 304);

        const distance = Phaser.Math.Distance.Between(this.player.x, this.player.y, this.star.x, this.star.y);
        if (distance < 28) {
          setScore((prev) => prev + 1);
          this.star.x = Phaser.Math.Between(30, 610);
          this.star.y = Phaser.Math.Between(30, 290);
        }

        this.hazards.forEach((hazard, idx) => {
          const velocity = this.hazardVelocities[idx];
          hazard.x += velocity.x;
          hazard.y += velocity.y;

          if (hazard.x < 20 || hazard.x > 620) velocity.x *= -1;
          if (hazard.y < 20 || hazard.y > 300) velocity.y *= -1;

          const hitDistance = Phaser.Math.Distance.Between(this.player.x, this.player.y, hazard.x, hazard.y);
          if (hitDistance < 28 && this.time.now - this.lastHitAt > 450) {
            this.lastHitAt = this.time.now;
            setHits((prev) => prev + 1);
          }
        });
      }
    }

    const game = new Phaser.Game({
      type: Phaser.AUTO,
      width: 640,
      height: 320,
      parent: mountRef.current,
      backgroundColor: '#0f172a',
      scene: MiniScene,
    });

    return () => {
      game.destroy(true);
    };
  }, [finished, sessionKey, started, config.hazards]);

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
    if (score >= config.goal || hits >= 6) {
      setFinished(true);
    }
  }, [score, hits, config.goal]);

  useEffect(() => {
    if (!finished || finalizedRef.current) return;
    finalizedRef.current = true;

    const performanceScore = Math.max(0, score - hits * 2);
    const dailyId = new Date().toISOString().slice(0, 10);
    const result = rewardGamePerformanceWithId('speed', performanceScore, config.goal, `phaser-arcade-${difficulty}-${dailyId}`);
    setReward(result);
     if (result.alreadyRewarded) {
       playLamsaSound('notification');
     } else {
       GameAudioEngine.play(result.xp >= 100 ? 'levelUp' : 'collectGem');
     }
  }, [finished, score, hits, config.goal, difficulty]);

  const restart = () => {
    finalizedRef.current = false;
    setReward(null);
    setScore(0);
    setHits(0);
    setTimeLeft(config.seconds);
    setFinished(false);
    setSessionKey((prev) => prev + 1);
    setStarted(true);
  };

  const performanceScore = Math.max(0, score - hits * 2);

  const startGame = () => {
    finalizedRef.current = false;
    setReward(null);
    setScore(0);
    setHits(0);
    setTimeLeft(config.seconds);
    setFinished(false);
    setSessionKey((prev) => prev + 1);
    setStarted(true);
  };

  return (
    <div className="space-y-4">
      <GameHud
        title="🕹️ Phaser Adventure"
        subtitle="اجمع النجوم وتجنب العوائق"
        accentClassName="border-sky-200 bg-sky-50 text-sky-700"
        metrics={[
          { label: 'الصعوبة', value: difficulty },
          { label: 'الهدف', value: `${config.goal} نجمة` },
          { label: 'النجوم', value: score },
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
                className={`rounded-xl px-4 py-2 text-sm font-black ${difficulty === mode ? 'bg-sky-700 text-white' : 'bg-slate-200 text-slate-700'}`}
              >
                {mode === 'easy' ? 'سهل' : mode === 'medium' ? 'متوسط' : 'صعب'}
              </button>
            ))}
          </div>
          <button onClick={startGame} className="rounded-xl bg-sky-700 px-4 py-2 text-sm font-black text-white">بدء الجولة</button>
        </div>
      )}

      {started && !finished && (
        <div ref={mountRef} className="overflow-hidden rounded-2xl border-2 border-sky-300 shadow-xl" />
      )}

      {started && finished && (
        <div className="space-y-3 rounded-2xl border border-emerald-200 bg-emerald-50 p-4">
          <h3 className="text-xl font-black text-emerald-800">نتيجة الجولة</h3>
          <p className="font-bold text-emerald-700">النتيجة الفعلية: {performanceScore} / {config.goal}</p>
          {reward && (
            <p className="font-bold text-emerald-700">
              {reward.alreadyRewarded
                ? 'تم صرف مكافأة هذا التحدي مسبقًا اليوم.'
                : `المكافأة: +${reward.gems} جواهر | +${reward.xp} XP`}
            </p>
          )}
          <button
            onClick={restart}
            className="rounded-xl bg-sky-700 px-4 py-2 text-sm font-black text-white"
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

export default PhaserMiniGame;
