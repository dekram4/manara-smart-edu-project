
export enum AdminMenuType {
  DASHBOARD = 'DASHBOARD',
  ACADEMIC_SETTINGS = 'ACADEMIC_SETTINGS',
  STUDENT_MANAGEMENT = 'STUDENT_MANAGEMENT',
  TEACHER_MANAGEMENT = 'TEACHER_MANAGEMENT',
  CONTENT_MANAGEMENT = 'CONTENT_MANAGEMENT',
  QUIZ_MANAGEMENT = 'QUIZ_MANAGEMENT',
  REPORTS = 'REPORTS',
  SYSTEM_SETTINGS = 'SYSTEM_SETTINGS',
}

export enum StudentModuleType {
  EXPLANATION = 'EXPLANATION',
  AVATAR_INTERACTION = 'AVATAR_INTERACTION',
  PERSONALITY = 'PERSONALITY',
  PROBLEM_SOLVING = 'PROBLEM_SOLVING',
  QUIZ = 'QUIZ',
  LIVE_MEETING = 'LIVE_MEETING',
  CHAT = 'CHAT',
  ACCOUNT = 'ACCOUNT',
  ENTERTAINMENT = 'ENTERTAINMENT',
  VIDEOS = 'VIDEOS', // 🎬 فيديوهات المعلم
}

export enum ParentMenuType {
  DASHBOARD = 'DASHBOARD',
  CHILDREN = 'CHILDREN',
  ADD_CHILDREN = 'ADD_CHILDREN',
  PERMISSION_PACKAGES = 'PERMISSION_PACKAGES',
  CERTIFICATES = 'CERTIFICATES',
  SETTINGS = 'SETTINGS',
  CHAT = 'CHAT',
}

export enum TeacherMenuType {
  DASHBOARD = 'DASHBOARD',
  ACADEMIC_SETTINGS = 'ACADEMIC_SETTINGS',
  CONTENT_MANAGEMENT = 'CONTENT_MANAGEMENT',
  VIDEO_MANAGEMENT = 'VIDEO_MANAGEMENT',
  QUIZ_MANAGEMENT = 'QUIZ_MANAGEMENT',
  ACCOUNT_MANAGEMENT = 'ACCOUNT_MANAGEMENT',
  PERMISSION_PACKAGES = 'PERMISSION_PACKAGES',
  REPORTS = 'REPORTS',
  CERTIFICATES = 'CERTIFICATES',
  MY_ACCOUNT = 'MY_ACCOUNT',
}

export interface StudentAppearance {
  shape: string;
  color: string;
  outfit: string;
}

export enum QuizType {
  PERIODIC = 'periodic',
  TEACHER = 'teacher',
}

export interface StudentInfo {
  id: string;
  name: string;
  /** Student-selected gender, used for the student avatar/emoji. */
  gender?: 'male' | 'female';
  /** Optional student-created avatar appearance. Legacy students use gender defaults. */
  appearance?: StudentAppearance;
  username?: string;
  password: string;
  parentPhoneNumber: string;
  parentId?: string;
  nationalId?: string; // رقم الهوية
  primaryGrade: string; // الصف الأساسي
  // كل صف له enrollments خاصة به
  gradeEnrollments: {
    grade: string;
    enrollments: {
      id?: string;
      subject: string;
      atram: string;
      term: string;
      unit: string;
    }[];
  }[];
  studentIdNumber?: string;
  createdAt: string;
  lastActivity: string;
  canChangeGrade?: boolean;
  /** Explicit teacher assignment. Presence is authoritative, including ''. */
  teacherId?: string;
  createdBy?: string;
  createdByName?: string;
  permissionPackageId?: string;
  quizResults?: QuizResult[]; // نتائج الاختبارات
  // للتوافقية مع الكود القديم
  grade?: string;
  subject?: string;
  atram?: string;
  term?: string;
  unit?: string;
  enrollments?: any[];
  /** Shared progress snapshot shown to teachers and parents. */
  gamification?: StudentGamification;
}

export interface StudentGamification {
  xp: number;
  gems: number;
  level: number;
  levelProgress: number;
  streak: number;
  totalQuizzes: number;
  totalLessons: number;
  totalGames: number;
  achievementsCount: number;
  averageScore: number;
  lastQuizAt?: string;
  lastQuizPercentage?: number;
  xpBonus200GrantedAt?: string;
  updatedAt: string;
}

export interface GradeConfig {
  grade: string;
  subjects: {
    subject: string;
    enrollments: {
      id?: string;
      atram?: string;
      term?: string;
      unit?: string;
    }[];
  }[];
}

