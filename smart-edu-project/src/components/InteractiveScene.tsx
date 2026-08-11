import React, { useCallback } from 'react';
import { motion } from 'framer-motion';
import Particles from 'react-tsparticles';
import type { Container, Engine } from 'tsparticles-engine';
import { loadSlim } from 'tsparticles-slim';

interface InteractiveSceneProps {
  children: React.ReactNode;
  className?: string;
  intensity?: number;
  accent?: string;
}

export const InteractiveScene: React.FC<InteractiveSceneProps> = ({
  children,
  className = '',
  intensity = 1,
  accent,
}) => {
  void intensity;

  const particlesInit = useCallback(async (engine: Engine) => {
    await loadSlim(engine);
  }, []);

  const particlesLoaded = useCallback(async (_container?: Container) => {
    // Subtle ambient particles only.
  }, []);

  return (
    <div
      className={`relative overflow-hidden rounded-[40px] border border-white/15 bg-gradient-to-br from-slate-900/90 via-slate-800/80 to-slate-900/90 shadow-[0_25px_80px_rgba(0,0,0,0.35)] ${className}`}
    >
      <div className="pointer-events-none absolute inset-0 bg-[radial-gradient(circle_at_top_left,_rgba(56,189,248,0.16),_transparent_30%),radial-gradient(circle_at_bottom_right,_rgba(236,72,153,0.16),_transparent_35%)]" />
      <Particles
        id={`interactive-scene-${accent ?? 'default'}`}
        className="pointer-events-none absolute inset-0 z-0"
        init={particlesInit}
        loaded={particlesLoaded}
        options={{
          fullScreen: false,
          fpsLimit: 60,
          particles: {
            number: { value: 10, density: { enable: true, area: 800 } },
            color: { value: ['#38bdf8', '#f472b6', '#fb923c'] },
            shape: { type: 'circle' },
            opacity: { value: 0.18 },
            size: { value: 2.2, random: true },
            move: { enable: true, speed: 0.4, direction: 'top', outModes: { default: 'out' } },
          },
          detectRetina: true,
        }}
      />

      <div className="pointer-events-none absolute inset-0" />

      <motion.div
        animate={{
          scale: 1,
          y: 0,
        }}
        transition={{ duration: 0.2 }}
        className="relative z-10"
      >
        {children}
      </motion.div>
    </div>
  );
};
