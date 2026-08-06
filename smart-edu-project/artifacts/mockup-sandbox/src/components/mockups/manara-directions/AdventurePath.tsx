import React, { useState } from 'react';
import { 
  Flame, Gem, Star, Map as MapIcon, 
  Trophy, Gamepad2, Check, Lock, Play,
  Target, Award, BookOpen, Beaker, 
  Globe, Puzzle, Zap, Cloud
} from 'lucide-react';

const STUDENT = {
  name: "ليان",
  level: 7,
  xp: 3240,
  maxXp: 3500,
  streak: 12,
  gems: 86,
};

const NODES = [
  { id: 1, title: 'النباتات وأجزاؤها', type: 'completed', icon: <BookOpen className="w-7 h-7" /> },
  { id: 2, title: 'حالات المادة', type: 'completed', icon: <Beaker className="w-7 h-7" /> },
  { id: 3, title: 'رحلة الماء في الطبيعة', type: 'current', icon: <Star className="w-8 h-8 fill-white" /> },
  { id: 4, title: 'النظام الشمسي', type: 'locked', icon: <Globe className="w-7 h-7" /> },
  { id: 5, title: 'جسم الإنسان', type: 'locked', icon: <Lock className="w-6 h-6" /> },
];

const TASKS = [
  { id: 1, title: "اقرأ مقالتين علميتين", progress: 1, max: 2 },
  { id: 2, title: "شاهد فيديو العلوم", progress: 1, max: 1 },
  { id: 3, title: "أكمل اختبار الأسبوع", progress: 0, max: 1 },
];

const BADGES = [
  { id: 1, title: 'مستكشف', emoji: '🧭', color: 'from-purple-100 to-indigo-100', ring: 'ring-purple-200' },
  { id: 2, title: 'عالم صغير', emoji: '🔬', color: 'from-emerald-100 to-teal-100', ring: 'ring-emerald-200' },
  { id: 3, title: 'قارئ نهم', emoji: '📚', color: 'from-orange-100 to-amber-100', ring: 'ring-orange-200' },
  { id: 4, title: 'بطل الأسبوع', emoji: '🏆', color: 'from-pink-100 to-rose-100', ring: 'ring-pink-200' },
];

const GAMES = [
  { id: 1, title: 'لعبة الذاكرة', desc: 'درب عقلك', icon: <Puzzle className="w-12 h-12 text-white/80" />, color: 'from-pink-400 to-rose-400' },
  { id: 2, title: 'مسابقة العلوم', desc: 'تحدى أصدقاءك', icon: <Zap className="w-12 h-12 text-white/80" />, color: 'from-indigo-400 to-purple-400' },
  { id: 3, title: 'كلمات متقاطعة', desc: 'اكتشف المصطلحات', icon: <Target className="w-12 h-12 text-white/80" />, color: 'from-emerald-400 to-teal-400' },
];

const CustomStyles = () => (
  <style>{`
    @keyframes wave {
      0%, 100% { transform: rotate(0deg); }
      25% { transform: rotate(15deg); }
      75% { transform: rotate(-10deg); }
    }
    .animate-wave {
      animation: wave 2s ease-in-out infinite;
    }
    @keyframes float {
      0%, 100% { transform: translateY(0px) translateX(0px); }
      33% { transform: translateY(-10px) translateX(5px); }
      66% { transform: translateY(5px) translateX(-5px); }
    }
    .animate-float-slow {
      animation: float 8s ease-in-out infinite;
    }
    .animate-float-slower {
      animation: float 12s ease-in-out infinite reverse;
    }
    .no-scrollbar::-webkit-scrollbar {
      display: none;
    }
    .no-scrollbar {
      -ms-overflow-style: none;
      scrollbar-width: none;
    }
  `}</style>
);

const BackgroundDecorations = () => (
  <div className="absolute inset-0 pointer-events-none overflow-hidden z-0 bg-gradient-to-b from-sky-400 via-sky-300 to-emerald-300">
    <CustomStyles />
    
    <div className="absolute top-[5%] right-[10%] opacity-70 animate-float-slow">
      <Cloud className="w-24 h-24 text-white fill-white drop-shadow-md" />
    </div>
    <div className="absolute top-[25%] left-[5%] opacity-50 animate-float-slower">
      <Cloud className="w-16 h-16 text-white fill-white drop-shadow-sm" />
    </div>
    <div className="absolute top-[45%] right-[25%] opacity-60 animate-float-slow" style={{ animationDelay: '1s' }}>
      <Cloud className="w-32 h-32 text-white fill-white drop-shadow-lg" />
    </div>
    <div className="absolute top-[65%] left-[15%] opacity-40 animate-float-slower" style={{ animationDelay: '2s' }}>
      <Cloud className="w-20 h-20 text-white fill-white drop-shadow-sm" />
    </div>

    <div className="absolute bottom-0 left-0 right-0 h-[30%] bg-gradient-to-t from-emerald-400/40 to-transparent" />
    <div className="absolute -bottom-[20%] -left-[20%] w-[140%] h-[40%] bg-emerald-400/40 rounded-t-[100%] blur-2xl" />
  </div>
);

