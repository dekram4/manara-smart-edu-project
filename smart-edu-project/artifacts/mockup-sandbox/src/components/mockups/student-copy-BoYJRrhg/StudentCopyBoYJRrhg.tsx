import { useState, useEffect, useRef } from 'react';
import './_group.css';

function FloatingEmoji({ emoji, delay, x, y, size = 'text-4xl' }: { emoji: string; delay: number; x: number; y: number; size?: string }) {
  return (
    <div className={`lamsa-float absolute ${size} select-none pointer-events-none opacity-40`} style={{ left: `${x}%`, top: `${y}%`, animationDelay: `${delay}s` }}>
      {emoji}
    </div>
  );
}

function ProgressBar({ label, value, color }: { label: string; value: number; color: string }) {
  return (
    <div className="mb-4">
      <div className="flex justify-between mb-1">
        <span className="font-bold text-gray-700">{label}</span>
        <span className="font-black" style={{ color }}>{value}%</span>
      </div>
      <div className="w-full h-5 bg-gray-100 rounded-full overflow-hidden border-2 border-gray-200">
        <div
          className="h-full rounded-full transition-all duration-1000 ease-out lamsa-bounce"
          style={{ width: `${value}%`, backgroundColor: color }}
        />
      </div>
    </div>
  );
}

function GameCard({ icon, title, color, onClick }: { icon: string; title: string; color: string; onClick: () => void }) {
  const [hovered, setHovered] = useState(false);
  return (
    <button
      onClick={onClick}
      onMouseEnter={() => setHovered(true)}
      onMouseLeave={() => setHovered(false)}
      className="relative overflow-hidden rounded-3xl p-6 text-white text-center transition-all duration-300 hover:scale-105 active:scale-95 shadow-lg"
      style={{
        background: `linear-gradient(135deg, ${color}, ${color}dd)`,
        boxShadow: hovered ? `0 10px 30px ${color}66` : '0 4px 15px rgba(0,0,0,0.1)',
      }}
    >
      <div className="text-5xl mb-3 lamsa-float" style={{ animationDelay: `${Math.random() * 2}s` }}>{icon}</div>
      <div className="font-black text-lg">{title}</div>
    </button>
  );
}

function SubjectCard({ icon, name, color }: { icon: string; name: string; color: string }) {
  return (
    <div className="flex items-center gap-3 bg-white rounded-2xl p-4 shadow-md border-2 border-gray-100 hover:border-orange-300 hover:shadow-lg transition-all duration-300 hover:scale-105 cursor-pointer">
      <div className="w-14 h-14 rounded-xl flex items-center justify-center text-3xl" style={{ backgroundColor: `${color}20` }}>
        {icon}
      </div>
      <div>
        <div className="font-black text-gray-800">{name}</div>
        <div className="text-xs font-bold" style={{ color }}>اضغط للبدء!</div>
      </div>
    </div>
  );
}

