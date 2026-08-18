import React from 'react';
import { motion } from 'framer-motion';

interface ManaraHeaderProps {
  name: string;
  age: number;
  xp: number;
  gems: number;
  level: number;
  levelProgress: number;
}

const ManaraHeader: React.FC<ManaraHeaderProps> = ({ name, age, xp, gems, level, levelProgress }) => {
  return (
    <div className="relative px-4 pt-4 pb-2 z-10" style={{ WebkitTransform: 'translateZ(0)' }}>
      {/* Floating sparkles */}
      <div className="absolute top-2 right-8 text-yellow-300 text-lg animate-float-slow" style={{ animationDelay: '0.5s', WebkitAnimationDelay: '0.5s' }}>✨</div>
      <div className="absolute top-8 left-4 text-yellow-200 text-sm animate-float-slow" style={{ animationDelay: '1.2s', WebkitAnimationDelay: '1.2s' }}>⭐</div>
      <div className="absolute top-1 left-1/3 text-pink-300 text-xs animate-float-slow" style={{ animationDelay: '0.8s', WebkitAnimationDelay: '0.8s' }}>💫</div>

      <div className="flex min-w-0 items-center gap-2 sm:gap-3">
        {/* Avatar with crown */}
        <motion.div
          className="relative"
          whileHover={{ scale: 1.1 }}
          transition={{ duration: 0.3 }}
          style={{ WebkitTapHighlightColor: 'transparent' }}
        >
          <div 
            className="h-11 w-11 sm:h-14 sm:w-14 rounded-full p-[2px] shadow-lg"
            style={{
              background: 'linear-gradient(135deg, #FFD700, #FF6B35)',
              WebkitBoxShadow: '0 4px 16px rgba(255,107,53,0.3)',
            }}
          >
            <div 
              className="w-full h-full rounded-full flex items-center justify-center text-2xl overflow-hidden"
              style={{ background: 'linear-gradient(135deg, #FCE4EC, #FFF3E0)' }}
            >
              👦
            </div>
          </div>
          {/* Crown */}
          <div 
            className="absolute -top-2 -right-1 text-base animate-badge-bounce"
            style={{ WebkitAnimation: 'badgeBounce 2s ease-in-out infinite' }}
          >👑</div>
        </motion.div>

        {/* Name & Level */}
        <div className="min-w-0 flex-1">
          <h2 className="text-white font-bold text-base leading-tight truncate">{name}</h2>
          <p className="text-purple-200 text-xs">{age} سنوات</p>
          {/* Level Progress Bar */}
          <div className="mt-1.5 flex items-center gap-2">
            <span className="text-yellow-300 text-[10px] font-bold">Lv.{level}</span>
            <div 
              className="flex-1 h-2 rounded-full overflow-hidden relative"
              style={{ background: 'rgba(0,0,0,0.3)' }}
            >
              <div
                className="h-full rounded-full"
                style={{
                  width: `${levelProgress}%`,
                  background: 'linear-gradient(90deg, #FFD700, #FF8C00)',
                  transition: 'width 1s ease-out',
                  WebkitTransition: 'width 1s ease-out',
                }}
              />
            </div>
          </div>
        </div>

        {/* Coins */}
        <div
          className="shrink-0 flex flex-col items-center gap-0.5"
          style={{ WebkitTapHighlightColor: 'transparent' }}
        >
          <div 
            className="flex items-center gap-1 px-2.5 py-1 rounded-full"
            style={{
              background: 'linear-gradient(135deg, #FFD700, #FF8C00)',
              WebkitBoxShadow: '0 2px 8px rgba(255,215,0,0.3)',
            }}
          >
            <span className="text-sm">💎</span>
            <span className="text-white font-bold text-xs">{gems}</span>
          </div>
          <span className="text-purple-200 text-[10px]">{xp} XP</span>
        </div>
      </div>
    </div>
  );
};

export default ManaraHeader;
