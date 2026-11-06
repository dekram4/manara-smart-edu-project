
import { readHierarchicalConfigs, subjectsOfConfig } from '../../utils/academic';
import React, { useState, useEffect, useMemo, useRef } from 'react';
import { ParentInfo, StudentInfo, TeacherInfo, QuizResult, ParentMenuType, CertificateRecord, CreatedQuiz, HierarchicalConfig, QuizType } from '../../types';
import { STORAGE_KEYS, DEFAULT_PASSWORD } from '../../constants';
import { hashPassword, passwordsMatch } from '../../utils/password';
import ParentLogin from './ParentLogin';
import ParentAccountSetup from './ParentAccountSetup';
import { getEffectiveParentPermissions, getStudentPermissions, isLimitReached } from '../../permissions';
import PrivateChat from '../shared/PrivateChat';
import { playWelcomeAdult } from '../../utils/sounds';
import { refreshSupabaseSync, rehydrateFromServer } from '../../db/sync';
import { clearLoggedOut, isLoggedOut } from '../../utils/logoutGuard';
import { formatAcademicPath, pathCell, quizResultPath } from '../../utils/academicPath';
import { getParentChildren, getParentTeacherId, getRecordTeacherId, getStudentTeacherScope } from '../../utils/scope';
import PortalShell, { PortalNavItem } from '../../components/portal/PortalShell';
import DocumentPreview from '../../components/portal/DocumentPreview';
import { Badge, EmptyState, PageHeader, Panel, ART, studentArt, subjectArt } from '../../components/portal/PortalUI';
import ParentHome from './ParentHome';
import ParentChildren, { SubjectDetails } from './ParentChildren';
import PortalDialog from '../../components/portal/PortalDialog';
import { CERTIFICATE_TYPES, certificateDocument, certificateNumber } from '../../utils/officialDocuments';
import type { LucideIcon } from 'lucide-react';
import {
  Award,
  Eye,
  KeyRound,
  LayoutDashboard,
  MessageSquareText,
  Printer,
  Settings2,
  ShieldCheck,
  UserPlus,
  UserRound,
  UsersRound,
} from 'lucide-react';
import PermissionPackageManagement from '../shared/PermissionPackageManagement';
import { getStudentEmoji, STUDENT_GENDER_OPTIONS, StudentGender } from '../../utils/studentAppearance';
import { getStudentProgressSummary } from '../../utils/studentProgress';
import { getQuizTypeLabel as formatQuizTypeLabel, normalizeQuizType as normalizeAssessmentType } from '../../utils/quizTypes';
import { getQuizResultPercentage, getQuizResultScore } from '../../utils/quizScoring';
import { keepIfSame } from '../../utils/stableState';
import { formatSafeDate } from '../../utils/safeDate';
import CardErrorBoundary from '../../components/CardErrorBoundary';
import { readActiveSession, readStorageArray, removeActiveSession, writeActiveSession } from '../../utils/storage';
import { writeAuthSession } from '../../utils/authSession';
import { readDashboardRoute } from '../../utils/dashboardRoute';
import { useDashboardPage } from '../../hooks/useDashboardPage';
import { html, printDocument, type SafeHtml } from '../../utils/printHtml';
import {
  BarChart, Bar, XAxis, YAxis, CartesianGrid, Tooltip, ResponsiveContainer, LineChart, Line,
  PieChart, Pie, Cell, Legend, RadarChart, PolarGrid, PolarAngleAxis, PolarRadiusAxis, Radar
} from 'recharts';
import { BookOpen as IconBookOpen, TriangleAlert as IconTriangleAlert } from 'lucide-react';

const CERT_KEY = 'smartEdu_certificates';

/** صفحاتُ القائمة — والدردشةُ نافذةٌ فوقها لا صفحة. */
const PARENT_PAGES: ParentMenuType[] = Object.values(ParentMenuType).filter(page => page !== ParentMenuType.CHAT);

