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
  sm: { shell: 'h-14 w-14', face: 'text-2xl', outfit: 'text-base', body: 'h-5 w-7' },
  md: { shell: 'h-24 w-24', face: 'text-4xl', outfit: 'text-xl', body: 'h-9 w-12' },
  lg: { shell: 'h-32 w-32', face: 'text-6xl', outfit: 'text-2xl', body: 'h-12 w-16' },
  xl: { shell: 'h-40 w-40', face: 'text-7xl', outfit: 'text-3xl', body: 'h-16 w-24' },
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
      <div className={`absolute bottom-[7%] left-1/2 z-10 -translate-x-1/2 rounded-[42%_42%_24%_24%] border-2 border-white/35 shadow-[0_8px_10px_rgba(0,0,0,0.24)] ${dimensions.body}`} style={{
        background: `linear-gradient(160deg, ${appearance.color}f5, ${appearance.color}88)`,
      }}>
        <span className={`absolute inset-0 flex items-center justify-center select-none leading-none drop-shadow-[0_4px_3px_rgba(0,0,0,0.38)] ${dimensions.outfit}`}>
          {appearance.outfit}
        </span>
      </div>
      <span className={`relative z-20 mb-[22%] select-none leading-none drop-shadow-[0_6px_4px_rgba(0,0,0,0.35)] ${dimensions.face}`}>
        {appearance.shape}
      </span>
      <span className="pointer-events-none absolute bottom-[4%] left-1/2 z-20 h-1 w-[44%] -translate-x-1/2 rounded-full bg-white/45" />
      <span
        className="absolute bottom-[12%] left-[12%] z-30 h-2 w-2 rounded-full bg-white/80"
        style={{ boxShadow: `0 0 12px ${appearance.color}` }}
      />
      </motion.div>
    </CardErrorBoundary>
  );
};

export default StudentAvatar;