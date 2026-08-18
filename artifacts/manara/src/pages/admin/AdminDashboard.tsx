
import React, { useState, useEffect } from 'react';
import { AdminMenuType, SystemStats } from '../../types';
import { COLORS, STORAGE_KEYS } from '../../constants';
import AdminLogin from './AdminLogin';
import { playWelcomeAdult } from '../../utils/sounds';
import DashboardHome from './DashboardHome';
import AcademicSettings from './AcademicSettings';
import StudentManagement from './StudentManagement';
import TeacherManagement from './TeacherManagement';
import ContentManagement from './ContentManagement';
import VideoManagement from '../teacher/VideoManagement';
import QuizManagement from './QuizManagement';
import Reports from './Reports';
import SystemSettings from './SystemSettings';
import PermissionPackages from './PermissionPackages';
import AdminVideoNotifications from './AdminVideoNotifications';
import ManaraBrand from '../../components/ManaraBrand';
import VideoNotificationBadge from './VideoNotificationBadge';
import PrivateChat from '../shared/PrivateChat';
import { getQuizResultPercentage } from '../../utils/quizScoring';
import {
  readSessionValue,
  removeSessionValue,
  writeSessionValue,
  SESSION_KEYS,
} from '../../utils/sessionPersistence';
import { writeAuthSession } from '../../utils/authSession';

interface AdminDashboardProps {
  onLogout: () => void;
}

