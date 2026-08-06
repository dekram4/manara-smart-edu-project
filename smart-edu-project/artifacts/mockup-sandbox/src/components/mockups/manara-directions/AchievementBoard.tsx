import React, { useState } from 'react';
import { Flame, Gem, Play, CheckCircle2, Circle, X, Star, ChevronLeft, Award } from 'lucide-react';

const student = {
  name: "ليان",
  level: 7,
  xp: 3240,
  maxXp: 3500,
  streak: 12,
  gems: 86,
};

const nextLesson = {
  title: "رحلة الماء في الطبيعة",
  subject: "العلوم",
  duration: "15 دقيقة",
};

const badges = [
  { id: 1, title: "عالم المستقبل", description: "أكملت 10 دروس في العلوم بتفوق", icon: "🔬", date: "15 أكتوبر" },
  { id: 2, title: "بطل الرياضيات", description: "حللت 50 مسألة متتالية بدون أخطاء", icon: "🔢", date: "10 أكتوبر" },
  { id: 3, title: "مستكشف الفضاء", description: "شاهدت جميع فيديوهات النظام الشمسي", icon: "🚀", date: "28 سبتمبر" },
  { id: 4, title: "قارئ نهم", description: "قرأت 5 قصص تفاعلية هذا الشهر", icon: "📚", date: "20 سبتمبر" },
];

const tasks = [
  { id: 1, title: "اقرأ قصة جديدة", progress: 1, total: 1, completed: true },
  { id: 2, title: "حل اختبار الأسبوع", progress: 0, total: 1, completed: false },
  { id: 3, title: "اجمع 50 نقطة خبرة إضافية", progress: 30, total: 50, completed: false },
];

