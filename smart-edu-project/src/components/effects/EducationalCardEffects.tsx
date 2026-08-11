import React, { useEffect, useRef } from 'react';

interface EducationalCardEffectsProps {
  accent?: string;
  compact?: boolean;
  variant?: 'default' | 'aurora' | 'constellation' | 'pulse';
}

/* Lightweight SVG constellation rendered once */
const Constellation: React.FC<{ color: string }> = ({ color }) => (
  <svg
    aria-hidden="true"
    className="absolute inset-0 h-full w-full"
    viewBox="0 0 240 140"
    fill="none"
    preserveAspectRatio="xMidYMid slice"
  >
    {/* connecting lines */}
    <line x1="18" y1="22" x2="58" y2="48" stroke={color} strokeWidth="0.6" strokeOpacity="0.35" />
    <line x1="58" y1="48" x2="112" y2="30" stroke={color} strokeWidth="0.6" strokeOpacity="0.28" />
    <line x1="112" y1="30" x2="168" y2="58" stroke={color} strokeWidth="0.6" strokeOpacity="0.28" />
    <line x1="168" y1="58" x2="220" y2="38" stroke={color} strokeWidth="0.6" strokeOpacity="0.22" />
    <line x1="58" y1="48" x2="82" y2="100" stroke={color} strokeWidth="0.6" strokeOpacity="0.22" />
    <line x1="168" y1="58" x2="152" y2="112" stroke={color} strokeWidth="0.6" strokeOpacity="0.22" />
    {/* nodes */}
    {[
      [18, 22], [58, 48], [112, 30], [168, 58], [220, 38],
      [82, 100], [152, 112], [210, 118],
    ].map(([cx, cy], i) => (
      <circle key={i} cx={cx} cy={cy} r={i === 2 ? 3.5 : 2.2} fill={color} fillOpacity={i === 2 ? 0.7 : 0.45} />
    ))}
  </svg>
);

/* Shimmer sweep — pure CSS animation via inline style */
const ShimmerSweep: React.FC<{ delay?: number }> = ({ delay = 0 }) => (
  <div
    aria-hidden="true"
    className="pointer-events-none absolute inset-0"
    style={{
      background:
        'linear-gradient(105deg, transparent 35%, rgba(255,255,255,0.18) 50%, transparent 65%)',
      backgroundSize: '200% 100%',
      animation: `shimmerSweep 3.8s ease-in-out infinite`,
      animationDelay: `${delay}s`,
    }}
  />
);

/* Glowing orb that drifts slowly */
const DriftOrb: React.FC<{
  size: number;
  color: string;
  x: string;
  y: string;
  delay: number;
  duration: number;
}> = ({ size, color, x, y, delay, duration }) => (
  <div
    aria-hidden="true"
    className="pointer-events-none absolute rounded-full"
    style={{
      width: size,
      height: size,
      left: x,
      top: y,
      background: `radial-gradient(circle, ${color} 0%, transparent 72%)`,
      animation: `orbDrift ${duration}s ease-in-out infinite alternate`,
      animationDelay: `${delay}s`,
      filter: 'blur(2px)',
    }}
  />
);

/* Tiny animated sparkle dot */
const SparkDot: React.FC<{ x: string; y: string; color: string; delay: number; size?: number }> = ({
  x, y, color, delay, size = 3,
}) => (
  <div
    aria-hidden="true"
    className="pointer-events-none absolute rounded-full"
    style={{
      width: size,
      height: size,
      left: x,
      top: y,
      background: color,
      boxShadow: `0 0 ${size * 2}px ${color}`,
      animation: `sparkPulse 2.4s ease-in-out infinite`,
      animationDelay: `${delay}s`,
    }}
  />
);

