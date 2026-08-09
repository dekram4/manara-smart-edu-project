
export const ADMIN_USERNAME = 'dekram';
export const ADMIN_PASSWORD = '123';
export const DEFAULT_PASSWORD = '123456';

export const STORAGE_KEYS = {
  LESSON_CONFIGS: 'smartEdu_lessonConfigs',
  STUDENTS: 'smartEdu_students',
  GRADES: 'smartEdu_grades',
  SUBJECTS: 'smartEdu_subjects',
  GRADE_CONFIGS: 'smartEdu_gradeConfigs',
  HIERARCHICAL_CONFIGS: 'smartEdu_hierarchicalConfigs',
  TERMS: 'smartEdu_terms',
  ATRAMS: 'smartEdu_atrams',
  UNITS: 'smartEdu_units',
  ACTIVE_STUDENT: 'smartEdu_activeStudent',
  ACTIVE_PARENT: 'smartEdu_activeParent',
  PARENTS: 'smartEdu_parents',
  TEACHERS: 'smartEdu_teachers', // 👨‍🏫 المعلمون
  CURRENT_TEACHER: 'smartEdu_currentTeacher', // المعلم الحالي المسجل دخوله
  QUIZ_RESULTS: 'smartEdu_quizResults',
  QUIZ_QUESTIONS: 'smartEdu_quizQuestions',
  CREATED_QUIZZES: 'smartEdu_createdQuizzes', // 🎯 اختبارات منشأة من المشرف
  CHAT_MESSAGES: 'smartEdu_chatMessages',
  INTERACTIONS: 'smartEdu_interactions',
  ADMIN_SETTINGS: 'smartEdu_adminSettings',
  REPORTS: 'smartEdu_reports',
  PERMISSIONS: 'smartEdu_permissions', // 🔐 نظام الصلاحيات
  PRIVATE_MESSAGES: 'smartEdu_privateMessages', // 💬 الدردشة الخاصة
  VIDEOS: 'smartEdu_videos', // 🎬 فيديوهات المعلم
  DELETED_VIDEOS: 'smartEdu_deletedVideos', // 🗑️ علامات حذف الفيديوهات حتى لا تعود من المزامنة
  VIDEO_NOTIFICATIONS: 'smartEdu_videoNotifications', // 🔔 إشعارات الفيديوهات للمشرف
};

export const COLORS = {
  primary: '#0B8693',
  secondary: '#10B981',
  danger: '#EF4444',
  warning: '#F59E0B',
  info: '#274E76',
  dark: '#0E1B2A',
  light: '#F3F8F9',
  success: '#10B981',
  gray: '#6B7280',
};

export const QUIZ_TYPES = [
  { value: 'periodic', label: 'الاختبار الدوري' },
  { value: 'teacher', label: 'اختبار المعلم' },
];

// الصلاحيات الافتراضية
export const DEFAULT_PERMISSIONS = {
  teacher: {
    canManageAcademicSettings: true,
    canEditGeneralSettings: true,
    canManageContent: true,
    canManageVideos: true,
    canCreateParents: true,
    canEditParents: true,
    canDeleteParents: true,
    canManageParentPermissions: true,
    canCreateStudents: true,
    canEditStudents: true,
    canDeleteStudents: true,
    canViewReports: true,
    canManageQuizzes: true,
    maxParents: 50,
    maxStudents: 200,
    maxContent: 100,
    maxVideos: 100,
    maxStorageMb: 500,
  },
  parent: {
    canCreateStudents: true,
    canEditStudents: true,
    canDeleteStudents: false,
    canResetStudentPassword: true,
    canViewReports: true,
    canChangeGrade: false,
    canChatWithSupport: true,
    maxStudents: 5,
  },
  student: {
    canChangeGrade: false,
    canAccessChat: true,
    canAccessLiveMeeting: true,
    canRetakeQuiz: true,
    canViewSolutions: true,
    canDownloadCertificates: true,
  },
};