const AdminDashboard: React.FC<AdminDashboardProps> = ({ onLogout }) => {
  const [isAuthenticated, setIsAuthenticated] = useState(false);
  const [authLoading, setAuthLoading] = useState(true);
  const [activeMenu, setActiveMenu] = useState<AdminMenuType>(AdminMenuType.DASHBOARD);
  const [showChat, setShowChat] = useState(false);
  const [mobileNavOpen, setMobileNavOpen] = useState(false);
  const [stats, setStats] = useState<SystemStats>({
    totalStudents: 0,
    totalParents: 0,
    activeStudents: 0,
    totalQuizzesTaken: 0,
    averageQuizScore: 0,
    recentActivities: [],
    lessonsCount: 0,
    subjectsCount: 0,
    gradesCount: 0,
  });

  useEffect(() => {
    let mounted = true;
    fetch('/api/auth/admin/session', { credentials: 'same-origin' })
      .then((response) => {
        if (!response.ok) throw new Error(`Admin session check failed (${response.status})`);
        return response.json();
      })
      .then((result) => {
        if (!mounted) return;
        if (result.authenticated) {
          setIsAuthenticated(true);
        } else {
          // A definitive server response wins over an old local marker.
          removeSessionValue(SESSION_KEYS.ADMIN_SESSION);
          setIsAuthenticated(false);
        }
        setAuthLoading(false);
      })
      .catch(() => {
        if (!mounted) return;
        // A temporary network failure is not a logout.
        setIsAuthenticated(readSessionValue(SESSION_KEYS.ADMIN_SESSION) === '1');
        setAuthLoading(false);
      });
    return () => {
      mounted = false;
    };
  }, []);

  useEffect(() => {
    if (isAuthenticated) {
      refreshStats();
      const interval = window.setInterval(refreshStats, 5000);
      return () => window.clearInterval(interval);
    }
  }, [isAuthenticated]);

  const refreshStats = () => {
    const parseList = (key: string) => {
      try {
        const value = JSON.parse(localStorage.getItem(key) || '[]');
        return Array.isArray(value) ? value : [];
      } catch {
        return [];
      }
    };
    const students = parseList(STORAGE_KEYS.STUDENTS);
    const parents = parseList(STORAGE_KEYS.PARENTS);
    const quizzes = parseList(STORAGE_KEYS.QUIZ_RESULTS);
    const lessons = parseList(STORAGE_KEYS.LESSON_CONFIGS);
    const configs = parseList(STORAGE_KEYS.HIERARCHICAL_CONFIGS);
    const now = Date.now();
    const activeWindow = 7 * 24 * 60 * 60 * 1000;
    const activeStudents = students.filter((student: any) => {
      const timestamp = Date.parse(student.lastActivity || student.createdAt || '');
      return Number.isFinite(timestamp) && now - timestamp <= activeWindow;
    }).length;
    const recentActivities = students
      .filter((student: any) => student.lastActivity)
      .sort((a: any, b: any) => Date.parse(b.lastActivity) - Date.parse(a.lastActivity))
      .slice(0, 6)
      .map((student: any) => ({
        studentName: student.name || 'طالب',
        activity: 'آخر نشاط تعليمي',
        time: student.lastActivity,
        grade: student.primaryGrade || student.grade || '—',
      }));
    const grades = new Set<string>();
    const subjects = new Set<string>();
    configs.forEach((config: any) => {
      if (config.grade) grades.add(config.grade);
      config.atrams?.forEach((atram: any) =>
        atram.subjects?.forEach((subject: any) => {
          if (subject.subject) subjects.add(subject.subject);
        }),
      );
    });

    setStats({
      totalStudents: students.length,
      totalParents: parents.length,
      activeStudents,
      totalQuizzesTaken: quizzes.length,
      averageQuizScore: quizzes.length
        ? quizzes.reduce((total: number, quiz: any) => total + getQuizResultPercentage(quiz), 0) / quizzes.length
        : 0,
      recentActivities,
      lessonsCount: lessons.length,
      subjectsCount: subjects.size,
      gradesCount: grades.size,
    });
  };

  if (authLoading) {
    return <div className="flex min-h-screen items-center justify-center bg-slate-50 font-tajawal text-slate-700">جارٍ استعادة جلسة المشرف…</div>;
  }

  if (!isAuthenticated) {
    return <AdminLogin onLoginSuccess={() => {
      writeSessionValue(SESSION_KEYS.ADMIN_SESSION, '1');
      writeAuthSession('admin', 'admin');
      setIsAuthenticated(true);
      playWelcomeAdult();
    }} onBack={onLogout} />;
  }

  const renderContent = () => {
    switch (activeMenu) {
      case AdminMenuType.DASHBOARD: return <DashboardHome stats={stats} onRefresh={refreshStats} />;
      case AdminMenuType.ACADEMIC_SETTINGS: return <AcademicSettings onUpdate={refreshStats} />;
      case AdminMenuType.STUDENT_MANAGEMENT: return <StudentManagement onUpdate={refreshStats} />;
      case AdminMenuType.TEACHER_MANAGEMENT: return <TeacherManagement onUpdate={refreshStats} />;
      case AdminMenuType.CONTENT_MANAGEMENT: return <ContentManagement onUpdate={refreshStats} />;
      case 'VIDEO_MANAGEMENT' as AdminMenuType: return <VideoManagement isAdmin />;
      case AdminMenuType.QUIZ_MANAGEMENT: return <QuizManagement onUpdate={refreshStats} />;
      case AdminMenuType.REPORTS: return <Reports />;
      case AdminMenuType.SYSTEM_SETTINGS: return <SystemSettings />;
      case 'PERMISSION_PACKAGES' as AdminMenuType: return <PermissionPackages onUpdate={refreshStats} />;
      case 'VIDEO_NOTIFICATIONS' as AdminMenuType: return <AdminVideoNotifications />;
      default: return <DashboardHome stats={stats} onRefresh={refreshStats} />;
    }
  };

  return (
    <div className="min-h-screen w-full flex flex-col md:flex-row-reverse bg-gradient-to-br from-purple-50 to-violet-50 animate-fadeIn overflow-x-hidden">
      {/* Sidebar */}
      {mobileNavOpen && (
        <button
          type="button"
          aria-label="إغلاق القائمة"
          onClick={() => setMobileNavOpen(false)}
          className="fixed inset-0 z-40 bg-slate-950/60 md:hidden"
        />
      )}
       <aside className={`fixed inset-y-0 right-0 z-50 flex w-[min(20rem,88vw)] transform flex-col bg-gradient-to-b from-purple-800 via-purple-700 to-purple-600 text-white shadow-2xl transition-transform duration-300 md:sticky md:top-0 md:min-h-screen md:z-auto md:w-80 md:translate-x-0 ${mobileNavOpen ? 'translate-x-0' : 'translate-x-full'}`}>
        <div className="p-4 sm:p-8 border-b">
          <button type="button" onClick={() => setMobileNavOpen(false)} className="mb-3 rounded-xl bg-white/10 px-3 py-2 text-sm font-bold md:hidden">✕ إغلاق</button>
          <ManaraBrand variant="sidebar" className="text-white" />
          <p className="mt-2 text-center text-purple-200 text-xs font-bold">لوحة إدارة المشرف</p>
        </div>

        <nav className="flex-1 p-6 space-y-3 overflow-y-auto">
          {[
            { id: AdminMenuType.DASHBOARD, label: 'الرئيسية', icon: '📊' },
            { id: AdminMenuType.ACADEMIC_SETTINGS, label: 'الإعدادات الأكاديمية', icon: '🏫' },
            { id: AdminMenuType.STUDENT_MANAGEMENT, label: 'إدارة الحسابات', icon: '👥' },
            { id: AdminMenuType.TEACHER_MANAGEMENT, label: 'إدارة المعلمين', icon: '👨‍🏫' },
            { id: AdminMenuType.CONTENT_MANAGEMENT, label: 'إدارة المحتوى', icon: '📚' },
            { id: 'VIDEO_MANAGEMENT' as AdminMenuType, label: 'سينما منارة', icon: '🎬' },
            { id: AdminMenuType.QUIZ_MANAGEMENT, label: 'إدارة الاختبارات', icon: '📝' },
            { id: AdminMenuType.REPORTS, label: 'التقارير', icon: '📋' },
            { id: 'PERMISSION_PACKAGES' as AdminMenuType, label: 'إدارة الصلاحيات', icon: '🔐' },
            { id: 'VIDEO_NOTIFICATIONS' as AdminMenuType, label: 'إشعارات الفيديو', icon: '📢' },
            { id: AdminMenuType.SYSTEM_SETTINGS, label: 'إعدادات النظام', icon: '⚙️' },
          ].map((item) => (
            <button
              key={item.id}
              onClick={() => { setActiveMenu(item.id); setMobileNavOpen(false); }}
              className={`w-full text-right p-4 rounded-2xl transition-all flex items-center gap-3 hover:translate-x-[-2px] active:scale-95 ${
                activeMenu === item.id
                ? 'bg-white/10 text-white shadow-lg font-bold'
                : 'text-purple-100 hover:bg-white/5'
              }`}
            >
              <span className="text-xl">{item.icon}</span>
              <span>{item.label}</span>
            </button>
          ))}
          
          {/* زر الدردشة */}
          <button
            onClick={() => { setShowChat(true); setMobileNavOpen(false); }}
            className="w-full p-4 rounded-2xl text-purple-100 hover:bg-white/5 font-bold transition-colors flex items-center justify-start gap-3"
          >
            <span className="text-xl">💬</span>
            <span>الدردشة مع المعلمين وأولياء الأمور</span>
          </button>
        </nav>

        <div className="p-4 border-t">
          <button
            onClick={onLogout}
            className="w-full p-4 rounded-2xl text-red-500 hover:bg-red-50 font-bold transition-all flex items-center justify-center gap-2 hover:scale-[1.02] active:scale-95"
          >
            <span>🚪</span>
            <span>تسجيل الخروج</span>
          </button>
        </div>
      </aside>

      {/* Main Area */}
      <main className="min-w-0 flex-1 flex flex-col">
        <header className="bg-white border-b px-4 sm:px-6 lg:px-10 py-3 sm:py-4 flex flex-wrap justify-between items-center gap-3 shrink-0 safe-area-top">
          <div className="flex items-center gap-6">
             <button type="button" onClick={() => setMobileNavOpen(true)} className="rounded-xl bg-purple-100 px-3 py-2 text-purple-800 font-black md:hidden" aria-label="فتح القائمة">☰</button>
             <div className="bg-purple-50 px-4 py-2 rounded-full border border-purple-100 flex items-center gap-2">
                <span className="w-2 h-2 bg-green-500 rounded-full animate-pulse"></span>
                <span className="text-xs font-bold text-purple-700">النظام نشط</span>
             </div>
          </div>
          <div className="flex flex-wrap items-center justify-end gap-2 sm:gap-4 min-w-0">
            {/* 🔔 Video Notifications Bell */}
            <VideoNotificationBadge onClick={() => setActiveMenu('VIDEO_NOTIFICATIONS' as AdminMenuType)} />
            <div className="text-left">
              <p className="text-sm font-bold text-purple-800">مشرف النظام</p>
              <p className="text-[10px] text-purple-400">آخر دخول: منذ دقائق</p>
            </div>
            <button
              type="button"
              onClick={() => alert('تتم إدارة كلمة مرور المشرف من Replit Secrets عبر ADMIN_PASSWORD.')}
              className="px-3 py-2 bg-purple-100 text-purple-800 rounded-md font-bold hover:bg-purple-200 whitespace-normal text-xs sm:text-sm"
            >
              🔐 إدارة كلمة المرور
            </button>
            <div className="w-10 h-10 bg-purple-100 rounded-full flex items-center justify-center text-xl">👤</div>
          </div>
        </header>

        <div className="min-w-0 flex-1 min-h-screen overflow-y-auto p-6 sm:p-7 lg:p-10 space-y-6 safe-area-x safe-area-bottom">
          <div className="max-w-7xl mx-auto">
            {renderContent()}
          </div>
        </div>
      </main>

      {/* Private Chat */}
      {showChat && (
        <PrivateChat
          currentUserId="admin"
          currentUserName="المشرف"
          currentUserRole="admin"
          onClose={() => setShowChat(false)}
        />
      )}
    </div>
  );
};

export default AdminDashboard;
