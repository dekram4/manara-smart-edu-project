import React, { useEffect, useState } from 'react';
import Immersive3DScene from '../Immersive3DScene';

const Interactive3DBackground: React.FC = () => {
  const [webglAvailable, setWebglAvailable] = useState(false);

  useEffect(() => {
    const canvas = document.createElement('canvas');
    const context =
      canvas.getContext('webgl', { failIfMajorPerformanceCaveat: true }) ||
      canvas.getContext('experimental-webgl', { failIfMajorPerformanceCaveat: true });
    setWebglAvailable(Boolean(context));
  }, []);

  return (
    <div className="pointer-events-none absolute inset-0 overflow-hidden bg-[linear-gradient(135deg,_#070b1f_0%,_#151039_48%,_#071d32_100%)]">
      {webglAvailable && <Immersive3DScene accent="#6366f1" intensity={1.15} />}
      <div className="absolute -left-16 top-16 h-72 w-72 animate-pulse rounded-full bg-indigo-500/20 blur-3xl" />
      <div className="absolute -right-20 bottom-0 h-80 w-80 animate-pulse rounded-full bg-fuchsia-500/15 blur-3xl [animation-delay:700ms]" />
      <div className="absolute left-1/3 top-1/3 h-40 w-40 animate-pulse rounded-full bg-cyan-400/10 blur-3xl [animation-delay:1.4s]" />
      <div className="absolute inset-0 bg-[radial-gradient(circle_at_50%_10%,_rgba(129,140,248,0.2),_transparent_34%),radial-gradient(circle_at_85%_85%,_rgba(236,72,153,0.14),_transparent_32%)]" />
      <div
        className="absolute inset-0 opacity-20"
        style={{
          backgroundImage:
            'linear-gradient(rgba(148,163,184,0.12) 1px, transparent 1px), linear-gradient(90deg, rgba(148,163,184,0.12) 1px, transparent 1px)',
          backgroundSize: '48px 48px',
        }}
      />
    </div>
  );
};

export default Interactive3DBackground;