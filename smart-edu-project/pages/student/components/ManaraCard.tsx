import React from 'react';
import { motion } from 'framer-motion';

interface ManaraCardProps {
  emoji: string;
  title: string;
  subtitle: string;
  color: string;
  bgColor: string;
  delay?: number;
  isNew?: boolean;
  onClick: () => void;
}

const ManaraCard: React.FC<ManaraCardProps> = ({
  emoji, title, subtitle, color, bgColor, delay = 0, isNew = false, onClick,
}) => {
  return (
    <motion.div
      className="relative"
      initial={{ opacity: 0, y: 30, scale: 0.9 }}
      animate={{ opacity: 1, y: 0, scale: 1 }}
      transition={{ duration: 0.4, delay, type: "spring", stiffness: 200 }}
      whileHover={{ scale: 1.05, y: -8, rotate: -2, boxShadow: '0 24px 48px rgba(15, 23, 42, 0.2)' }}
      whileTap={{ scale: 0.94, rotate: -1 }}
      onClick={onClick}
      style={{ WebkitTapHighlightColor: 'transparent', cursor: 'pointer' }}
    >
      {/* NEW badge */}
      {isNew && (
        <div 
          className="absolute -top-1.5 -right-1 z-10"
          style={{ WebkitAnimation: 'badgeBounce 2s ease-in-out infinite' }}
        >
          <span 
            className="text-white text-[9px] font-bold px-1.5 py-0.5 rounded-full shadow-md"
            style={{ background: '#EF4444' }}
          >
            جديد!
          </span>
        </div>
      )}

      <div
        className="relative rounded-2xl p-3 h-32 flex flex-col items-center justify-center text-center overflow-hidden"
        style={{
          background: bgColor,
          border: `1px solid ${color}30`,
          WebkitBoxShadow: `0 4px 16px ${color}25`,
          boxShadow: `0 4px 16px ${color}25`,
        }}
      >
        {/* Decorative circles */}
        <div
          className="absolute -top-4 -right-4 w-16 h-16 rounded-full opacity-20"
          style={{ background: color }}
        />
        <div
          className="absolute -bottom-6 -left-6 w-20 h-20 rounded-full opacity-15"
          style={{ background: color }}
        />

        {/* Floating emoji */}
        <div
          className="relative z-10 text-4xl mb-1"
          style={{ WebkitTransform: 'translateZ(0)' }}
        >
          {emoji}
        </div>

        <h3 className="relative z-10 font-bold text-sm text-gray-800 leading-tight">
          {title}
        </h3>
        <p className="relative z-10 text-[11px] text-gray-600 mt-0.5">
          {subtitle}
        </p>
      </div>
    </motion.div>
  );
};

export default ManaraCard;
