import React, { useEffect } from 'react';
import { motion } from 'framer-motion';
import ManaraHeader from './components/ManaraHeader';
import ManaraNav, { NavTab } from './components/ManaraNav';
import ManaraCard from './components/ManaraCard';
import { GameAudioEngine } from '../../utils/gameAudioEngine';
import Immersive3DScene from '../../src/components/Immersive3DScene';
import PremiumBackground from '../../src/components/PremiumBackground';

interface ManaraHomeProps {
  name: string;
  age: number;
  xp: number;
  gems: number;
  level: number;
  levelProgress: number;
  activeTab: NavTab;
  onTabChange: (tab: NavTab) => void;
  onNavigate: (screen: string) => void;
}

const sections = [
  { emoji: '🎭', title: 'انشطاطي', subtitle: 'تعلم باللعب', color: '#E91E63', bgColor: 'linear-gradient(135deg, #FCE4EC, #F8BBD0)', screen: 'entertainment', isNew: true },
  { emoji: '📚', title: 'صلصال', subtitle: 'دروسي اليوم', color: '#00BCD4', bgColor: 'linear-gradient(135deg, #E0F7FA, #B2EBF2)', screen: 'lessons' },
  { emoji: '🎯', title: 'مساراتي', subtitle: 'اختبر معارفتك', color: '#4CAF50', bgColor: 'linear-gradient(135deg, #E8F5E9, #C8E6C9)', screen: 'quiz', isNew: true },
  { emoji: '✍️', title: 'مهامي', subtitle: 'امتحان وتحدي', color: '#FF9800', bgColor: 'linear-gradient(135deg, #FFF3E0, #FFE0B2)', screen: 'homework' },
  { emoji: '🧪', title: 'الأنشطة', subtitle: 'تجارب واكتشافات', color: '#9C27B0', bgColor: 'linear-gradient(135deg, #F3E5F5, #E1BEE7)', screen: 'activities', isNew: true },
  { emoji: '🔢', title: 'عبقري', subtitle: 'احل وتعلم', color: '#2196F3', bgColor: 'linear-gradient(135deg, #E3F2FD, #BBDEFB)', screen: 'math' },
  { emoji: '🎥', title: 'فيديوهاتي', subtitle: 'تعلم بالمشاهدة', color: '#F44336', bgColor: 'linear-gradient(135deg, #FFEBEE, #FFCDD2)', screen: 'videos' },
  { emoji: '💬', title: 'دردشة', subtitle: 'تواصل مع أصدقائك', color: '#795548', bgColor: 'linear-gradient(135deg, #EFEBE9, #D7CCC8)', screen: 'chat' },
];

const achievementsPreview = [
  { emoji: '🏆', label: 'بطل' },
  { emoji: '⭐', label: 'نجم' },
  { emoji: '📚', label: 'قارئ' },
  { emoji: '🎮', label: 'لاعب' },
];

