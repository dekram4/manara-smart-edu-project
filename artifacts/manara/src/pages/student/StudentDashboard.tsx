import React, { Component, ErrorInfo, ReactNode, useState, useEffect, useRef } from 'react';
import { StudentInfo, LessonConfig, StudentModuleType, QuizQuestion, QuizResult, QuizType, CreatedQuiz } from '../../types';
import EntertainmentGames from './EntertainmentGames';
import StudentVideos from './StudentVideos';
import { STORAGE_KEYS, COLORS, QUIZ_TYPES } from '../../constants';
import { passwordsMatch } from '../../utils/password';
import StudentLogin from './StudentLogin';
import StudentPersonality from './StudentPersonality';
import * as math from 'mathjs';
import { getStudentPermissions } from '../../permissions';
import { getLessonExplanationVideos, isSafeVideoUrl } from '../../utils/video';
import { playWelcomeStudentOnRefresh, playLamsaSound } from '../../utils/sounds';
import { triggerCelebration } from '../../App';
import {
  filterTeacherOwnedRecords,
  getRecordTeacherId,
  getStudentTeacherScope,
  matchesAcademicScope,
  normalizeScopeValue,
} from '../../utils/scope';
import {
  checkStreak,
  getGamificationStats,
  hasCompletedActivity,
  resetGamification,
  rewardLessonComplete,
  rewardProblemSolved,
  rewardQuizCompleteWithId,
  syncGamificationToStudent,
  hydrateGamificationFromStudent,
} from '../../utils/gamification';

// 1. استدعاءات framer-motion والمؤثرات الصوتية من App.tsx
import { motion, AnimatePresence } from 'framer-motion';
import { soundPop, soundClick } from '../../App';
import { getStickerAsset } from '../../utils/contentAssets';
import { AnimatedCelebration } from '../../components/AnimatedCelebration';
import { InteractiveScene } from '../../components/InteractiveScene';
import PremiumBackground from '../../components/PremiumBackground';
import EducationalCardEffects from '../../components/effects/EducationalCardEffects';
import Interactive3DEmoji from '../../components/effects/Interactive3DEmoji';
import { GameAudioEngine } from '../../utils/gameAudioEngine';
import StudentAvatar from './components/StudentAvatar';
import ManaraBrand from '../../components/ManaraBrand';
import TouchCarousel from '../../components/TouchCarousel';
import VideoCarousel from '../../components/VideoCarousel';
import {
  getPeriodicQuizLabel,
  normalizeCreatedQuiz,
  normalizeQuizType,
  getQuizTypeLabel,
} from '../../utils/quizTypes';
import { getCorrectAnswerText, isQuizAnswerCorrect } from '../../utils/quizScoring';
import { readActiveSession, readStorageArray, writeActiveSession, removeActiveSession } from '../../utils/storage';
import { writeAuthSession } from '../../utils/authSession';

const stableQuestionHash = (value: string): number => {
  let hash = 2166136261;
  for (let index = 0; index < value.length; index += 1) {
    hash ^= value.charCodeAt(index);
    hash = Math.imul(hash, 16777619);
  }
  return hash >>> 0;
};

const getStudentQuestionSet = (
  questions: QuizQuestion[],
  studentId: string,
  quizId: string,
  requestedCount: number,
): QuizQuestion[] => {
  const count = Math.min(Math.max(1, requestedCount), questions.length);
  return [...questions]
    .sort((a, b) =>
      stableQuestionHash(`${studentId}:${quizId}:${a.id}`) -
      stableQuestionHash(`${studentId}:${quizId}:${b.id}`),
    )
    .slice(0, count);
};

type SafeGradeEnrollment = {
  grade?: string;
  enrollments?: Array<{
    subject?: string;
    atram?: string;
    term?: string;
    unit?: string;
    [key: string]: unknown;
  }>;
  [key: string]: unknown;
};

const getSafeGradeEnrollments = (
  candidate: StudentInfo | null | undefined,
): SafeGradeEnrollment[] => (
  Array.isArray(candidate?.gradeEnrollments)
    ? candidate.gradeEnrollments
      .filter((entry) => Boolean(entry && typeof entry === 'object'))
      .map((entry) => entry as SafeGradeEnrollment)
    : []
);

const getSafeEnrollments = (entry: SafeGradeEnrollment | null | undefined) => (
  Array.isArray(entry?.enrollments)
    ? entry.enrollments.filter((enrollment) => Boolean(enrollment && typeof enrollment === 'object'))
    : []
);

const getSafeLegacyEnrollments = (candidate: StudentInfo | null | undefined) => (
  Array.isArray(candidate?.enrollments)
    ? candidate.enrollments.filter((enrollment): enrollment is Record<string, any> => (
      Boolean(enrollment && typeof enrollment === 'object')
    ))
    : []
);

const moduleThemes: Record<string, { shellClass: string; glowClass: string; borderClass: string; portalClass: string }> = {
  explanation: {
    shellClass: 'from-amber-500/18 via-orange-500/10 to-transparent',
    glowClass: 'from-amber-400/30 via-orange-500/15 to-transparent',
    borderClass: 'border-amber-400/30',
    portalClass: 'from-amber-400/70 via-orange-500/45 to-transparent',
  },
  avatar: {
    shellClass: 'from-fuchsia-500/18 via-purple-500/10 to-transparent',
    glowClass: 'from-fuchsia-400/30 via-purple-500/15 to-transparent',
    borderClass: 'border-fuchsia-400/30',
    portalClass: 'from-fuchsia-400/70 via-purple-500/45 to-transparent',
  },
  problem: {
    shellClass: 'from-cyan-500/18 via-teal-500/10 to-transparent',
    glowClass: 'from-cyan-400/30 via-teal-500/15 to-transparent',
    borderClass: 'border-cyan-400/30',
    portalClass: 'from-cyan-400/70 via-teal-500/45 to-transparent',
  },
  meeting: {
    shellClass: 'from-rose-500/18 via-red-500/10 to-transparent',
    glowClass: 'from-rose-400/30 via-red-500/15 to-transparent',
    borderClass: 'border-rose-400/30',
    portalClass: 'from-rose-400/70 via-red-500/45 to-transparent',
  },
  entertainment: {
    shellClass: 'from-violet-500/18 via-purple-600/10 to-transparent',
    glowClass: 'from-violet-400/30 via-purple-500/15 to-transparent',
    borderClass: 'border-violet-400/30',
    portalClass: 'from-violet-400/70 via-purple-500/45 to-transparent',
  },
  videos: {
    shellClass: 'from-sky-500/18 via-blue-500/10 to-transparent',
    glowClass: 'from-sky-400/30 via-blue-500/15 to-transparent',
    borderClass: 'border-sky-400/30',
    portalClass: 'from-sky-400/70 via-blue-500/45 to-transparent',
  },
  quiz: {
    shellClass: 'from-amber-500/18 via-yellow-500/10 to-transparent',
    glowClass: 'from-amber-400/30 via-yellow-500/15 to-transparent',
    borderClass: 'border-amber-400/30',
    portalClass: 'from-amber-400/70 via-yellow-500/45 to-transparent',
  },
  default: {
    shellClass: 'from-slate-500/15 via-slate-600/10 to-transparent',
    glowClass: 'from-slate-400/20 via-slate-500/10 to-transparent',
    borderClass: 'border-white/15',
    portalClass: 'from-cyan-400/60 via-indigo-500/40 to-transparent',
  },
};

const getModuleTheme = (module: StudentModuleType | null) => {
  switch (module) {
    case StudentModuleType.EXPLANATION:
      return moduleThemes.explanation;
    case StudentModuleType.AVATAR_INTERACTION:
      return moduleThemes.avatar;
    case StudentModuleType.PROBLEM_SOLVING:
      return moduleThemes.problem;
    case StudentModuleType.LIVE_MEETING:
      return moduleThemes.meeting;
    case StudentModuleType.ENTERTAINMENT:
      return moduleThemes.entertainment;
    case StudentModuleType.VIDEOS:
      return moduleThemes.videos;
    case StudentModuleType.QUIZ:
      return moduleThemes.quiz;
    default:
      return moduleThemes.default;
  }
};

