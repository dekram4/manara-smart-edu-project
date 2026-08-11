import React from 'react';
import { GameAudioEngine } from '../../../utils/gameAudioEngine';
import Interactive3DEmoji from '../../../src/components/effects/Interactive3DEmoji';

interface GameButtonProps {
  icon: string;       // إيموجي أو مسار أيقونة كبيرة
  title: string;      // نص الزر
  color?: string;     // لون البطاقة
  onClick: () => void;
}

export const GameButton: React.FC<GameButtonProps> = ({ icon, title, color = 'bg-indigo-500', onClick }) => {
  return (
    <button
      onMouseEnter={() => GameAudioEngine.play('uiHover')}
      onClick={() => {
        GameAudioEngine.play('portalTransition');
        onClick();
      }}
      className={`${color} text-white font-bold p-6 rounded-3xl shadow-2xl flex flex-col items-center justify-center border-b-8 border-black/20 cursor-pointer select-none`}
    >
      <Interactive3DEmoji emoji={icon} accent="#ffffff" size="lg" className="mb-3" />
      <span className="text-xl tracking-wide">{title}</span>
    </button>
  );
};