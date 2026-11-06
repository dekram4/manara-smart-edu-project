
import React, { useState, useEffect } from 'react';
import { readHierarchicalConfigs, subjectsOfConfig } from '../../utils/academic';
import { useSyncHydrating } from '../../hooks/useSyncHydrating';
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
import DuelQuestionReview from '../shared/DuelQuestionReview';
import CardPermissions from '../shared/CardPermissions';
import { getTeacherPermissions } from '../../permissions';
import PrivateChat from '../shared/PrivateChat';
import { playWelcomeAdult } from '../../utils/sounds';
import { getTeacherParents, getTeacherStudents, getRecordTeacherId, normalizeScopeValue } from '../../utils/scope';
import ManaraBrand from '../../components/ManaraBrand';
import PermissionPackageManagement from '../shared/PermissionPackageManagement';
import { readActiveSession, readStorageArray, removeActiveSession, writeActiveSession } from '../../utils/storage';
import { writeAuthSession } from '../../utils/authSession';
import { refreshSupabaseSync } from '../../db/sync';
import { clearLoggedOut, isLoggedOut } from '../../utils/logoutGuard';
import { useDashboardPage } from '../../hooks/useDashboardPage';
import PortalShell, { PortalNavItem } from '../../components/portal/PortalShell';
import TeacherHome from './TeacherHome';
import type { LucideIcon } from 'lucide-react';
import {
  Award,
  BookOpenCheck,
  ChartColumn,
  ClipboardList,
  Film,
  LayoutDashboard,
  MessageSquareText,
  Package,
  Settings2,
  ShieldCheck,
  Swords,
  UserRound,
  UsersRound,
} from 'lucide-react';

/**
 * هل تظهر صفحةُ القائمة لهذا المعلم؟ القائمةُ تُخفي ما لا يملكه، والصفحةُ
 * المحفوظة في العنوان تُردّ إلى الرئيسية إن لم تعد له — بعد تحديثٍ أو تغيّر صلاحياته.
 */
const isTeacherMenuAllowed = (
  menu: TeacherMenuType,
  permissions: ReturnType<typeof getTeacherPermissions>,
): boolean => {
  if (menu === TeacherMenuType.ACADEMIC_SETTINGS && !permissions.canManageAcademicSettings) {
    return false;
  }
  if (menu === TeacherMenuType.CONTENT_MANAGEMENT && !permissions.canManageContent) {
    return false;
  }
  if (menu === TeacherMenuType.VIDEO_MANAGEMENT && !permissions.canManageVideos) {
    return false;
  }
  if (menu === TeacherMenuType.QUIZ_MANAGEMENT && !permissions.canManageQuizzes) {
    return false;
  }
  // أسئلةُ التحدي تُولَّد من دروسه، فتتبع صلاحيةَ المحتوى نفسها.
  if (menu === TeacherMenuType.DUEL_QUESTIONS && !permissions.canManageContent) {
    return false;
  }
  if (menu === TeacherMenuType.ACCOUNT_MANAGEMENT && 
      !permissions.canCreateParents && !permissions.canCreateStudents) {
    return false;
  }
  if (menu === TeacherMenuType.PERMISSION_PACKAGES &&
      !permissions.canCreatePermissionPackages) {
    return false;
  }
  if (menu === TeacherMenuType.REPORTS && !permissions.canViewReports) {
    return false;
  }
  return true;
};

const TEACHER_PAGES = Object.values(TeacherMenuType);

/** اسمُ كل صفحةٍ وأيقونتها، في القائمة وفي الشريط العلوي. */
const TEACHER_MENU: Record<TeacherMenuType, { label: string; icon: LucideIcon }> = {
  [TeacherMenuType.DASHBOARD]: { label: 'الرئيسية', icon: LayoutDashboard },
  [TeacherMenuType.ACADEMIC_SETTINGS]: { label: 'الإعدادات الأكاديمية', icon: Settings2 },
  [TeacherMenuType.CONTENT_MANAGEMENT]: { label: 'إدارة المحتوى', icon: BookOpenCheck },
  [TeacherMenuType.VIDEO_MANAGEMENT]: { label: 'فيديوهاتي', icon: Film },
  [TeacherMenuType.QUIZ_MANAGEMENT]: { label: 'إدارة الاختبارات', icon: ClipboardList },
  [TeacherMenuType.DUEL_QUESTIONS]: { label: 'أسئلة «تحدَّ زملاءك»', icon: Swords },
  [TeacherMenuType.CARD_PERMISSIONS]: { label: 'صلاحيات البطاقات', icon: ShieldCheck },
  [TeacherMenuType.ACCOUNT_MANAGEMENT]: { label: 'الطلاب وأولياء الأمور', icon: UsersRound },
  [TeacherMenuType.PERMISSION_PACKAGES]: { label: 'إدارة الصلاحيات', icon: Package },
  [TeacherMenuType.REPORTS]: { label: 'التقارير', icon: ChartColumn },
  [TeacherMenuType.CERTIFICATES]: { label: 'الشهادات', icon: Award },
  [TeacherMenuType.MY_ACCOUNT]: { label: 'حسابي', icon: UserRound },
};

