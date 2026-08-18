import React from 'react';
import { motion } from 'framer-motion';
import { GameAudioEngine } from '../../../utils/gameAudioEngine';
import { getStudentAppearance } from '../../../utils/studentAppearance';
import { StudentInfo, StudentAppearance } from '../../../types';
import CardErrorBoundary from '../../../src/components/CardErrorBoundary';
import EmojiIcon from '../../../src/components/EmojiIcon';

interface StudentAvatarProps {
  student?: Pick<StudentInfo, 'gender' | 'appearance'> | null;
  appearance?: StudentAppearance;
  size?: 'sm' | 'md' | 'lg' | 'xl';
  className?: string;
  interactive?: boolean;
}

const sizeMap = {
  sm: {
    shell: 'h-14 w-14',
    head: 'h-5 w-5',
    body: 'h-6 w-8',
    leg: 'h-3 w-1.5',
    faceSize: 20,
    outfitSize: 14,
    hairSize: 20,
    accessorySize: 18,
    bottomSize: 20,
    shoesSize: 10,
  },
  md: {
    shell: 'h-24 w-24',
    head: 'h-9 w-9',
    body: 'h-10 w-14',
    leg: 'h-5 w-2.5',
    faceSize: 30,
    outfitSize: 18,
    hairSize: 22,
    accessorySize: 20,
    bottomSize: 22,
    shoesSize: 14,
  },
  lg: {
    shell: 'h-32 w-32',
    head: 'h-12 w-12',
    body: 'h-14 w-20',
    leg: 'h-7 w-3.5',
    faceSize: 48,
    outfitSize: 24,
    hairSize: 28,
    accessorySize: 24,
    bottomSize: 28,
    shoesSize: 18,
  },
  xl: {
    shell: 'h-40 w-40',
    head: 'h-16 w-16',
    body: 'h-20 w-28',
    leg: 'h-10 w-5',
    faceSize: 60,
    outfitSize: 30,
    hairSize: 36,
    accessorySize: 28,
    bottomSize: 36,
    shoesSize: 22,
  },
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
  const hairColor = appearance.hairColor || '#3f2b24';
  const skinTone = appearance.skinTone || '#edb891';
  const accessory = appearance.accessory || '✨';

  if (appearance.readyPlayerMeAvatarImageUrl) {
    return (
      <CardErrorBoundary label="صورة الأفاتار">
        <motion.div
          className={`relative inline-flex items-center justify-center overflow-hidden rounded-[34%] ${dimensions.shell} ${className}`}
          whileHover={interactive ? { y: -5, scale: 1.06, rotate: 2 } : undefined}
          whileTap={interactive ? { scale: 0.95 } : undefined}
          onPointerEnter={interactive ? () => GameAudioEngine.play('uiHover') : undefined}
          aria-label="أفاتار الطالب من Ready Player Me"
        >
          <div className="absolute inset-0 rounded-[32%] border-2 border-white/60 bg-slate-950 shadow-[0_16px_30px_rgba(0,0,0,0.3)]" />
          <img
            src={appearance.readyPlayerMeAvatarImageUrl}
            alt="أفاتار الطالب"
            className="relative z-10 h-full w-full object-contain"
            loading="lazy"
          />
        </motion.div>
      </CardErrorBoundary>
    );
  }

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

        {/* Body */}
        <div
          className={`absolute bottom-[25%] left-1/2 z-10 -translate-x-1/2 rounded-[42%_42%_22%_22%] border-2 border-white/35 shadow-[0_8px_10px_rgba(0,0,0,0.24)] ${dimensions.body}`}
          style={{ background: `linear-gradient(160deg, ${appearance.color}f5, ${appearance.color}88)` }}
        >
          <span className="absolute inset-0 flex items-center justify-center select-none leading-none drop-shadow-[0_4px_3px_rgba(0,0,0,0.38)]">
            <EmojiIcon emoji={top} size={dimensions.outfitSize} aria-label="ملابس الطالب" />
          </span>
          <span className="pointer-events-none absolute inset-x-[16%] bottom-[10%] h-1 rounded-full bg-white/30" />
        </div>

        {/* Pants */}
        <div className={`absolute bottom-[13%] left-1/2 z-10 flex -translate-x-1/2 items-center justify-center rounded-[20%_20%_28%_28%] border border-white/30 bg-slate-950/25 ${dimensions.body}`}>
          <EmojiIcon emoji={bottom} size={dimensions.bottomSize} aria-label="بنطال الطالب" />
        </div>

        {/* Left shoe */}
        <div className={`absolute bottom-[4%] left-[32%] z-20 flex items-end justify-center rounded-b-full bg-slate-950/55 ${dimensions.leg}`}>
          <span className="absolute -bottom-1 select-none leading-none">
            <EmojiIcon emoji={shoes} size={dimensions.shoesSize} aria-label="حذاء الطالب" />
          </span>
        </div>

        {/* Right shoe */}
        <div className={`absolute bottom-[4%] right-[32%] z-20 flex items-end justify-center rounded-b-full bg-slate-950/55 ${dimensions.leg}`}>
          <span className="absolute -bottom-1 select-none leading-none">
            <EmojiIcon emoji={shoes} size={dimensions.shoesSize} />
          </span>
        </div>

        {/* Arms */}
        <div className="absolute bottom-[29%] left-[25%] z-20 h-[18%] w-[6%] rotate-[18deg] rounded-full" style={{ background: skinTone }} />
        <div className="absolute bottom-[29%] right-[25%] z-20 h-[18%] w-[6%] -rotate-[18deg] rounded-full" style={{ background: skinTone }} />

        {/* Head */}
        <div
          className={`absolute left-1/2 top-[7%] z-30 flex -translate-x-1/2 items-center justify-center overflow-hidden rounded-full border-2 border-white/65 shadow-[0_7px_12px_rgba(0,0,0,0.25)] ${dimensions.head}`}
          style={{ background: skinTone }}
        >
          {/* Hair band */}
          <span
            className="pointer-events-none absolute -top-[3%] h-[28%] w-[64%] rounded-t-full opacity-90"
            style={{ background: hairColor }}
          />
          {/* Face */}
          <EmojiIcon
            emoji={appearance.shape}
            size={dimensions.faceSize}
            aria-label="وجه الطالب"
          />
          {/* Hair emoji */}
          <span className="pointer-events-none absolute -top-[12%] select-none leading-none drop-shadow-md">
            <EmojiIcon emoji={hair} size={dimensions.hairSize} aria-label="شعر الطالب" />
          </span>
        </div>

        {/* Accessory */}
        <span className="absolute right-[17%] top-[40%] z-40 select-none leading-none drop-shadow-md">
          <EmojiIcon emoji={accessory} size={dimensions.accessorySize} aria-label="إكسسوار الطالب" />
        </span>

        {/* Glow dot */}
        <span
          className="absolute bottom-[12%] left-[12%] z-40 h-2 w-2 rounded-full bg-white/80"
          style={{ boxShadow: `0 0 12px ${appearance.color}` }}
        />
      </motion.div>
    </CardErrorBoundary>
  );
};

export default StudentAvatar;
