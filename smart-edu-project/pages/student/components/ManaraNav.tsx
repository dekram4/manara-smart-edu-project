import React from 'react';
import { motion } from 'framer-motion';
import EducationalCardEffects from '../../../src/components/effects/EducationalCardEffects';
import { GameAudioEngine } from '../../../utils/gameAudioEngine';

export type NavTab = 'home' | 'games' | 'lessons' | 'profile';

interface ManaraNavProps {
  activeTab: NavTab;
  onTabChange: (tab: NavTab) => void;
}

const tabs: { id: NavTab; label: string; emoji: string }[] = [
  { id: 'home', label: 'الرئيسية', emoji: '🏠' },
  { id: 'lessons', label: 'دروسي', emoji: '📚' },
  { id: 'games', label: 'ألعاب', emoji: '🎮' },
  { id: 'profile', label: 'أنا', emoji: '👤' },
];

const ManaraNav: React.FC<ManaraNavProps> = ({ activeTab, onTabChange }) => {
  return (
    <div 
      className="sticky bottom-0 z-50 px-3 py-2"
      style={{
        background: 'linear-gradient(to top, rgba(74,20,140,0.95), rgba(74,20,140,0.8), transparent)',
        WebkitBackdropFilter: 'blur(12px)',
        backdropFilter: 'blur(12px)',
      }}
    >
      <div 
        className="relative flex items-center justify-around rounded-full px-2 py-1.5"
        style={{
          background: 'rgba(106,27,154,0.5)',
          border: '1px solid rgba(255,255,255,0.1)',
        }}
      >
        <EducationalCardEffects accent="#c084fc" compact />
        {tabs.map((tab) => {
          const isActive = activeTab === tab.id;
          return (
            <button
              key={tab.id}
              onClick={() => {
                GameAudioEngine.play('portalTransition');
                onTabChange(tab.id);
              }}
              className="relative flex flex-col items-center gap-0.5 px-2.5 py-1.5 rounded-full transition-all duration-200"
              style={{
                WebkitTapHighlightColor: 'transparent',
                background: isActive ? 'linear-gradient(135deg, #FFD700, #FF8C00)' : 'transparent',
                WebkitBoxShadow: isActive ? '0 2px 8px rgba(255,140,0,0.4)' : 'none',
                boxShadow: isActive ? '0 2px 8px rgba(255,140,0,0.4)' : 'none',
              }}
            >
              <span className="text-xl">{tab.emoji}</span>
              <span className={`text-[9px] font-bold ${isActive ? 'text-white' : 'text-purple-300'}`}>
                {tab.label}
              </span>
            </button>
          );
        })}
      </div>
    </div>
  );
};

export default ManaraNav;
