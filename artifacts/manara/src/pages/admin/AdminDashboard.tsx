
import { subjectsOfConfig } from '../../utils/academic';
import React, { useState, useEffect } from 'react';
import { AdminMenuType, SystemStats } from '../../types';
import { COLORS, STORAGE_KEYS } from '../../constants';
import AdminLogin from './AdminLogin';
import { refreshSupabaseSync } from '../../db/sync';
import { clearLoggedOut, endServerSession, isLoggedOut } from '../../utils/logoutGuard';
import { playWelcomeAdult } from '../../utils/sounds';
import DashboardHome from './DashboardHome';
import AcademicSettings from './AcademicSettings';
import StudentManagement from './StudentManagement';
import TeacherManagement from './TeacherManagement';
import ContentManagement from './ContentManagement';
import VideoManagement from '../teacher/VideoManagement';
import EntertainmentManagement from './EntertainmentManagement';
import QuizManagement from './QuizManagement';
import Reports from './Reports';
import SystemSettings from './SystemSettings';
import PermissionPackages from './PermissionPackages';
import AdminVideoNotifications from './AdminVideoNotifications';
import DuelQuestionReview from '../shared/DuelQuestionReview';
import CardPermissions from '../shared/CardPermissions';
import TeacherCertificates from '../teacher/TeacherCertificates';
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
import { useDashboardPage } from '../../hooks/useDashboardPage';
import PortalShell, { PortalNavItem } from '../../components/portal/PortalShell';
import type { LucideIcon } from 'lucide-react';
import {
  Award,
  BellRing,
  BookOpenCheck,
  ChartColumn,
  ClipboardList,
  Film,
  Gamepad2,
  KeyRound,
  LayoutDashboard,
  MessageSquareText,
  Package,
  School,
  Settings2,
  ShieldCheck,
  SlidersHorizontal,
  Swords,
  UsersRound,
} from 'lucide-react';

/** صفحاتُ القائمة كلُّها — وما ليس منها في العنوان يُردّ إلى الرئيسية. */
const ADMIN_PAGES = [
  ...Object.values(AdminMenuType),
  'VIDEO_MANAGEMENT',
  'ENTERTAINMENT',
  'PERMISSION_PACKAGES',
  'VIDEO_NOTIFICATIONS',
  'DUEL_QUESTIONS',
  'CARD_PERMISSIONS',
  'CERTIFICATES',
] as AdminMenuType[];

/** القائمة بترتيبها، واسمُ كل صفحةٍ في الشريط العلوي. */
const ADMIN_MENU: { id: AdminMenuType; label: string; icon: LucideIcon }[] = [
  { id: AdminMenuType.DASHBOARD, label: 'الرئيسية', icon: LayoutDashboard },
  { id: AdminMenuType.ACADEMIC_SETTINGS, label: 'الإعدادات الأكاديمية', icon: Settings2 },
  { id: AdminMenuType.STUDENT_MANAGEMENT, label: 'إدارة الحسابات', icon: UsersRound },
  { id: AdminMenuType.TEACHER_MANAGEMENT, label: 'إدارة المعلمين', icon: School },
  { id: AdminMenuType.CONTENT_MANAGEMENT, label: 'إدارة المحتوى', icon: BookOpenCheck },
  { id: 'VIDEO_MANAGEMENT' as AdminMenuType, label: 'سينما منارة', icon: Film },
  { id: 'ENTERTAINMENT' as AdminMenuType, label: 'الترفيه والألعاب', icon: Gamepad2 },
  { id: AdminMenuType.QUIZ_MANAGEMENT, label: 'إدارة الاختبارات', icon: ClipboardList },
  { id: 'DUEL_QUESTIONS' as AdminMenuType, label: 'أسئلة «تحدَّ زملاءك»', icon: Swords },
  { id: 'CARD_PERMISSIONS' as AdminMenuType, label: 'صلاحيات البطاقات', icon: ShieldCheck },
  { id: AdminMenuType.REPORTS, label: 'التقارير', icon: ChartColumn },
  { id: 'CERTIFICATES' as AdminMenuType, label: 'الشهادات', icon: Award },
  { id: 'PERMISSION_PACKAGES' as AdminMenuType, label: 'إدارة الصلاحيات', icon: Package },
  { id: 'VIDEO_NOTIFICATIONS' as AdminMenuType, label: 'إشعارات الفيديو', icon: BellRing },
  { id: AdminMenuType.SYSTEM_SETTINGS, label: 'إعدادات النظام', icon: SlidersHorizontal },
];