export function StudentCopyBoYJRrhg() {
  const [xp, setXp] = useState(1250);
  const [level, setLevel] = useState(5);
  const [gems, setGems] = useState(42);
  const [activeTab, setActiveTab] = useState('home');
  const [showCelebration, setShowCelebration] = useState(false);
  const [welcomeDone, setWelcomeDone] = useState(false);

  useEffect(() => {
    const timer = setTimeout(() => setWelcomeDone(true), 500);
    return () => clearTimeout(timer);
  }, []);

  const handleCollectGems = () => {
    setGems(g => g + 5);
    setShowCelebration(true);
    setTimeout(() => setShowCelebration(false), 2000);
  };

  const subjects = [
    { icon: '🔬', name: 'العلوم', color: '#60A5FA' },
    { icon: '📝', name: 'اللغة العربية', color: '#F59E0B' },
    { icon: '📚', name: 'التاريخ', color: '#A78BFA' },
    { icon: '❤️', name: 'التربية الإسلامية', color: '#F472B6' },
    { icon: '🌍', name: 'الجغرافيا', color: '#4ADE80' },
    { icon: '💾', name: 'الحاسب آلي', color: '#FB923C' },
  ];

  const games = [
    { icon: '🎮', title: 'مغامرة الكلمات', color: '#FF6B35' },
    { icon: '🎲', title: 'تحدي الرقم', color: '#4ECDC4' },
    { icon: '🎨', title: 'الرسم والتلوين', color: '#A78BFA' },
    { icon: '🏆', title: 'المسابقة', color: '#FFE66D', textColor: '#333' },
  ];

  return (
    <div className="lamsa-root min-h-screen bg-gradient-to-br from-orange-50 via-pink-50 to-amber-50 relative overflow-hidden">
      {/* Floating decorations */}
      <FloatingEmoji emoji="⭐" x={5} y={10} delay={0} />
      <FloatingEmoji emoji="🌟" x={90} y={20} delay={0.5} />
      <FloatingEmoji emoji="🎈" x={85} y={80} delay={1} />
      <FloatingEmoji emoji="✨" x={10} y={70} delay={1.5} />

      {/* Celebration overlay */}
      {showCelebration && (
        <div className="fixed inset-0 z-50 pointer-events-none flex items-center justify-center">
          <div className="text-center">
            <div className="text-8xl lamsa-bounce">🎉</div>
            <div className="text-4xl font-black text-orange-500 mt-4">+5 جواهر!</div>
          </div>
          {['🎊', '⭐', '🎈', '🎁', '💎'].map((e, i) => (
            <div
              key={i}
              className="absolute text-4xl"
              style={{
                left: `${20 + i * 15}%`,
                top: `${10 + Math.random() * 20}%`,
                animation: `confetti-fall 2s ease-out forwards`,
                animationDelay: `${i * 0.1}s`,
              }}
            >
              {e}
            </div>
          ))}
        </div>
      )}

      <style>{`@keyframes confetti-fall { 0% { transform: translateY(-100px) rotate(0deg); opacity: 1; } 100% { transform: translateY(400px) rotate(720deg); opacity: 0; } }`}</style>

      {/* Header */}
      <div className="relative z-10 bg-gradient-to-r from-orange-400 via-pink-500 to-purple-500 text-white p-6 rounded-b-[2rem] shadow-lg">
        <div className="flex items-center justify-between">
          <div className="flex items-center gap-3">
            <div className="w-14 h-14 bg-white/20 rounded-full flex items-center justify-center text-3xl border-2 border-white/40 lamsa-float">
              👤
            </div>
            <div>
              <h1 className="text-xl font-black">أهلاً يا أحمد! 🌟</h1>
              <p className="text-orange-100 text-sm font-bold">المستوى {level} | ⭐ {xp} نقطة</p>
            </div>
          </div>
          <button onClick={handleCollectGems} className="flex items-center gap-2 bg-white/20 rounded-full px-4 py-2 border-2 border-white/30 hover:bg-white/30 transition-all active:scale-95">
            <span className="text-2xl">💎</span>
            <span className="font-black text-lg">{gems}</span>
          </button>
        </div>

        {/* XP Bar */}
        <div className="mt-4">
          <div className="w-full h-4 bg-black/20 rounded-full overflow-hidden border border-white/20">
            <div className="h-full bg-gradient-to-r from-yellow-300 to-amber-400 rounded-full transition-all duration-1000" style={{ width: '65%' }} />
          </div>
          <p className="text-center text-sm mt-1 font-bold text-orange-100">1250 / 2000 نقطة للمستوى التالي</p>
        </div>
      </div>

      {/* Quick Stats */}
      <div className="relative z-10 px-4 -mt-4">
        <div className="grid grid-cols-3 gap-3">
          {[
            { icon: '📚', label: 'الدروس', value: '12', color: '#60A5FA' },
            { icon: '🎯', label: 'الاختبارات', value: '8', color: '#4ADE80' },
            { icon: '🏆', label: 'الإنجازات', value: '5', color: '#F59E0B' },
          ].map((stat, i) => (
            <div
              key={i}
              className="bg-white rounded-2xl p-4 shadow-md text-center border-2 border-gray-100 hover:border-orange-300 hover:shadow-lg transition-all duration-300 hover:scale-105 cursor-pointer"
              style={{ animationDelay: `${i * 0.1}s` }}
            >
              <div className="text-3xl mb-1">{stat.icon}</div>
              <div className="text-2xl font-black" style={{ color: stat.color }}>{stat.value}</div>
              <div className="text-xs font-bold text-gray-500">{stat.label}</div>
            </div>
          ))}
        </div>
      </div>

      {/* Subjects Section */}
      <div className="relative z-10 px-4 mt-6">
        <div className="flex items-center gap-2 mb-4">
          <span className="text-2xl">📖</span>
          <h2 className="text-xl font-black text-gray-800">موادي الدراسية</h2>
        </div>
        <div className="grid grid-cols-1 gap-3">
          {subjects.map((subject, i) => (
            <div key={i} className="lamsa-bounce" style={{ animationDelay: `${i * 0.1}s` }}>
              <SubjectCard {...subject} />
            </div>
          ))}
        </div>
      </div>

      {/* Games Section */}
      <div className="relative z-10 px-4 mt-6">
        <div className="flex items-center gap-2 mb-4">
          <span className="text-2xl">🎮</span>
          <h2 className="text-xl font-black text-gray-800">ألعابي التعليمية</h2>
        </div>
        <div className="grid grid-cols-2 gap-3">
          {games.map((game, i) => (
            <div key={i} className="lamsa-bounce" style={{ animationDelay: `${i * 0.15}s` }}>
              <GameCard {...game} onClick={() => {}} />
            </div>
          ))}
        </div>
      </div>

      {/* Progress Section */}
      <div className="relative z-10 px-4 mt-6 mb-8">
        <div className="bg-white rounded-3xl p-6 shadow-lg border-2 border-gray-100">
          <div className="flex items-center gap-2 mb-4">
            <span className="text-2xl">📊</span>
            <h2 className="text-xl font-black text-gray-800">تقدمي</h2>
          </div>
          <ProgressBar label="🔬 العلوم" value={85} color="#60A5FA" />
          <ProgressBar label="📝 العربية" value={70} color="#F59E0B" />
          <ProgressBar label="📚 التاريخ" value={90} color="#A78BFA" />
          <ProgressBar label="🌍 الجغرافيا" value={60} color="#4ADE80" />
        </div>
      </div>

      {/* Bottom nav */}
      <div className="relative z-10 bg-white border-t-2 border-gray-100 px-4 py-3 flex justify-around items-center shadow-lg">
        {[
          { id: 'home', icon: '🏠', label: 'الرئيسية' },
          { id: 'games', icon: '🎮', label: 'الألعاب' },
          { id: 'progress', icon: '📊', label: 'تقدمي' },
          { id: 'profile', icon: '👤', label: 'حسابي' },
        ].map((tab) => (
          <button
            key={tab.id}
            onClick={() => setActiveTab(tab.id)}
            className={`flex flex-col items-center gap-1 transition-all duration-300 ${
              activeTab === tab.id ? 'scale-110' : 'opacity-60 hover:opacity-100'
            }`}
          >
            <span className="text-2xl">{tab.icon}</span>
            <span className="text-xs font-bold">{tab.label}</span>
            {activeTab === tab.id && (
              <div className="w-8 h-1 bg-orange-400 rounded-full mt-1" />
            )}
          </button>
        ))}
      </div>
    </div>
  );
}
