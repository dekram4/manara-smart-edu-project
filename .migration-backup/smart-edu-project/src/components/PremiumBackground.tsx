import React from 'react';
import { motion } from 'framer-motion';

interface PremiumBackgroundProps {
  accent?: string;
  className?: string;
}

const PremiumBackground: React.FC<PremiumBackgroundProps> = ({ accent = '#38bdf8', className = '' }) => {
  return (
    <div className={`pointer-events-none absolute inset-0 overflow-hidden ${className}`}>
      <motion.div
        className="absolute inset-0"
        animate={{ backgroundPosition: ['0% 0%', '100% 100%'] }}
        transition={{ duration: 18, repeat: Infinity, ease: 'linear' }}
        style={{
          backgroundImage: `radial-gradient(circle at 20% 20%, rgba(255,255,255,0.16), transparent 24%), radial-gradient(circle at 80% 0%, ${accent}33, transparent 25%), radial-gradient(circle at 20% 80%, rgba(255,255,255,0.14), transparent 24%), linear-gradient(135deg, rgba(255,255,255,0.08), transparent 70%)`,
          backgroundSize: '180% 180%',
        }}
      />
      <motion.div
        className="absolute inset-0"
        animate={{ rotate: [0, 360] }}
        transition={{ duration: 32, repeat: Infinity, ease: 'linear' }}
        style={{
          background: `conic-gradient(from 0deg, transparent 0deg, ${accent}22 90deg, transparent 180deg, rgba(255,255,255,0.1) 270deg, transparent 360deg)`,
          opacity: 0.5,
          filter: 'blur(48px)',
        }}
      />
      <div className="absolute inset-0 bg-[radial-gradient(circle_at_top_left,_rgba(255,255,255,0.16),_transparent_35%),radial-gradient(circle_at_bottom_right,_rgba(255,255,255,0.12),_transparent_30%)]" />
    </div>
  );
};

export default PremiumBackground;