interface AdminDashboardProps {
  onLogout: () => void;
}

const AdminDashboard: React.FC<AdminDashboardProps> = ({ onLogout }) => {
  const [isAuthenticated, setIsAuthenticated] = useState(false);
  const [authLoading, setAuthLoading] = useState(true);
  // ‏الصفحةُ في العنوان: التحديثُ يُبقي المشرفَ حيث كان — انظر utils/dashboardRoute.
  const [activeMenu, setActiveMenu] = useDashboardPage('admin', ADMIN_PAGES, AdminMenuType.DASHBOARD);
  const [showChat, setShowChat] = useState(false);
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
    // ‏بعد خروجٍ صريح: لا جلسةَ قديمة تُستعاد — كعكةٌ بقيت لأن طلبَ الخروج لم
    // ‏يصل كانت تفتح اللوحةَ بلا كلمة مرور. يُعاد طلبُ الخروج، ثم شاشةُ الدخول.
    if (isLoggedOut()) {
      removeSessionValue(SESSION_KEYS.ADMIN_SESSION);
      void endServerSession().finally(() => {
        if (!mounted) return;
        setIsAuthenticated(false);
        setAuthLoading(false);
      });
      return () => {
        mounted = false;
      };
    }
    fetch('/api/auth/admin/session', { credentials: 'same-origin', cache: 'no-store' })
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
    return undefined;
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
      subjectsOfConfig(config).forEach((subject: any) => {
        if (subject.subject) subjects.add(subject.subject);
      });
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
    return <AdminLogin onLoginSuccess={async () => {
      clearLoggedOut();
      writeSessionValue(SESSION_KEYS.ADMIN_SESSION, '1');
      writeAuthSession('admin', 'admin');
      await refreshSupabaseSync();
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
      case 'ENTERTAINMENT' as AdminMenuType: return <EntertainmentManagement />;
      case AdminMenuType.QUIZ_MANAGEMENT: return <QuizManagement onUpdate={refreshStats} />;
      case AdminMenuType.REPORTS: return <Reports />;
      case AdminMenuType.SYSTEM_SETTINGS: return <SystemSettings />;
      case 'PERMISSION_PACKAGES' as AdminMenuType: return <PermissionPackages onUpdate={refreshStats} />;
      case 'VIDEO_NOTIFICATIONS' as AdminMenuType: return <AdminVideoNotifications />;
      case 'DUEL_QUESTIONS' as AdminMenuType: return <DuelQuestionReview role="admin" />;
      case 'CARD_PERMISSIONS' as AdminMenuType: return <CardPermissions role="admin" />;
      case 'CERTIFICATES' as AdminMenuType: return <TeacherCertificates teacherId="" teacherName="مشرف النظام" issuerRole="admin" />;
      default: return <DashboardHome stats={stats} onRefresh={refreshStats} />;
    }
  };

  const nav: PortalNavItem[] = ADMIN_MENU.map((item) => ({
    id: item.id,
    label: item.label,
    icon: item.icon,
    active: activeMenu === item.id,
    onSelect: () => setActiveMenu(item.id),
  }));
  const pageTitle = ADMIN_MENU.find((item) => item.id === activeMenu)?.label ?? 'الرئيسية';

  return (
    <>
      <PortalShell
        portalName="لوحة المشرف"
        userName="مشرف النظام"
        userRole="إدارة المنصّة"
        nav={nav}
        secondaryNav={[{ id: 'chat', label: 'الدردشة مع المعلمين وأولياء الأمور', icon: MessageSquareText, onSelect: () => setShowChat(true) }]}
        onLogout={onLogout}
        pageTitle={pageTitle}
        topbarEnd={
          <>
            <VideoNotificationBadge onClick={() => setActiveMenu('VIDEO_NOTIFICATIONS' as AdminMenuType)} />
            <button
              type="button"
              onClick={() => alert('تتم إدارة كلمة مرور المشرف من متغيّرات الخادم (ADMIN_PASSWORD) في Railway.')}
              className="portal-btn portal-btn-secondary"
              title="إدارة كلمة المرور"
              aria-label="إدارة كلمة المرور"
            >
              <KeyRound aria-hidden="true" />
              <span className="hidden sm:inline">كلمة المرور</span>
            </button>
          </>
        }
      >
        {renderContent()}
      </PortalShell>

      {showChat && (
        <PrivateChat
          currentUserId="admin"
          currentUserName="المشرف"
          currentUserRole="admin"
          onClose={() => setShowChat(false)}
        />
      )}
    </>
  );
};

export default AdminDashboard;