// البنية الهرمية المثالية: صف → ترم → مادة → فصل → وحدة
export interface HierarchicalConfig {
  grade: string;
  atrams: {
    atram: string;
    subjects: {
      subject: string;
      terms: {
        term: string;
        units: string[];
      }[];
    }[];
  }[];
  createdBy?: string; // معرف المعلم الذي أنشأ هذا الإعداد
  createdByName?: string; // اسم المعلم
  createdAt?: string; // تاريخ الإنشاء
  createdByAdmin?: boolean; // true إذا أنشأه المشرف للمعلم
  copiedFrom?: string; // معرف المنشئ الأصلي (عند النسخ)
  copiedFromName?: string; // اسم المنشئ الأصلي
}

export interface LessonConfig {
  id: string;
  grade: string;
  subject: string;
  atram: string;
  term: string;
  unit: string;
  explanationVideoUrl?: string;
  avatarInteractionUrl?: string;
  liveMeetingUrl?: string;
  lessonContent: string;
  createdAt: string;
  createdBy: string;
  createdByName?: string; // اسم المعلم
  hierarchicalConfigId?: string; // معرف الإعداد الأكاديمي المرتبط
}

export interface QuizQuestion {
  id: string;
  question: string;
  options: string[];
  correctAnswer: string;
  lessonId: string;
  grade: string;
  subject: string;
  atram: string;
  term: string;
  unit: string;
  quizType: QuizType;
  /** Present for questions belonging to a created quiz; legacy questions may omit it. */
  quizId?: string;
  createdAt: string;
  source?: string;
  variation?: number;
}

// 🎯 نوع جديد: اختبار منشأ بواسطة المشرف
export interface CreatedQuiz {
  id: string;
  title: string;
  grade: string;
  subject: string;
  atram: string;
  term: string;
  unit: string;
  quizType: QuizType;
  questionCount: number;
  isActive: boolean; // مفعل أم لا
  questions: QuizQuestion[];
  /** How the quiz was created; legacy quizzes infer this from their questions. */
  creationMode?: 'manual' | 'ai';
  /** Periodic quiz number within the same owner and academic path. */
  periodicNumber?: number;
  /** Number of questions shown to one student from the question bank. */
  questionsPerAttempt?: number;
  /** Tombstone used to keep a deleted quiz from returning during sync. */
  deleted?: boolean;
  deletedAt?: string;
  createdAt: string;
  createdBy: string;
  createdByName?: string;
  lastModified?: string;
}

export interface QuizResult {
  id: string;
  studentId: string;
  studentName: string;
  quizId: string;
  quizType: string;
  subject: string;
  unit: string;
  grade: string;
  score: number;
  total: number;
  percentage: number;
  level: string;
  feedback: string;
  details: {
    question: string;
    userAnswer: string;
    correctAnswer: string;
    isCorrect: boolean;
  }[];
  createdAt: string;
  quizTitle?: string;
  attemptNumber?: number;
  isRetake?: boolean;
}

export interface ParentInfo {
  id: string;
  name: string;
  username: string;
  password: string;
  phoneNumber: string;
  nationalId?: string; // رقم الهوية
  children: StudentInfo[];
  mustChangePassword?: boolean;
  createdAt: string;
  lastLogin: string;
  createdBy?: string; // teacher ID who created this parent
  createdByName?: string; // teacher name
  parentPermissions?: Partial<Permissions['parent']>; // صلاحيات مخصصة يمنحها المعلم لولي الأمر
  permissionPackageId?: string;
}

export interface ChatMessage {
  id: string;
  senderId: string;
  senderName: string;
  grade: string;
  subject?: string;
  message: string;
  timestamp: string;
  isSystem: boolean;
}

export interface InteractionRecord {
  id: string;
  studentId: string;
  studentName: string;
  lessonId?: string;
  grade?: string;
  subject?: string;
  unit?: string;
  action: 'avatar_open' | 'avatar_close' | 'video_play' | 'other';
  timestamp: string;
}

export interface SystemStats {
  totalStudents: number;
  totalParents: number;
  activeStudents: number;
  totalQuizzesTaken: number;
  averageQuizScore: number;
  recentActivities: {
    studentName: string;
    activity: string;
    time: string;
    grade: string;
  }[];
  lessonsCount: number;
  subjectsCount: number;
  gradesCount: number;
}

export interface ReportData {
  reportId: string;
  type: 'students' | 'quizzes' | 'lessons' | 'parents';
  title: string;
  data: any[];
  generatedAt: string;
  generatedBy: string;
}

export interface AdminSettings {
  chatEnabled: boolean;
  allowGradeChange: boolean;
  maxStudentsPerParent: number;
  quizPassingScore: number;
  adminUsername?: string;
  adminPassword?: string;
  adminContactInfo?: string;
}