const TopHeader = () => (
  <header className="absolute top-0 left-0 right-0 z-50 w-full px-4 pt-4 pb-2 pointer-events-none max-w-lg mx-auto">
    <div className="bg-white/85 backdrop-blur-xl rounded-3xl p-4 shadow-[0_8px_30px_rgba(0,0,0,0.08)] border border-white/60 flex flex-col gap-4 pointer-events-auto transition-all">
      <div className="flex justify-between items-center">
        <div className="flex items-center gap-3">
          <div className="w-12 h-12 bg-gradient-to-tr from-indigo-500 to-purple-500 rounded-2xl flex items-center justify-center text-white text-xl font-black shadow-lg ring-4 ring-indigo-100/50 rotate-3">
            ل
          </div>
          <div>
            <h1 className="font-extrabold text-lg text-indigo-950 leading-tight flex items-center gap-1">
              أهلاً يا ليان <span className="animate-wave inline-block origin-bottom-right">👋</span>
            </h1>
            <p className="text-xs text-indigo-600/90 font-bold bg-indigo-50 inline-block px-2 py-0.5 rounded-md mt-1 border border-indigo-100">
              المستوى {STUDENT.level} • البطلة الذكية
            </p>
          </div>
        </div>
        <div className="flex flex-col items-end gap-1.5">
          <div className="flex items-center gap-1.5 bg-gradient-to-r from-orange-100 to-amber-50 px-2.5 py-1 rounded-xl border border-orange-200/50 shadow-sm">
            <span className="text-xs font-black text-orange-700">{STUDENT.streak} يوم</span>
            <Flame className="w-4 h-4 text-orange-500 fill-orange-500 animate-pulse" />
          </div>
          <div className="flex items-center gap-1.5 bg-gradient-to-r from-emerald-100 to-teal-50 px-2.5 py-1 rounded-xl border border-emerald-200/50 shadow-sm">
            <span className="text-xs font-black text-emerald-700">{STUDENT.gems}</span>
            <Gem className="w-4 h-4 text-emerald-500 fill-emerald-500" />
          </div>
        </div>
      </div>
      
      <div className="flex items-center gap-3 w-full">
        <div className="w-8 h-8 rounded-xl bg-gradient-to-br from-indigo-100 to-purple-100 flex items-center justify-center border border-indigo-200 shadow-sm">
          <Star className="w-4 h-4 text-indigo-500 fill-indigo-500" />
        </div>
        <div className="flex-1">
          <div className="flex justify-between text-[10px] font-black text-indigo-800/70 mb-1.5 px-1">
            <span>{STUDENT.xp} نقطة</span>
            <span>الهدف: {STUDENT.maxXp}</span>
          </div>
          <div className="h-3 w-full bg-slate-100/80 rounded-full overflow-hidden shadow-inner border border-slate-200/50">
            <div 
              className="h-full bg-gradient-to-r from-indigo-400 via-purple-500 to-indigo-500 rounded-full transition-all duration-1000 relative overflow-hidden" 
              style={{ width: `${(STUDENT.xp/STUDENT.maxXp)*100}%` }}
            >
              <div className="absolute inset-0 bg-white/20 skew-x-[-20deg] animate-[translateX_2s_infinite]" style={{ width: '200%', left: '-100%' }} />
            </div>
          </div>
        </div>
      </div>
    </div>
  </header>
);