export default function AchievementBoard() {
  const [selectedBadge, setSelectedBadge] = useState<typeof badges[0] | null>(null);

  const xpPercentage = (student.xp / student.maxXp) * 100;

  return (
    <div dir="rtl" className="min-h-screen bg-slate-950 bg-[radial-gradient(ellipse_at_top,_var(--tw-gradient-stops))] from-blue-900/40 via-slate-950 to-black text-slate-100 font-sans p-4 md:p-8 flex justify-center">
      <div className="max-w-5xl w-full grid grid-cols-1 lg:grid-cols-3 gap-6">
        
        {/* Main Column */}
        <div className="lg:col-span-2 space-y-6">
          
          {/* Welcome & Stats Glass Card */}
          <div className="bg-slate-900/60 backdrop-blur-xl border border-white/5 rounded-3xl p-6 md:p-8 shadow-2xl relative overflow-hidden">
            <div className="absolute top-0 right-0 w-64 h-64 bg-teal-500/10 rounded-full blur-3xl -translate-y-1/2 translate-x-1/4"></div>
            <div className="absolute bottom-0 left-0 w-64 h-64 bg-amber-500/10 rounded-full blur-3xl translate-y-1/4 -translate-x-1/4"></div>
            
            <div className="relative z-10 flex flex-col md:flex-row gap-8 items-center md:items-start">
              {/* Avatar & Level */}
              <div className="flex flex-col items-center gap-3">
                <div className="relative">
                  <div className="w-24 h-24 rounded-full bg-gradient-to-tr from-teal-400 to-blue-500 p-1 shadow-[0_0_20px_rgba(45,212,191,0.2)]">
                    <div className="w-full h-full rounded-full bg-slate-900 flex items-center justify-center text-4xl border-2 border-slate-900">
                      👩🏽‍🚀
                    </div>
                  </div>
                  <div className="absolute -bottom-2 -left-2 bg-gradient-to-r from-amber-400 to-yellow-500 text-amber-950 font-bold px-3 py-1 rounded-full text-sm border-2 border-slate-900 shadow-lg whitespace-nowrap">
                    مستوى {student.level}
                  </div>
                </div>
              </div>

              {/* Info & Core Stats */}
              <div className="flex-1 text-center md:text-right w-full">
                <h1 className="text-2xl md:text-3xl font-bold text-white mb-2">
                  مرحباً بكِ، <span className="text-teal-400">{student.name}</span>! ✨
                </h1>
                <p className="text-slate-400 mb-6 text-sm md:text-base">استمري في تألقكِ، أنتِ تقتربين من المستوى التالي.</p>
                
                <div className="grid grid-cols-2 md:grid-cols-3 gap-4">
                  {/* Streak */}
                  <div className="bg-slate-800/50 border border-white/5 rounded-2xl p-4 flex flex-col items-center justify-center gap-2 transition-transform hover:scale-105 hover:bg-slate-800 cursor-default shadow-inner">
                    <Flame className="w-8 h-8 text-amber-400 drop-shadow-[0_0_8px_rgba(251,191,36,0.5)]" />
                    <div className="text-center">
                      <div className="font-bold text-xl text-white">{student.streak} أيام</div>
                      <div className="text-xs text-slate-400">حماس متواصل</div>
                    </div>
                  </div>
                  
                  {/* Gems */}
                  <div className="bg-slate-800/50 border border-white/5 rounded-2xl p-4 flex flex-col items-center justify-center gap-2 transition-transform hover:scale-105 hover:bg-slate-800 cursor-default shadow-inner">
                    <Gem className="w-8 h-8 text-teal-400 drop-shadow-[0_0_8px_rgba(45,212,191,0.5)]" />
                    <div className="text-center">
                      <div className="font-bold text-xl text-white">{student.gems} جوهرة</div>
                      <div className="text-xs text-slate-400">رصيدك الحالي</div>
                    </div>
                  </div>

                  {/* XP Bar (Span 2 on mobile, 1 on desktop) */}
                  <div className="col-span-2 md:col-span-1 bg-slate-800/50 border border-white/5 rounded-2xl p-4 flex flex-col items-center justify-center gap-3 transition-transform hover:scale-105 hover:bg-slate-800 cursor-default shadow-inner">
                    <div className="flex justify-between w-full text-xs font-medium text-slate-300">
                      <span>الخبرة</span>
                      <span className="text-teal-400 font-bold">{student.xp} / {student.maxXp}</span>
                    </div>
                    <div className="w-full bg-slate-950 rounded-full h-2.5 border border-slate-700/50 overflow-hidden shadow-inner">
                      <div 
                        className="bg-gradient-to-r from-teal-500 to-blue-400 h-full rounded-full relative" 
                        style={{ width: `${xpPercentage}%` }}
                      >
                        <div className="absolute inset-0 bg-white/20 w-full h-full"></div>
                      </div>
                    </div>
                    <div className="text-[10px] text-slate-400 w-full text-right">
                      باقي {student.maxXp - student.xp} نقطة للمستوى {student.level + 1}
                    </div>
                  </div>
                </div>
              </div>
            </div>
          </div>

          {/* Next Lesson Action Card */}
          <div className="bg-gradient-to-r from-teal-900/40 to-blue-900/30 border border-teal-500/30 backdrop-blur-md rounded-3xl p-6 relative overflow-hidden group hover:border-teal-500/50 transition-all shadow-[0_0_30px_rgba(20,184,166,0.05)]">
            <div className="absolute right-0 top-0 h-full w-1.5 bg-teal-400 shadow-[0_0_10px_rgba(45,212,191,0.8)]"></div>
            <div className="flex flex-col sm:flex-row justify-between items-center gap-6">
              <div className="space-y-2 text-center sm:text-right">
                <div className="inline-flex items-center gap-2 px-3 py-1.5 rounded-full bg-teal-500/10 text-teal-300 text-xs font-semibold mb-1 border border-teal-500/20">
                  <Star className="w-3.5 h-3.5" />
                  الدرس التالي الموصى به
                </div>
                <h3 className="text-xl md:text-2xl font-bold text-white group-hover:text-teal-300 transition-colors">
                  {nextLesson.title}
                </h3>
                <p className="text-sm text-slate-400">
                  {nextLesson.subject} • {nextLesson.duration}
                </p>
              </div>
              <button className="flex items-center gap-3 bg-gradient-to-r from-teal-500 to-teal-400 hover:from-teal-400 hover:to-teal-300 text-slate-950 font-bold px-6 py-3.5 rounded-2xl transition-all hover:scale-105 active:scale-95 shadow-[0_4px_20px_rgba(20,184,166,0.3)]">
                <Play className="w-5 h-5 fill-current" />
                ابدأ الدرس الآن
              </button>
            </div>
          </div>

          {/* Badges Grid */}
          <div className="bg-slate-900/60 border border-white/5 backdrop-blur-md rounded-3xl p-6 shadow-xl">
            <div className="flex justify-between items-center mb-6">
              <h3 className="text-lg font-bold text-white flex items-center gap-2">
                <Award className="w-5 h-5 text-amber-400" />
                لوحة الشارات والإنجازات
              </h3>
              <button className="text-sm text-teal-400 hover:text-teal-300 flex items-center gap-1 font-medium bg-teal-400/10 px-3 py-1.5 rounded-full transition-colors hover:bg-teal-400/20">
                عرض الكل
                <ChevronLeft className="w-4 h-4" />
              </button>
            </div>
            
            <div className="grid grid-cols-2 sm:grid-cols-4 gap-4">
              {badges.map((badge) => (
                <button
                  key={badge.id}
                  onClick={() => setSelectedBadge(badge)}
                  className="bg-slate-950/50 border border-white/5 hover:bg-slate-800 hover:border-teal-500/40 rounded-2xl p-4 flex flex-col items-center gap-3 transition-all hover:-translate-y-1 hover:shadow-[0_10px_20px_rgba(20,184,166,0.1)] active:scale-95 group focus:outline-none focus:ring-2 focus:ring-teal-500/50"
                  aria-label={`عرض تفاصيل شارة ${badge.title}`}
                >
                  <div className="w-16 h-16 rounded-full bg-gradient-to-br from-slate-800 to-slate-900 flex items-center justify-center text-3xl shadow-inner border border-slate-700/50 group-hover:border-teal-500/50 group-hover:shadow-[0_0_20px_rgba(20,184,166,0.2)] transition-all">
                    {badge.icon}
                  </div>
                  <div className="text-center">
                    <div className="text-sm font-bold text-slate-300 group-hover:text-white line-clamp-1">{badge.title}</div>
                  </div>
                </button>
              ))}
            </div>
          </div>

        </div>

        {/* Sidebar */}
        <div className="space-y-6">
          
          {/* Weekly Tasks */}
          <div className="bg-slate-900/60 border border-white/5 backdrop-blur-md rounded-3xl p-6 shadow-xl sticky top-8">
            <h3 className="text-lg font-bold text-white mb-6 flex items-center gap-2">
              <CheckCircle2 className="w-5 h-5 text-teal-400" />
              مهام الأسبوع
            </h3>
            <div className="space-y-5">
              {tasks.map((task) => (
                <div key={task.id} className="group relative">
                  <div className="flex items-start gap-3">
                    <button 
                      className="mt-0.5 focus:outline-none flex-shrink-0 transition-transform active:scale-90"
                      aria-label={task.completed ? "مهمة مكتملة" : "حدد كمكتملة"}
                    >
                      {task.completed ? (
                        <CheckCircle2 className="w-5 h-5 text-teal-400 drop-shadow-[0_0_8px_rgba(45,212,191,0.5)]" />
                      ) : (
                        <Circle className="w-5 h-5 text-slate-600 hover:text-teal-400/70 transition-colors" />
                      )}
                    </button>
                    <div className="flex-1 space-y-2">
                      <div className={`text-sm font-medium transition-colors ${task.completed ? 'text-slate-500 line-through' : 'text-slate-200'}`}>
                        {task.title}
                      </div>
                      {!task.completed && task.total > 1 && (
                        <div className="space-y-1.5">
                          <div className="flex justify-between text-[10px] text-slate-400 font-medium">
                            <span>{task.progress} / {task.total}</span>
                            <span className="text-amber-400">{Math.round((task.progress / task.total) * 100)}%</span>
                          </div>
                          <div className="w-full bg-slate-950 rounded-full h-1.5 shadow-inner">
                            <div 
                              className="bg-gradient-to-r from-amber-500 to-yellow-400 h-1.5 rounded-full transition-all duration-1000 ease-out" 
                              style={{ width: `${(task.progress / task.total) * 100}%` }}
                            ></div>
                          </div>
                        </div>
                      )}
                    </div>
                  </div>
                </div>
              ))}
            </div>
            
            <div className="mt-8 pt-6 border-t border-white/5">
              <div className="text-xs text-center text-slate-400 bg-slate-950/50 py-3 rounded-xl">
                تتجدد المهام خلال <span className="text-teal-400 font-bold">2 أيام</span>
              </div>
            </div>
          </div>

        </div>

      </div>

      {/* Badge Modal */}
      {selectedBadge && (
        <div className="fixed inset-0 z-50 flex items-center justify-center p-4">
          <div 
            className="absolute inset-0 bg-slate-950/80 backdrop-blur-md"
            onClick={() => setSelectedBadge(null)}
          ></div>
          <div className="relative bg-slate-900 border border-white/10 rounded-3xl p-8 max-w-sm w-full shadow-2xl transform scale-100 transition-all">
            <button 
              onClick={() => setSelectedBadge(null)}
              className="absolute top-4 left-4 text-slate-400 hover:text-white bg-slate-800 hover:bg-slate-700 rounded-full p-1.5 transition-colors focus:outline-none focus:ring-2 focus:ring-slate-400"
              aria-label="إغلاق"
            >
              <X className="w-5 h-5" />
            </button>
            
            <div className="flex flex-col items-center text-center gap-5 pt-4">
              <div className="w-28 h-28 rounded-full bg-gradient-to-br from-amber-200 via-yellow-400 to-amber-600 flex items-center justify-center text-6xl shadow-[0_0_40px_rgba(251,191,36,0.2)] border-4 border-slate-900 relative">
                <div className="absolute inset-0 rounded-full bg-white/20 animate-pulse"></div>
                <span className="relative z-10">{selectedBadge.icon}</span>
              </div>
              
              <div className="space-y-2">
                <h4 className="text-2xl font-bold text-white">{selectedBadge.title}</h4>
                <p className="text-slate-400 text-sm leading-relaxed">{selectedBadge.description}</p>
              </div>
              
              <div className="bg-slate-950/50 border border-white/5 rounded-xl px-4 py-3 text-sm text-slate-300 w-full mt-2 flex justify-between items-center">
                <span>تاريخ الحصول عليها</span>
                <span className="text-teal-400 font-bold">{selectedBadge.date}</span>
              </div>
              
              <button 
                onClick={() => setSelectedBadge(null)}
                className="w-full bg-white/10 hover:bg-white/20 text-white font-bold py-3.5 rounded-xl transition-colors mt-2 focus:outline-none focus:ring-2 focus:ring-white/30 active:scale-95"
              >
                متابعة التألق
              </button>
            </div>
          </div>
        </div>
      )}

    </div>
  );
}