const EducationalCardEffects: React.FC<EducationalCardEffectsProps> = ({
  accent = '#38bdf8',
  compact = false,
  variant = 'default',
}) => {
  return (
    <>
      {/* Keyframe injection — rendered once per mount, pointer-events-none */}
      <style>{`
        @keyframes shimmerSweep {
          0%   { background-position: -200% 0; }
          60%  { background-position:  200% 0; }
          100% { background-position:  200% 0; }
        }
        @keyframes orbDrift {
          0%   { transform: translate(0px, 0px) scale(1); opacity: 0.55; }
          50%  { transform: translate(8px, -6px) scale(1.12); opacity: 0.75; }
          100% { transform: translate(-6px, 10px) scale(0.92); opacity: 0.5; }
        }
        @keyframes sparkPulse {
          0%, 100% { opacity: 0.3; transform: scale(0.8); }
          50%       { opacity: 1;   transform: scale(1.5); }
        }
        @keyframes auroraPan {
          0%   { transform: translateX(-60%) skewX(-8deg); opacity: 0; }
          20%  { opacity: 0.6; }
          80%  { opacity: 0.6; }
          100% { transform: translateX(160%) skewX(-8deg); opacity: 0; }
        }
      `}</style>

      <div
        aria-hidden="true"
        className="pointer-events-none absolute inset-0 overflow-hidden rounded-[inherit]"
      >
        {/* === Layer 1: Aurora background gradient === */}
        <div
          className="absolute inset-0"
          style={{
            background: `
              radial-gradient(ellipse 80% 55% at 85% 15%, ${accent}38 0%, transparent 70%),
              radial-gradient(ellipse 60% 50% at 10% 85%, ${accent}22 0%, transparent 65%)
            `,
          }}
        />

        {/* === Layer 2: Constellation (hidden on compact) === */}
        {!compact && <Constellation color={accent} />}

        {/* === Layer 3: Shimmer sweep === */}
        <ShimmerSweep delay={0} />

        {/* === Layer 4: Drifting orbs === */}
        <DriftOrb size={compact ? 52 : 80} color={`${accent}60`} x="-10%" y="-25%" delay={0} duration={5.5} />
        <DriftOrb size={compact ? 40 : 64} color={`${accent}40`} x="72%" y="55%"  delay={1.8} duration={6.8} />
        {!compact && (
          <DriftOrb size={48} color={`${accent}30`} x="35%" y="-15%" delay={3.2} duration={7.2} />
        )}

        {/* === Layer 5: Spark dots === */}
        <SparkDot x="88%"  y="12%"  color="#ffffff" delay={0}    size={compact ? 3 : 4} />
        <SparkDot x="12%"  y="78%"  color={accent}  delay={0.8}  size={compact ? 2 : 3} />
        <SparkDot x="54%"  y="8%"   color="#ffffff" delay={1.6}  size={2} />
        {!compact && (
          <>
            <SparkDot x="24%"  y="30%"  color={accent}  delay={2.2}  size={3} />
            <SparkDot x="75%"  y="85%"  color="#ffffff" delay={0.4}  size={2} />
          </>
        )}

        {/* === Layer 6: Aurora streak === */}
        <div
          className="absolute inset-y-0"
          style={{
            left: '-40%',
            width: '35%',
            background: `linear-gradient(to right, transparent, ${accent}30, transparent)`,
            animation: 'auroraPan 5.5s ease-in-out infinite',
            animationDelay: '1s',
          }}
        />

        {/* === Layer 7: Bottom edge highlight === */}
        <div
          className="absolute bottom-0 left-[8%] right-[8%] h-px rounded-full"
          style={{ background: `linear-gradient(90deg, transparent, ${accent}80, transparent)` }}
        />

        {/* === Layer 8: Corner glow pinpoints === */}
        <div
          className="absolute left-0 top-0 h-16 w-16 rounded-br-full"
          style={{ background: `radial-gradient(circle at 0% 0%, ${accent}45, transparent 72%)` }}
        />
        <div
          className="absolute bottom-0 right-0 h-12 w-12 rounded-tl-full"
          style={{ background: `radial-gradient(circle at 100% 100%, ${accent}35, transparent 72%)` }}
        />
      </div>
    </>
  );
};

export default EducationalCardEffects;
