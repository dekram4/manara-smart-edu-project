
import React from 'react';
import { SystemStats } from '../../types';
import { COLORS } from '../../constants';

interface DashboardHomeProps {
  stats: SystemStats;
  onRefresh: () => void;
}

const DashboardHome: React.FC<DashboardHomeProps> = ({ stats, onRefresh }) => {
  const cards = [
    { label: 'إجمالي الطلاب', value: stats.totalStudents, icon: '👨‍🎓', color: 'bg-blue-50 text-blue-600' },
    { label: 'طلاب نشطون خلال 7 أيام', value: stats.activeStudents, icon: '⚡', color: 'bg-cyan-50 text-cyan-600' },
    { label: 'أولياء الأمور', value: stats.totalParents, icon: '👨‍👩‍👧‍👦', color: 'bg-green-50 text-green-600' },
    { label: 'الدروس المضافة', value: stats.lessonsCount, icon: '📚', color: 'bg-purple-50 text-purple-600' },
    { label: 'الاختبارات المنجزة', value: stats.totalQuizzesTaken, icon: '📝', color: 'bg-orange-50 text-orange-600' },
  ];

  return (
    <div className="space-y-10 animate-fadeIn">
      <div className="flex justify-between items-end">
        <div>
          <h1 className="text-4xl font-black text-purple-900">نظرة عامة</h1>
          <p className="text-purple-500 mt-2">إليك ملخص سريع لأداء المنصة التعليمية اليوم</p>
        </div>
        <button 
          onClick={onRefresh}
          className="bg-white border p-3 rounded-xl hover:bg-purple-50 transition-colors shadow-sm text-purple-600 font-bold flex items-center gap-2"
        >
          <span>🔄</span>
          تحديث البيانات
        </button>
      </div>

      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-5 gap-6">
        {cards.map((card, i) => (
          <div key={i} className="bg-white p-8 rounded-[32px] shadow-sm border border-purple-100 flex flex-col items-center text-center">
            <div className={`w-16 h-16 rounded-2xl ${card.color} flex items-center justify-center text-3xl mb-4`}>
              {card.icon}
            </div>
            <p className="text-purple-400 font-medium text-sm">{card.label}</p>
            <p className="text-4xl font-black text-purple-900 mt-1">{card.value}</p>
          </div>
        ))}
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-2 gap-8">
        <div className="bg-white p-8 rounded-[32px] shadow-sm border border-purple-100">
           <h3 className="text-xl font-bold mb-6 flex items-center gap-2">
             <span>🚀</span> التوزيع الأكاديمي
           </h3>
           <div className="space-y-4">
              <div className="flex justify-between items-center p-4 bg-purple-50 rounded-2xl">
                 <span className="font-bold">الصفوف الدراسية</span>
                 <span className="bg-white px-3 py-1 rounded-lg border font-black">{stats.gradesCount}</span>
              </div>
              <div className="flex justify-between items-center p-4 bg-purple-50 rounded-2xl">
                 <span className="font-bold">المواد المسجلة</span>
                 <span className="bg-white px-3 py-1 rounded-lg border font-black">{stats.subjectsCount}</span>
              </div>
           </div>
        </div>

        <div className="bg-purple-800 p-8 rounded-[32px] shadow-xl text-white relative overflow-hidden">
           <div className="relative z-10">
             <h3 className="text-xl font-bold mb-2">متوسط النتائج</h3>
             <p className="text-purple-300 text-sm mb-6">معدل نجاح الطلاب في جميع الاختبارات</p>
             <div className="text-6xl font-black">{stats.averageQuizScore.toFixed(1)}%</div>
           </div>
           <div className="absolute -bottom-10 -right-10 text-[180px] opacity-10 pointer-events-none">📊</div>
        </div>
      </div>

       <div className="bg-white p-8 rounded-[32px] shadow-sm border border-purple-100">
         <div className="flex items-center justify-between mb-6">
           <h3 className="text-xl font-bold flex items-center gap-2">
             <span>🕘</span> آخر نشاط للطلاب
           </h3>
           <span className="text-xs font-bold text-purple-400">آخر 6 أنشطة</span>
         </div>
         {stats.recentActivities.length > 0 ? (
           <div className="grid grid-cols-1 md:grid-cols-2 gap-3">
             {stats.recentActivities.map((activity, index) => (
               <div key={`${activity.studentName}-${activity.time}-${index}`} className="flex items-center justify-between gap-4 p-4 bg-purple-50 rounded-2xl">
                 <div className="min-w-0">
                   <p className="font-black text-purple-900 truncate">{activity.studentName}</p>
                   <p className="text-xs text-purple-500">{activity.activity} · الصف {activity.grade}</p>
                 </div>
                 <time className="text-[11px] text-purple-400 shrink-0" dateTime={activity.time}>
                   {new Date(activity.time).toLocaleDateString('ar-SA')}
                 </time>
               </div>
             ))}
           </div>
         ) : (
           <div className="p-6 rounded-2xl bg-purple-50 text-center text-purple-500 font-bold">
             لا توجد أنشطة مسجلة حتى الآن
           </div>
         )}
       </div>
    </div>
  );
};

export default DashboardHome;
