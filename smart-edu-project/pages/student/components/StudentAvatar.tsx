import React from 'react';
import { motion } from 'framer-motion';
import { GameAudioEngine } from '../../../utils/gameAudioEngine';
import { getStudentAppearance } from '../../../utils/studentAppearance';
import { StudentInfo, StudentAppearance } from '../../../types';

interface StudentAvatarProps {
  student?: Pick<StudentInfo, 'gender' | 'appearance'> | null;
  appearance?: StudentAppearance;
  size?: 'sm' | 'md' | 'lg' | 'xl';
  className?: string;
  interactive?: boolean;
}

const sizeMap = {
  sm: { shell: 'h-14 w-14', face: 'text-3xl', outfit: 'text-lg' },
  md: { shell: 'h-24 w-24', face: 'text-5xl', outfit: 'text-2xl' },
  lg: { shell: 'h-32 w-32', face: 'text-7xl', outfit: 'text-3xl' },
  xl: { shell: 'h-40 w-40', face: 'text-8xl', outfit: 'text-4xl' },
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
    <motion.div
      className={`relative inline-flex items-center justify-center ${dimensions.shell} ${className}`}
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
      <span className={`relative z-10 select-none leading-none drop-shadow-[0_6px_4px_rgba(0,0,0,0.35)] ${dimensions.face}`}>
        {appearance.shape}
      </span>
      <span className={`absolute bottom-[8%] right-[9%] z-20 select-none leading-none drop-shadow-[0_4px_3px_rgba(0,0,0,0.35)] ${dimensions.outfit}`}>
        {appearance.outfit}
      </span>
      <span
        className="absolute bottom-[10%] left-[12%] z-20 h-2 w-2 rounded-full bg-white/80"
        style={{ boxShadow: `0 0 12px ${appearance.color}` }}
      />
    </motion.div>
  );
};

export default StudentAvatar;