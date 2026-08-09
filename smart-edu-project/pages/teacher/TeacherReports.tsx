import React, { useState, useEffect } from 'react';
import { ParentInfo, StudentInfo, QuizResult } from '../../types';
import { STORAGE_KEYS } from '../../constants';
import { getTeacherParents, getTeacherStudents } from '../../utils/scope';
import { getStudentProgressSummary } from '../../utils/studentProgress';
import { normalizeQuizType } from '../../utils/quizTypes';
import { QuizType } from '../../types';

interface TeacherReportsProps {
  teacherId: string;
}

const TeacherReports: React.FC<TeacherReportsProps> = ({ teacherId }) => {
  const [parents, setParents] = useState<ParentInfo[]>([]);
  const [students, setStudents] = useState<StudentInfo[]>([]);
  const [quizResults, setQuizResults] = useState<QuizResult[]>([]);
  const [loading, setLoading] = useState(true);
  const [searchQuery, setSearchQuery] = useState('');

  useEffect(() => {
    loadData();
    const interval = window.setInterval(loadData, 2000);
    return () => window.clearInterval(interval);
  }, [teacherId]);

  const loadData = () => {
    try {
      // تحميل أولياء الأمور المرتبطين بهذا المعلم
      const allParents: ParentInfo[] = JSON.parse(localStorage.getItem(STORAGE_KEYS.PARENTS) || '[]');
       const teacherParents = getTeacherParents(allParents, teacherId);
      
      // تحميل الطلاب المرتبطين بأولياء أمور هذا المعلم
      const allStudents: StudentInfo[] = JSON.parse(localStorage.getItem(STORAGE_KEYS.STUDENTS) || '[]');
      const teacherStudents = getTeacherStudents(allStudents, teacherId, teacherParents);
      const allQuizResults: QuizResult[] = JSON.parse(
        localStorage.getItem(STORAGE_KEYS.QUIZ_RESULTS) || '[]',
      );

      setParents(teacherParents);
      setStudents(teacherStudents);
      setQuizResults(allQuizResults);
      setLoading(false);
    } catch (error) {
      console.error('Error loading data:', error);
      setLoading(false);
    }
  };

  const calculateStudentStats = (student: StudentInfo) => {
    const quizzes = quizResults.filter(quiz => quiz.studentId === student.id);
    const legacyQuizzes = student.quizResults || [];
    const effectiveQuizzes = quizzes.length > 0 ? quizzes : legacyQuizzes;
    const progress = getStudentProgressSummary(student, quizResults);
    const totalQuizzes = effectiveQuizzes.length;
    const avgScore = totalQuizzes > 0 
      ? effectiveQuizzes.reduce(
        (sum, quiz) => sum + (
          'percentage' in quiz
            ? quiz.percentage
            : quiz.total > 0 ? (quiz.score / quiz.total) * 100 : quiz.score
        ),
        0,
      ) / totalQuizzes
      : 0;
    
    return {
      totalQuizzes,
      avgScore: Math.round(avgScore),
      lastActivity: student.lastActivity || 'لا يوجد نشاط',
      gems: progress.gems,
      xp: progress.xp,
      level: progress.level,
      streak: progress.streak,
    };
  };

  const getParentName = (parentId?: string) => {
    const parent = parents.find(p => p.id === parentId);
    return parent?.name || 'غير معروف';
  };

  const getTeacherResults = (studentId: string) => quizResults
    .filter(quiz => quiz.studentId === studentId && normalizeQuizType(quiz.quizType) === QuizType.TEACHER)
    .sort((a, b) => new Date(b.createdAt).getTime() - new Date(a.createdAt).getTime());

  const printStudentReport = (student: StudentInfo) => {
    const stats = calculateStudentStats(student);
    const teacherResults = getTeacherResults(student.id);
    const parentName = getParentName(student.parentId);
    const date = new Date().toLocaleDateString('ar-SA', { year: 'numeric', month: 'long', day: 'numeric' });
    
    const printWindow = window.open('', '_blank');
    if (!printWindow) return;

    printWindow.document.write(`
      <!DOCTYPE html>
      <html dir="rtl" lang="ar">
        <head>
          <meta charset="UTF-8">
          <title>تقرير الطالب - ${student.name}</title>
          <style>
            body { font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; padding: 40px; max-width: 800px; margin: 0 auto; }
            .header { text-align: center; border-bottom: 3px solid #4F46E5; padding-bottom: 20px; margin-bottom: 30px; }
            .header h1 { color: #4F46E5; font-size: 32px; margin-bottom: 10px; }
            .info-section { background: #F3F4F6; padding: 20px; border-radius: 10px; margin-bottom: 20px; }
            .info-row { display: flex; justify-content: space-between; padding: 10px 0; border-bottom: 1px solid #E5E7EB; }
            .info-label { font-weight: bold; color: #6B7280; }
            .info-value { color: #111827; font-weight: 600; }
            .stats { display: grid; grid-template-columns: repeat(3, 1fr); gap: 20px; margin: 30px 0; }
            .stat-card { background: linear-gradient(135deg, #667EEA 0%, #764BA2 100%); color: white; padding: 20px; border-radius: 10px; text-align: center; }
            .stat-value { font-size: 36px; font-weight: bold; margin-bottom: 5px; }
            .stat-label { font-size: 14px; opacity: 0.9; }
            .footer { margin-top: 50px; text-align: center; color: #6B7280; font-size: 12px; }
            @media print { body { padding: 20px; } }
          </style>
        </head>
        <body>
          <div class="header">
            <h1>📊 تقرير الأداء الأكاديمي</h1>
            <p style="color: #6B7280;">منصة التعليم الذكي</p>
          </div>
          
          <div class="info-section">
            <div class="info-row">
              <span class="info-label">اسم الطالب:</span>
              <span class="info-value">${student.name}</span>
            </div>
            <div class="info-row">
              <span class="info-label">ولي الأمر:</span>
              <span class="info-value">${parentName}</span>
            </div>
            <div class="info-row">
              <span class="info-label">الصف:</span>
              <span class="info-value">${student.primaryGrade || student.grade || 'غير محدد'}</span>
            </div>
            <div class="info-row">
              <span class="info-label">تاريخ التقرير:</span>
              <span class="info-value">${date}</span>
            </div>
          </div>
          
          <div class="stats">
            <div class="stat-card">
              <div class="stat-value">${stats.totalQuizzes}</div>
              <div class="stat-label">عدد الاختبارات</div>
            </div>
            <div class="stat-card">
              <div class="stat-value">${stats.avgScore}%</div>
              <div class="stat-label">المعدل العام</div>
            </div>
            <div class="stat-card">
              <div class="stat-value">${stats.avgScore >= 90 ? 'ممتاز' : stats.avgScore >= 70 ? 'جيد جداً' : stats.avgScore >= 50 ? 'جيد' : 'يحتاج تحسين'}</div>
              <div class="stat-label">مستوى الأداء</div>
            </div>
            <div class="stat-card">
              <div class="stat-value">${stats.level}</div>
              <div class="stat-label">المستوى</div>
            </div>
            <div class="stat-card">
              <div class="stat-value">${stats.gems} 💎</div>
              <div class="stat-label">الجواهر</div>
            </div>
            <div class="stat-card">
              <div class="stat-value">${stats.xp} ⚡</div>
              <div class="stat-label">الخبرة</div>
            </div>
          </div>
          
          <div class="footer">
            <p>تم إنشاء هذا التقرير تلقائياً بواسطة منصة التعليم الذكي</p>
            <p>للاستفسارات يرجى التواصل مع إدارة المنصة</p>
          </div>
          
          <script>
            window.onload = function() {
              setTimeout(() => {
                window.print();
              }, 500);
            };
          </script>
        </body>
      </html>
    `);
    
    printWindow.document.close();
  };

  const filteredStudents = students.filter(student => {
    const search = searchQuery.toLowerCase();
    return student.name.toLowerCase().includes(search) ||
           getParentName(student.parentId).toLowerCase().includes(search) ||
           (student.primaryGrade || student.grade || '').toLowerCase().includes(search);
  });

  if (loading) {
    return (
      <div className="flex items-center justify-center h-64">
        <div className="text-xl text-gray-600">جاري تحميل التقارير...</div>
      </div>
    );
  }

  return (
    <div className="space-y-6">
      {/* العنوان */}
      <div className="bg-gradient-to-r from-amber-600 to-orange-600 p-6 rounded-2xl text-white shadow-lg">
        <h1 className="text-3xl font-black mb-2">📊 التقارير والإحصائيات</h1>
        <p className="text-purple-100 font-medium">
          تقارير الأداء الخاصة بطلابك فقط
        </p>
        
        {/* Search */}
        <div className="mt-4">
          <div className="relative">
            <input
              type="text"
              value={searchQuery}
              onChange={(e) => setSearchQuery(e.target.value)}
              placeholder="🔍 ابحث عن طالب بالاسم، ولي الأمر، أو الصف..."
              className="w-full p-4 pr-12 rounded-xl border-2 border-white/30 bg-white/10 text-white placeholder-white/70 focus:bg-white/20 focus:border-white outline-none font-bold text-lg backdrop-blur"
            />
            {searchQuery && (
              <button
                onClick={() => setSearchQuery('')}
                className="absolute left-4 top-1/2 -translate-y-1/2 bg-white/20 hover:bg-white/30 text-white px-3 py-1 rounded-lg font-bold text-sm transition-all"
              >
                ✖ مسح
              </button>
            )}
          </div>
        </div>
      </div>

      {/* إحصائيات عامة */}
      <div className="grid grid-cols-1 md:grid-cols-4 gap-6">
        <div className="bg-gradient-to-br from-blue-500 to-blue-600 p-6 rounded-2xl text-white shadow-lg">
          <div className="text-5xl mb-2">👨‍👩‍👧‍👦</div>
          <div className="text-3xl font-black">{parents.length}</div>
          <div className="text-blue-100 font-medium">ولي أمر</div>
        </div>

        <div className="bg-gradient-to-br from-green-500 to-green-600 p-6 rounded-2xl text-white shadow-lg">
          <div className="text-5xl mb-2">🎓</div>
          <div className="text-3xl font-black">{students.length}</div>
          <div className="text-green-100 font-medium">طالب</div>
        </div>

        <div className="bg-gradient-to-br from-purple-500 to-purple-600 p-6 rounded-2xl text-white shadow-lg">
          <div className="text-5xl mb-2">📝</div>
          <div className="text-3xl font-black">
            {students.reduce((sum, student) => sum + calculateStudentStats(student).totalQuizzes, 0)}
          </div>
          <div className="text-purple-100 font-medium">اختبار مكتمل</div>
        </div>

        <div className="bg-gradient-to-br from-amber-500 to-orange-500 p-6 rounded-2xl text-white shadow-lg">
          <div className="text-5xl mb-2">💎</div>
          <div className="text-3xl font-black">
            {students.reduce((sum, student) => sum + calculateStudentStats(student).gems, 0)}
          </div>
          <div className="text-amber-100 font-medium">إجمالي الجواهر</div>
        </div>

        <div className="bg-gradient-to-br from-cyan-500 to-sky-600 p-6 rounded-2xl text-white shadow-lg">
          <div className="text-5xl mb-2">⚡</div>
          <div className="text-3xl font-black">
            {students.reduce((sum, student) => sum + calculateStudentStats(student).xp, 0)}
          </div>
          <div className="text-cyan-100 font-medium">إجمالي الخبرة</div>
        </div>
      </div>

      {/* جدول الطلاب */}
      <div className="bg-white p-6 rounded-2xl shadow-lg">
        <h2 className="text-2xl font-black text-gray-800 mb-4">📋 تقارير الطلاب</h2>
        
        {students.length === 0 ? (
          <div className="text-center py-12 text-gray-500">
            <div className="text-6xl mb-4">📭</div>
            <p className="text-xl font-medium">لا يوجد طلاب حتى الآن</p>
            <p className="text-sm mt-2">قم بإنشاء حسابات أولياء أمور وطلاب أولاً</p>
          </div>
        ) : filteredStudents.length === 0 ? (
          <div className="text-center py-12 text-gray-500">
            <div className="text-6xl mb-4">🔍</div>
            <p className="text-xl font-medium">لا توجد نتائج للبحث</p>
          </div>
        ) : (
          <div className="overflow-x-auto">
            <table className="w-full">
              <thead>
                <tr className="bg-gray-100">
                  <th className="p-4 text-right font-black text-gray-700">اسم الطالب</th>
                  <th className="p-4 text-right font-black text-gray-700">ولي الأمر</th>
                  <th className="p-4 text-right font-black text-gray-700">الصف</th>
                  <th className="p-4 text-center font-black text-gray-700">عدد الاختبارات</th>
                  <th className="p-4 text-center font-black text-gray-700">المعدل</th>
                   <th className="p-4 text-center font-black text-gray-700">المستوى</th>
                   <th className="p-4 text-center font-black text-gray-700">اختبار المعلم</th>
                   <th className="p-4 text-center font-black text-gray-700">الجواهر</th>
                   <th className="p-4 text-center font-black text-gray-700">الخبرة</th>
                  <th className="p-4 text-right font-black text-gray-700">آخر نشاط</th>
                  <th className="p-4 text-center font-black text-gray-700">الإجراءات</th>
                </tr>
              </thead>
              <tbody>
                {filteredStudents.map((student) => {
                  const stats = calculateStudentStats(student);
                  const teacherResults = getTeacherResults(student.id);
                  return (
                    <tr key={student.id} className="border-b hover:bg-gray-50 transition-colors">
                      <td className="p-4 font-bold text-gray-800">{student.name}</td>
                      <td className="p-4 text-gray-600">{getParentName(student.parentId)}</td>
                      <td className="p-4 text-gray-600">{student.primaryGrade || student.grade}</td>
                      <td className="p-4 text-center">
                        <span className="bg-amber-100 text-blue-800 px-3 py-1 rounded-full font-bold">
                          {stats.totalQuizzes}
                        </span>
                      </td>
                      <td className="p-4 text-center">
                        <span 
                          className={`px-3 py-1 rounded-full font-bold ${
                            stats.avgScore >= 90 ? 'bg-green-100 text-green-800' :
                            stats.avgScore >= 70 ? 'bg-yellow-100 text-yellow-800' :
                            stats.avgScore >= 50 ? 'bg-orange-100 text-orange-800' :
                            'bg-red-100 text-red-800'
                          }`}
                        >
                          {stats.totalQuizzes > 0 ? `${stats.avgScore}%` : '-'}
                        </span>
                      </td>
                       <td className="p-4 text-center">
                        <span className="bg-indigo-100 text-indigo-800 px-3 py-1 rounded-full font-bold">
                          {stats.level}
                        </span>
                      </td>
                       <td className="p-4 text-center">
                         {teacherResults.length > 0 ? (
                           <div className="space-y-1">
                             {teacherResults.map((result) => (
                               <div key={result.id} className="bg-rose-100 text-rose-800 px-3 py-1 rounded-full font-bold text-xs">
                                 {result.quizTitle || 'اختبار المعلم'}: {result.percentage}%
                               </div>
                             ))}
                           </div>
                         ) : (
                           <span className="text-gray-400 font-bold">لم يُنجز</span>
                         )}
                       </td>
                      <td className="p-4 text-center">
                        <span className="bg-amber-100 text-amber-800 px-3 py-1 rounded-full font-bold">
                          💎 {stats.gems}
                        </span>
                      </td>
                      <td className="p-4 text-center">
                        <span className="bg-cyan-100 text-cyan-800 px-3 py-1 rounded-full font-bold">
                          ⚡ {stats.xp}
                        </span>
                      </td>
                      <td className="p-4 text-gray-600 text-sm">
                        {stats.lastActivity === 'لا يوجد نشاط' 
                          ? stats.lastActivity 
                          : new Date(stats.lastActivity).toLocaleDateString('ar-SA')}
                      </td>
                      <td className="p-4 text-center">
                        <button
                          onClick={() => printStudentReport(student)}
                          className="bg-amber-500 hover:bg-amber-600 text-white px-4 py-2 rounded-lg font-bold transition-all"
                          title="طباعة التقرير"
                        >
                          🖨️ طباعة
                        </button>
                      </td>
                    </tr>
                  );
                })}
              </tbody>
            </table>
          </div>
        )}
      </div>

      {/* تفاصيل أولياء الأمور */}
      <div className="bg-white p-6 rounded-2xl shadow-lg">
        <h2 className="text-2xl font-black text-gray-800 mb-4">👪 أولياء الأمور</h2>
        
        {parents.length === 0 ? (
          <div className="text-center py-12 text-gray-500">
            <div className="text-6xl mb-4">📭</div>
            <p className="text-xl font-medium">لا يوجد أولياء أمور حتى الآن</p>
          </div>
        ) : (
          <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
            {parents.map((parent) => {
              const parentStudents = students.filter(s => s.parentId === parent.id);
              return (
                <div 
                  key={parent.id}
                  className="bg-gradient-to-br from-amber-50 to-purple-50 p-6 rounded-2xl border-2 border-amber-200"
                >
                  <div className="text-4xl mb-2">👤</div>
                  <h3 className="text-xl font-black text-gray-800 mb-2">{parent.name}</h3>
                  <div className="space-y-1 text-sm">
                    <p className="text-gray-600">
                      📱 <span className="font-bold">{parent.phoneNumber}</span>
                    </p>
                    <p className="text-gray-600">
                      🎓 <span className="font-bold">{parentStudents.length}</span> طالب/طلاب
                    </p>
                    <p className="text-gray-500 text-xs mt-3">
                      تاريخ الإنشاء: {new Date(parent.createdAt).toLocaleDateString('ar-SA')}
                    </p>
                  </div>
                </div>
              );
            })}
          </div>
        )}
      </div>
    </div>
  );
};

export default TeacherReports;
