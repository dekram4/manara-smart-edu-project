import React, { useState } from 'react';
import { motion } from 'framer-motion';
import { GameAudioEngine } from '../../../utils/gameAudioEngine';

interface Interactive3DEmojiProps {
  emoji: string;
  accent?: string;
  size?: 'sm' | 'md' | 'lg' | 'xl';
  label?: string;
  className?: string;
}

const sizeMap = {
  sm: { shell: 'h-14 w-14', emoji: 'text-2xl', ring: '-inset-1.5', dot: 'h-1.5 w-1.5' },
  md: { shell: 'h-[72px] w-[72px]', emoji: 'text-4xl', ring: '-inset-2', dot: 'h-2 w-2' },
  lg: { shell: 'h-24 w-24', emoji: 'text-6xl', ring: '-inset-2.5', dot: 'h-2.5 w-2.5' },
  xl: { shell: 'h-32 w-32', emoji: 'text-8xl', ring: '-inset-3', dot: 'h-3 w-3' },
} as const;

/**
 * A lightweight 3D emoji object for the student experience.
 * It uses pointer tilt instead of WebGL so it also works on low-power devices.
 */
const Interactive3DEmoji: React.FC<Interactive3DEmojiProps> = ({
  emoji,
  accent = '#38bdf8',
  size = 'md',
  label,
  className = '',
}) => {
  const [tilt, setTilt] = useState({ x: 0, y: 0 });
  const [active, setActive] = useState(false);
  const dimensions = sizeMap[size];

  const handlePointerMove = (event: React.PointerEvent<HTMLDivElement>) => {
    const rect = event.currentTarget.getBoundingClientRect();
    const x = ((event.clientX - rect.left) / rect.width - 0.5) * 2;
    const y = ((event.clientY - rect.top) / rect.height - 0.5) * 2;
    setTilt({ x: x * 16, y: -y * 16 });
  };

  const resetTilt = () => {
    setTilt({ x: 0, y: 0 });
    setActive(false);
  };

  return (
    <div
      className={`relative inline-flex flex-col items-center ${className}`}
      style={{ perspective: '900px', touchAction: 'none' }}
       onPointerEnter={() => {
         setActive(true);
         GameAudioEngine.play('uiHover');
       }}
      onPointerMove={handlePointerMove}
      onPointerLeave={resetTilt}
      onPointerCancel={resetTilt}
    >
      <motion.div
        className="relative"
        animate={{
          rotateX: tilt.y,
          rotateY: tilt.x,
          y: active ? -5 : [0, -4, 0],
          scale: active ? 1.08 : 1,
        }}
        transition={{
          rotateX: { type: 'spring', stiffness: 260, damping: 18 },
          rotateY: { type: 'spring', stiffness: 260, damping: 18 },
          y: active ? { type: 'spring', stiffness: 300, damping: 18 } : { duration: 3.2, repeat: Infinity, ease: 'easeInOut' },
          scale: { type: 'spring', stiffness: 280, damping: 18 },
        }}
        style={{ transformStyle: 'preserve-3d', transformOrigin: 'center center' }}
      >
        {/* orbit rings */}
        <motion.div
          aria-hidden="true"
          className={`pointer-events-none absolute ${dimensions.ring} rounded-full border border-dashed`}
          style={{
            borderColor: `${accent}75`,
            boxShadow: `0 0 18px ${accent}35`,
            transform: 'rotateX(66deg) rotateZ(-18deg)',
          }}
          animate={{ rotateZ: [-18, 342] }}
          transition={{ duration: 7, repeat: Infinity, ease: 'linear' }}
        />
        <motion.div
          aria-hidden="true"
          className={`pointer-events-none absolute ${dimensions.ring} rounded-full border`}
          style={{
            borderColor: `${accent}35`,
            transform: 'rotateY(66deg) rotateZ(28deg)',
          }}
          animate={{ rotateZ: [28, -332] }}
          transition={{ duration: 5.5, repeat: Infinity, ease: 'linear' }}
        />

        {/* glass volume */}
        <div
          className={`${dimensions.shell} relative flex items-center justify-center rounded-[28%] border backdrop-blur-md`}
          style={{
            background: `radial-gradient(circle at 30% 20%, rgba(255,255,255,0.28), transparent 28%), linear-gradient(145deg, ${accent}45, rgba(15,23,42,0.72))`,
            borderColor: `${accent}90`,
            boxShadow: `0 16px 30px rgba(0,0,0,0.28), 0 0 28px ${accent}45, inset 5px 5px 12px rgba(255,255,255,0.16), inset -8px -8px 16px rgba(0,0,0,0.18)`,
            transform: 'translateZ(18px)',
          }}
        >
          {/* gloss reflection */}
          <div
            aria-hidden="true"
            className="pointer-events-none absolute left-[14%] top-[10%] h-[24%] w-[42%] rotate-[-35deg] rounded-full bg-white/35 blur-[3px]"
          />
          <motion.span
            aria-hidden="true"
            className={`${dimensions.emoji} relative z-10 select-none leading-none drop-shadow-[0_8px_6px_rgba(0,0,0,0.3)]`}
            animate={active ? { rotate: [-5, 5, -2, 0], scale: [1, 1.16, 1.04, 1] } : { rotate: 0, scale: 1 }}
            transition={{ duration: 0.55 }}
            style={{ transform: 'translateZ(28px)' }}
          >
            {emoji}
          </motion.span>
          <motion.span
            aria-hidden="true"
            className={`absolute bottom-[13%] right-[13%] ${dimensions.dot} rounded-full`}
            style={{ background: accent, boxShadow: `0 0 12px ${accent}` }}
            animate={{ opacity: [0.35, 1, 0.35], scale: [0.8, 1.25, 0.8] }}
            transition={{ duration: 2, repeat: Infinity, ease: 'easeInOut' }}
          />
        </div>
      </motion.div>
      {label && (
        <span
          className="mt-2 rounded-full border px-2.5 py-0.5 text-[10px] font-black text-white/75 backdrop-blur-md"
          style={{ background: `${accent}20`, borderColor: `${accent}45` }}
        >
          {label}
        </span>
      )}
    </div>
  );
};

export default Interactive3DEmoji;