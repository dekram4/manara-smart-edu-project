import React from 'react';
import { motion } from 'framer-motion';
import { GameAudioEngine } from '../../../utils/gameAudioEngine';
import { getStudentAppearance } from '../../../utils/studentAppearance';
import { StudentInfo, StudentAppearance } from '../../../types';
import CardErrorBoundary from '../../../src/components/CardErrorBoundary';

interface StudentAvatarProps {
  student?: Pick<StudentInfo, 'gender' | 'appearance'> | null;
  appearance?: StudentAppearance;
  size?: 'sm' | 'md' | 'lg' | 'xl';
  className?: string;
  interactive?: boolean;
}

const sizeMap = {
  sm: { shell: 'h-14 w-14', face: 'text-xl', outfit: 'text-sm', head: 'h-5 w-5', body: 'h-6 w-8', leg: 'h-3 w-1.5' },
  md: { shell: 'h-24 w-24', face: 'text-3xl', outfit: 'text-lg', head: 'h-9 w-9', body: 'h-10 w-14', leg: 'h-5 w-2.5' },
  lg: { shell: 'h-32 w-32', face: 'text-5xl', outfit: 'text-2xl', head: 'h-12 w-12', body: 'h-14 w-20', leg: 'h-7 w-3.5' },
  xl: { shell: 'h-40 w-40', face: 'text-6xl', outfit: 'text-3xl', head: 'h-16 w-16', body: 'h-20 w-28', leg: 'h-10 w-5' },
} as const;

const StudentAvatar: React.FC<StudentAvatarProps> = ({
  student,
  appearance: providedAppearance,
  size = 'md',
  className = '',
  interactive = true,
}) => {
  const appearance = providedAppearance || getStudentAppearance(student);
  const dimensions = sizeMap[size];
  const top = appearance.top || appearance.outfit || '👕';
  const bottom = appearance.bottom || '👖';
  const shoes = appearance.shoes || '👟';
  const hair = appearance.hair || '🦱';
  const skinTone = appearance.skinTone || '#edb891';
  const accessory = appearance.accessory || '✨';

  return (
    <CardErrorBoundary label="الصورة الشخصية">
      <motion.div
        className={`relative inline-flex items-center justify-center overflow-hidden rounded-[34%] ${dimensions.shell} ${className}`}
        whileHover={interactive ? { y: -5, scale: 1.06, rotate: 2 } : undefined}
        whileTap={interactive ? { scale: 0.95 } : undefined}
        onPointerEnter={interactive ? () => GameAudioEngine.play('uiHover') : undefined}
        style={{ perspective: '700px' }}
        aria-label="شخصية الطالب"
      >
      <div
        className="absolute inset-0 overflow-hidden rounded-[32%] border-2 border-white/50 shadow-[0_16px_30px_rgba(0,0,0,0.3),inset_5px_5px_12px_rgba(255,255,255,0.28)]"
        style={{
          background: `radial-gradient(circle at 28% 18%, rgba(255,255,255,0.6), transparent 25%), linear-gradient(145deg, ${appearance.color}dd, ${appearance.color}55)`,
          boxShadow: `0 0 26px ${appearance.color}70, 0 16px 30px rgba(0,0,0,0.3), inset 5px 5px 12px rgba(255,255,255,0.22)`,
        }}
      />
      <div className={`absolute bottom-[25%] left-1/2 z-10 -translate-x-1/2 rounded-[42%_42%_22%_22%] border-2 border-white/35 shadow-[0_8px_10px_rgba(0,0,0,0.24)] ${dimensions.body}`} style={{
        background: `linear-gradient(160deg, ${appearance.color}f5, ${appearance.color}88)`,
      }}>
        <span className={`absolute inset-0 flex items-center justify-center select-none leading-none drop-shadow-[0_4px_3px_rgba(0,0,0,0.38)] ${dimensions.outfit}`}>
          {top}
        </span>
        <span className="pointer-events-none absolute inset-x-[16%] bottom-[10%] h-1 rounded-full bg-white/30" />
      </div>
      <div className={`absolute bottom-[13%] left-1/2 z-10 flex -translate-x-1/2 items-center justify-center rounded-[20%_20%_28%_28%] border border-white/30 bg-slate-950/25 ${dimensions.body}`}>
        <span className="select-none text-xl leading-none drop-shadow-md sm:text-2xl">{bottom}</span>
      </div>
      <div className={`absolute bottom-[4%] left-[32%] z-20 flex items-end justify-center rounded-b-full bg-slate-950/55 ${dimensions.leg}`}>
        <span className="absolute -bottom-1 select-none text-[10px] leading-none">{shoes}</span>
      </div>
      <div className={`absolute bottom-[4%] right-[32%] z-20 flex items-end justify-center rounded-b-full bg-slate-950/55 ${dimensions.leg}`}>
        <span className="absolute -bottom-1 select-none text-[10px] leading-none">{shoes}</span>
      </div>
      <div className="absolute bottom-[29%] left-[25%] z-20 h-[18%] w-[6%] rotate-[18deg] rounded-full" style={{ background: skinTone }} />
      <div className="absolute bottom-[29%] right-[25%] z-20 h-[18%] w-[6%] -rotate-[18deg] rounded-full" style={{ background: skinTone }} />
      <div className={`absolute left-1/2 top-[7%] z-30 flex -translate-x-1/2 items-center justify-center overflow-hidden rounded-full border-2 border-white/65 shadow-[0_7px_12px_rgba(0,0,0,0.25)] ${dimensions.head}`} style={{ background: skinTone }}>
        <span className={`select-none leading-none drop-shadow-[0_5px_3px_rgba(0,0,0,0.35)] ${dimensions.face}`}>
          {appearance.shape}
        </span>
        <span className="pointer-events-none absolute -top-[12%] select-none text-xl leading-none drop-shadow-md sm:text-2xl">{hair}</span>
      </div>
      <span className="absolute right-[17%] top-[40%] z-40 select-none text-lg leading-none drop-shadow-md sm:text-2xl">{accessory}</span>
      <span
        className="absolute bottom-[12%] left-[12%] z-40 h-2 w-2 rounded-full bg-white/80"
        style={{ boxShadow: `0 0 12px ${appearance.color}` }}
      />
      </motion.div>
    </CardErrorBoundary>
  );
};

export default StudentAvatar;