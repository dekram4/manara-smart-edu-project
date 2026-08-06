import AsyncStorage from '@react-native-async-storage/async-storage';

export const STORAGE_KEYS = {
  STUDENTS: 'manara_students',
  TEACHERS: 'manara_teachers',
  PARENTS: 'manara_parents',
  ADMINS: 'manara_admins',
  LESSONS: 'manara_lessons',
  VIDEOS: 'manara_videos',
  QUIZZES: 'manara_quizzes',
  CHAT_MESSAGES: 'manara_chat_messages',
  PRIVATE_MESSAGES: 'manara_private_messages',
  ACTIVE_USER: 'manara_active_user',
  ADMIN_SETTINGS: 'manara_admin_settings',
  XP: 'manara_xp',
  GEMS: 'manara_gems',
  ACHIEVEMENTS: 'manara_achievements',
  STREAK: 'manara_streak',
  LAST_LOGIN: 'manara_last_login',
  GAME_SCORES: 'manara_game_scores',
};

export const getData = async (key: string, defaultValue: any = null) => {
  try {
    const saved = await AsyncStorage.getItem(key);
    return saved ? JSON.parse(saved) : defaultValue;
  } catch { return defaultValue; }
};

export const setData = async (key: string, value: any) => {
  try {
    await AsyncStorage.setItem(key, JSON.stringify(value));
  } catch {}
};

export const removeData = async (key: string) => {
  try { await AsyncStorage.removeItem(key); } catch {}
};

export const addXP = async (amount: number) => {
  const current = await getData(STORAGE_KEYS.XP, 0);
  await setData(STORAGE_KEYS.XP, current + amount);
};

export const addGems = async (amount: number) => {
  const current = await getData(STORAGE_KEYS.GEMS, 0);
  await setData(STORAGE_KEYS.GEMS, current + amount);
};

export const checkStreak = async () => {
  const lastLogin = await getData(STORAGE_KEYS.LAST_LOGIN, null);
  const today = new Date().toDateString();
  if (lastLogin === today) return;
  
  const yesterday = new Date();
  yesterday.setDate(yesterday.getDate() - 1);
  const streak = await getData(STORAGE_KEYS.STREAK, 0);
  
  if (lastLogin === yesterday.toDateString()) {
    await setData(STORAGE_KEYS.STREAK, streak + 1);
    await addGems(5); // streak bonus
  } else {
    await setData(STORAGE_KEYS.STREAK, 1);
  }
  await setData(STORAGE_KEYS.LAST_LOGIN, today);
};

export const unlockAchievement = async (id: string, title: string) => {
  const achievements = await getData(STORAGE_KEYS.ACHIEVEMENTS, []);
  if (!achievements.find((a: any) => a.id === id)) {
    achievements.push({ id, title, unlockedAt: new Date().toISOString() });
    await setData(STORAGE_KEYS.ACHIEVEMENTS, achievements);
    await addGems(10); // achievement bonus
  }
};

export const getSampleLessons = () => [
  {
    id: '1', title: 'مقدمة في العلوم', subject: 'العلوم', grade: 'الصف السابس',
    term: 'الفصل الأول', unit: 'الوحدة 1',
    content: 'تعرف على عالم البيولوجيا والحياة وكيف تتأقلم المخلوقات...',
    videoUrl: 'https://www.youtube.com/watch?v=dQw4w9WgXcQ',
  },
  {
    id: '2', title: 'العدد والعملية الحسابية', subject: 'الحاسب', grade: 'الصف الرابع',
    term: 'الفصل الأول', unit: 'الوحدة 1',
    content: 'تعلم كيفية الجمع والطرح والضرب والقسمة...',
    videoUrl: '',
  },
  {
    id: '3', title: 'تاريخ العرب قبل الإسلام', subject: 'التاريخ', grade: 'الصف السابس',
    term: 'الفصل الأول', unit: 'الوحدة 2',
    content: 'الجزيرة العربية قبل بعث الإسلام كانت مليئة بالمجمعات...',
    videoUrl: '',
  },
];

export const getSampleVideos = () => [
  { id: '1', title: 'درس: الصور الكيميائية', teacher: 'أحمد المعلم', grade: 'الصف السابس', subject: 'العلوم', url: 'dQw4w9WgXcQ' },
  { id: '2', title: 'درس: المراجعات', teacher: 'فاطمة المعلم', grade: 'الصف الرابع', subject: 'العربية', url: '' },
  { id: '3', title: 'درس: الهدف الصحيح', teacher: 'أحمد المعلم', grade: 'الصف الثالث', subject: 'الإسلام', url: '' },
];

export const getSampleContacts = () => [
  { id: 't1', name: 'أحمد المعلم', role: 'teacher' as const },
  { id: 't2', name: 'فاطمة المعلم', role: 'teacher' as const },
  { id: 'a1', name: 'المشرف', role: 'admin' as const },
];
