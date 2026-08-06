import React, { useEffect, useState } from 'react';
import Immersive3DScene from '../Immersive3DScene';

const Interactive3DBackground: React.FC = () => {
  const [webglAvailable, setWebglAvailable] = useState(false);

  useEffect(() => {
    const canvas = document.createElement('canvas');
    const ctx =
      canvas.getContext('webgl', { failIfMajorPerformanceCaveat: true }) ||
      canvas.getContext('experimental-webgl', { failIfMajorPerformanceCaveat: true });
    setWebglAvailable(Boolean(ctx));
  }, []);

  return (
    <div className="pointer-events-none absolute inset-0 overflow-hidden">
      {/* base gradient */}
      <div className="absolute inset-0 bg-[linear-gradient(145deg,_#04041e_0%,_#100d3a_42%,_#071d36_70%,_#030516_100%)]" />

      {/* WebGL scene or rich CSS fallback */}
      {webglAvailable ? (
        <Immersive3DScene accent="#6366f1" intensity={1.15} />
      ) : (
        <>
          {/* floating icons with deep glow */}
          <span className="absolute left-[7%] top-[17%] -rotate-12 text-5xl opacity-55"
            style={{ animation: 'bgFloat 5s ease-in-out infinite', filter: 'drop-shadow(0 0 20px rgba(129,140,248,0.9))' }}>📚</span>
          <span className="absolute right-[8%] top-[19%] rotate-[30deg] text-5xl opacity-50"
            style={{ animation: 'bgFloat 5.5s ease-in-out infinite 0.6s', filter: 'drop-shadow(0 0 20px rgba(250,204,21,0.9))' }}>✏️</span>
          <span className="absolute bottom-[14%] right-[11%] text-5xl opacity-50"
            style={{ animation: 'bgFloat 6s ease-in-out infinite 1.1s', filter: 'drop-shadow(0 0 20px rgba(56,189,248,0.9))' }}>🌍</span>
          <span className="absolute bottom-[13%] left-[9%] rotate-12 text-5xl opacity-50"
            style={{ animation: 'bgFloat 5.8s ease-in-out infinite 1.6s', filter: 'drop-shadow(0 0 20px rgba(45,212,191,0.9))' }}>🔬</span>
          <span className="absolute left-[42%] top-[8%] text-4xl opacity-35"
            style={{ animation: 'bgFloat 6.5s ease-in-out infinite 2s', filter: 'drop-shadow(0 0 16px rgba(244,114,182,0.8))' }}>⭐</span>
          <span className="absolute right-[35%] bottom-[8%] text-4xl opacity-30"
            style={{ animation: 'bgFloat 5.2s ease-in-out infinite 0.4s', filter: 'drop-shadow(0 0 16px rgba(129,140,248,0.8))' }}>🎵</span>
        </>
      )}

      {/* animated nebula blobs */}
      <div className="absolute -left-20 top-10 h-80 w-80 animate-pulse rounded-full bg-indigo-600/22 blur-[80px]" />
      <div className="absolute -right-24 bottom-0 h-96 w-96 animate-pulse rounded-full bg-fuchsia-600/16 blur-[80px]"
        style={{ animationDelay: '0.9s' }} />
      <div className="absolute left-[38%] top-[30%] h-48 w-48 animate-pulse rounded-full bg-cyan-500/10 blur-[60px]"
        style={{ animationDelay: '1.8s' }} />

      {/* top-centre spotlight */}
      <div className="absolute inset-x-0 top-0 h-72 bg-[radial-gradient(ellipse_60%_55%_at_50%_0%,_rgba(99,102,241,0.22),_transparent)]" />
      {/* bottom-right warm glow */}
      <div className="absolute bottom-0 right-0 h-60 w-60 bg-[radial-gradient(circle_at_100%_100%,_rgba(244,114,182,0.14),_transparent_70%)]" />

      {/* fine grid */}
      <div
        className="absolute inset-0 opacity-[0.065]"
        style={{
          backgroundImage:
            'linear-gradient(rgba(148,163,184,0.6) 1px, transparent 1px), linear-gradient(90deg, rgba(148,163,184,0.6) 1px, transparent 1px)',
          backgroundSize: '52px 52px',
        }}
      />

      {/* horizontal aurora bands */}
      <div className="absolute inset-x-0 top-[25%] h-px bg-[linear-gradient(90deg,transparent,rgba(99,102,241,0.25),transparent)]" />
      <div className="absolute inset-x-0 top-[55%] h-px bg-[linear-gradient(90deg,transparent,rgba(244,114,182,0.18),transparent)]" />

      <style>{`
        @keyframes bgFloat {
          0%, 100% { transform: translateY(0px) rotate(var(--rot, 0deg)); }
          50%       { transform: translateY(-18px) rotate(calc(var(--rot, 0deg) + 5deg)); }
        }
      `}</style>
    </div>
  );
};

export default Interactive3DBackground;