const NodeContent = ({ node, isCurrent, isCompleted, isSelected, onClick }: any) => (
  <div className="relative flex flex-col items-center z-10 w-full cursor-pointer group" onClick={onClick}>
    <button 
      className={`
        relative z-10 w-16 h-16 sm:w-20 sm:h-20 rounded-full flex items-center justify-center shadow-xl transition-all duration-300
        ${isCurrent ? 'bg-gradient-to-br from-orange-400 to-red-500 scale-125 ring-4 ring-orange-200 shadow-orange-500/50' : ''}
        ${isCompleted ? 'bg-gradient-to-br from-emerald-400 to-teal-500 text-white hover:scale-110' : ''}
        ${!isCurrent && !isCompleted ? 'bg-white/90 backdrop-blur-md text-slate-300 border-4 border-slate-200 grayscale hover:scale-110' : ''}
        ${isSelected && !isCurrent ? 'ring-4 ring-white shadow-2xl scale-110' : ''}
      `}
    >
      {isCompleted && (
        <div className="absolute -top-1 -right-1 bg-white rounded-full p-1 shadow-sm border border-emerald-100 z-20">
          <Check className="w-4 h-4 text-emerald-500 font-black" />
        </div>
      )}
      
      {isCurrent && (
        <div className="absolute inset-0 rounded-full bg-orange-400 animate-ping opacity-40" />
      )}

      <div className={`text-white transition-transform ${isCurrent ? 'animate-bounce' : 'group-hover:scale-110'} ${!isCurrent && !isCompleted ? 'text-slate-400' : ''}`}>
        {node.icon}
      </div>
    </button>

    <div className={`
      absolute top-full mt-3 bg-white/95 backdrop-blur-xl p-3 rounded-2xl shadow-xl border-2 w-[150px] sm:w-[170px] text-center transition-all duration-300 z-30 origin-top
      ${isCurrent ? 'border-orange-300 scale-100 opacity-100 translate-y-0' : isCompleted ? 'border-emerald-200' : 'border-slate-100'}
      ${isSelected || isCurrent ? 'opacity-100 scale-100 pointer-events-auto translate-y-0' : 'opacity-0 scale-90 pointer-events-none translate-y-2 group-hover:opacity-100 group-hover:scale-100 group-hover:translate-y-0'}
    `}>
      <h3 className={`font-black text-sm leading-snug ${isCurrent ? 'text-orange-700' : isCompleted ? 'text-emerald-700' : 'text-slate-600'}`}>
        {node.title}
      </h3>
      
      {isCurrent && (
        <button className="mt-2 w-full bg-gradient-to-r from-orange-400 to-red-500 text-white text-xs font-black py-2.5 rounded-xl flex items-center justify-center gap-1 shadow-md hover:shadow-lg hover:scale-105 active:scale-95 transition-all">
          <Play className="w-3 h-3 fill-current" />
          ابدأ الدرس
        </button>
      )}
      {isCompleted && (
        <div className="mt-2 flex justify-center gap-1">
          <Star className="w-3 h-3 text-yellow-400 fill-yellow-400" />
          <Star className="w-3 h-3 text-yellow-400 fill-yellow-400" />
          <Star className="w-3 h-3 text-yellow-400 fill-yellow-400" />
        </div>
      )}
      {!isCurrent && !isCompleted && (
        <p className="text-[10px] font-bold text-slate-400 mt-1 flex items-center justify-center gap-1">
          <Lock className="w-3 h-3" /> مغلق
        </p>
      )}
    </div>
  </div>
);

const JourneyView = ({ onSelectNode, selectedNode }: any) => {
  return (
    <div className="relative py-8 px-4 min-h-[800px] w-full max-w-lg mx-auto flex flex-col items-center">
      <div className="absolute top-12 bottom-32 left-1/2 w-4 -ml-2 bg-white/40 rounded-full shadow-inner border border-white/50 backdrop-blur-sm" />
      <div className="absolute top-12 h-[45%] left-1/2 w-4 -ml-2 bg-gradient-to-b from-emerald-400 via-yellow-400 to-orange-400 rounded-full shadow-[0_0_20px_rgba(251,146,60,0.5)] border border-white/60" />

      <div className="w-full flex flex-col gap-24 sm:gap-28 mt-4">
        {NODES.map((node, index) => {
          const isRight = index % 2 === 0;
          const isCurrent = node.type === 'current';
          const isCompleted = node.type === 'completed';
          const isSelected = selectedNode === node.id;
          
          return (
            <div key={node.id} className="relative w-full flex">
              {isRight ? (
                <>
                  <div className="w-1/2 relative flex justify-center">
                    <NodeContent 
                      node={node} 
                      isCurrent={isCurrent} 
                      isCompleted={isCompleted} 
                      isSelected={isSelected}
                      onClick={() => onSelectNode(isSelected ? null : node.id)}
                    />
                    <div className={`absolute top-8 sm:top-10 left-0 w-1/2 h-0 border-t-[3.5px] border-dashed -z-10 ${isCompleted || isCurrent ? 'border-emerald-400/80' : 'border-white/80'}`} />
                  </div>
                  <div className="w-1/2" />
                </>
              ) : (
                <>
                  <div className="w-1/2" />
                  <div className="w-1/2 relative flex justify-center">
                    <NodeContent 
                      node={node} 
                      isCurrent={isCurrent} 
                      isCompleted={isCompleted} 
                      isSelected={isSelected}
                      onClick={() => onSelectNode(isSelected ? null : node.id)}
                    />
                    <div className={`absolute top-8 sm:top-10 right-0 w-1/2 h-0 border-t-[3.5px] border-dashed -z-10 ${isCompleted || isCurrent ? 'border-emerald-400/80' : 'border-white/80'}`} />
                  </div>
                </>
              )}
            </div>
          );
        })}
      </div>
      
      <div className="mt-16 text-white/80 flex flex-col items-center animate-bounce">
        <MapIcon className="w-8 h-8 opacity-60" />
      </div>
    </div>
  );
};