const ParentDashboard: React.FC<{ onLogout: () => void }> = ({ onLogout }) => {
  const [isAuthenticated, setIsAuthenticated] = useState(false);
  const [parent, setParent] = useState<ParentInfo | null>(null);
  // ‏الصفحةُ والابنُ والمادةُ في العنوان: التحديثُ يُبقي وليَّ الأمر حيث كان —
  // ‏انظر utils/dashboardRoute. تُقرأ هنا قبل أن يكتب الأثرُ الصفحةَ بلا ابن،
  // ‏فالأبناءُ لا يُعرفون إلا بعد `loadData`، وهناك يُستعاد الابنُ مرّةً واحدة.
  const [restoredRoute] = useState(() =>
    readDashboardRoute('parent', PARENT_PAGES, ParentMenuType.DASHBOARD),
  );
  const pendingChildId = useRef<string | null>(restoredRoute.params[0] || null);
  const [activeChild, setActiveChild] = useState<StudentInfo | null>(null);
  const [activeSubject, setActiveSubject] = useState<string | null>(
    restoredRoute.params[0] ? restoredRoute.params[1] || null : null,
  );
  const [storedMenu, setMenuType] = useDashboardPage(
    'parent',
    PARENT_PAGES,
    ParentMenuType.DASHBOARD,
    [activeChild?.id ?? pendingChildId.current, activeSubject],
  );
  const [mobileNavOpen, setMobileNavOpen] = useState(false);
  // حالُ السحب من الخادم: مؤشّرٌ خفيفٌ أثناءه، وإشارةٌ إن تعذّر.
  const [syncing, setSyncing] = useState(false);
  const [syncError, setSyncError] = useState(false);
  const [children, setChildren] = useState<StudentInfo[]>([]);
  const [allQuizzes, setAllQuizzes] = useState<QuizResult[]>([]);
  const [needsPasswordChange, setNeedsPasswordChange] = useState(false);
  const [showChat, setShowChat] = useState(false);
  // ‏«تفاصيل الابن» من صفحة الأبناء والمواد: صفحةٌ مستقلّة فوق اللوحة.
  const [childDialog, setChildDialog] = useState<StudentInfo | null>(null);
  const [showChangeGradeModal, setShowChangeGradeModal] = useState(false);
  const [studentToChangeGrade, setStudentToChangeGrade] = useState<StudentInfo | null>(null);
  const [availableGrades, setAvailableGrades] = useState<string[]>([]);
  const [selectedNewGrade, setSelectedNewGrade] = useState('');
  const [currentPasswordDraft, setCurrentPasswordDraft] = useState('');
  const [newPasswordDraft, setNewPasswordDraft] = useState('');
  const [confirmPasswordDraft, setConfirmPasswordDraft] = useState('');
  const [passwordSaveError, setPasswordSaveError] = useState('');

  const permissions = getEffectiveParentPermissions(parent);
  // ‏صفحةٌ محفوظةٌ لم تعد له صلاحيتُها تُفتح على الرئيسية، كما تُخفيها القائمة.
  const menuType =
    (storedMenu === ParentMenuType.ADD_CHILDREN && !permissions.canCreateStudents) ||
    (storedMenu === ParentMenuType.PERMISSION_PACKAGES &&
      !(permissions.canEditStudents && permissions.canCreatePermissionPackages))
      ? ParentMenuType.DASHBOARD
      : storedMenu;

  /* Dashboard filter */
  const [dashFilter, setDashFilter] = useState('');
  const [teacherResultStudentFilter, setTeacherResultStudentFilter] = useState('all');
  const [teacherResultQuizFilter, setTeacherResultQuizFilter] = useState('all');
  const [teacherResultParentFilter, setTeacherResultParentFilter] = useState('all');
  const [teacherResultSubjectFilter, setTeacherResultSubjectFilter] = useState('all');

  /* Certificates state */
  const [certSearch, setCertSearch] = useState('');
  const [certFilterType, setCertFilterType] = useState<'all' | 'excellence' | 'appreciation' | 'participation'>('all');
  const [certSelectedChild, setCertSelectedChild] = useState<StudentInfo | null>(null);
  const [previewCert, setPreviewCert] = useState<CertificateRecord | null>(null);

  const [showAddChildForm, setShowAddChildForm] = useState(false);
  const [newChild, setNewChild] = useState({
    name: '',
    gender: 'male' as StudentGender,
    username: '',
    password: '',
    studentIdNumber: '',
    primaryGrade: '',
    gradeEnrollments: [] as { grade: string; enrollments: { id?: string; subject: string; term: string; unit: string }[] }[],
    currentGradeForEnrollment: '',
    enrollmentSubject: '',
    enrollmentTerm: '',
    enrollmentUnit: '',
  });

  const [grades, setGrades] = useState<string[]>([]);
  const [subjects, setSubjects] = useState<string[]>([]);
  const [terms, setTerms] = useState<string[]>([]);
  const [units, setUnits] = useState<string[]>([]);
  const [gradeConfigs, setGradeConfigs] = useState<any[]>([]);
  const [hierarchicalConfigs, setHierarchicalConfigs] = useState<HierarchicalConfig[]>([]);
  const [availableSubjects, setAvailableSubjects] = useState<string[]>([]);
  // النتيجة تحمل الصف والمادة والوحدة فقط؛ الفصل الدراسي والدرس في
  // الاختبار نفسه، فيُقرأ ليكتمل المسار في كل موضع يُعرض فيه.
  const [createdQuizzes, setCreatedQuizzes] = useState<CreatedQuiz[]>([]);

  useEffect(() => {
    loadAcademicSettings();
    loadData();
  }, []);

  /**
   * قراءة ولي الأمر تأتي من الخادم، لا من نسخة متصفّح قديمة.
   *
   * كانت الشاشة تُعيد قراءة localStorage كل خمس ثوانٍ، وهي نسخة تُملأ مرة
   * واحدة عند تحميل الصفحة: فنتيجة اختبار يحلّها الابن بعد دخول أبيه
   * بدقيقة، أو شهادة يُصدرها المعلم، أو نقاط يكسبها الطالب — كلّها في
   * Supabase ولا يرى الأب منها شيئاً حتى يُحدّث الصفحة بنفسه.
   *
   * فصار السحب من الخادم أولاً ثم القراءة: مرة عند فتح اللوحة ليظهر
   * الأبناء فوراً، وكل نصف دقيقة بعدها، وكلما عاد إلى التبويب — فالعودة
   * إلى الصفحة أصدق إشارة على أنه ينتظر جديداً.
   */
  /**
   * ── ولا `activeChild` في قائمة التبعيات، وهذا موضعُ تجمّدٍ كان ──
   *
   * كانت `[isAuthenticated, activeChild]`، فدارت حلقةٌ لا تنتهي:
   *
   *   `loadChildrenOnly` تقرأ الطلاب من `localStorage` بـ`JSON.parse`، فتخرج
   *   كائناتٌ جديدةُ الهويّة في كل قراءة ولو لم يتغيّر حرفٌ. ثم
   *   `setActiveChild` تُمرَّر واحداً منها، فيرى React هويّةً جديدةً فيُعيد
   *   البناء، فتتغيّر التبعيّة، فيُعاد تشغيل هذا الأثر: يهدم المؤقّتين
   *   ويبنيهما، ويطلب `rehydrateFromServer` — وهي تسحب الجداول كلَّها من
   *   الخادم — ثم يقرأ فيُنشئ كائناتٍ جديدةً من جديد. بأسرع ما يجدول React.
   *
   * ولذلك كانت اللوحةُ تعمل حتى يُختار ابن: الدالّةُ تُعيد `null` حين لا ابنَ
   * مختار، و`null === null` فيتخطّى React إعادةَ البناء ولا تدور الحلقة.
   * فيُفتح ملفُّ ابنٍ — أو مادةٌ من موادّه — فتبدأ الدورة وتتجمّد الصفحة.
   *
   * وهذا الأثرُ لا يقرأ `activeChild` أصلاً: `loadChildrenOnly` تُحدّثه
   * بدالّةٍ تأخذ قيمتَه الحاليّة. فوجودُه في القائمة كان يُغلق الحلقة بلا
   * فائدة.
   *
   * والحرسُ الثاني في `loadChildrenOnly`: تُعيد المرجعَ القديم إن لم يتغيّر
   * المحتوى — فلا تدور الحلقةُ ولو أُعيدت التبعيّةُ يوماً، ولا تُعاد اللوحةُ
   * كلُّها كل خمس ثوانٍ على بياناتٍ لم تتغيّر.
   */
  useEffect(() => {
    if (!isAuthenticated) return;

    let alive = true;
    const pullThenRead = async () => {
      setSyncing(true);
      try {
        await rehydrateFromServer();
        if (alive) setSyncError(false);
      } catch (error) {
        console.warn('[parent] تعذّر تحديث البيانات من الخادم:', (error as Error)?.message || error);
        // ولا يُسقط التعذّرُ شيئاً: النسخةُ المحليّة تُقرأ على كل حال، ويُرفع
        // مؤشّرٌ خفيفٌ يقول إنّ ما يُعرض قد لا يكون الأحدث.
        if (alive) setSyncError(true);
      } finally {
        if (alive) setSyncing(false);
      }
      if (alive) loadChildrenOnly();
    };

    void pullThenRead();
    const pull = window.setInterval(() => { void pullThenRead(); }, 30000);
    // القراءة المحلية تبقى سريعة بينهما، فتظهر تغييرات هذه اللوحة فوراً.
    const read = window.setInterval(() => { if (alive) loadChildrenOnly(); }, 5000);
    const onFocus = () => { void pullThenRead(); };
    window.addEventListener('focus', onFocus);

    return () => {
      alive = false;
      window.clearInterval(pull);
      window.clearInterval(read);
      window.removeEventListener('focus', onFocus);
    };
  }, [isAuthenticated]);

  const loadChildrenOnly = () => {
    const activeUser = readActiveSession<ParentInfo>(STORAGE_KEYS.ACTIVE_PARENT);
    if (activeUser) {
      const allStudents = readStorageArray<StudentInfo>(STORAGE_KEYS.STUDENTS);
      const myChildren = getParentChildren(allStudents, activeUser);
      setChildren(current => keepIfSame(current, myChildren));
      const childIds = new Set(myChildren.map(child => child.id));
      setCreatedQuizzes(current =>
        keepIfSame(current, readStorageArray<CreatedQuiz>(STORAGE_KEYS.CREATED_QUIZZES)),
      );
      const allQuizzes = readStorageArray<QuizResult>(STORAGE_KEYS.QUIZ_RESULTS)
        .filter((quiz: QuizResult) => childIds.has(quiz.studentId))
        .map((quiz: QuizResult) => ({ ...quiz, percentage: getQuizResultPercentage(quiz) }));
      setAllQuizzes(current => keepIfSame(current, allQuizzes));
      setActiveChild(current =>
        current ? keepIfSame(current, myChildren.find(child => child.id === current.id) || null) : null,
      );
    }
  };

  const loadAcademicSettings = () => {
    setGrades(readStorageArray<string>(STORAGE_KEYS.GRADES));
    setSubjects(readStorageArray<string>(STORAGE_KEYS.SUBJECTS));
    setTerms(readStorageArray<string>(STORAGE_KEYS.TERMS));
    setUnits(readStorageArray<string>(STORAGE_KEYS.UNITS));
    setGradeConfigs(readStorageArray(STORAGE_KEYS.GRADE_CONFIGS));
    setHierarchicalConfigs(readStorageArray<HierarchicalConfig>(STORAGE_KEYS.HIERARCHICAL_CONFIGS));
  };

  const flattenGradeConfig = (cfg: any) => {
    if (!cfg) return [] as any[];
    if (cfg.subjects) {
      return (cfg.subjects || []).flatMap((s: any) => (s.enrollments || []).map((en: any, idx: number) => ({
        id: en.id || `gcfg-${Date.now()}-${idx}`,
        subject: s.subject,
        term: en.term || '',
        unit: en.unit || ''
      })));
    }
    return (cfg.enrollments || []).map((en: any, idx: number) => ({
      id: en.id || `gcfg-${Date.now()}-${idx}`,
      subject: en.subject,
      term: en.term || '',
      unit: en.unit || ''
    }));
  };

  const getSubjectsForGrade = (grade: string, teacherId?: string) => {
    if (!grade || !hierarchicalConfigs.length) return subjects;
    const configs = teacherId
      ? hierarchicalConfigs.filter((c: HierarchicalConfig) => getRecordTeacherId(c) === teacherId.toLowerCase())
      : hierarchicalConfigs;
    const cfg = configs.find((c: HierarchicalConfig) => c.grade === grade);
    if (!cfg) return subjects;
    const subs = new Set<string>();
    subjectsOfConfig(cfg).forEach((s: any) => { if (s.subject) subs.add(s.subject); });
    return subs.size > 0 ? Array.from(subs) : subjects;
  };

  const loadData = () => {
    // ‏بعد خروجٍ صريح لا يُستعاد وليُّ أمرٍ محفوظ — انظر utils/logoutGuard.
    if (isLoggedOut()) {
      removeActiveSession(STORAGE_KEYS.ACTIVE_PARENT);
      return;
    }
      const activeUser = readActiveSession<ParentInfo>(STORAGE_KEYS.ACTIVE_PARENT);
    if (activeUser) {
      setParent(activeUser);
      setIsAuthenticated(true);
      const allStudents = readStorageArray<StudentInfo>(STORAGE_KEYS.STUDENTS);
       const myChildren = getParentChildren(allStudents, activeUser);
      setChildren(myChildren);
      const childIds = new Set(myChildren.map(child => child.id));
      setCreatedQuizzes(readStorageArray<CreatedQuiz>(STORAGE_KEYS.CREATED_QUIZZES));
      const allQuizzes = readStorageArray<QuizResult>(STORAGE_KEYS.QUIZ_RESULTS);
       setAllQuizzes(allQuizzes
         .filter((quiz: QuizResult) => childIds.has(quiz.studentId))
         .map((quiz: QuizResult) => ({ ...quiz, percentage: getQuizResultPercentage(quiz) })));
      // ‏الابنُ الذي كان مفتوحاً قبل التحديث، إن كان من أبنائه — مرّةً واحدة.
      const restoredChild = pendingChildId.current
        ? myChildren.find(child => child.id === pendingChildId.current) || null
        : null;
      pendingChildId.current = null;
      setActiveChild(restoredChild);
      if (!restoredChild) setActiveSubject(null);
    }
  };

  const handleLogin = async (username: string, pass: string): Promise<string | null> => {
    const parents = readStorageArray<ParentInfo>(STORAGE_KEYS.PARENTS);
    // ‏الدخولُ من الخادم وحده، والدورُ من ردّه — لا من نسخة المتصفّح.
    let found: ParentInfo | undefined;
    if (!found) {
      try {
        const response = await fetch('/api/auth/parent/login', {
          method: 'POST',
          credentials: 'same-origin',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ username, password: pass }),
        });
        const result = await response.json().catch(() => ({}));
        if (!response.ok || !result.parent || (result.role && result.role !== 'parent')) {
          return result.error || 'اسم المستخدم أو كلمة المرور غير صحيحة';
        }
        found = {
          ...result.parent,
          username,
          password: hashPassword(pass),
          children: Array.isArray(result.parent.children)
            ? result.parent.children
            : [],
        } as ParentInfo;
        const withoutDuplicate = parents.filter(parent => parent.id !== found!.id);
        localStorage.setItem(
          STORAGE_KEYS.PARENTS,
          JSON.stringify([...withoutDuplicate, found]),
        );
      } catch {
        return 'تعذر الاتصال بالخادم. تحقق من الإنترنت ثم حاول مرة أخرى.';
      }
    }
    if (found) {
      clearLoggedOut();
      if (found.mustChangePassword === true) {
        setParent(found);
        setNeedsPasswordChange(true);
      } else {
        writeActiveSession(STORAGE_KEYS.ACTIVE_PARENT, found);
        writeAuthSession('parent', found.id);
        // سحب بيانات الأبناء من Supabase قبل العرض، كما يفعل المعلم والمشرف.
        // بدون هذا لا تمتلئ اللوحة إلا بعد إعادة تحميل الصفحة — وعلى جهاز
        // جديد تبقى فارغة تماماً لأن `localStorage` لا يحمل شيئاً بعد.
        try {
          await refreshSupabaseSync();
        } catch {
          // المزامنة تفشل بهدوء: اللوحة تعرض ما في التخزين المحلي، وهو
          // السلوك السابق نفسه، فلا يُمنع الدخول بسبب انقطاع شبكة.
        }
        loadData();
        playWelcomeAdult();
      }
      return null;
    }
    return 'اسم المستخدم أو كلمة المرور غير صحيحة';
  };

  const handleAccountPasswordChange = async (
    currentPass: string,
    newPass: string,
  ): Promise<string | null> => {
    if (!parent) return 'تعذر تحديد حساب ولي الأمر';
    try {
      const response = await fetch('/api/auth/parent/change-password', {
        method: 'POST',
        credentials: 'same-origin',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          username: parent.username,
          currentPassword: currentPass,
          newPassword: newPass,
        }),
      });
      const result = await response.json().catch(() => ({}));
      if (!response.ok) {
        return result.error || 'تعذر تحديث كلمة المرور الآن';
      }
    } catch {
      return 'تعذر الاتصال بالخادم. تحقق من الإنترنت ثم حاول مرة أخرى.';
    }
    const parents = readStorageArray<ParentInfo>(STORAGE_KEYS.PARENTS);
    const updated = parents.map((p: ParentInfo) => p.id === parent.id ? { ...p, password: hashPassword(newPass), mustChangePassword: false } : p);
    localStorage.setItem(STORAGE_KEYS.PARENTS, JSON.stringify(updated));
    const finalParent = updated.find((p: any) => p.id === parent.id);
    writeActiveSession(STORAGE_KEYS.ACTIVE_PARENT, finalParent);
    setNeedsPasswordChange(false);
    loadData();
    return null;
  };

  const handleSavePassword = async (e: React.FormEvent) => {
    e.preventDefault();
    setPasswordSaveError('');

    if (!parent || !passwordsMatch(currentPasswordDraft, parent.password)) {
      setPasswordSaveError('كلمة المرور الحالية غير صحيحة');
      return;
    }
    if (newPasswordDraft.length < 6) {
      setPasswordSaveError('كلمة المرور الجديدة يجب أن تكون 6 أحرف على الأقل');
      return;
    }
    if (newPasswordDraft === currentPasswordDraft) {
      setPasswordSaveError('كلمة المرور الجديدة يجب أن تكون مختلفة عن الحالية');
      return;
    }
    if (newPasswordDraft !== confirmPasswordDraft) {
      setPasswordSaveError('تأكيد كلمة المرور غير متطابق');
      return;
    }

    const saveError = await handleAccountPasswordChange(
      currentPasswordDraft,
      newPasswordDraft,
    );
    if (saveError) {
      setPasswordSaveError(saveError);
      return;
    }
    setCurrentPasswordDraft('');
    setNewPasswordDraft('');
    setConfirmPasswordDraft('');
    alert('تم حفظ تعديلات الحساب بنجاح');
  };

  const handleAddChild = (e: React.FormEvent) => {
    e.preventDefault();
    if (!permissions.canCreateStudents) {
      alert('ليس لديك صلاحية إضافة أبناء جدد');
      return;
    }
    if (!newChild.name || !newChild.password || !newChild.studentIdNumber || !newChild.primaryGrade) {
      alert('يرجى ملء الحقول المطلوبة');
      return;
    }
    if (newChild.password.length < 6) {
      alert('كلمة المرور يجب أن تكون 6 أحرف على الأقل');
      return;
    }
    const studentsList = readStorageArray<StudentInfo>(STORAGE_KEYS.STUDENTS);
    const currentChildren = parent ? getParentChildren(studentsList, parent) : [];
    if (isLimitReached(currentChildren.length, permissions.maxStudents)) {
      alert(`وصلت إلى الحد الأقصى المسموح به (${permissions.maxStudents}) من الأبناء`);
      return;
    }
    if (studentsList.some((s: any) => s.studentIdNumber === newChild.studentIdNumber)) {
      alert('رقم الهوية موجود بالفعل');
      return;
    }
    if (newChild.username && studentsList.some((s: any) => s.username === newChild.username)) {
      alert('اسم المستخدم موجود بالفعل');
      return;
    }

    const parentTeacherId = parent
      ? getParentTeacherId(parent, studentsList)
      : '';
    let gradeEnrollments = newChild.gradeEnrollments.length > 0 ? newChild.gradeEnrollments : [];
    if (gradeEnrollments.length === 0) {
      try {
        const configs = readStorageArray(STORAGE_KEYS.GRADE_CONFIGS);
        const found = configs.find((c: any) => c.grade === newChild.primaryGrade);
        const flattened = flattenGradeConfig(found);
        if (flattened.length > 0) gradeEnrollments = [{ grade: newChild.primaryGrade, enrollments: flattened }];
      } catch (e) { /* ignore */ }
    }
    if (gradeEnrollments.length === 0) {
      gradeEnrollments = [{ grade: newChild.primaryGrade, enrollments: [{ id: Date.now().toString(), subject: newChild.enrollmentSubject || subjects[0] || '', term: terms[0] || '', unit: units[0] || '' }] }];
    }

    const child: StudentInfo = {
      id: Date.now().toString(),
      name: newChild.name,
      gender: newChild.gender,
      password: hashPassword(newChild.password),
      username: newChild.username && newChild.username.trim() ? newChild.username.trim() : (newChild.studentIdNumber ? `stu_${newChild.studentIdNumber}` : `stu_${Date.now().toString().slice(-5)}`),
      parentPhoneNumber: parent?.phoneNumber || '',
      parentId: parent?.id || undefined,
      studentIdNumber: newChild.studentIdNumber,
      primaryGrade: newChild.primaryGrade,
      gradeEnrollments: gradeEnrollments,
      grade: newChild.primaryGrade,
      subject: newChild.enrollmentSubject || gradeEnrollments[0]?.enrollments[0]?.subject || '',
      term: gradeEnrollments[0]?.enrollments[0]?.term || '',
      unit: gradeEnrollments[0]?.enrollments[0]?.unit || '',
      canChangeGrade: false,
      createdAt: new Date().toISOString(),
      lastActivity: new Date().toISOString(),
       ...(parentTeacherId ? {
         teacherId: parentTeacherId,
         createdBy: parentTeacherId,
       } : {}),
    };

    const updatedStudents = [...studentsList, child];
    localStorage.setItem(STORAGE_KEYS.STUDENTS, JSON.stringify(updatedStudents));
    const parentsList = readStorageArray<ParentInfo>(STORAGE_KEYS.PARENTS);
    const updatedParents = parentsList.map((p: ParentInfo) => p.id === parent?.id ? { ...p, children: [...(p.children || []), child] } : p);
    localStorage.setItem(STORAGE_KEYS.PARENTS, JSON.stringify(updatedParents));
    const refreshedParent = updatedParents.find((p: ParentInfo) => p.id === parent?.id);
    if (refreshedParent) {
      writeActiveSession(STORAGE_KEYS.ACTIVE_PARENT, refreshedParent);
      setParent(refreshedParent);
    }
     if (parent) setChildren(getParentChildren(updatedStudents, parent));
    setNewChild({ name: '', gender: 'male', username: '', password: '', studentIdNumber: '', primaryGrade: '', gradeEnrollments: [], currentGradeForEnrollment: '', enrollmentSubject: '', enrollmentTerm: '', enrollmentUnit: '' });
    setShowAddChildForm(false);
    alert(`تمت إضافة ${newChild.name} بنجاح!`);
  };

  const handleResetStudentPassword = (child: StudentInfo) => {
    if (!permissions.canResetStudentPassword) {
      alert('ليس لديك صلاحية إعادة تعيين كلمة مرور الأبناء');
      return;
    }
    const newPass = prompt(`أدخل كلمة مرور جديدة لـ ${child.name}:`, DEFAULT_PASSWORD);
    if (newPass) {
      if (newPass.length < 6) { alert('كلمة المرور قصيرة جداً'); return; }
      const students = readStorageArray<StudentInfo>(STORAGE_KEYS.STUDENTS);
      const updated = students.map((s: StudentInfo) => s.id === child.id ? { ...s, password: hashPassword(newPass) } : s);
      localStorage.setItem(STORAGE_KEYS.STUDENTS, JSON.stringify(updated));
      alert('تم تغيير كلمة المرور بنجاح');
      loadData();
    }
  };

  const handleChangeStudentGrade = (child: StudentInfo) => {
    if (!permissions.canChangeGrade) { alert('ليس لديك صلاحية تغيير الصف'); return; }
    const students = readStorageArray<StudentInfo>(STORAGE_KEYS.STUDENTS);
    const teacherId = parent ? getParentTeacherId(parent, students) : '';
    if (!teacherId) { alert('لم يتم العثور على معلم مرتبط بحسابك'); return; }
    const hierarchicalConfigs = readHierarchicalConfigs();
     const teacherConfigs = hierarchicalConfigs.filter((config: any) => getRecordTeacherId(config) === teacherId);
    const gradesSet = new Set<string>();
    teacherConfigs.forEach((config: any) => { if (config.grade) gradesSet.add(config.grade); });
    const grades = Array.from(gradesSet).sort();
    if (grades.length === 0) { alert('لم يتم العثور على صفوف متاحة'); return; }
    setAvailableGrades(grades);
    setStudentToChangeGrade(child);
    setSelectedNewGrade(child.primaryGrade || child.grade || grades[0]);
    setShowChangeGradeModal(true);
  };

  const handleConfirmGradeChange = () => {
    if (!studentToChangeGrade || !selectedNewGrade) return;
    const students = readStorageArray<StudentInfo>(STORAGE_KEYS.STUDENTS);
    const updated = students.map((s: StudentInfo) => s.id === studentToChangeGrade.id ? { ...s, primaryGrade: selectedNewGrade, grade: selectedNewGrade } : s);
    localStorage.setItem(STORAGE_KEYS.STUDENTS, JSON.stringify(updated));
    alert('تم تغيير الصف بنجاح');
    setShowChangeGradeModal(false);
    setStudentToChangeGrade(null);
    setSelectedNewGrade('');
    loadData();
    loadChildrenOnly();
  };

  /* ===== Helpers ===== */
  const getChildQuizzes = (childId: string) => allQuizzes.filter(q => q.studentId === childId);
  const normalizeQuizType = (quizType: string | undefined) => normalizeAssessmentType(quizType);
  const getQuizTypeLabel = (quizType: string | undefined) => {
    return formatQuizTypeLabel(quizType);
  };
  const getChildSubjects = (child: StudentInfo) => {
    const set = new Set<string>();
    try {
      const allConfigs = readHierarchicalConfigs();
      const studentScope = getStudentTeacherScope(child);
      const teacherId = studentScope.teacherId || (
        studentScope.explicit
          ? ''
          : parent
            ? getParentTeacherId(parent, children)
            : ''
      );
      const configs = teacherId
        ? allConfigs.filter((c: any) => getRecordTeacherId(c) === teacherId)
        : studentScope.explicit ? [] : allConfigs;
      configs.filter((c: any) => c.grade === child.primaryGrade || c.grade === child.grade).forEach((cfg: any) => {
        subjectsOfConfig(cfg).forEach((s: any) => { if (s.subject) set.add(s.subject); });
      });
    } catch (e) { /* ignore */ }
    if (set.size === 0) {
      getChildQuizzes(child.id).forEach(q => set.add(q.subject));
    }
    return Array.from(set);
  };

  const getAllCertificates = (): CertificateRecord[] => {
    try { return JSON.parse(localStorage.getItem(CERT_KEY) || '[]'); } catch { return []; }
  };

  const filteredCertificates = useMemo(() => {
    let certs = getAllCertificates().filter((c: CertificateRecord) => children.some(ch => ch.id === c.studentId));
    if (certSelectedChild) certs = certs.filter(c => c.studentId === certSelectedChild.id);
    if (certFilterType !== 'all') certs = certs.filter(c => c.type === certFilterType);
    if (certSearch.trim()) {
      const q = certSearch.trim().toLowerCase();
      certs = certs.filter(c =>
        c.studentName.toLowerCase().includes(q) ||
        c.subject.toLowerCase().includes(q) ||
        c.grade.toLowerCase().includes(q) ||
        (c.type === 'excellence' && 'تفوق'.includes(q)) ||
        (c.type === 'appreciation' && 'شكر تقدير'.includes(q)) ||
        (c.type === 'participation' && 'مشاركة'.includes(q))
      );
    }
    return certs.sort((a, b) => new Date(b.date).getTime() - new Date(a.date).getTime());
  }, [children, certSelectedChild, certFilterType, certSearch]);

  /** الشهادةُ بالقالب الرسمي الموحّد — انظر utils/officialDocuments. */
  const printCertificate = (cert: CertificateRecord) => {
    printDocument(certificateDocument(cert), { autoPrintDelayMs: 600 });
  };

  const printSubjectReport = (child: StudentInfo, subject: string) => {
    const childQuizzes = allQuizzes.filter(q => q.studentId === child.id && q.subject === subject);
    const avg = childQuizzes.length > 0 ? (childQuizzes.reduce((acc, q) => acc + q.percentage, 0) / childQuizzes.length).toFixed(1) : '0';
    const periodicQuizzes = childQuizzes.filter(q => normalizeQuizType(q.quizType) === QuizType.PERIODIC);
    const teacherQuizzes = childQuizzes.filter(q => normalizeQuizType(q.quizType) === QuizType.TEACHER);
    const periodicAvg = periodicQuizzes.length > 0 ? (periodicQuizzes.reduce((acc, q) => acc + q.percentage, 0) / periodicQuizzes.length).toFixed(1) : '0';
    const teacherAvg = teacherQuizzes.length > 0 ? (teacherQuizzes.reduce((acc, q) => acc + q.percentage, 0) / teacherQuizzes.length).toFixed(1) : '0';
      const certificates = readStorageArray<CertificateRecord>(CERT_KEY);
    const studentCertificates = certificates.filter((c: any) => c.studentId === child.id && c.subject === subject);
    printDocument(html`
      <html dir="rtl" lang="ar"><head><title>تقرير مادة ${subject} - ${child.name}</title>
      <style>
        body { font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; padding: 40px; background: linear-gradient(to bottom, #f8fafc, #e2e8f0); }
        .header { text-align: center; border-bottom: 4px solid #3b82f6; padding-bottom: 20px; margin-bottom: 30px; background: white; padding: 30px; border-radius: 20px; box-shadow: 0 4px 6px rgba(0,0,0,0.1); }
        .info { display: flex; justify-content: space-between; margin-bottom: 30px; background: white; padding: 25px; border-radius: 20px; box-shadow: 0 2px 4px rgba(0,0,0,0.1); }
        .stats-grid { display: grid; grid-template-columns: repeat(3, 1fr); gap: 20px; margin-bottom: 30px; }
        .stat-card { background: white; padding: 25px; border-radius: 20px; text-align: center; box-shadow: 0 2px 4px rgba(0,0,0,0.1); border: 2px solid; }
        .stat-card.unit { border-color: #3b82f6; } .stat-card.term { border-color: #8b5cf6; } .stat-card.grade { border-color: #10b981; }
        .stat-card h3 { font-size: 14px; margin-bottom: 10px; color: #64748b; } .stat-card .value { font-size: 36px; font-weight: bold; margin: 10px 0; }
        .stat-card.unit .value { color: #3b82f6; } .stat-card.term .value { color: #8b5cf6; } .stat-card.grade .value { color: #10b981; }
        table { width: 100%; border-collapse: collapse; margin-top: 20px; background: white; border-radius: 20px; overflow: hidden; box-shadow: 0 2px 4px rgba(0,0,0,0.1); }
        th, td { border: 1px solid #e2e8f0; padding: 15px; text-align: right; }
        th { background: #3b82f6; color: white; font-weight: bold; }
        tr:nth-child(even) { background: #f8fafc; }
        .summary { margin-top: 30px; text-align: center; font-size: 28px; font-weight: bold; color: #1e40af; background: white; padding: 30px; border-radius: 20px; box-shadow: 0 4px 6px rgba(0,0,0,0.1); }
        .certificates { margin-top: 30px; background: white; padding: 30px; border-radius: 20px; box-shadow: 0 2px 4px rgba(0,0,0,0.1); }
        .cert-item { display: inline-block; margin: 10px; padding: 20px; border-radius: 15px; border: 2px solid; text-align: center; min-width: 200px; }
        .cert-item.excellence { background: #fef3c7; border-color: #f59e0b; } .cert-item.appreciation { background: #dbeafe; border-color: #3b82f6; } .cert-item.participation { background: #d1fae5; border-color: #10b981; }
        .section-title { background: #3b82f6; color: white; padding: 15px 25px; border-radius: 15px; margin: 30px 0 20px 0; font-size: 20px; font-weight: bold; }
      </style></head><body>
      <div class="header"><h1 style="margin:0;color:#1e40af;font-size:32px;">تقرير الأداء التعليمي الشامل</h1><h3 style="margin:10px 0 0 0;color:#64748b;">مادة ${subject}</h3></div>
      <div class="info"><div><strong style="color:#64748b;">الاسم:</strong> <span style="font-size:18px;font-weight:bold;">${child.name}</span></div><div><strong style="color:#64748b;">الصف:</strong> <span style="font-size:18px;font-weight:bold;">${child.grade}</span></div><div><strong style="color:#64748b;">الفصل:</strong> <span style="font-size:18px;font-weight:bold;">${child.term}</span></div><div><strong style="color:#64748b;">التاريخ:</strong> <span style="font-size:18px;font-weight:bold;">${new Date().toLocaleDateString('ar-SA')}</span></div></div>
      <div class="section-title">ملخص الأداء حسب نوع الاختبار</div>
      <div class="stats-grid">
         <div class="stat-card unit"><h3>الاختبار الدوري</h3><div class="value">${periodicAvg}%</div><p style="color:#64748b;margin:5px 0;">عدد المحاولات: ${periodicQuizzes.length}</p></div>
         <div class="stat-card grade"><h3>اختبار المعلم</h3><div class="value">${teacherAvg}%</div><p style="color:#64748b;margin:5px 0;">عدد الاختبارات: ${teacherQuizzes.length}</p></div>
      </div>
      ${studentCertificates.length > 0 ? html`<div class="certificates"><h2>الشهادات الممنوحة</h2><div style="text-align:center;">${studentCertificates.map((cert: any) => html`<div class="cert-item ${cert.type}"><div style="font-size:40px;margin-bottom:10px;">${cert.type === 'excellence' ? '🏆' : cert.type === 'appreciation' ? '⭐' : '🌟'}</div><strong style="font-size:16px;">${cert.type === 'excellence' ? 'شهادة تميز' : cert.type === 'appreciation' ? 'شهادة تقدير' : 'شهادة مشاركة'}</strong><p style="margin:10px 0 5px 0;font-size:14px;">المعلم: ${cert.teacherName || 'غير محدد'}</p><p style="margin:0;font-size:12px;color:#64748b;">${new Date(cert.date).toLocaleDateString('ar-SA')}</p></div>`)}</div></div>` : ''}
       <div class="section-title">تفاصيل جميع الاختبارات</div>
       <table><thead><tr><th>الصف</th><th>المادة</th><th>الفصل الدراسي</th><th>الوحدة</th><th>الدرس</th><th>نوع الاختبار</th><th>النتيجة</th><th>المستوى</th><th>التاريخ</th></tr></thead><tbody>${childQuizzes.map(q => { const p = quizResultPath(q, createdQuizzes); return html`<tr><td>${pathCell(p.grade)}</td><td>${pathCell(p.subject)}</td><td>${pathCell(p.term)}</td><td>${pathCell(p.unit)}</td><td style="font-weight:bold;">${pathCell(p.lesson)}</td><td>${getQuizTypeLabel(q.quizType)}</td><td style="font-weight:bold;font-size:18px;color:${q.percentage >= 80 ? '#10b981' : q.percentage >= 60 ? '#f59e0b' : '#ef4444'};">${q.percentage}%</td><td style="font-weight:bold;color:${q.percentage >= 60 ? '#10b981' : '#ef4444'};">${q.level}</td><td style="font-size:12px;color:#64748b;">${new Date(q.createdAt).toLocaleDateString('ar-SA')}</td></tr>`; })}</tbody></table>
       <div class="summary"><div style="color:#64748b;font-size:16px;margin-bottom:10px;">المعدل العام للمادة</div><div style="font-size:48px;color:${parseFloat(avg) >= 80 ? '#10b981' : parseFloat(avg) >= 60 ? '#f59e0b' : '#ef4444'};">${avg}%</div><div style="margin-top:15px;font-size:14px;color:#64748b;">إجمالي النتائج: ${childQuizzes.length} | أعلى درجة: ${childQuizzes.length > 0 ? Math.max(...childQuizzes.map(q => q.percentage)) : 0}% | أقل درجة: ${childQuizzes.length > 0 ? Math.min(...childQuizzes.map(q => q.percentage)) : 0}%</div></div>
      <div style="text-align:center;margin-top:40px;padding:20px;background:#f8fafc;border-radius:15px;color:#64748b;font-size:12px;"><p style="margin:0;">تم إنشاء هذا التقرير بواسطة منصة SmartEdu التعليمية</p><p style="margin:5px 0 0 0;">${new Date().toLocaleString('ar-SA')}</p></div>
      </body></html>
    `, { autoPrintDelayMs: 0 });
  };

  const printTeacherResultsReport = (child: StudentInfo) => {
      const teacherQuizzes = allQuizzes
      .filter(q => q.studentId === child.id && normalizeQuizType(q.quizType) === QuizType.TEACHER)
      .sort((a, b) => new Date(b.createdAt).getTime() - new Date(a.createdAt).getTime());
    if (teacherQuizzes.length === 0) return;

    const average = Math.round(
      teacherQuizzes.reduce((sum, quiz) => sum + getQuizResultPercentage(quiz), 0) / teacherQuizzes.length,
    );
    const level = average >= 90 ? 'ممتاز' : average >= 70 ? 'جيد جداً' : average >= 50 ? 'جيد' : 'يحتاج تحسين';

    printDocument(html`
      <!DOCTYPE html>
      <html dir="rtl" lang="ar">
        <head>
          <meta charset="UTF-8">
          <title>نتائج اختبارات المعلم - ${child.name}</title>
          <style>
            body { font-family: 'Segoe UI', Tahoma, sans-serif; padding: 32px; color: #172033; background: #f8fafc; }
            .header { text-align: center; background: linear-gradient(135deg, #be123c, #f97316); color: white; padding: 28px; border-radius: 18px; margin-bottom: 20px; }
            .header h1 { margin: 0 0 8px; font-size: 30px; }
            .info, .summary, .result { background: white; border-radius: 16px; padding: 18px; margin-bottom: 18px; box-shadow: 0 2px 8px rgba(15,23,42,.08); }
            .info { display: grid; grid-template-columns: repeat(4, 1fr); gap: 12px; }
            .info strong, .summary strong { display: block; color: #64748b; font-size: 12px; margin-bottom: 5px; }
            .summary { display: grid; grid-template-columns: repeat(4, 1fr); gap: 12px; text-align: center; }
            .summary .value { font-size: 25px; font-weight: 900; color: #be123c; }
            .result h2 { margin: 0 0 12px; color: #9f1239; font-size: 20px; }
            .result-meta { display: flex; flex-wrap: wrap; gap: 14px; color: #475569; font-size: 13px; margin-bottom: 12px; }
            table { width: 100%; border-collapse: collapse; margin-top: 12px; }
            th, td { border: 1px solid #e2e8f0; padding: 9px; text-align: right; font-size: 12px; }
            th { background: #be123c; color: white; }
            .score { font-size: 24px; font-weight: 900; color: #be123c; }
            .correct { color: #047857; font-weight: 800; }
            .wrong { color: #b91c1c; font-weight: 800; }
            .footer { text-align: center; color: #64748b; font-size: 11px; margin-top: 24px; }
            @media print { body { background: white; padding: 12px; } .result { break-inside: avoid; box-shadow: none; border: 1px solid #e2e8f0; } }
          </style>
        </head>
        <body>
          <div class="header">
            <h1>نتائج اختبارات المعلم</h1>
            <p>تقرير مستقل لأداء الطالب في تقييمات المعلم</p>
          </div>
          <div class="info">
            <div><strong>اسم الطالب</strong>${child.name}</div>
            <div><strong>الصف</strong>${child.primaryGrade || child.grade || '—'}</div>
            <div><strong>ولي الأمر</strong>${parent?.name || '—'}</div>
            <div><strong>تاريخ التقرير</strong>${new Date().toLocaleDateString('ar-SA')}</div>
          </div>
          <div class="summary">
            <div><strong>عدد اختبارات المعلم</strong><div class="value">${teacherQuizzes.length}</div></div>
            <div><strong>المعدل</strong><div class="value">${average}%</div></div>
            <div><strong>أعلى نتيجة</strong><div class="value">${Math.max(...teacherQuizzes.map(getQuizResultPercentage))}%</div></div>
            <div><strong>التقدير العام</strong><div class="value">${level}</div></div>
          </div>
          ${teacherQuizzes.map((quiz) => html`
            <section class="result">
              <h2>${quiz.quizTitle || 'اختبار المعلم'}</h2>
              <div class="result-meta">
                <span><b>المسار:</b> ${formatAcademicPath(quizResultPath(quiz, createdQuizzes)) || '—'}</span>
                <span><b>التاريخ:</b> ${new Date(quiz.createdAt).toLocaleString('ar-SA')}</span>
              </div>
              <div class="score">النتيجة: ${getQuizResultScore(quiz)} / ${quiz.total || 0} — ${getQuizResultPercentage(quiz)}% — ${quiz.level || '—'}</div>
              ${Array.isArray(quiz.details) && quiz.details.length > 0 ? html`
                <table>
                  <thead><tr><th>#</th><th>السؤال</th><th>إجابة الطالب</th><th>الإجابة الصحيحة</th><th>الحالة</th></tr></thead>
                  <tbody>${quiz.details.map((detail, index) => html`
                    <tr>
                      <td>${index + 1}</td>
                      <td>${detail.question}</td>
                      <td>${detail.userAnswer || '—'}</td>
                      <td>${detail.correctAnswer || '—'}</td>
                      <td class="${detail.isCorrect ? 'correct' : 'wrong'}">${detail.isCorrect ? 'صحيحة' : 'خاطئة'}</td>
                    </tr>
                  `)}</tbody>
                </table>
              ` : ''}
            </section>
          `)}
          <div class="footer">تم إنشاء التقرير بواسطة منصة التعليم الذكي — ${new Date().toLocaleString('ar-SA')}</div>
        </body>
      </html>
    `, { autoPrintDelayMs: 400 });
  };

  if (!isAuthenticated) {
    return needsPasswordChange ?
      <ParentAccountSetup parent={parent!} onPasswordChange={handleAccountPasswordChange} /> :
      <ParentLogin onLogin={handleLogin} onBack={onLogout} />;
  }


  /* ===== المعلم المرتبط ===== */
  const teacherName = (() => {
    if (!parent) return '';
    const myParent = readStorageArray<ParentInfo>(STORAGE_KEYS.PARENTS).find((p: ParentInfo) => p.id === parent.id);
    const parentTeacherId = myParent ? getParentTeacherId(myParent, children) : '';
    if (!parentTeacherId) return '';
    const teacher = readStorageArray<TeacherInfo>(STORAGE_KEYS.TEACHERS).find((t: TeacherInfo) =>
      getRecordTeacherId({ teacherId: t.id }) === parentTeacherId,
    );
    return teacher?.name || '';
  })();

  const childCertificates = getAllCertificates().filter((cert) => children.some((child) => child.id === cert.studentId));

  const goHome = () => {
    setMenuType(ParentMenuType.DASHBOARD);
    setActiveChild(null);
    setActiveSubject(null);
    setDashFilter('');
  };

  const canAddChild = permissions.canCreateStudents && !isLimitReached(children.length, permissions.maxStudents);
  const navItems: { key: ParentMenuType; label: string; icon: LucideIcon; shown: boolean }[] = [
    { key: ParentMenuType.DASHBOARD, label: 'الرئيسية', icon: LayoutDashboard, shown: true },
    { key: ParentMenuType.CHILDREN, label: 'الأبناء والمواد', icon: UsersRound, shown: true },
    { key: ParentMenuType.ADD_CHILDREN, label: 'إضافة ابن', icon: UserPlus, shown: canAddChild },
    { key: ParentMenuType.CERTIFICATES, label: 'الشهادات', icon: Award, shown: true },
    { key: ParentMenuType.PERMISSION_PACKAGES, label: 'صلاحيات الأبناء', icon: ShieldCheck, shown: Boolean(permissions.canEditStudents && permissions.canCreatePermissionPackages) },
    { key: ParentMenuType.SETTINGS, label: 'إعدادات الحساب', icon: Settings2, shown: true },
  ];
  const nav: PortalNavItem[] = navItems
    .filter((item) => item.shown)
    .map((item) => ({
      id: item.key,
      label: item.label,
      icon: item.icon,
      active: menuType === item.key,
      onSelect: () => (item.key === ParentMenuType.DASHBOARD ? goHome() : setMenuType(item.key)),
    }));
  const pageTitle = menuType === ParentMenuType.DASHBOARD && activeChild
    ? `تقرير ${activeChild.name}`
    : navItems.find((item) => item.key === menuType)?.label ?? 'الرئيسية';

  /* ===== Render ===== */
  return (
    <>
      <PortalShell
        portalName="بوابة ولي الأمر"
        userName={parent?.name || 'ولي الأمر'}
        userRole="ولي أمر"
        nav={nav}
        secondaryNav={permissions.canChatWithSupport
          ? [{ id: 'chat', label: 'الدردشة مع المعلم', icon: MessageSquareText, onSelect: () => setShowChat(true) }]
          : []}
        onLogout={() => { removeActiveSession(STORAGE_KEYS.ACTIVE_PARENT); onLogout(); }}
        pageTitle={pageTitle}
        topbarEnd={
          <>
            {syncing && <span className="hidden text-xs font-bold text-slate-400 sm:inline">جارٍ التحديث…</span>}
            {syncError && !syncing && <Badge tone="warning">قد لا تكون البيانات الأحدث</Badge>}
            {teacherName && <span className="hidden text-sm font-bold text-slate-500 md:inline">المعلم: <span className="text-slate-800">{teacherName}</span></span>}
          </>
        }
      >
        {/* ---------- DASHBOARD ---------- */}
        {menuType === ParentMenuType.DASHBOARD && parent && (
          <ParentHome
            parent={parent}
            children={children}
            results={allQuizzes}
            certificates={childCertificates}
            teacherName={teacherName}
            activeChild={activeChild}
            getChildSubjects={getChildSubjects}
            quizTypeLabel={getQuizTypeLabel}
            isTeacherQuiz={(quizType) => normalizeQuizType(quizType) === QuizType.TEACHER}
            canAddChild={canAddChild}
            onAddChild={() => setMenuType(ParentMenuType.ADD_CHILDREN)}
            onOpenChild={(child) => { setActiveChild(child); setActiveSubject(null); }}
            onBack={goHome}
            onOpenSubject={(child, subject) => { setActiveChild(child); setActiveSubject(subject); }}
            onPrintSubject={printSubjectReport}
            onPrintTeacherResults={printTeacherResultsReport}
            onPreviewCertificate={setPreviewCert}
          />
        )}

        {/* ---------- CHILDREN ---------- */}
        {menuType === ParentMenuType.CHILDREN && (
          <ParentChildren
            children={children}
            results={allQuizzes}
            certificates={childCertificates}
            selected={activeChild}
            onSelect={(child) => { setActiveChild(child); setActiveSubject(null); }}
            getChildSubjects={getChildSubjects}
            teacherName={teacherName}
            onOpenChild={setChildDialog}
            onOpenSubject={(child, subject) => { setActiveChild(child); setActiveSubject(subject); }}
            onPrintSubject={printSubjectReport}
            onResetPassword={permissions.canResetStudentPassword ? handleResetStudentPassword : undefined}
          />
        )}

        {/* ---------- ADD CHILDREN ---------- */}
        {menuType === ParentMenuType.ADD_CHILDREN && (
          <div className="dashboard-page max-w-xl mx-auto animate-fadeIn">
            <div className="dashboard-page-banner bg-gradient-to-r from-rose-500 to-rose-600">
              <h1 className="text-xl font-black">إضافة ابن/ابنة جديد</h1>
              <p className="text-rose-200 font-bold text-xs mt-1">قم بملء بيانات الابن</p>
            </div>
            <div className="dashboard-surface border-rose-100">
              <form onSubmit={handleAddChild} className="space-y-4 text-right">
                <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                  <div className="space-y-1"><label className="text-xs font-bold text-rose-600 block">الاسم الكامل *</label><input type="text" placeholder="أدخل اسم الابن" value={newChild.name} onChange={e => setNewChild({...newChild, name: e.target.value})} className="w-full p-3 bg-white rounded-xl border border-rose-200 focus:border-rose-400 focus:ring-4 focus:ring-rose-100 outline-none font-bold text-sm transition-all" required /></div>
                   <div className="space-y-1"><label className="text-xs font-bold text-rose-600 block">جنس الطالب *</label><select value={newChild.gender} onChange={e => setNewChild({...newChild, gender: e.target.value as StudentGender})} className="w-full p-3 bg-white rounded-xl border border-rose-200 focus:border-rose-400 focus:ring-4 focus:ring-rose-100 outline-none font-bold text-sm transition-all" required>{STUDENT_GENDER_OPTIONS.map(option => <option key={option.value} value={option.value}>{option.emoji} {option.label}</option>)}</select></div>
                  <div className="space-y-1"><label className="text-xs font-bold text-rose-600 block">اسم المستخدم (اختياري)</label><input type="text" placeholder="مثال: ali123" value={newChild.username} onChange={e => setNewChild({...newChild, username: e.target.value})} className="w-full p-3 bg-white rounded-xl border border-rose-200 focus:border-rose-400 focus:ring-4 focus:ring-rose-100 outline-none font-bold text-sm transition-all" /></div>
                  <div className="space-y-1"><label className="text-xs font-bold text-rose-600 block">رقم الهوية *</label><input type="text" placeholder="رقم الهوية الفريد" value={newChild.studentIdNumber} onChange={e => setNewChild({...newChild, studentIdNumber: e.target.value})} className="w-full p-3 bg-white rounded-xl border border-rose-200 focus:border-rose-400 focus:ring-4 focus:ring-rose-100 outline-none font-bold text-sm transition-all" required /></div>
                  <div className="space-y-1"><label className="text-xs font-bold text-rose-600 block">كلمة المرور *</label><input type="password" placeholder="كلمة المرور (6+ رموز)" value={newChild.password} onChange={e => setNewChild({...newChild, password: e.target.value})} className="w-full p-3 bg-white rounded-xl border border-rose-200 focus:border-rose-400 focus:ring-4 focus:ring-rose-100 outline-none font-bold text-sm transition-all" required /></div>
                  <div className="space-y-1"><label className="text-xs font-bold text-rose-600 block">الصف الأساسي *</label><select value={newChild.primaryGrade} onChange={e => { setNewChild({...newChild, primaryGrade: e.target.value}); const subs = getSubjectsForGrade(e.target.value, parent ? getParentTeacherId(parent, children) : ''); setAvailableSubjects(subs); }} className="w-full p-3 bg-white rounded-xl border border-rose-200 focus:border-rose-400 focus:ring-4 focus:ring-rose-100 outline-none font-bold text-sm transition-all" required><option value="">اختر الصف الأساسي</option>{grades.map((g, i) => <option key={i} value={g}>{g}</option>)}</select></div>
                  <div className="space-y-1"><label className="text-xs font-bold text-rose-600 block">المادة *</label><select value={newChild.enrollmentSubject} onChange={e => setNewChild({...newChild, enrollmentSubject: e.target.value})} className="w-full p-3 bg-white rounded-xl border border-rose-200 focus:border-rose-400 focus:ring-4 focus:ring-rose-100 outline-none font-bold text-sm transition-all" required><option value="">اختر المادة</option>{availableSubjects.map((s, i) => <option key={i} value={s}>{s}</option>)}</select></div>
                </div>
                <div className="flex gap-3 pt-2">
                  <button type="submit" className="flex-1 bg-rose-500 text-white px-5 py-2.5 rounded-xl font-black text-sm hover:bg-rose-600 shadow-md transition-all">حفظ البيانات</button>
                   <button type="button" onClick={() => setNewChild({ name: '', gender: 'male', username: '', password: '', studentIdNumber: '', primaryGrade: '', gradeEnrollments: [], currentGradeForEnrollment: '', enrollmentSubject: '', enrollmentTerm: '', enrollmentUnit: '' })} className="px-5 py-2.5 bg-rose-100 text-rose-600 rounded-xl font-bold text-sm hover:bg-rose-200 transition-all">إلغاء</button>
                </div>
              </form>
            </div>
          </div>
        )}

        {menuType === ParentMenuType.PERMISSION_PACKAGES && parent && (
          <PermissionPackageManagement
            managerRole="parent"
            parent={parent}
          />
        )}

        {/* ---------- CERTIFICATES ---------- */}
        {menuType === ParentMenuType.CERTIFICATES && (
          <div className="portal-page">
            <PageHeader
              eyebrow="بوابة ولي الأمر"
              title="الشهادات"
              description="معاينة شهادات أبنائك وطباعتها بتنسيقٍ رسمي جاهز للتعليق والحفظ."
              icon={Award}
              art={ART.reader}
            />
            <Panel
              title={`${filteredCertificates.length} شهادة`}
              icon={Award}
              flush
              actions={
                <div className="flex flex-wrap gap-2">
                  <select
                    value={certSelectedChild?.id || 'all'}
                    onChange={e => setCertSelectedChild(children.find(child => child.id === e.target.value) || null)}
                    className="rounded-lg border px-3 py-2 text-sm"
                    aria-label="الابن"
                  >
                    <option value="all">كل الأبناء</option>
                    {children.map(child => <option key={child.id} value={child.id}>{child.name}</option>)}
                  </select>
                  <select
                    value={certFilterType}
                    onChange={e => setCertFilterType(e.target.value as typeof certFilterType)}
                    className="rounded-lg border px-3 py-2 text-sm"
                    aria-label="نوع الشهادة"
                  >
                    <option value="all">كل الأنواع</option>
                    <option value="excellence">تفوّق</option>
                    <option value="appreciation">شكر وتقدير</option>
                    <option value="participation">مشاركة</option>
                  </select>
                  <input
                    type="search"
                    placeholder="بحث بالاسم أو المادة"
                    value={certSearch}
                    onChange={e => setCertSearch(e.target.value)}
                    className="rounded-lg border px-3 py-2 text-sm"
                  />
                </div>
              }
            >
              {filteredCertificates.length === 0 ? (
                <EmptyState title="لا شهادات" description="تظهر هنا الشهادات التي يصدرها المعلم لأبنائك." icon={Award} />
              ) : (
                <div className="portal-table-wrap">
                  <table className="portal-table">
                    <thead>
                      <tr>
                        <th>الشهادة</th>
                        <th>الطالب</th>
                        <th>المادة</th>
                        <th>الصف والفصل</th>
                        <th>المعلم</th>
                        <th>رقم الشهادة</th>
                        <th>التاريخ</th>
                        <th aria-label="إجراءات" />
                      </tr>
                    </thead>
                    <tbody>
                      {filteredCertificates.map(cert => (
                        <tr key={cert.id}>
                          <td>
                            <Badge tone={cert.type === 'excellence' ? 'gold' : cert.type === 'appreciation' ? 'primary' : 'accent'}>
                              {(CERTIFICATE_TYPES[cert.type] ?? CERTIFICATE_TYPES.participation).short}
                            </Badge>
                          </td>
                          <td className="font-bold text-slate-800">{cert.studentName}</td>
                          <td>{cert.subject}</td>
                          <td>{cert.grade} · {cert.term}</td>
                          <td>{cert.teacherName || '—'}</td>
                          <td className="is-num text-slate-500">{certificateNumber(cert)}</td>
                          <td className="is-num text-slate-500">{formatSafeDate(cert.date, { year: 'numeric', month: 'short', day: 'numeric' })}</td>
                          <td>
                            <div className="flex justify-end gap-1">
                              <button type="button" className="portal-btn portal-btn-secondary portal-btn-sm" onClick={() => setPreviewCert(cert)}>
                                <Eye aria-hidden="true" /> معاينة
                              </button>
                              <button type="button" className="portal-btn portal-btn-ghost portal-btn-sm" onClick={() => printCertificate(cert)} aria-label={`طباعة شهادة ${cert.studentName}`}>
                                <Printer aria-hidden="true" />
                              </button>
                            </div>
                          </td>
                        </tr>
                      ))}
                    </tbody>
                  </table>
                </div>
              )}
            </Panel>
          </div>
        )}

        {/* ---------- SETTINGS ---------- */}
        {menuType === ParentMenuType.SETTINGS && (
          <div className="portal-page">
            <PageHeader eyebrow="بوابة ولي الأمر" title="إعدادات الحساب" description="بيانات حسابك وتغيير كلمة المرور." icon={Settings2} />
            <div className="portal-grid-2">
              <Panel title="بيانات الحساب" icon={UserRound}>
                <dl className="portal-mini-stats" style={{ gridTemplateColumns: '1fr' }}>
                  <div><dt>الاسم الكامل</dt><dd>{parent?.name}</dd></div>
                  <div><dt>اسم المستخدم</dt><dd dir="ltr" className="text-right">{parent?.username}</dd></div>
                  <div><dt>المعلم المرتبط</dt><dd>{teacherName || '—'}</dd></div>
                  <div><dt>عدد الأبناء</dt><dd>{children.length}</dd></div>
                </dl>
              </Panel>
              <Panel title="تغيير كلمة المرور" icon={KeyRound}>
                <form onSubmit={handleSavePassword} className="flex flex-col gap-3">
                  <label className="flex flex-col gap-1 text-sm font-bold">
                    كلمة المرور الحالية
                    <input type="password" value={currentPasswordDraft} onChange={e => setCurrentPasswordDraft(e.target.value)} className="rounded-lg border px-3 py-2.5" autoComplete="current-password" required />
                  </label>
                  <label className="flex flex-col gap-1 text-sm font-bold">
                    كلمة المرور الجديدة
                    <input type="password" value={newPasswordDraft} onChange={e => setNewPasswordDraft(e.target.value)} className="rounded-lg border px-3 py-2.5" autoComplete="new-password" minLength={6} required />
                    <span className="text-xs font-medium text-slate-500">ستة أحرف على الأقل</span>
                  </label>
                  <label className="flex flex-col gap-1 text-sm font-bold">
                    تأكيد كلمة المرور الجديدة
                    <input type="password" value={confirmPasswordDraft} onChange={e => setConfirmPasswordDraft(e.target.value)} className="rounded-lg border px-3 py-2.5" autoComplete="new-password" required />
                  </label>
                  {passwordSaveError && (
                    <p className="rounded-lg bg-red-50 px-3 py-2 text-sm font-bold text-red-700" role="alert">{passwordSaveError}</p>
                  )}
                  <button type="submit" className="portal-btn portal-btn-primary self-start">حفظ كلمة المرور</button>
                </form>
              </Panel>
            </div>
          </div>
        )}
      </PortalShell>

      {childDialog && parent && (
        <PortalDialog
          title={childDialog.name}
          subtitle={`التقرير التفصيلي · ${childDialog.primaryGrade || childDialog.grade || 'بلا صف'}`}
          media={<img src={studentArt(childDialog.gender)} alt="" />}
          onClose={() => setChildDialog(null)}
        >
          <ParentHome
            parent={parent}
            children={children}
            results={allQuizzes}
            certificates={childCertificates}
            teacherName={teacherName}
            activeChild={childDialog}
            embedded
            getChildSubjects={getChildSubjects}
            quizTypeLabel={getQuizTypeLabel}
            isTeacherQuiz={(quizType) => normalizeQuizType(quizType) === QuizType.TEACHER}
            canAddChild={false}
            onAddChild={() => undefined}
            onOpenChild={setChildDialog}
            onBack={() => setChildDialog(null)}
            onOpenSubject={(child, subject) => { setActiveChild(child); setActiveSubject(subject); }}
            onPrintSubject={printSubjectReport}
            onPrintTeacherResults={printTeacherResultsReport}
            onPreviewCertificate={setPreviewCert}
          />
        </PortalDialog>
      )}

      {activeChild && activeSubject && (
        <PortalDialog
          title={`مادة ${activeSubject}`}
          subtitle={`${activeChild.name} · ${activeChild.primaryGrade || activeChild.grade || 'بلا صف'}${syncing ? ' · يُحدَّث…' : ''}`}
          media={<img src={subjectArt(activeSubject)} alt="" />}
          onClose={() => setActiveSubject(null)}
          actions={
            allQuizzes.some((quiz) => quiz.studentId === activeChild.id && quiz.subject === activeSubject) ? (
              <button type="button" className="portal-btn portal-btn-secondary" onClick={() => printSubjectReport(activeChild, activeSubject)}>
                <Printer aria-hidden="true" /> طباعة
              </button>
            ) : undefined
          }
        >
          <CardErrorBoundary label={`تفاصيل مادة ${activeSubject}`}>
            {syncError && (
              <div role="status" className="mb-4 flex items-center gap-2 rounded-lg border border-amber-200 bg-amber-50 px-3 py-2 text-xs font-bold text-amber-700">
                <IconTriangleAlert className="h-4 w-4" aria-hidden="true" />
                <span>تعذّر تحديث البيانات من الخادم — ما يُعرض قد لا يكون الأحدث.</span>
              </div>
            )}
            <SubjectDetails
              child={activeChild}
              subject={activeSubject}
              results={allQuizzes}
              certificates={childCertificates}
              quizTypeLabel={getQuizTypeLabel}
              isTeacherQuiz={(quizType) => normalizeQuizType(quizType) === QuizType.TEACHER}
              pathOf={(result) => formatAcademicPath(quizResultPath(result, createdQuizzes))}
              onPreviewCertificate={setPreviewCert}
            />
          </CardErrorBoundary>
        </PortalDialog>
      )}

      {/* ===== معاينة الشهادة ===== */}
      {previewCert && (
        <DocumentPreview
          title={`${(CERTIFICATE_TYPES[previewCert.type] ?? CERTIFICATE_TYPES.participation).title} — ${previewCert.studentName}`}
          document={certificateDocument(previewCert)}
          pageWidth={1123}
          onClose={() => setPreviewCert(null)}
        />
      )}

      {/* ===== Chat ===== */}
      {showChat && parent && (
        <PrivateChat currentUserId={parent.id} currentUserName={parent.name} currentUserRole="parent" onClose={() => setShowChat(false)} />
      )}

      {/* ===== Change Grade Modal ===== */}
      {showChangeGradeModal && studentToChangeGrade && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/50 p-3 safe-area-x safe-area-top safe-area-bottom">
          <div className="mobile-modal-panel w-full max-w-sm rounded-2xl bg-white p-5 shadow-2xl sm:p-6" role="dialog" aria-modal="true" aria-label="تغيير الصف">
            <div className="text-center mb-4"><div className="text-4xl mb-2"><IconBookOpen className="inline-block h-[1em] w-[1em] align-[-0.125em]" aria-hidden="true" /></div><h2 className="text-lg font-black text-rose-900 mb-1">تغيير الصف</h2><p className="text-rose-400 font-bold text-xs">{studentToChangeGrade.name}</p></div>
            <div className="mb-4 space-y-2">
              <label className="block text-xs font-bold text-rose-600">الصف الحالي: <span className="text-rose-500">{studentToChangeGrade.primaryGrade || studentToChangeGrade.grade}</span></label>
              <select value={selectedNewGrade} onChange={e => setSelectedNewGrade(e.target.value)} className="w-full p-3 rounded-xl border border-rose-200 focus:border-rose-400 focus:ring-4 focus:ring-rose-100 outline-none font-bold text-sm bg-rose-50">
                {availableGrades.map(grade => <option key={grade} value={grade}>{grade}</option>)}
              </select>
            </div>
            <div className="flex gap-2">
              <button onClick={() => { setShowChangeGradeModal(false); setStudentToChangeGrade(null); }} className="flex-1 py-2.5 rounded-xl border border-rose-200 text-rose-600 font-bold text-sm hover:bg-rose-50 transition-all">إلغاء</button>
              <button onClick={handleConfirmGradeChange} className="flex-1 py-2.5 rounded-xl bg-rose-500 text-white font-bold text-sm hover:bg-rose-600 transition-all">تأكيد</button>
            </div>
          </div>
        </div>
      )}

    </>
  );
};

export default ParentDashboard;
