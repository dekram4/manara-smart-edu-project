import React from 'react';

interface ManaraBrandProps {
  variant?: 'hero' | 'login' | 'sidebar' | 'compact';
  className?: string;
}

const variantStyles = {
  hero: {
    image: 'h-28 w-28 md:h-36 md:w-36',
    title: 'text-3xl md:text-5xl',
    subtitle: 'text-sm md:text-base',
  },
  login: {
    image: 'h-24 w-24',
    title: 'text-2xl md:text-3xl',
    subtitle: 'text-xs',
  },
  sidebar: {
    image: 'h-14 w-14',
    title: 'text-lg',
    subtitle: 'text-[10px]',
  },
  compact: {
    image: 'h-12 w-12',
    title: 'text-base',
    subtitle: 'text-[9px]',
  },
} as const;

const ManaraBrand: React.FC<ManaraBrandProps> = ({ variant = 'compact', className = '' }) => {
  const styles = variantStyles[variant];

  return (
    <div
      className={`flex items-center gap-3 ${variant === 'hero' || variant === 'login' ? 'flex-col text-center' : 'text-right'} ${className}`}
      dir="rtl"
    >
      <div className="relative shrink-0">
        <div className="absolute inset-0 rounded-full bg-cyan-300/20 blur-xl" />
        <img
          src="/manara-logo-mark-transparent.png"
          alt="شعار منصة منارة المعرفة التعليمية"
          className={`relative object-contain drop-shadow-[0_8px_14px_rgba(15,23,42,0.25)] ${styles.image}`}
        />
      </div>
      <div>
        <h1 className={`font-black leading-tight text-current ${styles.title}`}>
          منصة منارة المعرفة التعليمية
        </h1>
        <p className={`mt-1 font-bold opacity-70 ${styles.subtitle}`}>
          تعليم ذكي، معرفة، ومستقبل مشرق
        </p>
      </div>
    </div>
  );
};

export default ManaraBrand;