const ManaraHome: React.FC<ManaraHomeProps> = ({
  name, age, xp, gems, level, levelProgress, activeTab, onTabChange, onNavigate,
}) => {
  useEffect(() => {
    GameAudioEngine.play('portalTransition');
  }, []);

  return (
    <div className="manara-mobile-container relative overflow-hidden">
      <PremiumBackground accent="#8b5cf6" />
      <ManaraHeader name={name} age={age} xp={xp} gems={gems} level={level} levelProgress={levelProgress} />

      <div className="relative mx-3 mb-3 overflow-hidden rounded-[28px] border border-white/20 bg-gradient-to-br from-slate-900/80 to-slate-700/70 p-0 shadow-[0_20px_55px_rgba(0,0,0,0.28)]">
        <Immersive3DScene accent="#8b5cf6" intensity={0.9} />
        <motion.div 
          initial={{ opacity: 0, y: 12 }}
          animate={{ opacity: 1, y: 0 }}
          className="relative z-10 flex items-center gap-2 p-3"
        >
          <div 
            className="text-2xl"
            style={{ WebkitAnimation: 'badgeBounce 2s ease-in-out infinite' }}
          >🔥</div>
          <div className="flex-1">
            <p className="text-white font-bold text-sm">استمر بتعلمك يومياً!</p>
            <p className="text-yellow-100 text-xs">اجمع نقاط التواصل للحصول على مكافآت 🎁</p>
          </div>
          <button
            className="text-white px-3 py-1.5 rounded-full text-xs font-bold"
            style={{ background: 'rgba(255,255,255,0.2)', WebkitTapHighlightColor: 'transparent' }}
            onClick={() => {
              GameAudioEngine.play('portalTransition');
              onNavigate('lessons');
            }}
          >
            ابدأ ←
          </button>
        </motion.div>
      </div>

      {/* Streak Banner */}
      <motion.div 
        initial={{ opacity: 0, y: 12 }}
        animate={{ opacity: 1, y: 0 }}
        className="mx-3 mb-3 rounded-2xl p-3 flex items-center gap-2"
        style={{
          background: 'linear-gradient(135deg, #FF8C00, #FFD700)',
          WebkitBoxShadow: '0 4px 16px rgba(255,140,0,0.3)',
        }}
      >
        <div 
          className="text-2xl"
          style={{ WebkitAnimation: 'badgeBounce 2s ease-in-out infinite' }}
        >🔥</div>
        <div className="flex-1">
          <p className="text-white font-bold text-sm">استمر بتعلمك يومياً!</p>
          <p className="text-yellow-100 text-xs">اجمع نقاط التواصل للحصول على مكافآت 🎁</p>
        </div>
        <button
          className="text-white px-3 py-1.5 rounded-full text-xs font-bold"
          style={{ background: 'rgba(255,255,255,0.2)', WebkitTapHighlightColor: 'transparent' }}
          onClick={() => {
              GameAudioEngine.play('portalTransition');
            onNavigate('lessons');
          }}
        >
          ابدأ ←
        </button>
      </div>

      {/* Quick Achievements */}
      <div className="px-3 mb-3">
        <div className="flex items-center justify-between gap-1.5 overflow-x-auto pb-1" style={{ WebkitOverflowScrolling: 'touch' }}>
          {achievementsPreview.map((ach, i) => (
            <div
              key={i}
              className="flex-shrink-0 flex flex-col items-center gap-0.5 rounded-xl px-2.5 py-1.5"
              style={{
                background: 'rgba(255,255,255,0.1)',
                border: '1px solid rgba(255,255,255,0.1)',
              }}
            >
              <span className="text-xl">{ach.emoji}</span>
              <span className="text-purple-200 text-[9px] font-bold whitespace-nowrap">{ach.label}</span>
            </div>
          ))}
        </div>
      </div>

      {/* Section Title */}
      <div className="px-3 mb-2 flex items-center gap-2">
        <span className="text-xl">🌟</span>
        <h3 className="text-white font-bold text-base">اختر مغامرتك</h3>
      </div>

      {/* Cards Grid */}
      <div className="px-3 pb-3 grid grid-cols-2 gap-2.5 flex-1">
        {sections.map((section, i) => (
          <ManaraCard
            key={section.screen}
            emoji={section.emoji}
            title={section.title}
            subtitle={section.subtitle}
            color={section.color}
            bgColor={section.bgColor}
            delay={0.05 * i}
            isNew={section.isNew}
            onClick={() => {
              const sectionType = section.screen === 'videos' ? 'videos' : section.screen === 'entertainment' ? 'games' : section.screen === 'quiz' ? 'quiz' : section.screen === 'homework' ? 'homework' : 'portal';
              GameAudioEngine.play('portalTransition');
              onNavigate(section.screen);
            }}
          />
        ))}
      </div>

      <div className="h-2" />
      <ManaraNav activeTab={activeTab} onTabChange={onTabChange} />
    </div>
  );
};

export default ManaraHome;
