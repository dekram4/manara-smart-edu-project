import React, { useEffect, useRef, useState } from 'react';
import Phaser from 'phaser';
import confetti from 'canvas-confetti';

interface StudentGameCanvasProps {
  onGameComplete: (score: number) => void;
  onClose: () => void;
}

const WIDTH = 960;
const HEIGHT = 540;
const WORLD_WIDTH = 2200;
const GOAL_GEMS = 12;
const ROUND_SECONDS = 90;

const StudentGameCanvas: React.FC<StudentGameCanvasProps> = ({ onGameComplete, onClose }) => {
  const mountRef = useRef<HTMLDivElement | null>(null);
  const onGameCompleteRef = useRef(onGameComplete);
  const [score, setScore] = useState(0);
  const [lives, setLives] = useState(3);
  const [timeLeft, setTimeLeft] = useState(ROUND_SECONDS);
  const [status, setStatus] = useState<'playing' | 'won' | 'lost'>('playing');
  const [seed, setSeed] = useState(0);

  useEffect(() => {
    onGameCompleteRef.current = onGameComplete;
  }, [onGameComplete]);

  useEffect(() => {
    if (!mountRef.current) return;

    setScore(0);
    setLives(3);
    setTimeLeft(ROUND_SECONDS);
    setStatus('playing');

    let scoreValue = 0;
    let livesValue = 3;
    let timeValue = ROUND_SECONDS;
    let ended = false;

    class HeroScene extends Phaser.Scene {
      player!: Phaser.Physics.Arcade.Sprite;
      cursors!: Phaser.Types.Input.Keyboard.CursorKeys;
      wasd!: { W: Phaser.Input.Keyboard.Key; A: Phaser.Input.Keyboard.Key; S: Phaser.Input.Keyboard.Key; D: Phaser.Input.Keyboard.Key };
      gems!: Phaser.Physics.Arcade.Group;
      enemies!: Phaser.Physics.Arcade.Group;
      scoreText!: Phaser.GameObjects.Text;
      timerEvent!: Phaser.Time.TimerEvent;
      jumpBlocked = false;

      create() {
        const bg1 = this.add.rectangle(WORLD_WIDTH / 2, HEIGHT / 2, WORLD_WIDTH, HEIGHT, 0x0f172a);
        const bg2 = this.add.rectangle(WORLD_WIDTH / 2, HEIGHT - 110, WORLD_WIDTH, 220, 0x1e293b);
        bg1.setDepth(-5);
        bg2.setDepth(-4);

        if (!this.textures.exists('hero-block')) {
          const g = this.make.graphics({ x: 0, y: 0, add: false });
          g.fillStyle(0xfbbf24, 1);
          g.fillRoundedRect(0, 0, 38, 54, 10);
          g.generateTexture('hero-block', 38, 54);
          g.clear();

          g.fillStyle(0xec4899, 1);
          g.fillCircle(13, 13, 13);
          g.generateTexture('gem-orb', 26, 26);
          g.clear();

          g.fillStyle(0xef4444, 1);
          g.fillRoundedRect(0, 0, 34, 34, 8);
          g.generateTexture('enemy-cube', 34, 34);
          g.clear();

          g.fillStyle(0x475569, 1);
          g.fillRoundedRect(0, 0, 120, 24, 8);
          g.generateTexture('platform-slab', 120, 24);
          g.destroy();
        }

        this.physics.world.setBounds(0, 0, WORLD_WIDTH, HEIGHT);

        const platforms = this.physics.add.staticGroup();
        platforms.create(WORLD_WIDTH / 2, HEIGHT - 20, 'platform-slab').setDisplaySize(WORLD_WIDTH, 42).refreshBody();

        [280, 520, 760, 1040, 1320, 1580, 1840].forEach((x, idx) => {
          const y = 430 - (idx % 3) * 78;
          platforms.create(x, y, 'platform-slab').setDisplaySize(180, 24).refreshBody();
        });

        this.player = this.physics.add.sprite(100, 380, 'hero-block');
        this.player.setCollideWorldBounds(true);
        this.player.setBounce(0.05);
        this.player.body.setSize(34, 50);
        this.player.body.setOffset(2, 2);

        this.gems = this.physics.add.group();
        for (let i = 0; i < GOAL_GEMS; i += 1) {
          const x = Phaser.Math.Between(140, WORLD_WIDTH - 140);
          const y = Phaser.Math.Between(140, 390);
          const gem = this.physics.add.sprite(x, y, 'gem-orb');
          (gem.body as Phaser.Physics.Arcade.Body).setAllowGravity(false);
          this.gems.add(gem);
        }

        this.enemies = this.physics.add.group();
        [640, 1180, 1720].forEach((x) => {
          const enemy = this.physics.add.sprite(x, 470, 'enemy-cube');
          enemy.setVelocityX(Phaser.Math.Between(80, 120) * (Math.random() > 0.5 ? 1 : -1));
          enemy.setBounce(1, 0);
          enemy.setCollideWorldBounds(true);
          this.enemies.add(enemy);
        });

        this.physics.add.collider(this.player, platforms);
        this.physics.add.collider(this.enemies, platforms);

        this.physics.add.overlap(this.player, this.gems, (_player, gemObj) => {
          if (ended) return;
          const gem = gemObj as Phaser.Physics.Arcade.Sprite;
          gem.destroy();
          scoreValue += 10;
          setScore(scoreValue);
          this.scoreText.setText(`Score: ${scoreValue}`);

          const collected = scoreValue / 10;
          if (collected >= GOAL_GEMS) {
            ended = true;
            setStatus('won');
            confetti({ particleCount: 120, spread: 75, origin: { y: 0.6 } });
            this.time.delayedCall(700, () => onGameCompleteRef.current(scoreValue));
          }
        });

        this.physics.add.overlap(this.player, this.enemies, () => {
          if (ended) return;
          livesValue -= 1;
          setLives(livesValue);
          this.player.setTint(0xfca5a5);
          this.time.delayedCall(180, () => this.player.clearTint());
          const push = this.player.x < WORLD_WIDTH / 2 ? -180 : 180;
          this.player.setVelocity(push, -140);

          if (livesValue <= 0) {
            ended = true;
            setStatus('lost');
          }
        });

        this.cameras.main.setBounds(0, 0, WORLD_WIDTH, HEIGHT);
        this.cameras.main.startFollow(this.player, true, 0.08, 0.08);

        this.cursors = this.input.keyboard.createCursorKeys();
        this.wasd = this.input.keyboard.addKeys('W,A,S,D') as any;

        this.scoreText = this.add.text(18, 16, `Score: ${scoreValue}`, {
          fontFamily: 'Tahoma',
          fontSize: '22px',
          color: '#f8fafc',
          stroke: '#0f172a',
          strokeThickness: 5,
        }).setScrollFactor(0);

        this.add.text(18, 48, 'Move: Arrows/WASD | Jump: Space/Up/W', {
          fontFamily: 'Tahoma',
          fontSize: '14px',
          color: '#cbd5e1',
          stroke: '#0f172a',
          strokeThickness: 4,
        }).setScrollFactor(0);

        this.timerEvent = this.time.addEvent({
          delay: 1000,
          loop: true,
          callback: () => {
            if (ended) return;
            timeValue -= 1;
            setTimeLeft(timeValue);
            if (timeValue <= 0) {
              ended = true;
              setStatus('lost');
            }
          },
        });
      }

      update() {
        if (ended) {
          this.player.setVelocityX(0);
          return;
        }

        const body = this.player.body as Phaser.Physics.Arcade.Body;
        const goLeft = this.cursors.left?.isDown || this.wasd.A?.isDown;
        const goRight = this.cursors.right?.isDown || this.wasd.D?.isDown;
        const wantJump = this.cursors.up?.isDown || this.cursors.space?.isDown || this.wasd.W?.isDown;

        if (goLeft) {
          this.player.setVelocityX(-250);
        } else if (goRight) {
          this.player.setVelocityX(250);
        } else {
          this.player.setVelocityX(0);
        }

        if (wantJump && body.blocked.down && !this.jumpBlocked) {
          this.player.setVelocityY(-470);
          this.jumpBlocked = true;
          this.tweens.add({
            targets: this.player,
            scaleX: 1.08,
            scaleY: 0.92,
            duration: 80,
            yoyo: true,
          });
        }

        if (!wantJump) {
          this.jumpBlocked = false;
        }
      }
    }

    mountRef.current.innerHTML = '';

    const game = new Phaser.Game({
      type: Phaser.CANVAS,
      width: WIDTH,
      height: HEIGHT,
      parent: mountRef.current,
      backgroundColor: '#0f172a',
      physics: {
        default: 'arcade',
        arcade: {
          gravity: { x: 0, y: 980 },
          debug: false,
        },
      },
      scene: HeroScene,
    });

    return () => {
      game.destroy(true);
      if (mountRef.current) {
        mountRef.current.innerHTML = '';
      }
    };
  }, [seed]);

  const restart = () => {
    setSeed((prev) => prev + 1);
  };

  return (
    <div className="fixed inset-0 z-[90] flex items-center justify-center bg-slate-950/80 p-3 sm:p-4 backdrop-blur-md safe-area-x safe-area-top safe-area-bottom">
      <div className="mobile-modal-panel relative w-full max-w-5xl rounded-3xl border-4 border-amber-400/50 bg-slate-900 p-4 sm:p-6 shadow-2xl">
        <button
          onClick={onClose}
          className="absolute left-4 top-4 rounded-xl bg-red-500 px-4 py-2 text-sm font-black text-white transition-all hover:bg-red-600"
        >
          ✖ إغلاق
        </button>

        <div className="mb-4 text-center">
          <h2 className="text-3xl font-black text-amber-300">🎮 مغامرة البطل التعليمية</h2>
          <p className="mt-2 text-sm font-bold text-slate-300">لعبة منصات احترافية: شخصية، قفز، أعداء، وجواهر</p>
        </div>

        <div className="mb-3 grid grid-cols-2 gap-2 rounded-2xl border border-white/10 bg-slate-800/70 p-3 text-sm font-black text-slate-200 md:grid-cols-4">
          <div>⭐ النقاط: {score}</div>
          <div>💗 المحاولات: {lives}</div>
          <div>💎 الجواهر: {Math.min(GOAL_GEMS, Math.floor(score / 10))} / {GOAL_GEMS}</div>
          <div>⏱️ الوقت: {timeLeft}s</div>
        </div>

        <div className="overflow-hidden rounded-2xl border-4 border-slate-700 shadow-inner">
          <div ref={mountRef} className="mx-auto w-full max-w-[960px]" />
        </div>

        {status !== 'playing' && (
          <div className="mt-4 flex flex-wrap items-center justify-center gap-3 rounded-2xl border border-white/15 bg-slate-800/80 p-4 text-center">
            <p className="text-lg font-black text-amber-300">
              {status === 'won' ? '🏆 إنجاز رائع! تم إنهاء المرحلة بنجاح' : '💥 انتهت الجولة، أعد المحاولة'}
            </p>
            <button
              onClick={restart}
              className="rounded-xl bg-cyan-500 px-4 py-2 text-sm font-black text-slate-950 transition-all hover:bg-cyan-400"
            >
              إعادة اللعب
            </button>
          </div>
        )}
      </div>
    </div>
  );
};

export default StudentGameCanvas;