const parseExternalUrl = (rawUrl?: string) => {
  if (!rawUrl) return null;
  try {
    const value = rawUrl.trim();
    if (!value) return null;
    return new URL(/^https?:\/\//i.test(value) ? value : `https://${value}`);
  } catch {
    return null;
  }
};

const isBlockedMeetingEmbed = (url: URL) => {
  const host = url.hostname.toLowerCase();
  return (
    host === 'meet.google.com'
    || host.endsWith('.zoom.us')
    || host === 'zoom.us'
    || host === 'teams.microsoft.com'
    || host.endsWith('.teams.microsoft.com')
    || host === 'webex.com'
    || host.endsWith('.webex.com')
  );
};

const OpenExternalButton: React.FC<{ url: string; label: string }> = ({ url, label }) => (
  <a
    href={url}
    target="_blank"
    rel="noopener noreferrer"
    className="inline-flex min-h-11 items-center justify-center rounded-xl bg-white px-4 py-2.5 text-center text-sm font-black text-slate-950 shadow-lg transition hover:bg-cyan-100 active:scale-[0.98]"
  >
    {label}
  </a>
);

const ResponsiveAvatarEmbed: React.FC<{ rawUrl: string }> = ({ rawUrl }) => {
  const url = parseExternalUrl(rawUrl);
  if (!url) {
    return (
      <div className="rounded-2xl border border-amber-300/25 bg-amber-400/10 p-6 text-center text-sm font-bold leading-7 text-amber-100">
        رابط المعلم الافتراضي غير صالح. اطلب من المعلم تحديث الرابط من لوحة المحتوى.
      </div>
    );
  }

  return (
    <div className="space-y-3">
      <div className="relative aspect-[4/3] min-h-[360px] w-full overflow-hidden rounded-2xl border-2 border-purple-500/40 bg-black shadow-2xl sm:aspect-video sm:min-h-[390px] sm:rounded-[26px] sm:border-4 md:min-h-[480px]">
        <iframe
          src={url.toString()}
          title="المعلم الافتراضي"
          allow="camera; microphone; autoplay; clipboard-write; encrypted-media; fullscreen; picture-in-picture"
          allowFullScreen
          loading="eager"
          referrerPolicy="strict-origin-when-cross-origin"
          className="h-full w-full border-0"
          style={{ background: '#000' }}
        />
      </div>
      <div className="flex flex-col gap-2 rounded-2xl border border-purple-300/15 bg-purple-950/45 p-3 sm:flex-row sm:items-center sm:justify-between">
        <p className="text-xs font-bold leading-5 text-purple-100">
          تم ضبط إطار المعلم ليتكيف تلقائيًا مع الجوال والتابلت والآيباد.
        </p>
      </div>
    </div>
  );
};

const LiveMeetingEmbed: React.FC<{ rawUrl?: string }> = ({ rawUrl }) => {
  const url = parseExternalUrl(rawUrl);
  if (!url) {
    return (
      <div className="flex min-h-[260px] flex-col items-center justify-center bg-slate-900 px-5 text-center text-slate-300">
        <p className="text-lg font-black">لم يتم إضافة رابط الاجتماع بعد</p>
        <p className="mt-2 text-sm font-bold text-slate-400">سيظهر زر الانضمام هنا بعد حفظ رابط صحيح من لوحة المعلم.</p>
      </div>
    );
  }

  if (isBlockedMeetingEmbed(url)) {
    return (
      <div className="flex min-h-[300px] flex-col items-center justify-center bg-[radial-gradient(circle_at_top,rgba(244,63,94,0.2),transparent_45%),#0f172a] px-5 text-center">
        <p className="text-xl font-black text-white sm:text-2xl">الاجتماع جاهز للانضمام</p>
        <p className="mx-auto mt-2 max-w-lg text-sm font-bold leading-7 text-slate-300">
          هذا التطبيق يمنع تشغيل الاجتماع داخل إطار الصفحة. افتحه في نافذة كاملة ليعمل الصوت والكاميرا بشكل صحيح على الجوال والتابلت والآيباد.
        </p>
        <div className="mt-5">
          <OpenExternalButton url={url.toString()} label="الانضمام إلى الاجتماع" />
        </div>
      </div>
    );
  }

  return (
    <div className="flex min-h-[260px] w-full flex-col bg-black">
      <div className="min-h-[220px] flex-1">
        <iframe
          src={url.toString()}
          title="الاجتماع المباشر"
          className="h-full min-h-[220px] w-full border-0"
          allow="camera; microphone; display-capture; autoplay; fullscreen; speaker-selection"
          allowFullScreen
          loading="eager"
          referrerPolicy="strict-origin-when-cross-origin"
        />
      </div>
      <div className="flex shrink-0 flex-col gap-2 border-t border-white/10 bg-slate-950 p-3 sm:flex-row sm:items-center sm:justify-between">
        <p className="text-center text-xs font-bold text-slate-300 sm:text-right">
          استخدم زر الاتصال إذا لم يعمل الاجتماع داخل الصفحة.
        </p>
        <OpenExternalButton url={url.toString()} label="اتصال بالاجتماع" />
      </div>
    </div>
  );
};

const getLessonRewardId = (lesson: LessonConfig) => {
  const unitKey = [lesson.grade, lesson.atram, lesson.subject, lesson.term, lesson.unit]
    .map((value) => normalizeScopeValue(value || ''))
    .join('|');
  const videoKey = normalizeScopeValue(lesson.explanationVideoUrl || 'no-video');
  return `lesson_reward:${lesson.id}:${unitKey}:${videoKey}`;
};

const getQuizRewardId = (
  questions: QuizQuestion[],
  lesson: LessonConfig | null,
  quizType: QuizType,
  quizId?: string,
) => {
  if (quizId) return `quiz_reward:${normalizeScopeValue(quizType)}:${quizId}`;
  const first = questions[0];
  const scopeKey = [first?.grade, first?.atram, first?.subject, first?.term, first?.unit]
    .map((value) => normalizeScopeValue(value || ''))
    .join('|');
  const lessonKey = normalizeScopeValue(first?.lessonId || lesson?.id || 'no-lesson');
  return `quiz_reward:${normalizeScopeValue(quizType)}:${lessonKey}:${scopeKey}`;
};

const getGamificationResetKey = (studentInfo: StudentInfo) => {
  const identity = studentInfo.id || studentInfo.studentIdNumber || studentInfo.username || 'anonymous';
  return `MANARA_GAMIFICATION_RESET_V4_${String(identity)}`;
};

const ensureGamificationResetIfNeeded = (studentInfo: StudentInfo) => {
  const resetKey = getGamificationResetKey(studentInfo);
  const isResetDone = localStorage.getItem(resetKey) === '1';
  if (!isResetDone) {
    resetGamification();
    localStorage.setItem(resetKey, '1');
  }
};

// 2. مكون بطاقات الألعاب التفاعلية (Game Engine Style Card)
const GameModeCard = ({
  title,
  subtitle,
  icon,
  color,
  onClick,
  badge,
}: {
  title: string;
  subtitle?: string;
  icon: string;
  color: string;
  onClick: () => void;
  badge?: string;
}) => {
  const [hovered, setHovered] = React.useState(false);

  /* Extract a rough accent colour from the Tailwind gradient class for EducationalCardEffects */
  const accentMap: Record<string, string> = {
    amber: '#fbbf24', orange: '#fb923c', purple: '#a855f7', pink: '#ec4899',
    emerald: '#34d399', teal: '#2dd4bf', cyan: '#22d3ee', blue: '#60a5fa',
    violet: '#8b5cf6', rose: '#fb7185', red: '#f87171', indigo: '#818cf8',
  };
  const guessedAccent =
    Object.entries(accentMap).find(([k]) => color.includes(k))?.[1] ?? '#ffffff';

  return (
    <motion.div
      layout
      initial={{ opacity: 0, y: 24, scale: 0.93 }}
      animate={{ opacity: 1, y: 0, scale: 1 }}
      whileHover={{ scale: 1.055, y: -10 }}
       whileTap={{ scale: 1.035, y: -3 }}
      transition={{ type: 'spring', stiffness: 300, damping: 22 }}
       onHoverStart={() => {
         setHovered(true);
         GameAudioEngine.play('uiHover');
       }}
      onHoverEnd={() => setHovered(false)}
      onClick={() => { GameAudioEngine.play('portalTransition'); onClick(); }}
       className={`${color} min-h-[220px] sm:min-h-[260px] md:min-h-[300px] p-4 sm:p-6 md:p-8 text-white rounded-3xl sm:rounded-[32px] cursor-pointer flex flex-col justify-between relative overflow-hidden group select-none`}
      style={{
        boxShadow: hovered
          ? `0 28px 64px rgba(0,0,0,0.45), 0 0 0 1px rgba(255,255,255,0.12), inset 0 1px 0 rgba(255,255,255,0.18)`
          : `0 10px 32px rgba(0,0,0,0.3), inset 0 1px 0 rgba(255,255,255,0.12)`,
        transition: 'box-shadow 0.3s',
      }}
    >
      {/* Rich layered effects */}
      <EducationalCardEffects accent={guessedAccent} compact />

      {/* Top shimmer line */}
      <div className="pointer-events-none absolute inset-x-0 top-0 h-px bg-[linear-gradient(90deg,transparent,rgba(255,255,255,0.55),transparent)]" />

      {/* Animated vertical accent bar */}
      <motion.div
        className="pointer-events-none absolute left-4 top-5 w-1 rounded-full bg-white/70"
        animate={{ height: hovered ? 56 : 40, opacity: hovered ? 1 : 0.65 }}
        transition={{ duration: 0.3 }}
      />

      {/* Large corner radial glow */}
      <div
        className="pointer-events-none absolute -right-8 -top-8 h-32 w-32 rounded-full"
        style={{
          background: 'radial-gradient(circle, rgba(255,255,255,0.22), transparent 70%)',
          transform: hovered ? 'scale(1.35)' : 'scale(1)',
          transition: 'transform 0.4s',
        }}
      />

      {/* Bottom-left secondary glow */}
      <div className="pointer-events-none absolute -bottom-10 -left-10 h-28 w-28 rounded-full bg-black/20 blur-xl" />

      {/* Badge */}
      {badge && (
        <motion.div
          animate={{ scale: [1, 1.08, 1] }}
          transition={{ duration: 1.8, repeat: Infinity }}
          className="absolute left-4 top-4 z-10 rounded-full bg-yellow-400 px-3 py-1 text-xs font-black text-slate-900 shadow-lg shadow-yellow-400/40"
        >
          {badge}
        </motion.div>
      )}

      {/* Emoji with animated glow on hover */}
        <Interactive3DEmoji emoji={icon} accent={guessedAccent} size="lg" className="relative z-10 mb-3 sm:mb-5" />

      {/* Text */}
      <div className="relative z-10">
         <h3 className="mb-1 text-2xl font-black leading-tight drop-shadow-sm sm:text-3xl md:text-4xl">{title}</h3>
        {subtitle && (
          <p className="text-sm font-medium text-white/85 leading-relaxed">{subtitle}</p>
        )}
      </div>

      {/* Bottom edge shimmer */}
      <div className="pointer-events-none absolute inset-x-[10%] bottom-0 h-px bg-[linear-gradient(90deg,transparent,rgba(255,255,255,0.35),transparent)]" />
    </motion.div>
  );
};

class StudentPortalErrorBoundary extends Component<
  { children: ReactNode; fallback: ReactNode },
  { hasError: boolean }
> {
  state = { hasError: false };

  static getDerivedStateFromError() {
    return { hasError: true };
  }

  componentDidCatch(error: Error, errorInfo: ErrorInfo) {
    console.error('[student] learning portal render error:', error, errorInfo);
  }

  render() {
    return this.state.hasError ? this.props.fallback : this.props.children;
  }
}

const StudentExplanationFallback: React.FC<{ onBack: () => void }> = ({ onBack }) => (
  <div className="rounded-[32px] border border-amber-300/25 bg-slate-900/90 p-6 text-center shadow-2xl sm:p-10" dir="rtl">
    <Interactive3DEmoji emoji="📺" accent="#fbbf24" size="xl" className="mb-5" />
    <h2 className="mb-3 text-2xl font-black text-white">شرح الدرس غير متاح مؤقتًا</h2>
    <p className="mx-auto mb-6 max-w-xl text-sm font-bold leading-7 text-slate-300">
      يوجد رابط فيديو غير صالح أو بيانات قديمة لهذا الدرس. يمكنك العودة إلى البوابة واختيار مغامرة أخرى، ولن يتم تسجيل خروجك.
    </p>
    <button
      type="button"
      onClick={onBack}
      className="rounded-2xl bg-amber-400 px-6 py-3 font-black text-slate-950 transition hover:bg-amber-300"
    >
      العودة إلى بوابة المغامرات
    </button>
  </div>
);

const StudentCardErrorFallback: React.FC<{ onBack: () => void }> = ({ onBack }) => (
  <div dir="rtl" className="rounded-[32px] border border-rose-300/25 bg-slate-950/90 p-8 text-center shadow-2xl">
    <div className="mb-3 text-5xl">🛟</div>
    <h2 className="mb-2 text-2xl font-black text-white">تعذر فتح هذا المحتوى</h2>
    <p className="mx-auto mb-5 max-w-xl text-sm font-bold leading-7 text-slate-300">
      حدثت مشكلة في بطاقة المحتوى فقط. لم يتم تسجيل خروجك ويمكنك العودة للبطاقات وتجربة محتوى آخر.
    </p>
    <button
      type="button"
      onClick={onBack}
      className="rounded-2xl bg-cyan-400 px-6 py-3 font-black text-slate-950 transition hover:bg-cyan-300"
    >
      العودة إلى البطاقات
    </button>
  </div>
);

const StudentPortalFallback: React.FC<{
  subject: string;
  atram: string;
  term: string;
  unit: string;
  onChangeSelection: () => void;
  onOpenModule: (module: StudentModuleType) => void;
}> = ({ subject, atram, term, unit, onChangeSelection, onOpenModule }) => (
  <div className="rounded-[28px] border border-cyan-300/20 bg-slate-900/90 p-5 shadow-2xl sm:p-8" dir="rtl">
    <div className="mb-6 flex flex-wrap items-center justify-between gap-4">
      <div>
        <p className="text-sm font-bold text-cyan-300">تم حفظ مسارك الدراسي بنجاح</p>
        <h2 className="mt-1 text-2xl font-black text-white">اختر مغامرتك اليوم 🌟</h2>
        <p className="mt-2 text-sm font-bold text-amber-300">
          {subject} • {atram} • {term} • {unit}
        </p>
      </div>
      <button
        type="button"
        onClick={onChangeSelection}
        className="rounded-xl border border-white/15 bg-white/10 px-4 py-3 text-sm font-black text-slate-200"
      >
        ⚙️ تغيير المسار
      </button>
    </div>
    <div className="grid grid-cols-1 gap-3 sm:grid-cols-2">
      {[
        [StudentModuleType.EXPLANATION, '📺 شرح الدرس'],
        [StudentModuleType.AVATAR_INTERACTION, '🤖 المعلم الافتراضي'],
        [StudentModuleType.PERSONALITY, '🧑‍🎓 شخصيتي'],
        [StudentModuleType.PROBLEM_SOLVING, '💡 حل المسائل'],
        [StudentModuleType.VIDEOS, '🎬 سينما منارة'],
        [StudentModuleType.ENTERTAINMENT, '🎮 عالم الترفيه'],
      ].map(([module, label]) => (
        <button
          key={module}
          type="button"
          onClick={() => onOpenModule(module as StudentModuleType)}
          className="rounded-2xl border border-cyan-300/20 bg-gradient-to-r from-indigo-500/80 to-cyan-600/70 px-5 py-4 text-right font-black text-white transition hover:from-indigo-400 hover:to-cyan-500"
        >
          {label}
        </button>
      ))}
    </div>
  </div>
);

// 3. المكون الرئيسي
const StudentDashboard: React.FC<{ onLogout: () => void }> = ({ onLogout }) => {
  const [isAuthenticated, setIsAuthenticated] = useState(false);
  const [student, setStudent] = useState<StudentInfo | null>(null);
  const [activeLesson, setActiveLesson] = useState<LessonConfig | null>(null);
  const [activeModule, setActiveModule] = useState<StudentModuleType | null>(null);
  const [problemText, setProblemText] = useState('');
  const [solutionText, setSolutionText] = useState('');
  const [isSolving, setIsSolving] = useState(false);

  const permissions = getStudentPermissions(student);

  const [grades, setGrades] = useState<string[]>([]);
  const [subjects, setSubjects] = useState<string[]>([]);
  const [terms, setTerms] = useState<string[]>([]);
  const [units, setUnits] = useState<string[]>([]);
  const [atrams, setAtrams] = useState<string[]>([]);

  const [selectedGrade, setSelectedGrade] = useState('');
  const [selectedSubject, setSelectedSubject] = useState('');
  const [selectedAtram, setSelectedAtram] = useState('');
  const [selectedTerm, setSelectedTerm] = useState('');
  const [selectedUnit, setSelectedUnit] = useState('');
  const [showSelectionPanel, setShowSelectionPanel] = useState(false);
  const [explanationVideoIndex, setExplanationVideoIndex] = useState(0);
  const explanationVideoSignatureRef = useRef('');
  const matchedContentSignatureRef = useRef('');

  const [currentQuiz, setCurrentQuiz] = useState<QuizQuestion[]>([]);
  const [activeQuizId, setActiveQuizId] = useState<string | null>(null);
  const [activeQuizTitle, setActiveQuizTitle] = useState<string | null>(null);
  const [qIndex, setQIndex] = useState(0);
  const [userAnswers, setUserAnswers] = useState<Record<string, string>>({});
  const [quizResult, setQuizResult] = useState<QuizResult | null>(null);
  const [quizEmptyMessage, setQuizEmptyMessage] = useState<string | null>(null);

  const [chatMessages, setChatMessages] = useState<Array<{id: string; from: string; name: string; message: string; time: string}>>([]);
  const [chatInput, setChatInput] = useState('');
  const [showChat, setShowChat] = useState(false);
  const [hasNewMessage, setHasNewMessage] = useState(false);
  const [chatTarget, setChatTarget] = useState<'all' | string>('all');
  const [peers, setPeers] = useState<Array<{id: string; name: string}>>([]);
  const [chatEnabled, setChatEnabled] = useState(true);
  const [lastMessageCount, setLastMessageCount] = useState(0);
  const [studentApiToken, setStudentApiToken] = useState<string | null>(null);

  const [showModuleCards, setShowModuleCards] = useState(false);
  const [selectedPath, setSelectedPath] = useState(false);

  // Gamification state
  const [xp, setXp] = useState(0);
  const [gems, setGems] = useState(0);
  const [level, setLevel] = useState(0);
  const [streak, setStreak] = useState(0);
  const [levelProgress, setLevelProgress] = useState(0);
  const [achievements, setAchievements] = useState<any[]>([]);
  const [showRewardPopup, setShowRewardPopup] = useState(false);
  const [rewardInfo, setRewardInfo] = useState({ xp: 0, gems: 0, message: '' });
  const [pendingStreakBonus, setPendingStreakBonus] = useState(0);

  const chatContainerRef = useRef<HTMLDivElement>(null);
  const messageSignatureRef = useRef('');
  const rewardTimersRef = useRef<number[]>([]);
  const studentRef = useRef<StudentInfo | null>(null);
  const isAuthenticatedRef = useRef(false);
  studentRef.current = student;
  isAuthenticatedRef.current = isAuthenticated;

  // Load gamification stats
  const refreshGamification = () => {
    const stats = getGamificationStats();
    setXp(stats.xp);
    setGems(stats.gems);
    setLevel(stats.level);
    setStreak(stats.streak);
    setLevelProgress(stats.levelProgress);
    setAchievements((previous) =>
      JSON.stringify(previous) === JSON.stringify(stats.achievements)
        ? previous
        : stats.achievements,
    );
    // Read the latest active student from storage. Passing the render's
    // previous `student` snapshot here could overwrite a newly selected
    // subject/unit during the periodic gamification refresh.
    syncGamificationToStudent();
  };

  useEffect(() => {
    const active = readActiveSession<StudentInfo>(STORAGE_KEYS.ACTIVE_STUDENT);
    if (active) {
      ensureGamificationResetIfNeeded(active);
      hydrateGamificationFromStudent(active);

      setStudent(active);
      setIsAuthenticated(true);
       playWelcomeStudentOnRefresh();
      const streakCheck = checkStreak();
      if (streakCheck.bonusXp > 0) setPendingStreakBonus(streakCheck.bonusXp);
      refreshGamification();
      syncGamificationToStudent(active);

       let primaryGrade = active.grade || active.primaryGrade;
       const activeGradeEnrollments = getSafeGradeEnrollments(active);
       if (!primaryGrade && activeGradeEnrollments.length > 0) {
         primaryGrade = activeGradeEnrollments[0].grade || '';
      }
      setSelectedGrade(primaryGrade || '');

       let savedAtram = active.atram || '';
       let savedSubject = active.subject || '';
       let savedTerm = active.term || '';
       let savedUnit = active.unit || '';

      if (activeGradeEnrollments.length > 0) {
        const primaryGradeEnrollments = activeGradeEnrollments.find((g: any) => normalizeScopeValue(g.grade) === normalizeScopeValue(primaryGrade));
        const enrollSource = primaryGradeEnrollments || activeGradeEnrollments[0];
        const enrollments = getSafeEnrollments(enrollSource);
        if (enrollments.length > 0) {
          const firstEnroll = enrollments[0];
           savedSubject = savedSubject || firstEnroll.subject || '';
           savedAtram = savedAtram || firstEnroll.atram || '';
           savedTerm = savedTerm || firstEnroll.term || '';
           savedUnit = savedUnit || firstEnroll.unit || '';
        }
      }

       const hasCompleteSelection = !!(savedAtram && savedSubject && savedTerm && savedUnit);
       setSelectedSubject(savedSubject);
       setSelectedAtram(savedAtram);
       setSelectedTerm(savedTerm);
       setSelectedUnit(savedUnit);
       setSelectedPath(hasCompleteSelection);
       setShowSelectionPanel(!hasCompleteSelection);
       setShowModuleCards(hasCompleteSelection);
      setActiveModule(null);
      matchContent(active);
    }
  }, []);

  useEffect(() => {
    if (student) {
      loadAcademicSettings();
    }
  }, [
    student?.id,
    student?.grade,
    student?.subject,
    student?.atram,
    student?.term,
    student?.unit,
    selectedGrade,
  ]);

  useEffect(() => {
    const interval = window.setInterval(() => {
      const current = readActiveSession<StudentInfo>(STORAGE_KEYS.ACTIVE_STUDENT);
      if (current) {
        const previous = studentRef.current;
        const accountChanged = current.id !== previous?.id;
        const sessionDataChanged = current.lastActivity !== previous?.lastActivity ||
          current.grade !== previous?.grade ||
          current.subject !== previous?.subject ||
          current.atram !== previous?.atram ||
          current.term !== previous?.term ||
          current.unit !== previous?.unit;
        if (accountChanged || sessionDataChanged) {
          if (accountChanged) {
            ensureGamificationResetIfNeeded(current);
          }
          studentRef.current = current;
          setStudent(current);
          let fallbackGrade = current.primaryGrade || current.grade || '';
          const currentGradeEnrollments = getSafeGradeEnrollments(current);
          if (!fallbackGrade && currentGradeEnrollments.length > 0) {
            fallbackGrade = currentGradeEnrollments[0].grade || '';
          }
          setSelectedGrade(fallbackGrade);
          setSelectedSubject(current.subject || '');
          setSelectedAtram(current.atram || '');
          setSelectedTerm(current.term || '');
          setSelectedUnit(current.unit || '');
          setIsAuthenticated(true);
          refreshGamification();
        }
        matchContent(current);
      } else {
        // A transient localStorage read must never look like a logout. The
        // explicit logout button is the only place allowed to clear the
        // student session from this dashboard.
        console.warn('[student] session read was temporarily unavailable; preserving current session');
      }
    }, 5000);
    return () => window.clearInterval(interval);
  }, []);

  useEffect(() => {
    const interval = window.setInterval(() => {
      if (isAuthenticatedRef.current) refreshGamification();
    }, 5000);
    return () => window.clearInterval(interval);
  }, []);

  useEffect(() => {
    if (chatEnabled) {
      loadChatMessages();
      const interval = window.setInterval(loadChatMessages, 4000);
      return () => window.clearInterval(interval);
    }
    return undefined;
  }, [student?.id, chatEnabled, showChat, studentApiToken]);

  useEffect(() => {
    if (showChat) {
      setHasNewMessage(false);
      const timer = window.setTimeout(() => setHasNewMessage(false), 100);
      return () => window.clearTimeout(timer);
    }
    return undefined;
  }, [showChat]);

  useEffect(() => () => {
    rewardTimersRef.current.forEach((timer) => window.clearTimeout(timer));
    rewardTimersRef.current = [];
  }, []);

  useEffect(() => {
    if (chatContainerRef.current && showChat) {
      chatContainerRef.current.scrollTop = chatContainerRef.current.scrollHeight;
    }
  }, [chatMessages, showChat]);

  const loadChatMessages = async () => {
    if (!studentApiToken) {
      setChatEnabled(false);
      setChatMessages([]);
      setPeers([]);
      return;
    }
    if (!chatEnabled) return;
    const headers = { Authorization: `Bearer ${studentApiToken}` };
    try {
      const [messagesResponse, peersResponse] = await Promise.all([
        fetch('/api/student/chat/messages', { headers }),
        fetch('/api/student/chat/peers', { headers }),
      ]);
      const messagesBody = await messagesResponse.json().catch(() => ({}));
      const peersBody = await peersResponse.json().catch(() => ({}));
      if (!messagesResponse.ok || !peersResponse.ok) {
        setChatEnabled(false);
        return;
      }
      const messages = Array.isArray(messagesBody.messages) ? messagesBody.messages : [];
      const nextPeers = Array.isArray(peersBody.peers) ? peersBody.peers : [];
      if (!showChat && messages.some((message: any) => message.from !== student?.id)) {
        setHasNewMessage(true);
      }
      const signature = messages.map((message: any) => `${message.id}:${message.time}:${message.message}`).join('|');
      setLastMessageCount(messages.length);
      setPeers(nextPeers);
      if (messageSignatureRef.current !== signature) {
        messageSignatureRef.current = signature;
        setChatMessages(messages);
      }
    } catch {
      setChatEnabled(false);
    }
  };

  const showRewardPopupFor = (info: { xp: number; gems: number; message: string }, delay: number) => {
    rewardTimersRef.current.forEach((timer) => window.clearTimeout(timer));
    rewardTimersRef.current = [];
    setRewardInfo(info);
    setShowRewardPopup(true);
    const timer = window.setTimeout(() => {
      setShowRewardPopup(false);
      rewardTimersRef.current = rewardTimersRef.current.filter((item) => item !== timer);
    }, delay);
    rewardTimersRef.current.push(timer);
  };

  useEffect(() => {
    if (pendingStreakBonus <= 0) return;
    showRewardPopupFor({
      xp: pendingStreakBonus,
      gems: 0,
      message: `ممتاز! أكملت ${5} أيام استمرار متتالية 🎉`,
    }, 5000);
    setPendingStreakBonus(0);
  }, [pendingStreakBonus]);

  const sendChatMessage = async () => {
    if (!chatInput.trim() || !student || !studentApiToken) return;
    playLamsaSound('send');
    try {
      const response = await fetch('/api/student/chat/messages', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${studentApiToken}` },
        body: JSON.stringify({ message: chatInput.trim(), to: chatTarget || 'all' }),
      });
      if (!response.ok) throw new Error();
      setChatInput('');
      setHasNewMessage(false);
      await loadChatMessages();
    } catch {
      alert('تعذر إرسال الرسالة. أعد تسجيل الدخول أو حاول مرة أخرى.');
    }
  };

  const getFilteredHierarchicalConfigs = () => {
    const allConfigs = readStorageArray(STORAGE_KEYS.HIERARCHICAL_CONFIGS)
      .filter((config): config is Record<string, any> => Boolean(config && typeof config === 'object'));
    const allParents = readStorageArray<import('../../types').ParentInfo>(STORAGE_KEYS.PARENTS);
    const allStudents = readStorageArray<StudentInfo>(STORAGE_KEYS.STUDENTS);
    if (!student) return [];

    const filtered = filterTeacherOwnedRecords(allConfigs, student, allParents, allStudents);
    if (filtered && filtered.length > 0) {
      return filtered;
    }

    const studentTeacherId = getStudentTeacherScope(student, allParents, allStudents).teacherId;
    if (studentTeacherId) {
      const scoped = allConfigs.filter(
        (config: any) => getRecordTeacherId(config) === studentTeacherId || normalizeScopeValue(config.createdBy) === studentTeacherId,
      );
      if (scoped.length > 0) return scoped;
    }

    const generalConfigs = allConfigs.filter((config: any) => !normalizeScopeValue(config.createdBy) || normalizeScopeValue(config.createdBy) === 'admin');
    if (generalConfigs.length > 0) return generalConfigs;

    return allConfigs;
  };

  const loadAcademicSettings = () => {
    if (!student) return;
    const hierarchicalConfigs = getFilteredHierarchicalConfigs();
    const gradesList = hierarchicalConfigs.map((c: any) => c.grade).filter(Boolean);
    setGrades(gradesList);

    const studentGradeEnrollments = getSafeGradeEnrollments(student);
    if (studentGradeEnrollments.length > 0) {
      const studentGrades = studentGradeEnrollments.map((g: any) => g.grade).filter(Boolean);
      setGrades(studentGrades);

      const selectedGradeValue = selectedGrade || student.primaryGrade || studentGrades[0] || '';
      if (selectedGradeValue) {
        setSelectedGrade(selectedGradeValue);
      }

      const gradeEntry = studentGradeEnrollments.find((g: any) => normalizeScopeValue(g.grade) === normalizeScopeValue(selectedGradeValue)) || studentGradeEnrollments[0];
      const enrollments = getSafeEnrollments(gradeEntry);
      if (enrollments.length > 0) {
        const firstEnroll = enrollments[0];
        const uniqueAtrams = Array.from(new Set(enrollments.map((e: any) => e.atram).filter(Boolean))) as string[];
        const uniqueSubjects = Array.from(new Set(enrollments.map((e: any) => e.subject).filter(Boolean))) as string[];
        const uniqueTerms = Array.from(new Set(enrollments.map((e: any) => e.term).filter(Boolean))) as string[];
        const uniqueUnits = Array.from(new Set(enrollments.map((e: any) => e.unit).filter(Boolean))) as string[];
         const savedSelectionIsForGrade =
           normalizeScopeValue(student.grade || student.primaryGrade || '') === normalizeScopeValue(selectedGradeValue);
         const savedAtram = savedSelectionIsForGrade ? student.atram : '';
         const savedSubject = savedSelectionIsForGrade ? student.subject : '';
         const savedTerm = savedSelectionIsForGrade ? student.term : '';
         const savedUnit = savedSelectionIsForGrade ? student.unit : '';

        setAtrams(uniqueAtrams);
        setSubjects(uniqueSubjects);
        setTerms(uniqueTerms);
        setUnits(uniqueUnits);

         setSelectedAtram(uniqueAtrams.includes(savedAtram || '') ? savedAtram || '' : (firstEnroll?.atram || ''));
         setSelectedSubject(uniqueSubjects.includes(savedSubject || '') ? savedSubject || '' : (firstEnroll?.subject || ''));
         setSelectedTerm(uniqueTerms.includes(savedTerm || '') ? savedTerm || '' : (firstEnroll?.term || ''));
         setSelectedUnit(uniqueUnits.includes(savedUnit || '') ? savedUnit || '' : (firstEnroll?.unit || ''));
      }
      return;
    }

    const normalizedGrade = normalizeScopeValue(selectedGrade || '');
    const gradeConfig = hierarchicalConfigs.find((c: any) => normalizeScopeValue(c.grade) === normalizedGrade) || hierarchicalConfigs[0];

    if (gradeConfig) {
      if (normalizeScopeValue(gradeConfig.grade) !== normalizedGrade) {
        setSelectedGrade(gradeConfig.grade);
      }

      const gradeAtrams = Array.isArray(gradeConfig.atrams) ? gradeConfig.atrams : [];
      const atrams = gradeAtrams.map((a: any) => a?.atram).filter(Boolean);
      setAtrams(atrams);

      const normalizedAtram = normalizeScopeValue(selectedAtram || '');
      const atramConfig = gradeAtrams.find((a: any) => normalizeScopeValue(a?.atram) === normalizedAtram) || gradeAtrams[0];

      if (atramConfig) {
        const atramSubjects = Array.isArray(atramConfig.subjects) ? atramConfig.subjects : [];
        setSubjects(atramSubjects.map((s: any) => s?.subject).filter(Boolean));

        const normalizedSubject = normalizeScopeValue(selectedSubject || '');
        const subjectConfig = atramSubjects.find((s: any) => normalizeScopeValue(s?.subject) === normalizedSubject) || atramSubjects[0];

        if (subjectConfig) {
          const subjectTerms = Array.isArray(subjectConfig.terms) ? subjectConfig.terms : [];
          setTerms(subjectTerms.map((t: any) => t?.term).filter(Boolean));

          const normalizedTerm = normalizeScopeValue(selectedTerm || '');
          const termConfig = subjectTerms.find((t: any) => normalizeScopeValue(t?.term) === normalizedTerm) || subjectTerms[0];

          if (termConfig) {
            const units = Array.isArray(termConfig.units) ? termConfig.units.filter(Boolean) : [];
            setUnits(units);
            if (!units.find((unit: any) => normalizeScopeValue(unit) === normalizeScopeValue(selectedUnit || ''))) {
              setSelectedUnit(units[0] || '');
            }
          } else {
            setUnits([]);
            setSelectedUnit('');
          }
        } else {
          setTerms([]);
          setUnits([]);
          setSelectedSubject('');
          setSelectedTerm('');
          setSelectedUnit('');
        }
      } else {
        setSubjects([]);
        setTerms([]);
        setUnits([]);
        setSelectedAtram('');
        setSelectedSubject('');
        setSelectedTerm('');
        setSelectedUnit('');
      }
    } else {
      setAtrams([]);
      setSubjects([]);
      setTerms([]);
      setUnits([]);
    }
  };

  const handleSelectContent = () => {
    if (!student) return;

    const currentGrade = student.primaryGrade || student.grade || '';
    if (!permissions.canChangeGrade && normalizeScopeValue(selectedGrade) !== normalizeScopeValue(currentGrade)) {
      playLamsaSound('error');
      alert('❌ ليس لديك صلاحية تغيير الصف');
      setSelectedGrade(currentGrade);
      loadAcademicSettings();
      return;
    }

    if (!selectedAtram || !selectedSubject || !selectedTerm || !selectedUnit) {
      playLamsaSound('error');
      alert('الرجاء اختيار جميع الحقول (الترم، المادة، الفصل، الوحدة)');
      return;
    }

    const updatedStudent = persistAcademicSelection({
      grade: selectedGrade || student.primaryGrade || student.grade,
      subject: selectedSubject,
      atram: selectedAtram,
      term: selectedTerm,
      unit: selectedUnit,
    });
    if (!updatedStudent) return;

    setShowSelectionPanel(false);
    setShowModuleCards(true);
    setSelectedPath(true);
  };

  const persistAcademicSelection = (selection: Partial<StudentInfo>): StudentInfo | null => {
    if (!student) return null;

    const updatedStudent: StudentInfo = {
      ...student,
      ...selection,
    };
    try {
      setStudent(updatedStudent);
      writeActiveSession(STORAGE_KEYS.ACTIVE_STUDENT, updatedStudent);

      const allStudents = readStorageArray<StudentInfo>(STORAGE_KEYS.STUDENTS)
        .filter((item): item is StudentInfo => Boolean(item && typeof item === 'object'));
      localStorage.setItem(
        STORAGE_KEYS.STUDENTS,
        JSON.stringify(allStudents.map((item) => item.id === student.id ? updatedStudent : item)),
      );
    } catch (error) {
      // A malformed legacy collection must not block the student from entering
      // the learning portal. The active session remains in component state.
      console.error('[student] academic selection persistence failed:', error);
    }

    try {
      matchContent(updatedStudent);
    } catch (error) {
      // Lesson content is optional. A content-sync problem must never turn a
      // valid academic selection into a dashboard error screen.
      console.error('[student] lesson matching failed after academic selection:', error);
      setActiveLesson(null);
    }
    return updatedStudent;
  };

  const matchContent = (s: StudentInfo) => {
    const all = readStorageArray<LessonConfig>(STORAGE_KEYS.LESSON_CONFIGS)
      .filter((lesson): lesson is LessonConfig => Boolean(lesson && typeof lesson === 'object'));
    const teacherContent = filterTeacherOwnedRecords(all, s);
    const generalContent = all.filter((lesson: LessonConfig) => {
      const owner = normalizeScopeValue(getRecordTeacherId(lesson));
      return !owner || owner === 'admin';
    });
    const filteredContent = Array.from(
      new Map([...teacherContent, ...generalContent].map((lesson: LessonConfig) => [lesson.id, lesson])).values(),
    );
    const normalize = (v: any) => (v || '').toString().trim().toLowerCase();

    const studentKey = {
      grade: normalize(s.grade || s.primaryGrade),
      atram: normalize(s.atram),
      subject: normalize(s.subject),
      term: normalize(s.term),
      unit: normalize(s.unit),
    };

    // A student may have only grade/subject on older accounts. Empty
    // academic selections must not be treated as a literal mismatch with a
    // teacher lesson that has a term, atram, or unit.
    const matchingContent = filteredContent
      .filter((lesson: LessonConfig) => matchesAcademicScope(lesson, studentKey))
      .sort((a: LessonConfig, b: LessonConfig) => {
        const score = (lesson: LessonConfig) => ['grade', 'atram', 'subject', 'term', 'unit']
          .reduce((total, field) => {
            const expected = studentKey[field as keyof typeof studentKey];
            return total + (expected && normalize(lesson[field as keyof LessonConfig]) === expected ? 1 : 0);
          }, 0);
        return score(b) - score(a);
      });
    const found = matchingContent[0];
    if (!found) {
      if (matchedContentSignatureRef.current === 'empty') return;
      matchedContentSignatureRef.current = 'empty';
      setActiveLesson(null);
      explanationVideoSignatureRef.current = '';
      return;
    }

    const mergedVideos = matchingContent
      .flatMap((lesson: LessonConfig) => getLessonExplanationVideos(lesson))
      .filter((video, index, all) =>
        all.findIndex(item => item.url === video.url) === index,
      );
    const videoSignature = mergedVideos.map(video => `${video.id}:${video.url}`).join('|');
    if (explanationVideoSignatureRef.current !== videoSignature) {
      explanationVideoSignatureRef.current = videoSignature;
      setExplanationVideoIndex(0);
    }

    // The session monitor runs periodically. Avoid replacing the lesson
    // object when its content did not change; replacing it remounts the
    // video/Swiper surfaces while a student is touching the screen.
    const foundMetadata = found as LessonConfig & {
      title?: string;
      description?: string;
      updatedAt?: string;
    };
    const contentSignature = JSON.stringify({
      id: found.id,
      title: foundMetadata.title,
      description: foundMetadata.description,
      updatedAt: foundMetadata.updatedAt,
      videoSignature,
    });
    if (matchedContentSignatureRef.current === contentSignature) return;
    matchedContentSignatureRef.current = contentSignature;

    setActiveLesson({
      ...found,
      explanationVideoUrl: mergedVideos[0]?.url || found.explanationVideoUrl || '',
      explanationVideoType: mergedVideos[0]?.sourceType || found.explanationVideoType,
      explanationVideos: mergedVideos,
    });
  };

  const startQuiz = (type: QuizType, requestedQuizId?: string): boolean => {
    playLamsaSound('pop');
    if (!student) return false;
    const allQuestions = readStorageArray<QuizQuestion>(STORAGE_KEYS.QUIZ_QUESTIONS);
    const createdQuizzes = readStorageArray<CreatedQuiz>(STORAGE_KEYS.CREATED_QUIZZES)
      .filter((quiz): quiz is CreatedQuiz => Boolean(quiz && typeof quiz === 'object'))
      .map(normalizeCreatedQuiz);

    const academicPath = {
      grade: selectedGrade,
      subject: selectedSubject,
      atram: selectedAtram,
      term: selectedTerm,
      unit: selectedUnit,
    };
    const scopedCreatedQuizzes = filterTeacherOwnedRecords(createdQuizzes, student)
      .filter(quiz => !quiz.deleted && quiz.isActive && normalizeQuizType(quiz.quizType) === type)
      .filter(quiz => !requestedQuizId || quiz.id === requestedQuizId)
      .filter(quiz => matchesAcademicScope(quiz, academicPath));
    const selectedCreatedQuiz = scopedCreatedQuizzes.find((quiz) => quiz.id === requestedQuizId)
      || scopedCreatedQuizzes[0];

    // Teacher assessments are one-attempt-only. If the student opens the
    // same card again, show the saved first result instead of opening a new
    // question set.
    const quizIdForAttempt = selectedCreatedQuiz?.id || requestedQuizId;
    if (type === QuizType.TEACHER && quizIdForAttempt) {
      const allResults = readStorageArray<QuizResult>(STORAGE_KEYS.QUIZ_RESULTS);
      const previousResult = [...allResults, ...(student.quizResults || [])]
        .filter((result, index, all) =>
          result.studentId === student.id &&
          result.quizId === quizIdForAttempt &&
          all.findIndex((item) => item.id === result.id) === index,
        )
        .sort((a, b) => a.createdAt.localeCompare(b.createdAt))[0];

      if (previousResult) {
        setActiveQuizId(quizIdForAttempt);
        setActiveQuizTitle(selectedCreatedQuiz?.title || previousResult.quizTitle || 'اختبار المعلم');
        setCurrentQuiz([]);
        setUserAnswers({});
        setQuizEmptyMessage(null);
        setQuizResult(previousResult);
        setActiveModule(StudentModuleType.QUIZ);
        return true;
      }
    }

    const scopedCreatedQuestions = selectedCreatedQuiz
      ? selectedCreatedQuiz.questions.filter(question => matchesAcademicScope(question, academicPath))
      : [];
    const scopedLegacyQuestions = filterTeacherOwnedRecords(allQuestions, student)
      .filter(question => normalizeQuizType(question.quizType) === type && matchesAcademicScope(question, academicPath));

    let filtered = selectedCreatedQuiz
      ? scopedCreatedQuestions
      : [...scopedCreatedQuestions, ...scopedLegacyQuestions];

    if (filtered.length === 0 && type === QuizType.PERIODIC) {
      const count = 10;
      filtered = localGenerateQuestionsFromLesson(activeLesson?.lessonContent || '', count, type);
    }

    if (filtered.length === 0) {
      playLamsaSound('error');
      setActiveQuizId(selectedCreatedQuiz?.id || requestedQuizId || null);
      setActiveQuizTitle(
        selectedCreatedQuiz?.title ||
        (type === QuizType.TEACHER ? 'اختبار المعلم' : 'الاختبار الدوري'),
      );
      setCurrentQuiz([]);
      setUserAnswers({});
      setQuizResult(null);
      setQuizEmptyMessage(
        type === QuizType.TEACHER
          ? 'لا يوجد اختبار مضاف من المعلم حالياً.'
          : 'لا توجد أسئلة متوفرة لهذا الاختبار حالياً.',
      );
      setActiveModule(StudentModuleType.QUIZ);
      return true;
    }

    const quizId = selectedCreatedQuiz?.id || filtered[0]?.quizId || `${type}:${student.id}`;
    const limit = selectedCreatedQuiz?.questionsPerAttempt
      || (selectedCreatedQuiz?.creationMode === 'ai'
        ? Math.min(10, selectedCreatedQuiz.questions.length)
        : selectedCreatedQuiz?.questions.length || 10);
    const studentQuestions = selectedCreatedQuiz
      ? getStudentQuestionSet(filtered, student.id, quizId, limit)
      : filtered.slice(0, limit);
    setActiveQuizId(selectedCreatedQuiz?.id || filtered[0]?.quizId || null);
    setActiveQuizTitle(selectedCreatedQuiz?.title || null);
    setCurrentQuiz(studentQuestions);
    setQIndex(0);
    setUserAnswers({});
    setQuizEmptyMessage(null);
    setQuizResult(null);
    setActiveModule(StudentModuleType.QUIZ);
    return true;
  };

  const getAvailablePeriodicQuizzes = (): CreatedQuiz[] => {
    if (!student) return [];
    const academicPath = {
      grade: selectedGrade,
      subject: selectedSubject,
      atram: selectedAtram,
      term: selectedTerm,
      unit: selectedUnit,
    };
    try {
      return filterTeacherOwnedRecords(
        readStorageArray<CreatedQuiz>(STORAGE_KEYS.CREATED_QUIZZES)
          .filter((quiz): quiz is CreatedQuiz => Boolean(quiz && typeof quiz === 'object'))
          .map(normalizeCreatedQuiz),
        student,
      )
        .filter((quiz) => !quiz.deleted && quiz.isActive && normalizeQuizType(quiz.quizType) === QuizType.PERIODIC)
        .filter((quiz) => matchesAcademicScope(quiz, academicPath))
        .sort((a, b) => (a.periodicNumber || 999) - (b.periodicNumber || 999));
    } catch {
      return [];
    }
  };

  const getAvailableTeacherQuizzes = (): CreatedQuiz[] => {
    if (!student) return [];
    const academicPath = {
      grade: selectedGrade,
      subject: selectedSubject,
      atram: selectedAtram,
      term: selectedTerm,
      unit: selectedUnit,
    };
    try {
      const createdQuizzes = readStorageArray<CreatedQuiz>(STORAGE_KEYS.CREATED_QUIZZES)
        .filter((quiz): quiz is CreatedQuiz => Boolean(quiz && typeof quiz === 'object'))
        .map(normalizeCreatedQuiz);
      return filterTeacherOwnedRecords(createdQuizzes, student)
        .filter((quiz) => !quiz.deleted && quiz.isActive && normalizeQuizType(quiz.quizType) === QuizType.TEACHER)
        .filter((quiz) => matchesAcademicScope(quiz, academicPath));
    } catch {
      return [];
    }
  };

  const submitQuiz = () => {
    if (!student || currentQuiz.length === 0) return;

    let score = 0;
    currentQuiz.forEach((q) => {
      if (isQuizAnswerCorrect(q, userAnswers[q.id])) {
        score++;
      }
    });

    const percentage = Math.round((score / currentQuiz.length) * 100);
    const quizType = normalizeQuizType(currentQuiz[0]?.quizType);
    const firstQuestion = currentQuiz[0];
    const fallbackQuizId = [
      'periodic',
      firstQuestion?.grade || selectedGrade,
      firstQuestion?.subject || selectedSubject,
      firstQuestion?.term || selectedTerm,
      firstQuestion?.unit || selectedUnit,
    ].map(normalizeScopeValue).join(':');
    const quizId = activeQuizId || firstQuestion?.quizId || fallbackQuizId;
    const allResults = readStorageArray<QuizResult>(STORAGE_KEYS.QUIZ_RESULTS);
    const previousResults = [...allResults, ...(student.quizResults || [])]
      .filter((result, index, all) =>
        result.studentId === student.id &&
        result.quizId === quizId &&
        all.findIndex(item => item.id === result.id) === index,
      );

    if (quizType === QuizType.TEACHER && previousResults.length > 0) {
      playLamsaSound('error');
      alert('هذا اختبار معلم محفوظ مسبقاً ولا يمكن إعادته.');
      return;
    }

    let feedback = 'حاول مجدداً، أنت بطل ذكي وستتحسن بالتأكيد! 💪';

    // Gamification rewards
    const rewardId = getQuizRewardId(currentQuiz, activeLesson, quizType, quizId);
    const reward = rewardQuizCompleteWithId(score, currentQuiz.length, rewardId);
    if (percentage >= 60) {
      GameAudioEngine.playRewardSequence({ celebrate: true, gems: reward.gems });
    } else {
      triggerCelebration(false);
    }
    refreshGamification();

    if (reward.alreadyRewarded) {
      feedback = 'تمت إعادة نفس الاختبار: النتيجة محفوظة، بدون جواهر إضافية لهذه المحاولة. ✅';
      showRewardPopupFor(
        { xp: 0, gems: 0, message: 'لا توجد جواهر إضافية عند إعادة نفس الاختبار' },
        2500,
      );
    }

    if (!reward.alreadyRewarded && percentage >= 90) {
      feedback = 'رائع ومذهل جداً! أنت عبقري ومتميز اليوم! 🏆✨';
      showRewardPopupFor({ xp: reward.xp, gems: reward.gems, message: `عبقري! حصلت على ${percentage}%` }, 3000);
    } else if (!reward.alreadyRewarded && percentage >= 60) {
      feedback = 'عمل رائع ودرجة ممتازة! تستحق نجمة لمسة البراقة! ⭐';
      showRewardPopupFor({ xp: reward.xp, gems: reward.gems, message: `ممتاز! حصلت على ${percentage}%` }, 3000);
    } else if (!reward.alreadyRewarded) {
      playLamsaSound('magic');
    }

    const createdAt = new Date().toISOString();
    const quizResultRecord: QuizResult = {
      id: `result_${student.id}_${Date.now()}`,
      studentId: student.id,
      studentName: student.name,
      quizId,
      quizType,
      subject: currentQuiz[0]?.subject || student.subject || selectedSubject || '',
      unit: currentQuiz[0]?.unit || student.unit || selectedUnit || '',
      grade: currentQuiz[0]?.grade || student.grade || student.primaryGrade || selectedGrade || '',
      score,
      total: currentQuiz.length,
      percentage,
      level: percentage >= 90 ? 'ممتاز' : percentage >= 70 ? 'جيد جداً' : percentage >= 50 ? 'جيد' : 'يحتاج تحسين',
      feedback,
      details: currentQuiz.map((question) => ({
        question: question.question,
        userAnswer: userAnswers[question.id] || '',
        correctAnswer: getCorrectAnswerText(question),
        isCorrect: isQuizAnswerCorrect(question, userAnswers[question.id]),
      })),
      createdAt,
      quizTitle: activeQuizTitle || getQuizTypeLabel(quizType),
      attemptNumber: previousResults.length + 1,
      isRetake: previousResults.length > 0,
    };

    localStorage.setItem(
      STORAGE_KEYS.QUIZ_RESULTS,
      JSON.stringify([...allResults, quizResultRecord]),
    );

    const updatedStudent: StudentInfo = {
      ...student,
      lastActivity: createdAt,
      quizResults: [...(student.quizResults || []), quizResultRecord],
    };
    const allStudents = readStorageArray<StudentInfo>(STORAGE_KEYS.STUDENTS);
    localStorage.setItem(
      STORAGE_KEYS.STUDENTS,
      JSON.stringify(allStudents.map((item) => item.id === student.id ? updatedStudent : item)),
    );
    const gamificationSnapshot = syncGamificationToStudent(updatedStudent);
    const finalStudent: StudentInfo = {
      ...updatedStudent,
      ...(gamificationSnapshot ? { gamification: gamificationSnapshot } : {}),
    };
    // syncGamificationToStudent writes the same final snapshot to both
    // STUDENTS and ACTIVE_STUDENT. Do not overwrite it with the pre-sync
    // student object, otherwise the new quiz result and level can diverge.
    writeActiveSession(STORAGE_KEYS.ACTIVE_STUDENT, finalStudent);
    setStudent(finalStudent);
    setQuizResult(quizResultRecord);
  };

  const localGenerateQuestionsFromLesson = (lessonText: string, count: number, type: QuizType) => {
    const sentences = lessonText.split(/\.|\?|!|\n/).map(s => s.trim()).filter(Boolean);
    const topic = [student?.subject || selectedSubject || 'المادة التعليمية', student?.unit || selectedUnit || 'الدرس']
      .filter(Boolean)
      .join(' - ');
    const fallbackPrompts = [
      `ما الفكرة الأساسية التي نتعلمها في درس ${topic}؟`,
      `أي عبارة تساعدك على فهم درس ${topic}؟`,
      `ما أفضل طريقة لمراجعة درس ${topic}؟`,
      `ماذا نتوقع أن نتعلم من موضوع ${topic}؟`,
      `أي خيار يمثل تطبيقاً صحيحاً لما تعلمناه في ${topic}؟`,
      `ما المعلومة التي يجب تذكرها بعد دراسة ${topic}؟`,
      `كيف نتحقق من فهمنا لموضوع ${topic}؟`,
      `أي خطوة نبدأ بها عند دراسة ${topic}؟`,
      `ما الهدف من النشاط التعليمي في ${topic}؟`,
      `أي وصف يناسب موضوع ${topic}؟`,
    ];
    const fallbackAnswers = [
      'فهم الفكرة الأساسية وتطبيقها',
      'مراجعة المفهوم ثم حل مثال',
      'قراءة الدرس والانتباه إلى النقاط المهمة',
      'التعلم بالتدرج مع ربط المعلومات',
      'استخدام المعرفة في موقف جديد',
    ];
    const picks = sentences.length > 0
      ? sentences.slice(0, Math.max(count, 1))
      : Array.from({ length: Math.max(count, 1) }, (_, index) => fallbackPrompts[index % fallbackPrompts.length]);

    return picks.map((s, idx) => {
      const correct = sentences.length > 0
        ? (s.length > 80 ? s.substring(0, 80) + '...' : s)
        : fallbackAnswers[idx % fallbackAnswers.length];
      const options = sentences.length > 0
        ? [correct, 'خلاصة قصيرة', 'فكرة رئيسية', 'نقطة هامة']
        : [
            correct,
            fallbackAnswers[(idx + 1) % fallbackAnswers.length],
            'تجاهل الفكرة وعدم مراجعتها',
            'اختيار إجابة بلا قراءة السؤال',
          ];
      return {
        id: `local_quiz_${Date.now()}_${idx}_${Math.random()}`,
        grade: student?.grade || '',
        subject: student?.subject || '',
        atram: student?.atram || '',
        term: student?.term || '',
        unit: student?.unit || '',
        question: `اختر الفكرة الأكثر ملاءمة للنص الآتي: "${s}"`,
        options,
        correctAnswer: options[0],
        quizType: type,
        lessonId: 'local-fallback',
        createdAt: new Date().toISOString(),
        source: 'local-random',
        variation: idx,
      } as QuizQuestion;
    });
  };

  const handleLogin = async (username: string, password: string) => {
    const all = readStorageArray<StudentInfo>(STORAGE_KEYS.STUDENTS);
    const found = all.find((s: StudentInfo) => 
      (s.username === username || s.studentIdNumber === username) && passwordsMatch(password, s.password)
    );
    if (found) {
      const firstEnroll = getSafeLegacyEnrollments(found)[0] || null;
      const activeStudent = { ...found } as StudentInfo;
      const activeGradeEnrollments = getSafeGradeEnrollments(activeStudent);
      const modernEnrollment = getSafeEnrollments(activeGradeEnrollments[0])[0];
      if (modernEnrollment) {
        activeStudent.grade = activeGradeEnrollments[0].grade || '';
        activeStudent.subject = modernEnrollment.subject;
        activeStudent.atram = modernEnrollment.atram;
        activeStudent.term = modernEnrollment.term;
        activeStudent.unit = modernEnrollment.unit;
      } else if (firstEnroll) {
        activeStudent.grade = firstEnroll.grade;
        activeStudent.subject = firstEnroll.subject;
        activeStudent.atram = firstEnroll.atram;
        activeStudent.term = firstEnroll.term;
        activeStudent.unit = firstEnroll.unit;
      }
      writeActiveSession(STORAGE_KEYS.ACTIVE_STUDENT, activeStudent);
      writeAuthSession('student', activeStudent.id);
      ensureGamificationResetIfNeeded(activeStudent);
      hydrateGamificationFromStudent(activeStudent);
      setStudent(activeStudent);
      setIsAuthenticated(true);
      // The dashboard itself remains legacy-compatible, but protected student
      // services use the server-issued token rather than localStorage identity.
      try {
        const response = await fetch('/api/auth/student/session', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ username, password }),
        });
        const body = await response.json().catch(() => ({}));
        setStudentApiToken(response.ok && typeof body.token === 'string' ? body.token : null);
      } catch {
        setStudentApiToken(null);
      }
      const streakCheck = checkStreak();
      if (streakCheck.bonusXp > 0) setPendingStreakBonus(streakCheck.bonusXp);
      refreshGamification();
      let fallbackGrade = activeStudent.grade || activeStudent.primaryGrade || '';
      if (!fallbackGrade && activeGradeEnrollments.length > 0) {
        fallbackGrade = activeGradeEnrollments[0].grade || '';
      }
      setSelectedGrade(fallbackGrade);
      setSelectedSubject(activeStudent.subject || '');
      setSelectedAtram(activeStudent.atram || '');
      setSelectedTerm(activeStudent.term || '');
      setSelectedUnit(activeStudent.unit || '');
      setSelectedPath(false);
      setShowSelectionPanel(true);
      setShowModuleCards(false);
      setActiveModule(null);
      matchContent(activeStudent);
    } else {
      playLamsaSound('error');
      alert('اسم المستخدم أو كلمة المرور غير صحيحة');
    }
  };

  const handleSolveProblem = async () => {
    if (!problemText.trim() || !activeLesson) {
      playLamsaSound('error');
      setSolutionText('يرجى اختيار مادة تعليمية صالحة قبل طرح الأسئلة');
      return;
    }
    if (!activeLesson.lessonContent || activeLesson.lessonContent.trim() === '') {
      playLamsaSound('error');
      setSolutionText('عذراً، لم يتم إضافة محتوى تعليمي لهذا الدرس بعد. يرجى التواصل مع المشرف لإضافة المحتوى.');
      return;
    }
    setIsSolving(true);
    setSolutionText('');
    playLamsaSound('send');
    try {
      if (!studentApiToken) {
        setSolutionText('لأمان حسابك، سجّل الخروج ثم ادخل باسم المستخدم وكلمة المرور قبل استخدام المساعد.');
        return;
      }
      const response = await fetch('/api/gemini/answer', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          Authorization: `Bearer ${studentApiToken}`,
        },
        body: JSON.stringify({
          lessonId: activeLesson.id,
          question: problemText
        })
      });
      if (response.ok) {
        const data = await response.json();
        if (data.answer) {
          playLamsaSound('magic');
          const reward = rewardProblemSolved();
          GameAudioEngine.playRewardSequence({ gems: reward.gems });
          refreshGamification();
           showRewardPopupFor({ xp: reward.xp, gems: reward.gems, message: 'أحسنت! حللت مسألة!' }, 3000);
          setSolutionText(`💡 ${data.answer}`);
        } else {
          playLamsaSound('error');
          setSolutionText('❌ لم يتم الحصول على إجابة من Gemini.');
        }
      } else {
        playLamsaSound('error');
        setSolutionText('❌ حدث خطأ في الاتصال بالسيرفر أو Gemini.');
      }
    } catch (e) {
      playLamsaSound('error');
      setSolutionText('❌ حدث خطأ أثناء الاتصال بالسيرفر.');
    }
    setIsSolving(false);
  };

  const completeCurrentLesson = () => {
    if (!activeLesson?.id) {
      playLamsaSound('error');
      return;
    }

    const rewardId = getLessonRewardId(activeLesson);
    const reward = rewardLessonComplete(rewardId);
    if (reward.alreadyRewarded) {
      playLamsaSound('click');
      showRewardPopupFor({ xp: 0, gems: 0, message: 'هذا الدرس مكتمل في سجل إنجازاتك ✅' }, 3000);
    } else {
      GameAudioEngine.playRewardSequence({ celebrate: true, gems: reward.gems });
      showRewardPopupFor({ xp: reward.xp, gems: reward.gems, message: 'أحسنت! أنهيت الدرس بنجاح! +5 جواهر' }, 3000);
    }
    refreshGamification();
  };

  const openModule = (module: StudentModuleType) => {
    GameAudioEngine.play('portalTransition');
    setActiveModule(module);
    setShowModuleCards(false);
  };

  const saveStudentAppearance = (appearance: StudentInfo['appearance']) => {
    if (!student || !appearance) return;
    const updatedStudent: StudentInfo = { ...student, appearance };
    setStudent(updatedStudent);
    writeActiveSession(STORAGE_KEYS.ACTIVE_STUDENT, updatedStudent);
    const allStudents = readStorageArray<StudentInfo>(STORAGE_KEYS.STUDENTS);
    localStorage.setItem(
      STORAGE_KEYS.STUDENTS,
      JSON.stringify(allStudents.map(current => current.id === student.id ? updatedStudent : current)),
    );
  };

  const moduleTheme = getModuleTheme(activeModule);
  const lessonRewarded = activeLesson ? hasCompletedActivity('lesson', getLessonRewardId(activeLesson)) : false;
  const explanationVideos = getLessonExplanationVideos(activeLesson);
  const nextLevelXP = (level + 1) * 100;
  const xpRemainingToNextLevel = Math.max(0, nextLevelXP - xp);

  if (!isAuthenticated) {
    return <StudentLogin onLogin={handleLogin} onBack={onLogout} />;
  }

  return (
    <div className="student-dashboard-shell min-h-screen w-full min-w-0 max-w-full bg-[linear-gradient(135deg,_#020617,_#111827,_#312e81)] text-white p-3 sm:p-4 lg:p-6 font-tajawal relative overflow-x-hidden safe-area-x safe-area-bottom">
      <PremiumBackground accent="#8b5cf6" />
      <div className="absolute left-3 top-[calc(0.75rem+env(safe-area-inset-top))] z-10 hidden items-center gap-3 rounded-[28px] border border-white/20 bg-white/10 px-3 py-2 backdrop-blur-lg sm:flex">
        <img src={getStickerAsset('spark')} alt="spark" className="h-10 w-10 rounded-2xl border border-white/20 bg-white/80 p-2 shadow" />
        <div>
          <p className="text-xs font-black uppercase tracking-[0.3em] text-cyan-200">مكافآت اليوم</p>
          <p className="text-sm font-bold text-white">{gems} جِمّات • {xp} XP</p>
        </div>
      </div>

      {/* خلفية تفاعلية ضوئية للألعاب */}
      <div className="absolute top-10 left-10 w-96 h-96 bg-indigo-500/10 rounded-full blur-3xl pointer-events-none" />
      <div className="absolute bottom-10 right-10 w-96 h-96 bg-purple-500/10 rounded-full blur-3xl pointer-events-none" />

      {/* الهيدر العلوي */}
      <div className="max-w-7xl mx-auto mb-4 sm:mb-6 flex flex-wrap items-center justify-between gap-3 z-10 relative">
        <div className="min-w-0 flex items-center gap-3 bg-white/10 backdrop-blur-md rounded-2xl p-3 px-4 border border-white/10 shadow-xl">
          <StudentAvatar student={student} size="sm" />
          <div>
            <h1 className="text-lg font-black text-white">أهلاً يا {student?.name}!</h1>
            <p className="text-amber-300 text-xs font-bold">Lv.{level} | ⭐ {xp} | 💎 {gems} {streak > 0 ? `| 🔥 ${streak}` : ''}</p>
          </div>
        </div>
        <ManaraBrand variant="compact" className="hidden text-white md:flex" />
          <motion.button
          whileHover={{ scale: 1.05 }}
          whileTap={{ scale: 0.95 }}
          onClick={() => {
            soundClick.play();
            removeActiveSession(STORAGE_KEYS.ACTIVE_STUDENT);
            onLogout();
          }}
           className="min-h-11 px-4 py-3 bg-red-500/20 text-red-200 border border-red-500/40 rounded-xl font-bold hover:bg-red-500/30 transition-all cursor-pointer"
        >
          🚪 خروج
        </motion.button>
      </div>

      <div className="max-w-7xl mx-auto z-10 relative">
        <motion.div initial={{ y: 20, opacity: 0 }} animate={{ y: 0, opacity: 1 }} transition={{ duration: 0.4 }} className="rounded-[28px] sm:rounded-[32px] border border-white/10 bg-white/10 backdrop-blur-xl p-4 sm:p-5 md:p-6 mb-4 sm:mb-6 shadow-2xl">
          <div className="flex flex-col lg:flex-row lg:items-center lg:justify-between gap-4">
            <div>
              <div className="inline-flex items-center gap-2 rounded-full bg-cyan-500/20 px-3 py-1 text-cyan-200 text-sm font-semibold mb-3">
                <span>✨</span> رحلة التقدم اليوم
              </div>
              <h2 className="text-2xl md:text-3xl font-black text-white">مرحبًا، {student?.name || 'طالب'}!</h2>
              <p className="text-slate-300 mt-1">أكمل المهام، ارفع مستواك، وحقق إنجازات جديدة.</p>
            </div>
            <div className="flex flex-wrap gap-3">
              <div className="rounded-2xl bg-slate-900/70 px-4 py-3 min-w-[110px] text-center">
                <div className="text-2xl font-black text-yellow-300">{xp}</div>
                <div className="text-xs text-slate-300">XP</div>
              </div>
              <div className="rounded-2xl bg-slate-900/70 px-4 py-3 min-w-[110px] text-center">
                <div className="text-2xl font-black text-cyan-300">{gems}</div>
                <div className="text-xs text-slate-300">جواهر</div>
              </div>
              <div className="rounded-2xl bg-slate-900/70 px-4 py-3 min-w-[110px] text-center">
                <div className="text-2xl font-black text-fuchsia-300">{streak}</div>
                <div className="text-xs text-slate-300">استمرار</div>
              </div>
            </div>
          </div>
          <div className="mt-4">
            <div className="flex items-center justify-between text-sm text-slate-300 mb-2">
              <span>تقدم المستوى {level}</span>
              <span>{levelProgress}%</span>
            </div>
            <div className="h-3 rounded-full bg-slate-800 overflow-hidden">
              <motion.div initial={{ width: 0 }} animate={{ width: `${Math.min(levelProgress, 100)}%` }} transition={{ duration: 0.5 }} className="h-full rounded-full bg-gradient-to-r from-cyan-400 via-blue-500 to-fuchsia-500" />
            </div>
            <p className="mt-2 text-xs font-bold text-cyan-200">
              المستوى القادم {level + 1} عند {nextLevelXP} XP • المتبقي {xpRemainingToNextLevel} XP
            </p>
          </div>
        </motion.div>

        {/* Step 1: Selection Form */}
        {(!selectedPath || showSelectionPanel) && !activeModule && (
          <InteractiveScene className="p-4 sm:p-6 md:p-12" intensity={1.15}>
            <div className="bg-slate-800/80 backdrop-blur-xl rounded-[2rem] shadow-2xl p-4 sm:p-6 md:p-12 border border-slate-700 relative overflow-hidden">
              <div className="text-center mb-10">
              <motion.div
                animate={{ y: [0, -10, 0] }}
                transition={{ repeat: Infinity, duration: 2.5 }}
                className="mb-4 inline-block"
              >
                <Interactive3DEmoji emoji="🎓" accent="#fbbf24" size="lg" />
              </motion.div>
              <h2 className="text-2xl font-black text-white mb-3 sm:text-4xl">مرحباً يا بطل! ✨</h2>
              <p className="text-base text-slate-300 mb-2 sm:text-lg">اختر مسارك السحري وابدأ التحدي والمرح</p>
              <p className="text-lg text-amber-400 font-bold sm:text-xl">
                {student?.createdByName ? `مع معلمك ${student.createdByName}` : 'اختر تفاصيل درسك اليوم 🚀'}
              </p>
            </div>

             <div className="grid grid-cols-1 gap-3 sm:grid-cols-2 sm:gap-4 xl:grid-cols-5 xl:gap-6 mb-6 sm:mb-8">
              <div>
                <label className="block font-bold text-slate-300 mb-3 text-right">🎒 الصف *</label>
                <select
                  value={selectedGrade}
                  onChange={e => {
                    soundClick.play();
                    const newGrade = e.target.value;
                     if (!permissions.canChangeGrade && normalizeScopeValue(newGrade) !== normalizeScopeValue(student?.primaryGrade || student?.grade || '')) {
                       playLamsaSound('error');
                       alert('❌ ليس لديك صلاحية تغيير الصف');
                       return;
                     }
                    setSelectedGrade(newGrade);
                    setSelectedAtram('');
                    setSelectedSubject('');
                    setSelectedTerm('');
                    setSelectedUnit('');
                  }}
                   disabled={!permissions.canChangeGrade}
                   className="w-full p-4 bg-slate-900/90 border-2 border-slate-700 rounded-2xl text-white font-bold text-right outline-none focus:border-amber-400 transition-all disabled:cursor-not-allowed disabled:opacity-60"
                >
                  <option value="">اختر الصف</option>
                  {grades.map((grade, i) => <option key={i} value={grade}>{grade}</option>)}
                </select>
              </div>

              <div>
                <label className="block font-bold text-slate-300 mb-3 text-right">📅 الترم *</label>
                <select
                  value={selectedAtram}
                  onChange={e => {
                    soundClick.play();
                    const newAtram = e.target.value;
                    setSelectedAtram(newAtram);
                    setSelectedSubject('');
                    setSelectedTerm('');
                    setSelectedUnit('');

                    const hierarchicalConfigs = getFilteredHierarchicalConfigs();
                    const gradeConfig = hierarchicalConfigs.find((c: any) => normalizeScopeValue(c.grade) === normalizeScopeValue(selectedGrade));
                    if (gradeConfig) {
                      const gradeAtrams = Array.isArray(gradeConfig.atrams) ? gradeConfig.atrams : [];
                      const atramConfig = gradeAtrams.find((a: any) => normalizeScopeValue(a?.atram) === normalizeScopeValue(newAtram));
                      if (atramConfig) {
                        setSubjects(
                          (Array.isArray(atramConfig.subjects) ? atramConfig.subjects : [])
                            .map((s: any) => s?.subject)
                            .filter(Boolean),
                        );
                      }
                    }
                  }}
                  disabled={!selectedGrade}
                  className="w-full p-4 bg-slate-900/90 border-2 border-slate-700 rounded-2xl text-white font-bold text-right outline-none focus:border-amber-400 transition-all disabled:opacity-40"
                >
                  <option value="">اختر الترم</option>
                  {atrams.map((a, i) => <option key={i} value={a}>{a}</option>)}
                </select>
              </div>

              <div>
                <label className="block font-bold text-slate-300 mb-3 text-right">📚 المادة *</label>
                <select
                  value={selectedSubject}
                  onChange={e => {
                    soundClick.play();
                    const newSubject = e.target.value;
                    setSelectedSubject(newSubject);
                    setSelectedTerm('');
                    setSelectedUnit('');

                    const hierarchicalConfigs = getFilteredHierarchicalConfigs();
                    const gradeConfig = hierarchicalConfigs.find((c: any) => normalizeScopeValue(c.grade) === normalizeScopeValue(selectedGrade));
                    if (gradeConfig) {
                      const gradeAtrams = Array.isArray(gradeConfig.atrams) ? gradeConfig.atrams : [];
                      const atramConfig = gradeAtrams.find((a: any) => normalizeScopeValue(a?.atram) === normalizeScopeValue(selectedAtram));
                      if (atramConfig) {
                        const atramSubjects = Array.isArray(atramConfig.subjects) ? atramConfig.subjects : [];
                        const subjectConfig = atramSubjects.find((s: any) => normalizeScopeValue(s?.subject) === normalizeScopeValue(newSubject));
                        if (subjectConfig) {
                          setTerms(
                            (Array.isArray(subjectConfig.terms) ? subjectConfig.terms : [])
                              .map((t: any) => t?.term)
                              .filter(Boolean),
                          );
                        }
                      }
                    }
                  }}
                  disabled={!selectedAtram}
                  className="w-full p-4 bg-slate-900/90 border-2 border-slate-700 rounded-2xl text-white font-bold text-right outline-none focus:border-amber-400 transition-all disabled:opacity-40"
                >
                  <option value="">اختر المادة</option>
                  {subjects.map((s, i) => <option key={i} value={s}>{s}</option>)}
                </select>
              </div>

              <div>
                <label className="block font-bold text-slate-300 mb-3 text-right">📖 الفصل</label>
                <select
                  value={selectedTerm}
                  onChange={e => {
                    soundClick.play();
                    const newTerm = e.target.value;
                    setSelectedTerm(newTerm);
                    setSelectedUnit('');

                    const hierarchicalConfigs = getFilteredHierarchicalConfigs();
                    const gradeConfig = hierarchicalConfigs.find((c: any) => normalizeScopeValue(c.grade) === normalizeScopeValue(selectedGrade));
                    if (gradeConfig) {
                      const gradeAtrams = Array.isArray(gradeConfig.atrams) ? gradeConfig.atrams : [];
                      const atramConfig = gradeAtrams.find((a: any) => normalizeScopeValue(a?.atram) === normalizeScopeValue(selectedAtram));
                      if (atramConfig) {
                        const atramSubjects = Array.isArray(atramConfig.subjects) ? atramConfig.subjects : [];
                        const subjectConfig = atramSubjects.find((s: any) => normalizeScopeValue(s?.subject) === normalizeScopeValue(selectedSubject));
                        if (subjectConfig) {
                          const subjectTerms = Array.isArray(subjectConfig.terms) ? subjectConfig.terms : [];
                          const termConfig = subjectTerms.find((t: any) => normalizeScopeValue(t?.term) === normalizeScopeValue(newTerm));
                          if (termConfig) {
                            setUnits(Array.isArray(termConfig.units) ? termConfig.units.filter(Boolean) : []);
                          }
                        }
                      }
                    }
                  }}
                  disabled={!selectedSubject}
                  className="w-full p-4 bg-slate-900/90 border-2 border-slate-700 rounded-2xl text-white font-bold text-right outline-none focus:border-amber-400 transition-all disabled:opacity-40"
                >
                  <option value="">اختر الفصل</option>
                  {terms.map((t, i) => <option key={i} value={t}>{t}</option>)}
                </select>
              </div>

              <div>
                <label className="block font-bold text-slate-300 mb-3 text-right">📝 الوحدة</label>
                <select
                  value={selectedUnit}
                  onChange={e => { soundClick.play(); setSelectedUnit(e.target.value); }}
                  disabled={!selectedTerm}
                  className="w-full p-4 bg-slate-900/90 border-2 border-slate-700 rounded-2xl text-white font-bold text-right outline-none focus:border-amber-400 transition-all disabled:opacity-40"
                >
                  <option value="">اختر الوحدة</option>
                  {units.map((u, i) => <option key={i} value={u}>{u}</option>)}
                </select>
              </div>
            </div>

            <div className="text-center">
              {(() => {
                const isFormComplete = selectedAtram && selectedAtram !== '' && 
                                       selectedSubject && selectedSubject !== '' && 
                                       selectedTerm && selectedTerm !== '' && 
                                       selectedUnit && selectedUnit !== '';

                return (
                  <motion.button
                    whileHover={{ scale: isFormComplete ? 1.05 : 1 }}
                    whileTap={{ scale: isFormComplete ? 0.95 : 1 }}
                    onClick={() => {
                      if (!isFormComplete) {
                        playLamsaSound('error');
                        alert('الرجاء اختيار جميع الحقول (الترم، المادة، الفصل، الوحدة)');
                        return;
                      }
                      soundPop.play();
                      handleSelectContent();
                      setSelectedPath(true);
                      setShowModuleCards(true);
                      setShowSelectionPanel(false);
                    }}
                    disabled={!isFormComplete}
                    className={`px-16 py-5 rounded-3xl font-black text-2xl transition-all shadow-2xl ${
                      isFormComplete
                        ? 'bg-gradient-to-r from-amber-400 via-orange-500 to-pink-500 text-slate-950 border-b-8 border-orange-700 cursor-pointer'
                        : 'bg-slate-700 text-slate-400 cursor-not-allowed opacity-50'
                    }`}
                  >
                    🚀 ابدأ رحلة التعلم! ✨
                  </motion.button>
                );
              })()}
            </div>
            </div>
          </InteractiveScene>
        )}

        {/* Step 2: Module Cards (Game Engine UI) */}
        {selectedPath && showModuleCards && !activeModule && !showSelectionPanel && (
          <StudentPortalErrorBoundary
            fallback={
              <StudentPortalFallback
                subject={selectedSubject}
                atram={selectedAtram}
                term={selectedTerm}
                unit={selectedUnit}
                onChangeSelection={() => {
                  setShowSelectionPanel(true);
                  setShowModuleCards(false);
                }}
                onOpenModule={openModule}
              />
            }
          >
            <InteractiveScene className="p-6 md:p-8" intensity={1.08}>
              <div className="space-y-6 animate-fadeIn">
              <div className="bg-slate-800/80 backdrop-blur-md rounded-3xl p-6 flex flex-wrap justify-between items-center border border-slate-700 gap-4">
              <div>
                <h2 className="text-3xl font-black text-white">اختر مغامرتك اليوم يا بطل! 🌟</h2>
                <p className="text-amber-400 font-bold mt-1">
                  {selectedSubject} • {selectedAtram} {selectedTerm && `• ${selectedTerm}`} {selectedUnit && `• ${selectedUnit}`}
                </p>
              </div>

              <div className="flex gap-3 items-center">
                <motion.button
                  whileHover={{ scale: 1.05 }}
                  whileTap={{ scale: 0.95 }}
                  onClick={() => {
                    soundClick.play();
                    setShowSelectionPanel(true);
                    setShowModuleCards(false);
                    loadAcademicSettings();
                  }}
                  className="px-5 py-3 bg-slate-700 text-amber-300 rounded-2xl font-bold hover:bg-slate-600 transition-all border border-slate-600 cursor-pointer"
                >
                  ⚙️ تغيير المواد
                </motion.button>

                <select
                  value={selectedUnit}
                  onChange={e => {
                    soundClick.play();
                    const newUnit = e.target.value;
                    persistAcademicSelection({ unit: newUnit });
                  }}
                  className="px-5 py-3 bg-slate-900 text-amber-300 rounded-2xl font-bold border border-slate-700 outline-none cursor-pointer"
                >
                  {(() => {
                    const hierarchicalConfigs = getFilteredHierarchicalConfigs();
                    const gradeConfig = hierarchicalConfigs.find((c: any) => normalizeScopeValue(c.grade) === normalizeScopeValue(selectedGrade));
                    let availableUnits: string[] = [];
                    if (gradeConfig) {
                      const gradeAtrams = Array.isArray(gradeConfig.atrams) ? gradeConfig.atrams : [];
                      const atramConfig = gradeAtrams.find((a: any) => normalizeScopeValue(a?.atram) === normalizeScopeValue(selectedAtram));
                      if (atramConfig) {
                        const atramSubjects = Array.isArray(atramConfig.subjects) ? atramConfig.subjects : [];
                        const subjectConfig = atramSubjects.find((s: any) => normalizeScopeValue(s?.subject) === normalizeScopeValue(selectedSubject));
                        if (subjectConfig) {
                          const subjectTerms = Array.isArray(subjectConfig.terms) ? subjectConfig.terms : [];
                          const termConfig = subjectTerms.find((t: any) => normalizeScopeValue(t?.term) === normalizeScopeValue(selectedTerm));
                          if (termConfig && termConfig.units) {
                            availableUnits = Array.isArray(termConfig.units) ? termConfig.units.filter(Boolean) : [];
                          }
                        }
                      }
                    }
                    if (availableUnits.length === 0) {
                      return <option value="">لا توجد وحدات متاحة</option>;
                    }
                    return availableUnits.map((u, i) => (
                      <option key={i} value={u}>{u}</option>
                    ));
                  })()}
                </select>
              </div>
            </div>

            {/* شبكة الأبطال التفاعلية بروح محرك الألعاب */}
            <TouchCarousel
              label="بطاقات مغامرات الطالب"
              trackClassName="md:grid md:grid-cols-2 lg:grid-cols-3 md:gap-6"
            >
              <motion.div initial={{ opacity: 0, y: 22 }} animate={{ opacity: 1, y: 0 }} transition={{ duration: 0.3 }}>
                <GameModeCard
                title="شرح الدرس"
                subtitle="شاهد سينما الشرح الممتع"
                icon="📺"
                color="bg-gradient-to-br from-amber-400 to-orange-600 border-orange-700"
                onClick={() => {
                  openModule(StudentModuleType.EXPLANATION);
                }}
                />
              </motion.div>

              <motion.div initial={{ opacity: 0, y: 22 }} animate={{ opacity: 1, y: 0 }} transition={{ duration: 0.34, delay: 0.02 }}>
                <GameModeCard
                title="المعلم الافتراضي"
                subtitle="تفاعل وتحدث مع الشخصية الذكية"
                icon="🤖"
                color="bg-gradient-to-br from-purple-500 to-pink-600 border-pink-700"
                onClick={() => {
                  openModule(StudentModuleType.AVATAR_INTERACTION);
                }}
                />
              </motion.div>

              <motion.div initial={{ opacity: 0, y: 22 }} animate={{ opacity: 1, y: 0 }} transition={{ duration: 0.38, delay: 0.04 }}>
                <GameModeCard
                title="شخصيتي"
                subtitle="صمّم أفاتارك ثلاثي الأبعاد"
                icon="3D"
                color="bg-gradient-to-br from-fuchsia-400 to-purple-700 border-purple-900"
                badge="جديد!"
                onClick={() => {
                  openModule(StudentModuleType.PERSONALITY);
                }}
                />
              </motion.div>

              <motion.div initial={{ opacity: 0, y: 22 }} animate={{ opacity: 1, y: 0 }} transition={{ duration: 0.42, delay: 0.06 }}>
                <GameModeCard
                title="حل المسائل"
                subtitle="اسأل مساعدك الذكي السحري"
                icon="💡"
                color="bg-gradient-to-br from-emerald-400 to-teal-600 border-teal-700"
                onClick={() => {
                  openModule(StudentModuleType.PROBLEM_SOLVING);
                  setSolutionText('');
                  setProblemText('');
                }}
                />
              </motion.div>

              {/* بطاقة الاختبارات */}
               <motion.div initial={{ opacity: 0, y: 22 }} animate={{ opacity: 1, y: 0 }} transition={{ duration: 0.46, delay: 0.08 }} className="h-full">
                <div className="relative h-full overflow-hidden bg-gradient-to-br from-indigo-500 to-indigo-700 p-8 rounded-[36px] shadow-2xl border-b-8 border-indigo-900 select-none flex flex-col justify-between">
                 <EducationalCardEffects accent="#fbbf24" />
                <div>
                   <div className="text-6xl mb-3">📝</div>
                   <h3 className="text-3xl font-black mb-1">مركز الاختبارات</h3>
                   <p className="text-indigo-200 text-sm font-medium mb-4">تحدّ معلوماتك واجمع النجوم الذهبية!</p>
                </div>
                 <div className="space-y-2">
                   {getAvailablePeriodicQuizzes().length > 0 ? (
                     getAvailablePeriodicQuizzes().map((quiz) => (
                       <button
                         key={quiz.id}
                         onClick={(e) => { e.stopPropagation(); GameAudioEngine.play('portalTransition'); startQuiz(QuizType.PERIODIC, quiz.id); setShowModuleCards(false); }}
                         className="bg-white/20 hover:bg-white/30 text-white font-bold px-4 py-2.5 rounded-xl text-sm w-full text-center transition-all cursor-pointer active:scale-95"
                       >
                         {getPeriodicQuizLabel(quiz)} ⭐
                       </button>
                     ))
                   ) : (
                     <button
                       onClick={(e) => { e.stopPropagation(); GameAudioEngine.play('portalTransition'); startQuiz(QuizType.PERIODIC); setShowModuleCards(false); }}
                       className="bg-white/20 hover:bg-white/30 text-white font-bold px-4 py-2.5 rounded-xl text-sm w-full text-center transition-all cursor-pointer active:scale-95"
                     >
                       الاختبار الدوري ⭐
                     </button>
                   )}
                  {getAvailableTeacherQuizzes().length > 0 ? (
                    getAvailableTeacherQuizzes().map((quiz) => (
                      <button
                        key={quiz.id}
                        onClick={(e) => { e.stopPropagation(); GameAudioEngine.play('portalTransition'); startQuiz(QuizType.TEACHER, quiz.id); setShowModuleCards(false); }}
                        className="bg-white/20 hover:bg-white/30 text-white font-bold px-4 py-2.5 rounded-xl text-sm w-full text-center transition-all cursor-pointer active:scale-95"
                      >
                         اختبار المعلم 🏆
                      </button>
                    ))
                  ) : (
                    <button
                      onClick={(e) => { e.stopPropagation(); GameAudioEngine.play('portalTransition'); startQuiz(QuizType.TEACHER); setShowModuleCards(false); }}
                      className="bg-white/20 hover:bg-white/30 text-white font-bold px-4 py-2.5 rounded-xl text-sm w-full text-center transition-all cursor-pointer active:scale-95"
                    >
                      اختبار المعلم 🏆
                    </button>
                  )}
                </div>
                </div>
              </motion.div>

              <motion.div initial={{ opacity: 0, y: 22 }} animate={{ opacity: 1, y: 0 }} transition={{ duration: 0.5, delay: 0.1 }}>
                <GameModeCard
                title="الدردشة التفاعلية"
                subtitle="تواصل وامرح مع أصدقائك"
                icon="💬"
                color="bg-gradient-to-br from-pink-500 to-rose-600 border-rose-800"
                badge={hasNewMessage ? 'رسالة جديدة 📬' : undefined}
                onClick={() => {
                  setShowChat(true);
                  setShowModuleCards(false);
                  setHasNewMessage(false);
                }}
                />
              </motion.div>

              <motion.div initial={{ opacity: 0, y: 22 }} animate={{ opacity: 1, y: 0 }} transition={{ duration: 0.54, delay: 0.12 }}>
                <GameModeCard
                title="اجتماع مباشر"
                subtitle="انضم للحصة المباشرة فوراً"
                icon="📞"
                color="bg-gradient-to-br from-red-500 to-rose-700 border-red-900"
                onClick={() => {
                  openModule(StudentModuleType.LIVE_MEETING);
                }}
                />
              </motion.div>

              <motion.div initial={{ opacity: 0, y: 22 }} animate={{ opacity: 1, y: 0 }} transition={{ duration: 0.58, delay: 0.14 }}>
                <GameModeCard
                title="عالم الترفيه والألعاب"
                 subtitle={`اللعبة الأولى متاحة من البداية • الثانية في المستوى 2 • الثالثة في المستوى 3`}
                icon="🎮"
                color="bg-gradient-to-br from-violet-500 to-purple-800 border-purple-950"
                badge={
                   level >= 2
                    ? level >= 3
                      ? '3 ألعاب مفتوحة'
                      : 'لعبتان مفتوحتان'
                     : 'اللعبة الأولى مفتوحة'
                }
                onClick={() => {
                  openModule(StudentModuleType.ENTERTAINMENT);
                }}
                />
              </motion.div>

              <motion.div initial={{ opacity: 0, y: 22 }} animate={{ opacity: 1, y: 0 }} transition={{ duration: 0.62, delay: 0.16 }}>
                <GameModeCard
                title="سينما منارة"
                subtitle="شاهد الفيديوهات المفضلة"
                icon="🎬"
                color="bg-gradient-to-br from-cyan-500 to-blue-700 border-blue-900"
                onClick={() => {
                  openModule(StudentModuleType.VIDEOS);
                }}
                />
              </motion.div>
            </TouchCarousel>
              </div>
            </InteractiveScene>
          </StudentPortalErrorBoundary>
        )}

        {/* Step 3: Active Module Content */}
        {activeModule && !showChat && (
          <AnimatePresence mode="wait">
             <motion.div
              key={activeModule}
              initial={{ opacity: 0, y: 24, scale: 0.97, rotateX: -3 }}
              animate={{ opacity: 1, y: 0, scale: 1, rotateX: 0 }}
              exit={{ opacity: 0, y: -16, scale: 0.98 }}
              transition={{ duration: 0.33, ease: 'easeOut' }}
               className="space-y-6"
            >
            <div className="bg-slate-800/80 backdrop-blur-md rounded-2xl p-4 flex justify-between items-center border border-slate-700">
              <button
                onClick={() => {
                  GameAudioEngine.play('portalTransition');
                  setActiveModule(null);
                  setShowModuleCards(true);
                }}
                className="px-6 py-3 bg-amber-400 text-slate-950 font-black rounded-xl hover:bg-amber-300 transition-all flex items-center gap-2 cursor-pointer shadow-lg"
              >
                ← عودة لبوابة المغامرات
              </button>
              <button
                onClick={() => {
                  GameAudioEngine.play('portalTransition');
                  setActiveModule(null);
                  setShowModuleCards(false);
                  setShowSelectionPanel(true);
                  loadAcademicSettings();
                }}
                className="px-6 py-3 bg-slate-700 text-slate-300 font-bold rounded-xl hover:bg-slate-600 transition-all cursor-pointer"
              >
                ⚙️ تغيير المواد
              </button>
            </div>

            {/* Video Explanation */}
            {activeModule === StudentModuleType.EXPLANATION && (
              <StudentPortalErrorBoundary
                fallback={
                  <StudentExplanationFallback
                    onBack={() => {
                      setActiveModule(null);
                      setShowModuleCards(true);
                    }}
                  />
                }
              >
              <InteractiveScene className="p-8" intensity={1.2} accent={moduleTheme.portalClass}>
                <div className="relative overflow-hidden rounded-[32px] border border-white/10 bg-white/5 p-6 backdrop-blur-md">
                  <EducationalCardEffects accent="#fbbf24" />
                  <div className="pointer-events-none absolute inset-0 bg-[radial-gradient(circle_at_top_left,_rgba(251,191,36,0.22),_transparent_35%),radial-gradient(circle_at_bottom_right,_rgba(59,130,246,0.18),_transparent_30%)]" />
                  <div className="relative z-10">
                  <h2 className="mb-6 text-3xl font-black text-white">📺 سينما الشرح الممتع</h2>
                  <VideoCarousel
                    videos={explanationVideos}
                    activeIndex={explanationVideoIndex}
                    onActiveIndexChange={setExplanationVideoIndex}
                    title="🎞️ اختر شرح الدرس"
                    subtitle="اختر أي بطاقة لتشغيل الفيديو وتكبيره"
                    accent="rose"
                    emptyMessage="لم يتم رفع فيديو لهذا الدرس بعد"
                  />
                  {activeLesson && (
                    <button
                      onClick={completeCurrentLesson}
                      disabled={lessonRewarded}
                      className={`mt-6 w-full rounded-2xl px-6 py-4 text-xl font-black shadow-lg transition-all ${
                        lessonRewarded
                          ? 'bg-slate-700 text-slate-300 cursor-not-allowed opacity-70'
                          : 'bg-gradient-to-r from-emerald-400 to-teal-500 text-slate-950 hover:scale-[1.01] active:scale-95 cursor-pointer'
                      }`}
                    >
                      {lessonRewarded ? '✅ تم استلام مكافأة هذا الدرس لهذه الوحدة' : '✅ أنهيت المهمة — احصل على 5 جواهر 🎉'}
                    </button>
                  )}
                  </div>
                </div>
              </InteractiveScene>
              </StudentPortalErrorBoundary>
            )}

            {/* Student Personality */}
            {activeModule === StudentModuleType.PERSONALITY && student && (
              <StudentPersonality
                student={student}
                onSave={saveStudentAppearance}
              />
            )}

            {/* Avatar Interaction */}
            {activeModule === StudentModuleType.AVATAR_INTERACTION && (
              <InteractiveScene className="p-3 sm:p-4 md:p-8" intensity={1.1}>
                <div className="relative overflow-hidden rounded-2xl sm:rounded-[32px] border border-white/10 bg-white/5 p-3 sm:p-5 md:p-6 backdrop-blur-md">
                  <EducationalCardEffects accent="#c084fc" />
                  <div className="pointer-events-none absolute inset-0 bg-[radial-gradient(circle_at_top_left,_rgba(192,132,252,0.22),_transparent_35%),radial-gradient(circle_at_bottom_right,_rgba(34,211,238,0.18),_transparent_30%)]" />
                  <div className="relative z-10">
                    <div className="mb-4 flex flex-col items-start gap-3 sm:mb-5 sm:flex-row sm:items-center sm:gap-4">
                     <Interactive3DEmoji emoji="🤖" accent="#c084fc" size="md" />
                      <h2 className="text-xl font-black leading-tight text-white sm:text-2xl md:text-3xl">صديقك المعلم الافتراضي</h2>
                   </div>
                  {activeLesson?.avatarInteractionUrl ? (
                    <div className="space-y-6">
                      <div className="rounded-2xl border border-purple-500/30 bg-purple-950/40 p-3 sm:rounded-[28px] sm:p-5 md:p-6">
                        <p className="mb-3 text-base font-bold leading-6 text-purple-200 sm:mb-4 sm:text-xl">
                          صديقك الذكي مستعد للعب والكلام!
                        </p>
                        <ResponsiveAvatarEmbed rawUrl={activeLesson.avatarInteractionUrl} />
                      </div>
                    </div>
                  ) : (
                    <div className="p-20 text-center text-slate-500">
                      <Interactive3DEmoji emoji="🤖" accent="#c084fc" size="xl" className="mb-4" />
                      <p className="text-2xl font-bold">لم يتم إضافة رابط التفاعل بعد</p>
                    </div>
                  )}
                  </div>
                </div>
              </InteractiveScene>
            )}

            {/* Problem Solving */}
            {activeModule === StudentModuleType.PROBLEM_SOLVING && (
              <InteractiveScene className="p-8" intensity={1.1}>
                <div className="relative overflow-hidden bg-slate-800/90 backdrop-blur-xl rounded-[40px] shadow-2xl p-8 border border-slate-700">
                  <EducationalCardEffects accent="#2dd4bf" />
                  <div className="pointer-events-none absolute inset-0 bg-[radial-gradient(circle_at_top_left,_rgba(16,185,129,0.18),_transparent_30%),radial-gradient(circle_at_bottom_right,_rgba(245,158,11,0.18),_transparent_30%)]" />
                  <div className="relative z-10">
                  <h2 className="text-3xl font-black text-white mb-6 text-center">💡 اسأل المساعد السحري</h2>
                  <textarea
                    className="w-full p-6 bg-slate-900/90 rounded-3xl border-2 border-slate-700 focus:border-amber-400 outline-none h-48 text-lg font-medium mb-6 text-white"
                    placeholder="اكتب سؤالك هنا يا بطل وصديقك الذكي سيجيبك فوراً..."
                    value={problemText}
                    onChange={e => setProblemText(e.target.value)}
                  />
                  <button
                    onClick={handleSolveProblem}
                    disabled={isSolving || !problemText.trim()}
                    className="w-full bg-gradient-to-r from-amber-400 to-orange-500 text-slate-950 py-5 rounded-2xl font-black text-xl shadow-xl disabled:opacity-50 cursor-pointer active:scale-95 transition-all"
                  >
                    {isSolving ? 'جاري التفكير وحل المسألة... 🤔' : 'إرسال السؤال السحري ✨'}
                  </button>

                  {solutionText && (
                    <div className="mt-6 p-8 bg-slate-900 rounded-3xl border border-slate-700">
                      <h4 className="font-black text-amber-400 text-2xl mb-4">فانوس الإجابة الذكية:</h4>
                      <div className="text-slate-200 text-lg leading-relaxed whitespace-pre-wrap">{solutionText}</div>
                    </div>
                  )}
                  </div>
                </div>
              </InteractiveScene>
            )}

            {/* Live Meeting */}
            {activeModule === StudentModuleType.LIVE_MEETING && (
              <InteractiveScene className="p-3 sm:p-4 md:p-8" intensity={1.1}>
                <div className="relative overflow-hidden bg-slate-800/90 backdrop-blur-xl rounded-2xl sm:rounded-[40px] shadow-2xl p-3 sm:p-5 md:p-8 border border-slate-700">
                  <EducationalCardEffects accent="#fb7185" />
                  <div className="pointer-events-none absolute inset-0 bg-[radial-gradient(circle_at_top_left,_rgba(248,113,113,0.18),_transparent_30%),radial-gradient(circle_at_bottom_right,_rgba(129,140,248,0.16),_transparent_30%)]" />
                  <div className="relative z-10">
                     <div className="mb-4 flex flex-col items-start gap-3 sm:mb-5 sm:flex-row sm:items-center sm:gap-4">
                       <Interactive3DEmoji emoji="📞" accent="#fb7185" size="md" />
                       <h2 className="text-xl font-black leading-tight text-white sm:text-2xl md:text-3xl">البث المباشر الممتع</h2>
                     </div>
                    <div className="min-h-[220px] w-full overflow-hidden rounded-2xl bg-black shadow-2xl aspect-video sm:min-h-[300px] md:min-h-[420px]">
                      <LiveMeetingEmbed rawUrl={activeLesson?.liveMeetingUrl} />
                    </div>
                  </div>
                </div>
              </InteractiveScene>
            )}

            {/* Videos */}
            {activeModule === StudentModuleType.VIDEOS && (
              <div className="relative overflow-hidden rounded-[40px]">
                <EducationalCardEffects accent="#38bdf8" />
                <StudentPortalErrorBoundary
                  fallback={
                    <StudentCardErrorFallback
                      onBack={() => {
                        setActiveModule(null);
                        setShowModuleCards(true);
                      }}
                    />
                  }
                >
                  <StudentVideos
                    grade={selectedGrade}
                    atram={selectedAtram}
                    subject={selectedSubject}
                    term={selectedTerm}
                    unit={selectedUnit}
                  />
                </StudentPortalErrorBoundary>
              </div>
            )}

            {/* Entertainment / Games */}
            {activeModule === StudentModuleType.ENTERTAINMENT && (
              <div className="relative overflow-hidden rounded-[40px]">
                <EducationalCardEffects accent="#a78bfa" />
                <StudentPortalErrorBoundary
                  fallback={
                    <StudentCardErrorFallback
                      onBack={() => {
                        setActiveModule(null);
                        setShowModuleCards(true);
                      }}
                    />
                  }
                >
                  <EntertainmentGames
                    grade={selectedGrade}
                    subject={selectedSubject}
                    term={selectedTerm}
                    unit={selectedUnit}
                    lessonContent={activeLesson?.lessonContent}
                  />
                </StudentPortalErrorBoundary>
              </div>
            )}

            {/* Quiz */}
            {activeModule === StudentModuleType.QUIZ && (
              <InteractiveScene className="p-8" intensity={1.1}>
                <div className="relative overflow-hidden bg-slate-800/90 backdrop-blur-xl rounded-[40px] shadow-2xl p-8 border border-slate-700">
                  <EducationalCardEffects accent="#facc15" />
                  <div className="pointer-events-none absolute inset-0 bg-[radial-gradient(circle_at_top_left,_rgba(250,204,21,0.18),_transparent_30%),radial-gradient(circle_at_bottom_right,_rgba(244,114,182,0.18),_transparent_30%)]" />
                  <div className="relative z-10">
                  {!quizResult ? (
                    quizEmptyMessage ? (
                      <div className="text-center py-16">
                        <Interactive3DEmoji
                          emoji="📝"
                          accent="#facc15"
                          size="xl"
                          className="mb-6"
                        />
                        <h2 className="text-4xl font-black mb-4 text-white">لا يوجد اختبار متاح</h2>
                        <p className="text-xl text-amber-400 font-bold mb-8">{quizEmptyMessage}</p>
                        <button
                          onClick={() => {
                            soundClick.play();
                            setActiveModule(null);
                            setQuizResult(null);
                            setQuizEmptyMessage(null);
                            setCurrentQuiz([]);
                            setUserAnswers({});
                            setShowModuleCards(true);
                          }}
                          className="px-12 py-4 bg-white text-slate-950 rounded-2xl font-black text-xl hover:bg-slate-200 shadow-xl cursor-pointer"
                        >
                          العودة إلى الصفحة الرئيسية 🏠
                        </button>
                      </div>
                    ) : (
                    <div>
                      <div className="flex justify-between items-center mb-8">
                        <div className="bg-slate-900 px-6 py-3 rounded-full font-black text-amber-400 text-lg border border-slate-700">
                          السؤال {qIndex + 1} / {currentQuiz.length} ⭐
                        </div>
                        <div className="h-4 w-64 bg-slate-900 rounded-full overflow-hidden border border-slate-700">
                          <div className="h-full bg-gradient-to-r from-amber-400 to-pink-500 transition-all" style={{ width: `${((qIndex + 1) / currentQuiz.length) * 100}%` }}></div>
                        </div>
                      </div>

                      <h3 className="text-3xl font-black mb-8 text-white text-right">{currentQuiz[qIndex]?.question}</h3>

                      <div className="space-y-4 mb-8">
                        {currentQuiz[qIndex]?.options.map((opt, i) => (
                          <button
                            key={i}
                            onClick={() => {
                              playLamsaSound('star');
                              setUserAnswers({...userAnswers, [currentQuiz[qIndex].id]: opt});
                            }}
                            className={`w-full p-6 text-right rounded-2xl border-2 transition-all font-bold text-lg cursor-pointer ${
                              userAnswers[currentQuiz[qIndex].id] === opt
                                ? 'bg-gradient-to-r from-amber-400 to-orange-500 border-amber-300 text-slate-950 shadow-xl scale-[1.01]'
                                : 'bg-slate-900/80 border-slate-700 hover:border-amber-400 text-slate-200'
                            }`}
                          >
                            ✨ {opt}
                          </button>
                        ))}
                      </div>

                      <div className="flex justify-between pt-6 border-t border-slate-700">
                        <button 
                          onClick={() => { soundClick.play(); setQIndex(Math.max(0, qIndex - 1)); }} 
                          disabled={qIndex === 0}
                          className="px-8 py-3 bg-slate-700 text-slate-300 rounded-xl font-bold hover:bg-slate-600 disabled:opacity-40 cursor-pointer"
                        >
                          السابق
                        </button>
                        {qIndex === currentQuiz.length - 1 ? (
                           <button
                             onClick={submitQuiz}
                             disabled={!userAnswers[currentQuiz[qIndex]?.id]}
                             className="px-8 py-3 bg-gradient-to-r from-emerald-400 to-teal-500 text-slate-950 rounded-xl font-black text-lg shadow-xl cursor-pointer active:scale-95 disabled:opacity-40 disabled:cursor-not-allowed"
                           >
                            تسليم وإنهاء الاختبار 🏆
                          </button>
                        ) : (
                           <button
                             onClick={() => { soundClick.play(); setQIndex(qIndex + 1); }}
                             disabled={!userAnswers[currentQuiz[qIndex]?.id]}
                             className="px-8 py-3 bg-gradient-to-r from-amber-400 to-orange-500 text-slate-950 rounded-xl font-black text-lg shadow-xl cursor-pointer active:scale-95 disabled:opacity-40 disabled:cursor-not-allowed"
                           >
                            التالي
                          </button>
                        )}
                      </div>
                    </div>
                    )
                  ) : (
                    <div className="text-center">
                       <Interactive3DEmoji
                         emoji={quizResult.percentage >= 90 ? '🏆' : quizResult.percentage >= 60 ? '⭐' : '💪'}
                         accent={quizResult.percentage >= 90 ? '#fbbf24' : '#38bdf8'}
                         size="xl"
                         className="mb-6"
                       />
                      <h2 className="text-5xl font-black mb-4 text-white">انتهت المغامرة بنجاح!</h2>
                      <p className="text-2xl text-amber-400 font-bold mb-8">{quizResult.feedback}</p>

                      <div className="flex justify-center gap-6 mb-8">
                        <div className="bg-slate-900 p-8 rounded-3xl border border-slate-700">
                          <p className="text-slate-400 font-bold mb-2">مجموع النجوم</p>
                          <p className="text-5xl font-black text-white">{quizResult.score} / {quizResult.total}</p>
                        </div>
                        <div className="bg-gradient-to-br from-amber-400 to-orange-500 p-8 rounded-3xl text-slate-950 shadow-xl">
                          <p className="text-slate-900/80 font-bold mb-2">النسبة الذهبية</p>
                          <p className="text-5xl font-black">{quizResult.percentage}%</p>
                        </div>
                      </div>

                      <button onClick={() => { soundClick.play(); setActiveModule(null); setQuizResult(null); setShowModuleCards(true); }} className="px-12 py-4 bg-white text-slate-950 rounded-2xl font-black text-xl hover:bg-slate-200 shadow-xl cursor-pointer">
                        العودة للرئيسية 🏠
                      </button>
                    </div>
                  )}
                  </div>
                </div>
              </InteractiveScene>
            )}
            </motion.div>
          </AnimatePresence>
        )}

        {/* Chat (Full Screen) */}
        {showChat && (
          <div className="relative min-h-[min(600px,calc(100dvh-8rem))] overflow-hidden bg-slate-800/95 backdrop-blur-xl rounded-[28px] sm:rounded-[40px] shadow-2xl p-4 sm:p-8 flex flex-col border border-slate-700 animate-fadeIn safe-area-bottom">
             <EducationalCardEffects accent="#ec4899" />
            <div className="pointer-events-none absolute inset-0 bg-[radial-gradient(circle_at_top_left,_rgba(236,72,153,0.16),_transparent_32%),radial-gradient(circle_at_bottom_right,_rgba(34,211,238,0.16),_transparent_32%)]" />
            <div className="relative z-10 flex min-h-0 h-full flex-col">
            <div className="flex flex-col sm:flex-row justify-between items-stretch sm:items-center gap-3 mb-4 sm:mb-6">
              <div className="flex flex-wrap items-center gap-3 sm:gap-4">
                 <div className="flex min-w-0 items-center gap-3 sm:gap-4">
                   <Interactive3DEmoji emoji="💬" accent="#ec4899" size="md" />
                    <h2 className="text-xl sm:text-3xl font-black text-pink-400">غرفة الأصدقاء والمرح</h2>
                 </div>
                <button 
                  onClick={() => {
                    soundClick.play();
                    let newChatState = !chatEnabled;
                    setChatEnabled(newChatState);
                    if (newChatState === false) {
                      setChatMessages([]);
                      setHasNewMessage(false);
                    }
                  }}
                  className={`min-h-11 px-4 py-2 rounded-xl font-bold transition-all ${
                    chatEnabled 
                      ? 'bg-emerald-500/20 text-emerald-300 border border-emerald-500/30' 
                      : 'bg-slate-700 text-slate-400'
                  }`}
                >
                  {chatEnabled ? '✅ مفعلة' : '⏸️ متوقفة'}
                </button>
              </div>
              <button onClick={() => { 
                soundClick.play();
                setShowChat(false); 
                setShowModuleCards(true);
                setHasNewMessage(false);
               }} className="min-h-11 self-start px-5 py-3 bg-red-500/20 text-red-300 rounded-xl font-bold hover:bg-red-500/30 border border-red-500/30 cursor-pointer">
                إغلاق
              </button>
            </div>

            <div ref={chatContainerRef} className="min-h-0 flex-1 overflow-y-auto bg-slate-900/90 rounded-2xl sm:rounded-3xl p-3 sm:p-6 mb-4 sm:mb-6 space-y-4 border border-slate-700">
              {!chatEnabled ? (
                <div className="flex items-center justify-center h-full text-slate-500">
                  <div className="text-center">
                     <Interactive3DEmoji emoji="⏸️" accent="#94a3b8" size="lg" className="mb-4" />
                    <p className="font-bold text-xl">الدردشة في استراحة قصيرة</p>
                  </div>
                </div>
              ) : chatMessages.length === 0 ? (
                <div className="flex items-center justify-center h-full text-slate-500">
                  <div className="text-center">
                     <Interactive3DEmoji emoji="💬" accent="#ec4899" size="lg" className="mb-4" />
                    <p className="font-bold text-xl">لا توجد رسائل، كن أول من يرحب بأصدقائه! 👋</p>
                  </div>
                </div>
              ) : (
                chatMessages.map((msg: any) => (
                  <div key={msg.id} className={`flex gap-4 ${msg.from === student?.id ? 'justify-end' : ''}`}>
                    <div className={`max-w-md p-4 rounded-2xl ${msg.from === student?.id ? 'bg-gradient-to-br from-pink-500 to-purple-600 text-white rounded-br-none' : 'bg-slate-800 text-slate-100 border border-slate-700 rounded-bl-none'}`}>
                      <p className="font-bold text-sm mb-1 text-amber-300">{msg.name}</p>
                      <p className="leading-relaxed">{msg.message}</p>
                      <p className="text-[10px] mt-2 text-white/60">
                        {new Date(msg.time).toLocaleTimeString('ar-SA')}
                      </p>
                    </div>
                  </div>
                ))
              )}
            </div>

            <div className="flex gap-4">
              <select 
                value={chatTarget} 
                onChange={e => { soundClick.play(); setChatTarget(e.target.value as any); }} 
                className="p-4 rounded-xl border border-slate-700 bg-slate-900 text-white font-bold outline-none cursor-pointer"
                disabled={!chatEnabled}
              >
                <option value="all">الجميع 🌍</option>
                {peers.map(p => <option key={p.id} value={p.id}>{p.name} 🎈</option>)}
              </select>
              <input
                type="text"
                value={chatInput}
                onChange={e => setChatInput(e.target.value)}
                onKeyPress={e => { if (e.key === 'Enter' && chatEnabled) sendChatMessage(); }}
                placeholder={chatEnabled ? "اكتب رسالة جميلة لأصدقائك..." : "الدردشة متوقفة حالياً..."}
                className="flex-1 p-4 bg-slate-900 border border-slate-700 text-white rounded-xl outline-none focus:border-pink-500 text-right font-medium"
                disabled={!chatEnabled}
              />
              <button 
                onClick={sendChatMessage} 
                className={`px-8 py-4 rounded-xl font-black shadow-xl transition-all ${
                  chatEnabled 
                    ? 'bg-gradient-to-r from-pink-500 to-purple-500 text-white hover:from-pink-600 hover:to-purple-600 cursor-pointer' 
                    : 'bg-slate-700 text-slate-500 cursor-not-allowed'
                }`}
                disabled={!chatEnabled}
              >
                إرسال 🚀
              </button>
            </div>
          </div>
        </div>
        )}
      </div>

      <AnimatedCelebration
        visible={showRewardPopup}
        title="إنجاز رائع!"
        subtitle={rewardInfo.message}
        emoji={rewardInfo.gems > 0 ? '🏆' : '✨'}
      />
    </div>
  );
};

export default StudentDashboard;