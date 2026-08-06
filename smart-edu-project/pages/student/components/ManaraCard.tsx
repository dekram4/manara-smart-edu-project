import React, { useState } from 'react';
import { motion } from 'framer-motion';
import EducationalCardEffects from '../../../components/effects/EducationalCardEffects';
import Interactive3DEmoji from '../../../components/effects/Interactive3DEmoji';
import { GameAudioEngine } from '../../../utils/gameAudioEngine';

interface ManaraCardProps {
  emoji: string;
  title: string;
  subtitle: string;
  color: string;       // accent hex
  bgColor: string;     // card bg (can be gradient string or color)
  delay?: number;
  isNew?: boolean;
  onClick: () => void;
}

const ManaraCard: React.FC<ManaraCardProps> = ({
  emoji, title, subtitle, color, bgColor, delay = 0, isNew = false, onClick,
}) => {
  const [hovered, setHovered] = useState(false);

  return (
    <motion.div
      className="relative cursor-pointer"
      initial={{ opacity: 0, y: 30, scale: 0.88 }}
      animate={{ opacity: 1, y: 0, scale: 1 }}
      transition={{ duration: 0.42, delay, type: 'spring', stiffness: 220, damping: 20 }}
      whileHover={{ scale: 1.07, y: -10 }}
      whileTap={{ scale: 0.94 }}
       onHoverStart={() => {
         setHovered(true);
         GameAudioEngine.play('uiHover');
       }}
      onHoverEnd={() => setHovered(false)}
      onClick={onClick}
      style={{ WebkitTapHighlightColor: 'transparent' }}
    >
      {/* NEW badge */}
      {isNew && (
        <div className="absolute -right-1 -top-1.5 z-20">
          <span className="rounded-full bg-red-500 px-2 py-0.5 text-[9px] font-black text-white shadow-lg shadow-red-500/40">
            جديد!
          </span>
        </div>
      )}

      {/* Card shell */}
      <div
        className="relative h-32 overflow-hidden rounded-2xl border"
        style={{
          background: bgColor,
          borderColor: `${color}30`,
          boxShadow: hovered
            ? `0 16px 40px ${color}45, 0 0 0 1px ${color}25, inset 0 1px 0 rgba(255,255,255,0.15)`
            : `0 4px 16px ${color}20, inset 0 1px 0 rgba(255,255,255,0.08)`,
          transition: 'box-shadow 0.3s',
        }}
      >
        {/* Rich card effects */}
        <EducationalCardEffects accent={color} compact />

        {/* Large decorative orb top-right */}
        <div
          className="pointer-events-none absolute -right-6 -top-6 h-24 w-24 rounded-full"
          style={{ background: `radial-gradient(circle, ${color}35, transparent 72%)` }}
        />
        {/* Bottom-left secondary orb */}
        <div
          className="pointer-events-none absolute -bottom-8 -left-8 h-20 w-20 rounded-full"
          style={{ background: `radial-gradient(circle, ${color}25, transparent 72%)` }}
        />

        {/* Top shimmer line */}
        <div
          className="pointer-events-none absolute inset-x-0 top-0 h-px"
          style={{ background: `linear-gradient(90deg, transparent, ${color}80, transparent)` }}
        />

        {/* Animated corner sparkle */}
        <motion.div
          className="pointer-events-none absolute right-2 top-2 h-1.5 w-1.5 rounded-full bg-white"
          animate={{ opacity: [0.3, 1, 0.3], scale: [0.8, 1.4, 0.8] }}
          transition={{ duration: 2.5, repeat: Infinity, ease: 'easeInOut', delay }}
        />

        {/* Content */}
        <div className="relative z-10 flex h-full flex-col items-center justify-center gap-1 px-2 text-center">
          {/* Emoji with glow */}
          <Interactive3DEmoji emoji={emoji} accent={color} size="sm" />

          <h3 className="font-black text-sm leading-tight text-gray-800">{title}</h3>
          <p className="text-[11px] text-gray-600">{subtitle}</p>
        </div>
      </div>
    </motion.div>
  );
};

export default ManaraCard;
