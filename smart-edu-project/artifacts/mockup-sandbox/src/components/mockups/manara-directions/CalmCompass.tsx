import React, { useState } from 'react';
import { Play, Star, Flame, Gem, Trophy, BookOpen, Gamepad2, CheckCircle, ChevronLeft, Map, Compass, Award } from 'lucide-react';

// Color Palette Variables for consistency
const colors = {
  ivory: '#FAF9F6',
  ivoryDark: '#F0EFEA',
  darkPurple: '#2D1B4E',
  lightPurple: '#E9E4F0',
  mint: '#A7E6D7',
  mintDark: '#0C6B58',
  gold: '#FBBF24',
  coral: '#FB7185',
};

export default function CalmCompass() {
  const [activeTab, setActiveTab] = useState('lessons');
  const [activeSubject, setActiveSubject] = useState('all');

  const subjects = [
    { id: 'all', name: 'الكل', icon: '🌟' },
    { id: 'science', name: 'العلوم', icon: '🔬' },
    { id: 'math', name: 'الرياضيات', icon: '📐' },
    { id: 'arabic', name: 'العربية', icon: '📚' },
  ];

  const lessons = [
    { id: 1, title: 'رحلة الماء في الطبيعة', subject: 'science', duration: '15 دقيقة', status: 'next' },
    { id: 2, title: 'الكسور المتكافئة', subject: 'math', duration: '20 دقيقة', status: 'new' },
    { id: 3, title: 'الفعل الماضي والمضارع', subject: 'arabic', duration: '10 دقائق', status: 'completed' },
    { id: 4, title: 'المجموعة الشمسية', subject: 'science', duration: '25 دقيقة', status: 'new' },
  ];

  const filteredLessons = activeSubject === 'all' 
    ? lessons 
    : lessons.filter(l => l.subject === activeSubject);

  return (
    <div 
      className="min-h-screen font-sans" 
      style={{ backgroundColor: colors.ivory, color: colors.darkPurple }}
      dir="rtl"
    >
      {/* Top Navigation Bar */}
      <nav className="sticky top-0 z-10 px-6 py-4 shadow-sm backdrop-blur-md" style={{ backgroundColor: 'rgba(250, 249, 246, 0.9)' }}>
        <div className="max-w-4xl mx-auto flex flex-col sm:flex-row justify-between items-center gap-4">
          <div className="flex items-center gap-3">
            <div className="w-12 h-12 rounded-full flex items-center justify-center text-white text-xl font-bold shadow-md" style={{ background: `linear-gradient(135deg, ${colors.mintDark}, ${colors.darkPurple})` }}>
              ل
            </div>
            <div>
              <h1 className="text-xl font-bold">مرحباً، ليان 👋</h1>
              <p className="text-sm opacity-70">المستوى 7 • البوصلة الهادئة</p>
            </div>
          </div>
          
          {/* Horizontal Indicators */}
          <div className="flex items-center gap-3 bg-white p-2 rounded-2xl shadow-sm border border-gray-100 overflow-x-auto w-full sm:w-auto">
            <div className="flex items-center gap-2 px-3 py-1 rounded-xl" style={{ backgroundColor: colors.lightPurple }}>
              <Star size={18} style={{ color: colors.gold }} className="fill-current" />
              <div className="flex flex-col">
                <span className="text-xs font-bold whitespace-nowrap">3240 / 3500</span>
                <div className="w-20 h-1.5 bg-white rounded-full mt-0.5 overflow-hidden">
                  <div className="h-full rounded-full" style={{ width: '92%', backgroundColor: colors.gold }}></div>
                </div>
              </div>
            </div>
            
            <div className="flex items-center gap-1.5 px-3 py-1.5 rounded-xl bg-orange-50 text-orange-600 font-bold">
              <Flame size={18} className="fill-current" />
              <span>12</span>
            </div>
            
            <div className="flex items-center gap-1.5 px-3 py-1.5 rounded-xl bg-emerald-50 text-emerald-600 font-bold">
              <Gem size={18} className="fill-current" />
              <span>86</span>
            </div>
          </div>
        </div>
      </nav>

      <main className="max-w-4xl mx-auto px-6 py-8 pb-24">
        
        {/* Continue Where You Left Off Card */}
        <section className="mb-10">
          <div className="flex items-center gap-2 mb-4">
            <Compass className="text-emerald-600" size={24} />
            <h2 className="text-2xl font-bold">وجهتك القادمة</h2>
          </div>
          
          <div 
            className="relative rounded-3xl p-6 sm:p-8 overflow-hidden shadow-lg transition-transform hover:-translate-y-1 duration-300"
            style={{ 
              background: `linear-gradient(120deg, ${colors.darkPurple}, #4a2b82)`,
              color: 'white'
            }}
          >
            {/* Decorative background elements */}
            <div className="absolute top-0 left-0 w-64 h-64 bg-white opacity-5 rounded-full blur-3xl -translate-x-1/2 -translate-y-1/2"></div>
            <div className="absolute bottom-0 right-0 w-48 h-48 bg-emerald-400 opacity-10 rounded-full blur-2xl translate-x-1/3 translate-y-1/3"></div>
            
            <div className="relative z-10 flex flex-col md:flex-row justify-between items-start md:items-center gap-6">
              <div className="space-y-4 max-w-lg">
                <span className="inline-block px-3 py-1 rounded-full text-xs font-bold uppercase tracking-wider" style={{ backgroundColor: colors.mint, color: colors.mintDark }}>
                  علوم • متابعة الدرس
                </span>
                <h3 className="text-3xl sm:text-4xl font-bold leading-tight">رحلة الماء في الطبيعة</h3>
                <p className="text-white/80 line-clamp-2">
                  تعرفي على كيفية تبخر الماء، وتكثفه، وهطوله في دورة مستمرة تحافظ على الحياة في كوكبنا.
                </p>
                
                <div className="flex items-center gap-4 text-sm font-medium text-white/90">
                  <span className="flex items-center gap-1.5"><Play size={16} /> المتبقي: 5 دقائق</span>
                  <span className="flex items-center gap-1.5"><Gem size={16} /> +15 جوهرة</span>
                </div>
              </div>
              
              <button 
                className="w-full md:w-auto flex items-center justify-center gap-2 px-8 py-4 rounded-2xl font-bold text-lg shadow-lg hover:shadow-xl hover:scale-105 active:scale-95 transition-all"
                style={{ backgroundColor: colors.mint, color: colors.mintDark }}
              >
                <Play className="fill-current" size={20} />
                بدء الاستكشاف
              </button>
            </div>
          </div>
        </section>

        {/* Tab Navigation */}
        <div className="flex gap-4 mb-8 overflow-x-auto pb-2 scrollbar-hide">
          <button 
            onClick={() => setActiveTab('lessons')}
            className={`flex items-center gap-2 px-6 py-3 rounded-2xl font-bold whitespace-nowrap transition-colors ${activeTab === 'lessons' ? 'shadow-sm' : 'opacity-70 hover:opacity-100'}`}
            style={{ 
              backgroundColor: activeTab === 'lessons' ? 'white' : 'transparent',
              color: activeTab === 'lessons' ? colors.darkPurple : 'inherit'
            }}
          >
            <Map size={20} /> خريطة الدروس
          </button>
          <button 
            onClick={() => setActiveTab('tasks')}
            className={`flex items-center gap-2 px-6 py-3 rounded-2xl font-bold whitespace-nowrap transition-colors ${activeTab === 'tasks' ? 'shadow-sm' : 'opacity-70 hover:opacity-100'}`}
            style={{ 
              backgroundColor: activeTab === 'tasks' ? 'white' : 'transparent',
              color: activeTab === 'tasks' ? colors.darkPurple : 'inherit'
            }}
          >
            <CheckCircle size={20} /> المهام (3)
          </button>
          <button 
            onClick={() => setActiveTab('achievements')}
            className={`flex items-center gap-2 px-6 py-3 rounded-2xl font-bold whitespace-nowrap transition-colors ${activeTab === 'achievements' ? 'shadow-sm' : 'opacity-70 hover:opacity-100'}`}
            style={{ 
              backgroundColor: activeTab === 'achievements' ? 'white' : 'transparent',
              color: activeTab === 'achievements' ? colors.darkPurple : 'inherit'
            }}
          >
            <Trophy size={20} /> الإنجازات
          </button>
        </div>

        {/* Tab Content */}
        {activeTab === 'lessons' && (
          <div className="space-y-6">
            {/* Subject Filters */}
            <div className="flex flex-wrap gap-3">
              {subjects.map(subject => (
                <button
                  key={subject.id}
                  onClick={() => setActiveSubject(subject.id)}
                  className={`flex items-center gap-2 px-5 py-2.5 rounded-full font-medium transition-all ${activeSubject === subject.id ? 'shadow-md scale-105' : 'hover:bg-white/50'}`}
                  style={{ 
                    backgroundColor: activeSubject === subject.id ? colors.darkPurple : colors.lightPurple,
                    color: activeSubject === subject.id ? 'white' : colors.darkPurple
                  }}
                >
                  <span>{subject.icon}</span>
                  {subject.name}
                </button>
              ))}
            </div>

            {/* Lesson List */}
            <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
              {filteredLessons.map(lesson => (
                <div 
                  key={lesson.id} 
                  className="group bg-white rounded-2xl p-5 shadow-sm hover:shadow-md transition-shadow border border-transparent hover:border-emerald-100 flex items-center justify-between cursor-pointer"
                >
                  <div className="flex items-center gap-4">
                    <div 
                      className={`w-14 h-14 rounded-2xl flex items-center justify-center text-2xl ${
                        lesson.status === 'completed' ? 'bg-gray-100' : 'bg-emerald-50'
                      }`}
                    >
                      {lesson.subject === 'science' ? '🔬' : lesson.subject === 'math' ? '📐' : '📚'}
                    </div>
                    <div>
                      <h4 className="font-bold text-lg mb-1 group-hover:text-emerald-700 transition-colors">{lesson.title}</h4>
                      <div className="flex items-center gap-3 text-sm text-gray-500 font-medium">
                        <span className="flex items-center gap-1"><BookOpen size={14} /> {subjects.find(s => s.id === lesson.subject)?.name}</span>
                        <span className="flex items-center gap-1">⏱️ {lesson.duration}</span>
                      </div>
                    </div>
                  </div>
                  
                  {lesson.status === 'completed' ? (
                    <div className="w-10 h-10 rounded-full bg-gray-50 flex items-center justify-center text-emerald-500">
                      <CheckCircle size={20} />
                    </div>
                  ) : lesson.status === 'next' ? (
                    <div className="w-10 h-10 rounded-full bg-emerald-100 flex items-center justify-center text-emerald-700 shadow-inner">
                      <Play className="fill-current" size={16} />
                    </div>
                  ) : (
                    <div className="w-10 h-10 rounded-full bg-gray-50 flex items-center justify-center text-gray-400 group-hover:bg-emerald-50 group-hover:text-emerald-600 transition-colors">
                      <ChevronLeft size={20} />
                    </div>
                  )}
                </div>
              ))}
            </div>
          </div>
        )}

        {activeTab === 'tasks' && (
          <div className="bg-white rounded-3xl p-6 shadow-sm border border-gray-100">
            <h3 className="text-xl font-bold mb-6 flex items-center gap-2">
              <Star className="text-yellow-500 fill-current" /> 
              مهام هذا الأسبوع
            </h3>
            <div className="space-y-4">
              {[
                { title: 'أكملي 3 دروس علوم', progress: 1, total: 3, reward: 50 },
                { title: 'احصلي على درجة كاملة في اختبار', progress: 0, total: 1, reward: 30 },
                { title: 'حافظي على الشعلة لـ 14 يوم', progress: 12, total: 14, reward: 100 },
              ].map((task, idx) => (
                <div key={idx} className="p-4 rounded-2xl bg-gray-50 flex flex-col sm:flex-row justify-between gap-4 items-start sm:items-center">
                  <div className="flex-1 w-full">
                    <div className="flex justify-between items-center mb-2">
                      <h4 className="font-bold">{task.title}</h4>
                      <span className="text-sm font-bold text-gray-500">{task.progress} / {task.total}</span>
                    </div>
                    <div className="w-full h-2 bg-gray-200 rounded-full overflow-hidden">
                      <div 
                        className="h-full rounded-full transition-all duration-1000" 
                        style={{ width: `${(task.progress / task.total) * 100}%`, backgroundColor: colors.mintDark }}
                      ></div>
                    </div>
                  </div>
                  <div className="flex items-center gap-1.5 px-3 py-1.5 bg-white rounded-xl shadow-sm text-sm font-bold text-emerald-600 shrink-0">
                    <Gem size={16} className="fill-current" />
                    +{task.reward}
                  </div>
                </div>
              ))}
            </div>
          </div>
        )}

        {activeTab === 'achievements' && (
          <div className="grid grid-cols-2 sm:grid-cols-4 gap-4">
            {[
              { title: 'بداية الرحلة', icon: '🚀', desc: 'أكملت أول درس', earned: true },
              { title: 'عالمة المستقبل', icon: '🔭', desc: '5 دروس علوم', earned: true },
              { title: 'شعلة النشاط', icon: '🔥', desc: '10 أيام متتالية', earned: true },
              { title: 'جامعة الجواهر', icon: '💎', desc: '50 جوهرة', earned: true },
              { title: 'عبقرية الرياضيات', icon: '🧮', desc: '5 دروس رياضيات', earned: false },
              { title: 'قارئة نهمة', icon: '📖', desc: '10 دروس لغة عربية', earned: false },
            ].map((badge, idx) => (
              <div 
                key={idx} 
                className={`flex flex-col items-center text-center p-5 rounded-3xl transition-all ${
                  badge.earned 
                    ? 'bg-white shadow-sm border border-emerald-100' 
                    : 'bg-gray-50 opacity-60 grayscale'
                }`}
              >
                <div className={`w-16 h-16 rounded-full flex items-center justify-center text-3xl mb-3 shadow-inner ${badge.earned ? 'bg-emerald-50' : 'bg-gray-200'}`}>
                  {badge.icon}
                </div>
                <h4 className="font-bold text-sm mb-1">{badge.title}</h4>
                <p className="text-xs text-gray-500">{badge.desc}</p>
              </div>
            ))}
          </div>
        )}
      </main>

      {/* Floating Bottom Nav (Mobile/Tablet focus) */}
      <div className="fixed bottom-6 left-1/2 -translate-x-1/2 w-[90%] max-w-sm bg-white rounded-full p-2 shadow-xl border border-gray-100 flex justify-between items-center z-50">
        <button className="flex-1 flex flex-col items-center justify-center py-2 text-emerald-600">
          <Compass size={24} className="mb-1" />
          <span className="text-[10px] font-bold">البوصلة</span>
        </button>
        <button className="flex-1 flex flex-col items-center justify-center py-2 text-gray-400 hover:text-emerald-600 transition-colors">
          <Gamepad2 size={24} className="mb-1" />
          <span className="text-[10px] font-bold">العب وتعلم</span>
        </button>
        <button className="flex-1 flex flex-col items-center justify-center py-2 text-gray-400 hover:text-emerald-600 transition-colors">
          <Award size={24} className="mb-1" />
          <span className="text-[10px] font-bold">المتجر</span>
        </button>
      </div>

    </div>
  );
}
