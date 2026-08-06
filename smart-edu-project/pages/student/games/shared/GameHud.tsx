import React from 'react';

type HudMetric = {
  label: string;
  value: string | number;
};

interface GameHudProps {
  title: string;
  subtitle?: string;
  metrics: HudMetric[];
  accentClassName?: string;
}

const GameHud: React.FC<GameHudProps> = ({ title, subtitle, metrics, accentClassName = 'border-sky-200 bg-sky-50 text-sky-700' }) => {
  return (
    <div className={`rounded-2xl border p-4 font-bold ${accentClassName}`}>
      <div className="flex flex-wrap items-center justify-between gap-2">
        <h3 className="text-base font-black md:text-lg">{title}</h3>
        {subtitle && <span className="text-xs md:text-sm">{subtitle}</span>}
      </div>
      <div className="mt-3 grid grid-cols-2 gap-2 md:grid-cols-4">
        {metrics.map((metric) => (
          <div key={metric.label} className="rounded-xl bg-white/70 px-3 py-2 text-xs md:text-sm">
            <span className="opacity-80">{metric.label}: </span>
            <span className="font-black">{metric.value}</span>
          </div>
        ))}
      </div>
    </div>
  );
};

export default GameHud;