const AchievementsView = () => (
  <div className="px-4 py-8 max-w-lg mx-auto space-y-8 animate-in fade-in slide-in-from-bottom-4 duration-500">
    
    <section>
      <div className="flex items-center justify-between mb-4 bg-white/40 p-3 rounded-2xl backdrop-blur-sm border border-white/50">
        <div className="flex items-center gap-2">
          <Target className="w-6 h-6 text-indigo-700" />
          <h2 className="text-lg font-black text-indigo-950">مهام الأسبوع</h2>
        </div>
        <span className="text-xs font-bold text-indigo-700 bg-white/60 px-2 py-1 rounded-lg">3 مهام</span>
      </div>
      
      <div className="space-y-3">
        {TASKS.map(task => {
          const isDone = task.progress === task.max;
          return (
            <div key={task.id} className="bg-white/90 backdrop-blur-md p-4 rounded-2xl shadow-sm border border-white/80 flex flex-col gap-3 hover:shadow-md transition-all">
              <div className="flex justify-between items-center">
                <div className="flex items-center gap-3">
                  <div className={`w-8 h-8 rounded-full flex items-center justify-center border-2 ${isDone ? 'bg-emerald-100 border-emerald-300 text-emerald-600' : 'bg-slate-50 border-slate-200 text-slate-400'}`}>
                    {isDone ? <Check className="w-4 h-4 font-bold" /> : <div className="w-2 h-2 bg-slate-300 rounded-full" />}
                  </div>
                  <h3 className={`font-bold text-sm ${isDone ? 'text-slate-400 line-through decoration-slate-300' : 'text-slate-800'}`}>{task.title}</h3>
                </div>
                <span className={`text-xs font-black px-2 py-1 rounded-lg ${isDone ? 'bg-emerald-100 text-emerald-700' : 'bg-indigo-50 text-indigo-700'}`}>
                  {task.progress} / {task.max}
                </span>
              </div>
              <div className="h-2.5 w-full bg-slate-100 rounded-full overflow-hidden shadow-inner">
                <div 
                  className={`h-full rounded-full transition-all duration-1000 ${isDone ? 'bg-emerald-400' : 'bg-indigo-400'}`} 
                  style={{ width: `${(task.progress/task.max)*100}%` }} 
                />
              </div>
            </div>
          );
        })}
      </div>
    </section>

    <section>
      <div className="flex items-center justify-between mb-4 bg-white/40 p-3 rounded-2xl backdrop-blur-sm border border-white/50">
        <div className="flex items-center gap-2">
          <Award className="w-6 h-6 text-purple-700" />
          <h2 className="text-lg font-black text-indigo-950">شاراتي</h2>
        </div>
        <span className="text-xs font-bold text-purple-700 bg-white/60 px-2 py-1 rounded-lg">4 شارات</span>
      </div>
      
      <div className="grid grid-cols-2 gap-4">
        {BADGES.map(badge => (
          <div key={badge.id} className={`bg-gradient-to-br ${badge.color} p-4 rounded-3xl shadow-sm border border-white/60 flex flex-col items-center text-center gap-3 hover:scale-105 transition-transform cursor-pointer`}>
            <div className={`w-16 h-16 bg-white/90 rounded-2xl rotate-3 flex items-center justify-center shadow-md ring-4 ${badge.ring}`}>
              <span className="text-3xl filter drop-shadow-sm">{badge.emoji}</span>
            </div>
            <h4 className="font-black text-sm text-indigo-950/80">{badge.title}</h4>
          </div>
        ))}
      </div>
    </section>
  </div>
);

