import React from 'react';

interface EducationalCardEffectsProps {
  accent?: string;
  compact?: boolean;
}

const EducationalCardEffects: React.FC<EducationalCardEffectsProps> = ({
  accent = '#38bdf8',
  compact = false,
}) => {
  return (
    <div
      aria-hidden="true"
      className={`pointer-events-none absolute inset-0 overflow-hidden rounded-[inherit] ${
        compact ? 'opacity-70' : 'opacity-90'
      }`}
    >
      <div
        className="absolute -right-8 -top-10 h-28 w-28 rounded-full blur-2xl"
        style={{ background: `${accent}35` }}
      />
      <div
        className="absolute -bottom-12 -left-8 h-32 w-32 rounded-full blur-2xl"
        style={{ background: `${accent}24` }}
      />
      <div
        className="absolute right-4 top-4 h-1.5 w-1.5 animate-ping rounded-full bg-white/80"
        style={{ animationDuration: '2.8s' }}
      />
      <div
        className="absolute bottom-5 left-6 h-1 w-1 animate-pulse rounded-full bg-cyan-200"
        style={{ animationDelay: '700ms' }}
      />
      <div className="absolute left-1/2 top-1/2 h-px w-24 -translate-x-1/2 rotate-[-18deg] bg-gradient-to-r from-transparent via-white/25 to-transparent" />
      {!compact && (
        <>
          <span className="absolute left-4 top-3 text-sm opacity-50 animate-float">✦</span>
          <span className="absolute bottom-3 right-5 text-xs opacity-40 animate-float [animation-delay:900ms]">✎</span>
        </>
      )}
    </div>
  );
};

export default EducationalCardEffects;