interface TeacherDashboardProps {
  onLogout: () => void;
}

const TeacherDashboard: React.FC<TeacherDashboardProps> = ({ onLogout }) => {
  const [isAuthenticated, setIsAuthenticated] = useState(false);
  const [currentTeacher, setCurrentTeacher] = useState<TeacherInfo | null>(null);
  // ‏الصفحةُ في العنوان: التحديثُ يُبقي المعلمَ حيث كان — انظر utils/dashboardRoute.
  const [storedMenu, setActiveMenu] = useDashboardPage('teacher', TEACHER_PAGES, TeacherMenuType.DASHBOARD);
  const [showChat, setShowChat] = useState(false);
  /// يتغيّر مع كل قراءةٍ للبيانات، فتُعيد الصفحةُ الرئيسية حسابَ ما تعرضه.
  const [refreshToken, setRefreshToken] = useState(0);
  const [dashboardStats, setDashboardStats] = useState({
    parentsCount: 0,
    studentsCount: 0,
    lessonsCount: 0,
    academicSettingsCount: 0,
    academicSubjectsCount: 0,
  });
  /// هل ما زالت الشجرة في طريقها من الخادم؟ العدّ قبل وصولها ليس عدّاً.
  const hydrating = useSyncHydrating();

  useEffect(() => {
    // ‏بعد خروجٍ صريح لا يُستعاد معلّمٌ محفوظ: شاشةُ الدخول — انظر utils/logoutGuard.
    if (isLoggedOut()) {
      removeActiveSession(STORAGE_KEYS.CURRENT_TEACHER);
      return;
    }
    const savedTeacher = readActiveSession<TeacherInfo>(STORAGE_KEYS.CURRENT_TEACHER);
    if (savedTeacher) {
      setCurrentTeacher(savedTeacher);
      setIsAuthenticated(true);
    }
  }, []);

  useEffect(() => {
    if (isAuthenticated && currentTeacher) {
      loadDashboardStats();
      const interval = window.setInterval(() => {
        const storedTeachers = readStorageArray<TeacherInfo>(STORAGE_KEYS.TEACHERS);
        const latestTeacher = storedTeachers.find(teacher => teacher.id === currentTeacher.id);
        if (latestTeacher && JSON.stringify(latestTeacher) !== JSON.stringify(currentTeacher)) {
          setCurrentTeacher(latestTeacher);
          writeActiveSession(STORAGE_KEYS.CURRENT_TEACHER, latestTeacher);
        }
        loadDashboardStats();
      }, 5000);
      return () => window.clearInterval(interval);
    }
    return undefined;
  }, [isAuthenticated, currentTeacher?.id]);

  const loadDashboardStats = () => {
    if (!currentTeacher) return;

    // Load parents
    const allParents = readStorageArray<ParentInfo>(STORAGE_KEYS.PARENTS);
     const teacherParents = getTeacherParents(allParents, currentTeacher.id);

    // Load students
    const allStudents = readStorageArray<StudentInfo>(STORAGE_KEYS.STUDENTS);
     const teacherStudents = getTeacherStudents(allStudents, currentTeacher.id, teacherParents);

    // Load lessons
    const allLessons = readStorageArray<LessonConfig>(STORAGE_KEYS.LESSON_CONFIGS);
    const teacherLessons = allLessons.filter(l =>
      getRecordTeacherId(l) === normalizeScopeValue(currentTeacher.id)
    );

    // ‏الشجرة تُقرأ مدموجة، كما تقرؤها كل شاشة أخرى.
    //
    // ‏كانت تُقرأ خاماً هنا وحدها. والمصفوفة الخام تحمل أكثر من مدخل للصف
    // ‏الواحد — يتراكم ذلك من دمج المزامنة — فكانت البطاقة تعدّ المكرّرات
    // ‏وتُظهر خمسة حيث صفٌّ واحد. ثم يفتح المعلم شاشة الإعدادات، وهي تدمج
    // ‏وتعيد الكتابة، فيعود فيجد واحداً. لم يكن الرقم يتذبذب: كان الأول
    // ‏خطأً والثاني صواباً.
    const teacherConfigs = readHierarchicalConfigs().filter((c: any) =>
      getRecordTeacherId(c) === normalizeScopeValue(currentTeacher.id)
    );
    // ‏المواد عبر صفوفه كلها، بلا تكرار: البطاقة تقول «الصفوف والمواد»،
    // ‏فيجب أن يكون للمواد عدد حقيقي لا أن تبقى الكلمة بلا رقم.
    const teacherSubjects = new Set(
      teacherConfigs.flatMap((config: any) =>
        subjectsOfConfig(config)
          .map((subject: any) => String(subject?.subject ?? '').trim())
          .filter(Boolean),
      ),
    );

    setRefreshToken((token) => token + 1);
    setDashboardStats({
      parentsCount: teacherParents.length,
      studentsCount: teacherStudents.length,
      lessonsCount: teacherLessons.length,
      academicSettingsCount: teacherConfigs.length,
      academicSubjectsCount: teacherSubjects.size,
    });
  };

  if (!isAuthenticated || !currentTeacher) {
    return <TeacherLogin onLoginSuccess={async (teacher) => {
      clearLoggedOut();
      writeAuthSession('teacher', teacher.id);
      await refreshSupabaseSync();
      setCurrentTeacher(teacher);
      setIsAuthenticated(true);
      playWelcomeAdult();
    }} onBack={onLogout} />;
  }

  // Always resolve the latest persisted teacher before evaluating permissions.
  // Admin package assignment updates TEACHERS while this dashboard can remain open.
  const latestStoredTeacher = (() => {
    try {
      const teachers = readStorageArray<TeacherInfo>(STORAGE_KEYS.TEACHERS);
      return teachers.find(teacher => teacher.id === currentTeacher.id) || currentTeacher;
    } catch {
      return currentTeacher;
    }
  })();
  const effectiveTeacher = latestStoredTeacher;
  const teacherPermissions = getTeacherPermissions(effectiveTeacher);
  const activeMenu = isTeacherMenuAllowed(storedMenu, teacherPermissions)
    ? storedMenu
    : TeacherMenuType.DASHBOARD;

  const handleLogout = () => {
    setIsAuthenticated(false);
    setCurrentTeacher(null);
    removeActiveSession(STORAGE_KEYS.CURRENT_TEACHER);
    onLogout();
  };

  const renderContent = () => {
    switch (activeMenu) {
      case TeacherMenuType.DASHBOARD:
        return (
          <TeacherHome
            teacher={currentTeacher}
            refreshToken={refreshToken}
            hydrating={hydrating}
            academic={{ grades: dashboardStats.academicSettingsCount, subjects: dashboardStats.academicSubjectsCount }}
            canOpen={(menu) => isTeacherMenuAllowed(menu, teacherPermissions)}
            onNavigate={setActiveMenu}
            onRefresh={loadDashboardStats}
          />
        );
      case TeacherMenuType.ACADEMIC_SETTINGS:
        return <MyAcademicSettings teacher={effectiveTeacher} />;
      case TeacherMenuType.CONTENT_MANAGEMENT:
         return <TeacherContentManagement teacherId={currentTeacher.id} teacherName={currentTeacher.name} permissionPackageId={currentTeacher.permissionPackageId} />;
      case TeacherMenuType.QUIZ_MANAGEMENT:
        return <QuizManagement onUpdate={loadDashboardStats} teacherId={currentTeacher.id} teacherName={currentTeacher.name} />;
      case TeacherMenuType.DUEL_QUESTIONS:
        // المعلمُ يُعرَف في الخادم من جلسته لا من هنا: ما يُرى وما يُعطَّل يحسمه هو.
        return <DuelQuestionReview role="teacher" />;
      case TeacherMenuType.CARD_PERMISSIONS:
        // الخادمُ يقصر الطلابَ والقواعد على هذا المعلم من جلسته.
        return <CardPermissions role="teacher" teacherId={currentTeacher.id} />;
      case TeacherMenuType.ACCOUNT_MANAGEMENT:
         return <ParentStudentManagement teacherId={currentTeacher.id} teacherName={currentTeacher.name} permissionPackageId={currentTeacher.permissionPackageId} />;
      case TeacherMenuType.PERMISSION_PACKAGES:
        return (
          <PermissionPackageManagement
            managerRole="teacher"
            teacherId={currentTeacher.id}
            teacherName={currentTeacher.name}
            teacherPermissionPackageId={currentTeacher.permissionPackageId}
          />
        );
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

  const nav: PortalNavItem[] = TEACHER_PAGES
    .filter((menu) => isTeacherMenuAllowed(menu, teacherPermissions))
    .map((menu) => ({
      id: menu,
      label: TEACHER_MENU[menu].label,
      icon: TEACHER_MENU[menu].icon,
      active: activeMenu === menu,
      onSelect: () => setActiveMenu(menu),
    }));

  return (
    <>
      <PortalShell
        portalName="بوابة المعلم"
        userName={currentTeacher.name}
        userRole={currentTeacher.subject ? `معلم ${currentTeacher.subject}` : 'معلم'}
        nav={nav}
        secondaryNav={[{ id: 'chat', label: 'الدردشة والدعم', icon: MessageSquareText, onSelect: () => setShowChat(true) }]}
        onLogout={handleLogout}
        pageTitle={TEACHER_MENU[activeMenu].label}
      >
        {renderContent()}
      </PortalShell>

      {showChat && currentTeacher && (
        <PrivateChat
          currentUserId={currentTeacher.id}
          currentUserName={currentTeacher.name}
          currentUserRole="teacher"
          onClose={() => setShowChat(false)}
        />
      )}
    </>
  );
};

export default TeacherDashboard;