const GamesView = () => (
  <div className="px-4 py-8 max-w-lg mx-auto animate-in fade-in slide-in-from-bottom-4 duration-500">
    <div className="mb-6 bg-white/40 p-5 rounded-3xl backdrop-blur-sm border border-white/50 text-center shadow-sm">
      <Gamepad2 className="w-10 h-10 text-pink-500 mx-auto mb-2 animate-bounce" />
      <h2 className="text-2xl font-black text-indigo-950">وقت اللعب!</h2>
      <p className="text-sm font-bold text-indigo-700/80 mt-1">تعلم وامرح واجمع المزيد من النقاط</p>
    </div>
    
    <div className="grid gap-5">
      {GAMES.map(game => (
        <div key={game.id} className="bg-white/95 backdrop-blur-xl rounded-3xl overflow-hidden shadow-lg border border-white/80 transform hover:-translate-y-1 hover:shadow-xl transition-all cursor-pointer group">
          <div className={`h-32 bg-gradient-to-br ${game.color} flex items-center justify-center relative overflow-hidden`}>
            <div className="absolute inset-0 opacity-20 bg-[radial-gradient(circle_at_center,white_0%,transparent_100%)] mix-blend-overlay" />
            <div className="group-hover:scale-110 transition-transform duration-500">
              {game.icon}
            </div>
          </div>
          <div className="p-4 flex justify-between items-center bg-white">
            <div>
              <h3 className="font-black text-lg text-slate-800">{game.title}</h3>
              <p className="text-xs font-bold text-slate-500 mt-0.5">{game.desc}</p>
            </div>
            <button className="w-12 h-12 rounded-2xl bg-indigo-50 flex items-center justify-center text-indigo-600 group-hover:bg-indigo-600 group-hover:text-white group-hover:shadow-lg group-hover:shadow-indigo-500/30 transition-all">
              <Play className="w-5 h-5 fill-current ml-1" />
            </button>
          </div>
        </div>
      ))}
    </div>
  </div>
);

const BottomNav = ({ activeTab, onTabChange }: any) => {
  const tabs = [
    { id: 'journey', label: 'الرحلة', icon: <MapIcon className="w-6 h-6" /> },
    { id: 'achievements', label: 'إنجازاتي', icon: <Trophy className="w-6 h-6" /> },
    { id: 'games', label: 'الألعاب', icon: <Gamepad2 className="w-6 h-6" /> },
  ];

  return (
    <nav className="absolute bottom-0 left-0 right-0 z-50 px-4 pb-6 pt-6 bg-gradient-to-t from-sky-300 via-sky-300/90 to-transparent pointer-events-none">
      <div className="bg-white/95 backdrop-blur-xl rounded-3xl shadow-[0_10px_40px_rgba(0,0,0,0.15)] p-2 flex justify-between items-center border border-white pointer-events-auto max-w-lg mx-auto">
        {tabs.map((tab) => {
          const isActive = activeTab === tab.id;
          return (
            <button
              key={tab.id}
              onClick={() => onTabChange(tab.id)}
              className={`
                relative flex flex-col items-center justify-center w-1/3 py-2.5 rounded-2xl transition-all duration-300
                ${isActive ? 'bg-indigo-50/80 text-indigo-600' : 'text-slate-400 hover:bg-slate-50 hover:text-slate-600'}
              `}
            >
              <div className={`relative transition-transform duration-300 ${isActive ? '-translate-y-1 scale-110' : ''}`}>
                {tab.icon}
                {isActive && (
                  <span className="absolute -top-1 -right-1 w-2.5 h-2.5 bg-orange-400 rounded-full border-2 border-white shadow-sm" />
                )}
              </div>
              <span className={`text-[11px] mt-1.5 font-black transition-all duration-300 ${isActive ? 'opacity-100 text-indigo-700' : 'opacity-70'}`}>
                {tab.label}
              </span>
            </button>
          );
        })}
      </div>
    </nav>
  );
};

export function AdventurePath() {
  const [activeTab, setActiveTab] = useState('journey');
  const [selectedNode, setSelectedNode] = useState<number | null>(null);

  return (
    <div dir="rtl" className="w-full h-[100dvh] relative font-sans overflow-hidden text-slate-800 bg-sky-300 selection:bg-indigo-200">
      <BackgroundDecorations />

      <TopHeader />

      <main className="absolute inset-0 z-10 overflow-y-auto overflow-x-hidden no-scrollbar pt-[150px] pb-[100px]">
        {activeTab === 'journey' && <JourneyView onSelectNode={setSelectedNode} selectedNode={selectedNode} />}
        {activeTab === 'achievements' && <AchievementsView />}
        {activeTab === 'games' && <GamesView />}
      </main>

      <BottomNav activeTab={activeTab} onTabChange={setActiveTab} />
    </div>
  );
}

export default AdventurePath;
