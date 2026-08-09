
import React, { useState, useEffect } from 'react';
import { TeacherInfo, TeacherMenuType, ParentInfo, StudentInfo, LessonConfig } from '../../types';
import { COLORS, STORAGE_KEYS } from '../../constants';
import TeacherLogin from './TeacherLogin';
import MyAccount from './MyAccount';
import MyAcademicSettings from './MyAcademicSettings';
import TeacherContentManagement from './TeacherContentManagement';
import VideoManagement from './VideoManagement';
import ParentStudentManagement from './ParentStudentManagement';
import TeacherReports from './TeacherReports';
import TeacherCertificates from './TeacherCertificates';
import QuizManagement from '../admin/QuizManagement';
import { getTeacherPermissions } from '../../permissions';
import PrivateChat from '../shared/PrivateChat';
import { playWelcomeAdult } from '../../utils/sounds';
import { getTeacherParents, getTeacherStudents, getRecordTeacherId, normalizeScopeValue } from '../../utils/scope';
import ManaraBrand from '../../components/ManaraBrand';

interface TeacherDashboardProps {
  onLogout: () => void;
}

const TeacherDashboard: React.FC<TeacherDashboardProps> = ({ onLogout }) => {
  const [isAuthenticated, setIsAuthenticated] = useState(false);
  const [currentTeacher, setCurrentTeacher] = useState<TeacherInfo | null>(null);
  const [activeMenu, setActiveMenu] = useState(TeacherMenuType.DASHBOARD);
  const [showChat, setShowChat] = useState(false);
  const [dashboardStats, setDashboardStats] = useState({
    parentsCount: 0,
    studentsCount: 0,
    lessonsCount: 0,
    academicSettingsCount: 0,
  });

  useEffect(() => {
    if (isAuthenticated && currentTeacher) {
      loadDashboardStats();
      const interval = window.setInterval(loadDashboardStats, 2000);
      return () => window.clearInterval(interval);
    }
  }, [isAuthenticated, currentTeacher]);

  const loadDashboardStats = () => {
    if (!currentTeacher) return;

    // Load parents
    const allParents: ParentInfo[] = JSON.parse(localStorage.getItem(STORAGE_KEYS.PARENTS) || '[]');
     const teacherParents = getTeacherParents(allParents, currentTeacher.id);

    // Load students
    const allStudents: StudentInfo[] = JSON.parse(localStorage.getItem(STORAGE_KEYS.STUDENTS) || '[]');
     const teacherStudents = getTeacherStudents(allStudents, currentTeacher.id, teacherParents);

    // Load lessons
    const allLessons: LessonConfig[] = JSON.parse(localStorage.getItem(STORAGE_KEYS.LESSON_CONFIGS) || '[]');
    const teacherLessons = allLessons.filter(l =>
      getRecordTeacherId(l) === normalizeScopeValue(currentTeacher.id)
    );

    // Load academic settings
    const hierarchicalConfigs = JSON.parse(localStorage.getItem(STORAGE_KEYS.HIERARCHICAL_CONFIGS) || '[]');
    const teacherConfigs = hierarchicalConfigs.filter((c: any) =>
      getRecordTeacherId(c) === normalizeScopeValue(currentTeacher.id)
    );

    setDashboardStats({
      parentsCount: teacherParents.length,
      studentsCount: teacherStudents.length,
      lessonsCount: teacherLessons.length,
      academicSettingsCount: teacherConfigs.length,
    });
  };

  if (!isAuthenticated || !currentTeacher) {
    return <TeacherLogin onLoginSuccess={(teacher) => {
      setCurrentTeacher(teacher);
      setIsAuthenticated(true);
      playWelcomeAdult();
    }} onBack={onLogout} />;
  }

  const handleLogout = () => {
    setIsAuthenticated(false);
    setCurrentTeacher(null);
    localStorage.removeItem(STORAGE_KEYS.CURRENT_TEACHER);
    onLogout();
  };

  const renderContent = () => {
    switch (activeMenu) {
      case TeacherMenuType.DASHBOARD:
        return (
          <div className="space-y-8">
            {/* Header */}
            <div className="bg-gradient-to-r from-amber-500 to-orange-500 p-8 rounded-[40px] shadow-2xl text-white">
              <div className="flex items-center justify-between">
                <div>
                  <h1 className="text-4xl font-black mb-2">👋 مرحباً {currentTeacher.name}</h1>
                  <p className="text-amber-100 text-lg font-medium">مرحباً بك في منصة التعليم الذكي. استخدم القائمة الجانبية للوصول إلى جميع الأدوات.</p>
                </div>
                <div className="text-6xl opacity-20">🏠</div>
              </div>
            </div>

            {/* Statistics Cards */}
            <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6">
              {/* Parents Card */}
              <div className="bg-gradient-to-br from-purple-50 to-purple-100 p-6 rounded-[30px] shadow-lg border-2 border-purple-200 hover:shadow-xl transition-all hover:scale-105 cursor-pointer"
                   onClick={() => setActiveMenu(TeacherMenuType.ACCOUNT_MANAGEMENT)}>
                <div className="flex items-center justify-between mb-4">
                  <div className="text-4xl">👨‍👩‍👧‍👦</div>
                  <div className="bg-purple-500 text-white px-3 py-1 rounded-full text-sm font-bold">
                    {dashboardStats.parentsCount}
                  </div>
                </div>
                <h3 className="text-purple-900 font-black text-xl mb-1">أولياء الأمور</h3>
                <p className="text-purple-600 text-sm font-medium">إجمالي أولياء الأمور المسجلين</p>
              </div>

              {/* Students Card */}
              <div className="bg-gradient-to-br from-blue-50 to-blue-100 p-6 rounded-[30px] shadow-lg border-2 border-amber-200 hover:shadow-xl transition-all hover:scale-105 cursor-pointer"
                   onClick={() => setActiveMenu(TeacherMenuType.ACCOUNT_MANAGEMENT)}>
                <div className="flex items-center justify-between mb-4">
                  <div className="text-4xl">👨‍🎓</div>
                  <div className="bg-amber-500 text-white px-3 py-1 rounded-full text-sm font-bold">
                    {dashboardStats.studentsCount}
                  </div>
                </div>
                <h3 className="text-blue-900 font-black text-xl mb-1">الطلاب</h3>
                <p className="text-amber-500 text-sm font-medium">إجمالي الطلاب المسجلين</p>
              </div>

              {/* Lessons Card */}
              <div className="bg-gradient-to-br from-green-50 to-green-100 p-6 rounded-[30px] shadow-lg border-2 border-green-200 hover:shadow-xl transition-all hover:scale-105 cursor-pointer"
                   onClick={() => setActiveMenu(TeacherMenuType.CONTENT_MANAGEMENT)}>
                <div className="flex items-center justify-between mb-4">
                  <div className="text-4xl">📚</div>
                  <div className="bg-green-500 text-white px-3 py-1 rounded-full text-sm font-bold">
                    {dashboardStats.lessonsCount}
                  </div>
                </div>
                <h3 className="text-green-900 font-black text-xl mb-1">المحتوى التعليمي</h3>
                <p className="text-green-600 text-sm font-medium">إجمالي الدروس المضافة</p>
              </div>

              {/* Academic Settings Card */}
              <div className="bg-gradient-to-br from-orange-50 to-orange-100 p-6 rounded-[30px] shadow-lg border-2 border-orange-200 hover:shadow-xl transition-all hover:scale-105 cursor-pointer"
                   onClick={() => setActiveMenu(TeacherMenuType.ACADEMIC_SETTINGS)}>
                <div className="flex items-center justify-between mb-4">
                  <div className="text-4xl">⚙️</div>
                  <div className="bg-orange-500 text-white px-3 py-1 rounded-full text-sm font-bold">
                    {dashboardStats.academicSettingsCount}
                  </div>
                </div>
                <h3 className="text-orange-900 font-black text-xl mb-1">الإعدادات الأكاديمية</h3>
                <p className="text-orange-600 text-sm font-medium">إعدادات الصفوف والمواد</p>
              </div>
            </div>

            {/* Quick Actions */}
            <div className="bg-white p-8 rounded-[40px] shadow-lg border-2 border-amber-200">
              <h2 className="text-2xl font-black text-amber-900 mb-6 flex items-center gap-3">
                <span className="text-3xl">⚡</span>
                إجراءات سريعة
              </h2>
              <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
                <button
                  onClick={() => setActiveMenu(TeacherMenuType.ACCOUNT_MANAGEMENT)}
                  className="bg-gradient-to-r from-purple-500 to-purple-600 hover:from-purple-600 hover:to-purple-700 text-white p-6 rounded-[25px] font-bold text-lg transition-all shadow-md hover:shadow-xl hover:scale-[1.02] hover:-translate-y-1 flex items-center gap-4 active:scale-95"
                >
                  <span className="text-3xl">➕</span>
                  <span>إضافة ولي أمر / طالب</span>
                </button>

                <button
                  onClick={() => setActiveMenu(TeacherMenuType.CONTENT_MANAGEMENT)}
                  className="bg-gradient-to-r from-green-500 to-green-600 hover:from-green-600 hover:to-green-700 text-white p-6 rounded-[25px] font-bold text-lg transition-all shadow-md hover:shadow-xl hover:scale-[1.02] hover:-translate-y-1 flex items-center gap-4 active:scale-95"
                >
                  <span className="text-3xl">📖</span>
                  <span>إضافة محتوى تعليمي</span>
                </button>

                <button
                  onClick={() => setActiveMenu(TeacherMenuType.ACADEMIC_SETTINGS)}
                  className="bg-gradient-to-r from-orange-500 to-orange-600 hover:from-orange-600 hover:to-orange-700 text-white p-6 rounded-[25px] font-bold text-lg transition-all shadow-md hover:shadow-xl hover:scale-[1.02] hover:-translate-y-1 flex items-center gap-4 active:scale-95"
                >
                  <span className="text-3xl">🔧</span>
                  <span>إدارة الإعدادات</span>
                </button>

                <button
                  onClick={() => setActiveMenu(TeacherMenuType.REPORTS)}
                  className="bg-gradient-to-r from-blue-500 to-blue-600 hover:from-blue-600 hover:to-blue-700 text-white p-6 rounded-[25px] font-bold text-lg transition-all shadow-md hover:shadow-xl hover:scale-[1.02] hover:-translate-y-1 flex items-center gap-4 active:scale-95"
                >
                  <span className="text-3xl">📊</span>
                  <span>عرض التقارير</span>
                </button>

                <button
                  onClick={() => setActiveMenu(TeacherMenuType.MY_ACCOUNT)}
                  className="bg-gradient-to-r from-amber-500 to-amber-600 hover:from-amber-600 hover:to-orange-700 text-white p-6 rounded-[25px] font-bold text-lg transition-all shadow-md hover:shadow-xl hover:scale-[1.02] hover:-translate-y-1 flex items-center gap-4 active:scale-95"
                >
                  <span className="text-3xl">👤</span>
                  <span>إعدادات الحساب</span>
                </button>

                <button
                  onClick={loadDashboardStats}
                  className="bg-gradient-to-r from-orange-400 to-amber-500 hover:from-orange-500 hover:to-amber-600 text-white p-6 rounded-[25px] font-bold text-lg transition-all shadow-md hover:shadow-xl hover:scale-[1.02] hover:-translate-y-1 flex items-center gap-4 active:scale-95"
                >
                  <span className="text-3xl">🔄</span>
                  <span>تحديث البيانات</span>
                </button>
              </div>
            </div>

            {/* Welcome Message */}
            <div className="bg-gradient-to-br from-amber-50 to-orange-50 p-8 rounded-[40px] border-2 border-amber-200 shadow-lg">
              <div className="flex items-start gap-4">
                <div className="text-5xl">💡</div>
                <div>
                  <h3 className="text-2xl font-black text-amber-800 mb-3">نصائح للبداية</h3>
                  <ul className="space-y-2 text-amber-700 font-medium">
                    <li className="flex items-start gap-2">
                      <span className="text-amber-500 font-black">1.</span>
                      <span>ابدأ بإنشاء الإعدادات الأكاديمية (الصفوف والمواد والفصول)</span>
                    </li>
                    <li className="flex items-start gap-2">
                      <span className="text-amber-500 font-black">2.</span>
                      <span>أضف أولياء الأمور وربطهم بالطلاب</span>
                    </li>
                    <li className="flex items-start gap-2">
                      <span className="text-amber-500 font-black">3.</span>
                      <span>أنشئ المحتوى التعليمي والاختبارات</span>
                    </li>
                    <li className="flex items-start gap-2">
                      <span className="text-amber-500 font-black">4.</span>
                      <span>تابع تقدم الطلاب من خلال التقارير</span>
                    </li>
                  </ul>
                </div>
              </div>
            </div>
          </div>
        );
      case TeacherMenuType.ACADEMIC_SETTINGS:
        return <MyAcademicSettings />;
      case TeacherMenuType.CONTENT_MANAGEMENT:
         return <TeacherContentManagement teacherId={currentTeacher.id} teacherName={currentTeacher.name} permissionPackageId={currentTeacher.permissionPackageId} />;
      case TeacherMenuType.QUIZ_MANAGEMENT:
        return <QuizManagement onUpdate={loadDashboardStats} teacherId={currentTeacher.id} teacherName={currentTeacher.name} />;
      case TeacherMenuType.ACCOUNT_MANAGEMENT:
         return <ParentStudentManagement teacherId={currentTeacher.id} teacherName={currentTeacher.name} permissionPackageId={currentTeacher.permissionPackageId} />;
      case TeacherMenuType.REPORTS:
        return <TeacherReports teacherId={currentTeacher.id} />;
      case TeacherMenuType.CERTIFICATES:
        return <TeacherCertificates teacherId={currentTeacher.id} teacherName={currentTeacher.name} />;
      case TeacherMenuType.VIDEO_MANAGEMENT:
         return <VideoManagement teacherId={currentTeacher.id} teacherName={currentTeacher.name} permissionPackageId={currentTeacher.permissionPackageId} />;
      case TeacherMenuType.MY_ACCOUNT:
        return <MyAccount teacher={currentTeacher} onUpdate={(updated) => setCurrentTeacher(updated)} />;
      default:
        return null;
    }
  };

  return (
    <div className="min-h-screen bg-gradient-to-br from-amber-50 to-orange-50 flex animate-fadeIn">
      {/* Sidebar */}
      <div className="w-80 bg-gradient-to-b from-amber-800 to-amber-900 text-white p-6 flex flex-col shadow-2xl">
        <div className="flex items-center gap-3 mb-6 pb-6 border-b border-white/10">
          <ManaraBrand variant="sidebar" className="text-white" />
        </div>
        <div className="mb-8">
          <div className="flex items-center gap-3 mb-2">
            <div className="w-16 h-16 bg-white rounded-full flex items-center justify-center text-4xl animate-float">
              👨‍🏫
            </div>
            <div>
              <h2 className="text-xl font-black">{currentTeacher.name}</h2>
              <p className="text-blue-200 text-sm">معلم</p>
            </div>
          </div>
        </div>

        <nav className="flex-1 space-y-2">
          {Object.values(TeacherMenuType).map((menu) => {
            // فحص الصلاحيات
            const permissions = getTeacherPermissions(currentTeacher);
            
            // إخفاء الخيارات بناءً على الصلاحيات
            if (menu === TeacherMenuType.ACADEMIC_SETTINGS && !permissions.canManageAcademicSettings) {
              return null;
            }
            if (menu === TeacherMenuType.CONTENT_MANAGEMENT && !permissions.canManageContent) {
              return null;
            }
            if (menu === TeacherMenuType.VIDEO_MANAGEMENT && !permissions.canManageVideos) {
              return null;
            }
            if (menu === TeacherMenuType.QUIZ_MANAGEMENT && !permissions.canManageQuizzes) {
              return null;
            }
            if (menu === TeacherMenuType.ACCOUNT_MANAGEMENT && 
                !permissions.canCreateParents && !permissions.canCreateStudents) {
              return null;
            }
            if (menu === TeacherMenuType.REPORTS && !permissions.canViewReports) {
              return null;
            }
            
            const icons: Record<TeacherMenuType, string> = {
              [TeacherMenuType.DASHBOARD]: '🏠',
              [TeacherMenuType.ACADEMIC_SETTINGS]: '⚙️',
              [TeacherMenuType.CONTENT_MANAGEMENT]: '📚',
              [TeacherMenuType.VIDEO_MANAGEMENT]: '🎬',
              [TeacherMenuType.QUIZ_MANAGEMENT]: '📝',
              [TeacherMenuType.ACCOUNT_MANAGEMENT]: '👥',
              [TeacherMenuType.REPORTS]: '📊',
              [TeacherMenuType.CERTIFICATES]: '🏆',
              [TeacherMenuType.MY_ACCOUNT]: '👤'
            };

            const labels: Record<TeacherMenuType, string> = {
              [TeacherMenuType.DASHBOARD]: 'الصفحة الرئيسية',
              [TeacherMenuType.ACADEMIC_SETTINGS]: 'الإعدادات الأكاديمية',
              [TeacherMenuType.CONTENT_MANAGEMENT]: 'إدارة المحتوى',
              [TeacherMenuType.VIDEO_MANAGEMENT]: 'فيديوهاتي',
              [TeacherMenuType.QUIZ_MANAGEMENT]: 'إدارة الاختبارات',
              [TeacherMenuType.ACCOUNT_MANAGEMENT]: 'إدارة الحسابات',
              [TeacherMenuType.REPORTS]: 'التقارير',
              [TeacherMenuType.CERTIFICATES]: 'الشهادات',
              [TeacherMenuType.MY_ACCOUNT]: 'حسابي'
            };

            return (
              <button
                key={menu}
                onClick={() => setActiveMenu(menu)}
                className={`w-full text-right p-4 rounded-[20px] font-bold text-lg transition-all hover:translate-x-[-2px] active:scale-95 ${
                  activeMenu === menu
                    ? 'bg-white text-amber-800 shadow-lg'
                    : 'hover:bg-white/10'
                }`}
              >
                <span className="mr-3">{icons[menu]}</span>
                {labels[menu]}
              </button>
            );
          })}
          
          {/* زر الدردشة */}
          <button
            onClick={() => setShowChat(true)}
            className="w-full text-right p-4 rounded-[20px] font-bold text-lg transition-all hover:bg-white/10 hover:translate-x-[-2px] active:scale-95"
          >
            <span className="mr-3">💬</span>
            الدردشة والدعم
          </button>
        </nav>

        <button
          onClick={handleLogout}
          className="w-full bg-red-500 hover:bg-red-600 text-white p-4 rounded-[20px] font-bold text-lg transition-all mt-4 hover:scale-[1.02] active:scale-95"
        >
          🚪 تسجيل الخروج
        </button>
      </div>

      {/* Main Content */}
      <div className="flex-1 p-8 overflow-y-auto">
        {renderContent()}
      </div>

      {/* Private Chat */}
      {showChat && currentTeacher && (
        <PrivateChat
          currentUserId={currentTeacher.id}
          currentUserName={currentTeacher.name}
          currentUserRole="teacher"
          onClose={() => setShowChat(false)}
        />
      )}
    </div>
  );
};

export default TeacherDashboard;