export interface StudentProgress {
  studentId: string;
  subject: string;
  unit: string;
  term: string;
  completionPercentage: number;
  explanationCompleted: boolean;
  avatarInteractionCompleted: boolean;
  problemSolvingCompleted: boolean;
  quizCompleted: boolean;
  quizScore?: number;
  lastActivityTime: string;
}

export interface SubjectPerformance {
  subject: string;
  averageScore: number;
  quizzesCount: number;
  lastActivity: string;
  units: {
    unit: string;
    score: number;
    completed: boolean;
  }[];
}

export interface CertificateRecord {
  id: string;
  studentId: string;
  studentName: string;
  teacherId: string;
  teacherName: string;
  type: 'excellence' | 'appreciation' | 'participation';
  subject: string;
  grade: string;
  atram: string;
  term: string;
  date: string;
  average: number;
  note?: string;
}

export interface TeacherInfo {
  id: string;
  name: string;
  username: string;
  password: string;
  teacherId: string; // هوية المعلم (رقم الهوية)
  subject?: string; // المادة
  createdAt: string;
  createdBy: string; // المشرف الذي أنشأه
  lastActivity: string;
  mustChangePassword: boolean; // إجبار تغيير كلمة المرور عند أول دخول
  permissionPackageId?: string;
}

export interface TeacherStats {
  totalParents: number;
  totalStudents: number;
  totalAcademicConfigs: number;
  lastActivity: string;
}

// نظام الصلاحيات
export interface TeacherPermissions {
    canManageAcademicSettings: boolean; // إضافة/تعديل الإعدادات الأكاديمية
    canEditGeneralSettings: boolean; // تعديل الإعدادات العامة من المشرف
    canManageContent: boolean; // إضافة/تعديل المحتوى
    canManageVideos: boolean; // إضافة/تعديل الفيديوهات
    canCreateParents: boolean; // إنشاء أولياء أمور
    canEditParents: boolean; // تعديل أولياء أمور
    canDeleteParents: boolean; // حذف أولياء أمور
    canManageParentPermissions: boolean; // منح صلاحيات مخصصة لولي الأمر
    canCreateStudents: boolean; // إنشاء طلاب
    canEditStudents: boolean; // تعديل طلاب
    canDeleteStudents: boolean; // حذف طلاب
    canViewReports: boolean; // عرض التقارير
    canManageQuizzes: boolean; // إدارة الاختبارات
    maxParents: number; // الحد الأقصى لأولياء الأمور، -1 = غير محدود
    maxStudents: number; // الحد الأقصى للطلاب، -1 = غير محدود
    maxContent: number; // الحد الأقصى للدروس، -1 = غير محدود
    maxVideos: number; // الحد الأقصى للفيديوهات، -1 = غير محدود
    maxStorageMb: number; // مساحة الفيديوهات بالميجابايت، -1 = غير محدود
}

export interface ParentPermissions {
    canCreateStudents: boolean; // إنشاء أبناء
    canEditStudents: boolean; // تعديل بيانات الأبناء
    canDeleteStudents: boolean; // حذف أبناء
    canResetStudentPassword: boolean; // إعادة تعيين كلمة مرور الأبناء
    canViewReports: boolean; // عرض التقارير والإحصائيات
    canChangeGrade: boolean; // تغيير الصف للطالب
    canChatWithSupport: boolean; // التواصل مع الدعم
    maxStudents: number; // الحد الأقصى للأبناء، -1 = غير محدود
}

export interface Permissions {
  // صلاحيات المعلمين
  teacher: TeacherPermissions;
  // صلاحيات أولياء الأمور
  parent: ParentPermissions;
  // صلاحيات الطلاب
  student: {
    canChangeGrade: boolean; // تغيير الصف
    canAccessChat: boolean; // الوصول للشات
    canAccessLiveMeeting: boolean; // الوصول للقاءات المباشرة
    canRetakeQuiz: boolean; // إعادة الاختبار
    canViewSolutions: boolean; // عرض الحلول
    canDownloadCertificates: boolean; // تحميل الشهادات
  };
}

export type PermissionPackageRole = 'teacher' | 'parent' | 'student';

export interface PermissionPackage {
  id: string;
  name: string;
  description?: string;
  role: PermissionPackageRole;
  permissions: TeacherPermissions | ParentPermissions | Permissions['student'];
  createdAt: string;
  updatedAt: string;
  /** Missing owner metadata means the package was created by the admin. */
  ownerRole?: 'admin' | 'teacher' | 'parent';
  ownerId?: string;
  ownerName?: string;
}
