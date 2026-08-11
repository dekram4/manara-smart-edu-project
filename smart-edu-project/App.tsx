import React, { Component, ErrorInfo, ReactNode, useState, useEffect, useRef, Suspense } from 'react';
import { motion } from 'framer-motion';
import Spline from '@splinetool/react-spline';
import { gsap } from 'gsap';
import RoleSelection from './pages/RoleSelection';
import AdminDashboard from './pages/admin/AdminDashboard';
import TeacherDashboard from './pages/teacher/TeacherDashboard';
import StudentDashboard from './pages/student/StudentDashboard';
import ParentDashboard from './pages/parent/ParentDashboard';
import { STORAGE_KEYS } from './constants';
import { initSupabaseSync } from './db/sync';
import { migratePasswordsToHash } from './db/migratePasswords';
import { GameControls } from './src/components/GameControls';
import {
  readSessionValue,
  removeSessionValue,
  SESSION_KEYS,
  writeSessionValue,
} from './utils/sessionPersistence';

// ✅ الاستدعاء المباشر والمحلي للمكتبات (Game Engine Infrastructure)
import { playLamsaSound } from './utils/sounds';
import { GameAudioEngine } from './utils/gameAudioEngine';

// أصوات تفاعلية سريعة
const readControlState = () => {
  if (typeof window === 'undefined') return { soundEnabled: true, hapticsEnabled: true };
  try {
    const raw = window.localStorage.getItem('manara_game_controls');
    if (!raw) return { soundEnabled: true, hapticsEnabled: true };
    const parsed = JSON.parse(raw);
    return {
      soundEnabled: parsed.soundEnabled ?? true,
      hapticsEnabled: parsed.hapticsEnabled ?? true,
    };
  } catch {
    return { soundEnabled: true, hapticsEnabled: true };
  }
};

export const soundPop = {
  play: () => {
    const { soundEnabled } = readControlState();
    if (soundEnabled) GameAudioEngine.play('uiSelect');
  },
};

export const soundClick = {
  play: () => {
    const { soundEnabled } = readControlState();
    if (soundEnabled) GameAudioEngine.play('uiHover');
  },
};

export const triggerCelebration = (won = true) => {
  if (won) {
    GameAudioEngine.play('correctAnswer');
  } else {
    GameAudioEngine.play('wrongAnswer');
  }
};

type MainView = 'role' | 'admin' | 'teacher' | 'student' | 'parent';

class DashboardErrorBoundary extends Component<
  { children: ReactNode },
  { hasError: boolean; errorMessage: string }
> {
  state = { hasError: false, errorMessage: '' };

  static getDerivedStateFromError(error: unknown) {
    return {
      hasError: true,
      errorMessage: error instanceof Error ? error.message : 'حدث خطأ غير متوقع',
    };
  }

  componentDidCatch(error: Error, errorInfo: ErrorInfo) {
    console.error('[app] dashboard render error:', error, errorInfo);
  }

  handleRetry = () => {
    this.setState({ hasError: false, errorMessage: '' });
  };

  render() {
    if (!this.state.hasError) return this.props.children;

    return (
      <div dir="rtl" className="flex min-h-screen items-center justify-center bg-slate-950 px-4 py-8 font-tajawal text-white">
        <div className="w-full max-w-md rounded-3xl border border-amber-300/30 bg-white/10 p-6 text-center shadow-2xl backdrop-blur-xl sm:p-8">
          <div className="mb-4 text-5xl">🛟</div>
          <h1 className="mb-2 text-2xl font-black">حدثت مشكلة مؤقتة</h1>
          <p className="mb-6 text-sm font-bold leading-7 text-slate-300">
            لم يتم تسجيل خروجك. أعد المحاولة لاستكمال الشاشة، وستبقى بياناتك وجلسة الدخول محفوظة.
          </p>
          <button
            type="button"
            onClick={this.handleRetry}
            className="min-h-11 w-full rounded-2xl bg-cyan-500 px-5 py-3 font-black text-slate-950 transition hover:bg-cyan-300"
          >
            إعادة المحاولة
          </button>
          <p className="mt-4 break-words text-[11px] text-slate-500">{this.state.errorMessage}</p>
        </div>
      </div>
    );
  }
}

const BootLoader: React.FC = () => {
  const loaderRef = useRef<HTMLDivElement | null>(null);

  useEffect(() => {
    if (!loaderRef.current) return;
    const tl = gsap.timeline({ repeat: -1, yoyo: true });
    tl.to(loaderRef.current, { scale: 1.04, duration: 1.2, ease: 'power2.inOut' });
    return () => {
      tl.kill();
    };
  }, []);

  const splineScene = (import.meta as ImportMeta & { env?: { VITE_SPLINE_SCENE_URL?: string } }).env?.VITE_SPLINE_SCENE_URL;

  return (
    <div className="flex flex-col items-center justify-center gap-4">
      <motion.div ref={loaderRef} initial={{ opacity: 0, scale: 0.9 }} animate={{ opacity: 1, scale: 1 }} className="relative flex items-center justify-center" style={{ width: '180px', height: '180px' }}>
        <div className="absolute inset-0 rounded-full border-8 border-indigo-200 border-t-indigo-600 animate-spin" />
        <div className="absolute inset-6 rounded-full border-4 border-cyan-200 border-b-cyan-500 animate-[spin_1.4s_linear_infinite_reverse]" />
        {splineScene ? (
          <div className="relative flex h-28 w-28 items-center justify-center overflow-hidden rounded-full border border-white/20 bg-slate-950/80 shadow-2xl">
            <Suspense fallback={<div className="text-5xl">🚀</div>}>
              <Spline scene={splineScene} className="h-full w-full" />
            </Suspense>
          </div>
        ) : (
          <div className="relative flex h-28 w-28 items-center justify-center overflow-hidden rounded-full border border-white/20 bg-slate-950/80 text-5xl shadow-2xl">
            🚀
          </div>
        )}
      </motion.div>
      <p className="text-sm font-semibold text-slate-600">تجهيز تجربة منارة المعرفة…</p>
    </div>
  );
};

const ScrollDownButton: React.FC = () => {
  const [visible, setVisible] = useState(false);

  useEffect(() => {
    const update = () => {
      const scrollTop = window.scrollY || document.documentElement.scrollTop;
      const maxScroll = document.documentElement.scrollHeight - window.innerHeight;
      setVisible(maxScroll > 140 && scrollTop < maxScroll - 100);
    };

    update();
    window.addEventListener('scroll', update, { passive: true });
    window.addEventListener('resize', update);
    return () => {
      window.removeEventListener('scroll', update);
      window.removeEventListener('resize', update);
    };
  }, []);

  const handleClick = () => {
    window.scrollTo({ top: document.documentElement.scrollHeight, behavior: 'smooth' });
  };

  return (
    <motion.button
      initial={{ opacity: 0, y: 12 }}
      animate={{ opacity: visible ? 1 : 0, y: visible ? 0 : 12 }}
      whileHover={{ scale: 1.04 }}
      whileTap={{ scale: 0.96 }}
      onClick={handleClick}
      className="fixed bottom-[calc(1rem+env(safe-area-inset-bottom))] left-[calc(1rem+env(safe-area-inset-left))] z-50 rounded-full border border-cyan-300/40 bg-slate-900/85 px-4 py-3 text-sm font-black text-cyan-100 shadow-2xl backdrop-blur-md"
    >
      ↓ للأسفل
    </motion.button>
  );
};

const App: React.FC = () => {
  const [mainView, setMainView] = useState<MainView>('role');
  const [booting, setBooting] = useState(true);
  const [sessionReady, setSessionReady] = useState(false);
  const [syncing, setSyncing] = useState(true);

  const clearActiveSessions = () => {
    removeSessionValue(STORAGE_KEYS.ACTIVE_STUDENT);
    removeSessionValue(STORAGE_KEYS.ACTIVE_PARENT);
    removeSessionValue(STORAGE_KEYS.CURRENT_TEACHER);
  };

  const enterRole = (role: MainView) => {
    clearActiveSessions();
    writeSessionValue(SESSION_KEYS.ACTIVE_ROLE, role);
    setMainView(role);
  };

  const leaveRole = () => {
    clearActiveSessions();
    removeSessionValue(SESSION_KEYS.ACTIVE_ROLE);
    removeSessionValue(SESSION_KEYS.ADMIN_SESSION);
    void fetch('/api/auth/admin/logout', { method: 'POST' }).catch(() => {});
    setMainView('role');
  };

  // عند الإقلاع: نحمّل البيانات من Supabase
  useEffect(() => {
    let mounted = true;
    const savedRole = readSessionValue(SESSION_KEYS.ACTIVE_ROLE);
    const validRoles: MainView[] = ['admin', 'teacher', 'student', 'parent'];
    const legacyRole =
      readSessionValue(STORAGE_KEYS.ACTIVE_STUDENT) ? 'student' :
      readSessionValue(STORAGE_KEYS.CURRENT_TEACHER) ? 'teacher' :
      readSessionValue(STORAGE_KEYS.ACTIVE_PARENT) ? 'parent' :
      readSessionValue(SESSION_KEYS.ADMIN_SESSION) === '1' ? 'admin' :
      null;
    const restoredRole = savedRole && validRoles.includes(savedRole as MainView)
      ? savedRole as MainView
      : legacyRole;
    if (restoredRole) {
      setMainView(restoredRole);
      if (restoredRole !== savedRole) {
        writeSessionValue(SESSION_KEYS.ACTIVE_ROLE, restoredRole);
      }
    }
    setSessionReady(true);

    (async () => {
      const syncTask = (async () => {
        migratePasswordsToHash();
        await new Promise((resolve) => setTimeout(resolve, 300));
        // Do not mount role dashboards until the shared data has been loaded.
        // Otherwise a student can read an empty local content list on a new device.
        await initSupabaseSync();
      })();

      try {
        // A remote connector must never keep the whole app on the boot screen.
        // If it is slow, initSupabaseSync continues in the background and the
        // existing localStorage data remains available to the user.
        const bootFallback = new Promise<'timeout'>((resolve) => {
          window.setTimeout(() => resolve('timeout'), 2500);
        });
        const result = await Promise.race([
          syncTask.then(() => 'ready' as const, (error) => {
            console.error('[app] Supabase sync initialization failed:', error);
            return 'failed' as const;
          }),
          bootFallback,
        ]);
        if (mounted && result === 'timeout') {
          setBooting(false);
          setSyncing(false);
        }
      } finally {
        if (mounted) {
          setBooting(false);
          setSyncing(false);
        }
      }
    })();
    return () => {
      mounted = false;
    };
  }, []);

  const renderView = () => {
    switch (mainView) {
      case 'admin':
        return <AdminDashboard onLogout={leaveRole} />;
      case 'teacher':
        return <TeacherDashboard onLogout={leaveRole} />;
      case 'student':
        return <StudentDashboard onLogout={leaveRole} />;
      case 'parent':
        return <ParentDashboard onLogout={leaveRole} />;
      default:
        return (
          <RoleSelection
            onSelectAdmin={() => enterRole('admin')}
            onSelectTeacher={() => enterRole('teacher')}
            onSelectStudent={() => enterRole('student')}
            onSelectParent={() => enterRole('parent')}
          />
        );
    }
  };

  if (booting || !sessionReady) {
    return (
      <div className="flex flex-col items-center justify-center min-h-screen bg-gradient-to-br from-blue-50 to-indigo-100 font-tajawal">
        <BootLoader />
        <p className="text-indigo-900 text-lg font-semibold mt-4">جارٍ تحميل المشروع، انتظر لحظة... ✨</p>
      </div>
    );
  }

  return (
    <div className="min-h-screen font-tajawal">
      <ScrollDownButton />
      <GameControls />
      <DashboardErrorBoundary key={mainView}>{renderView()}</DashboardErrorBoundary>
      {syncing && (
        <div className="fixed bottom-[calc(1rem+env(safe-area-inset-bottom))] right-[calc(1rem+env(safe-area-inset-right))] max-w-[calc(100vw-2rem)] bg-white/90 border border-gray-300 rounded-3xl shadow-xl px-4 py-3 backdrop-blur-md flex items-center gap-3">
          <div className="w-3 h-3 rounded-full bg-green-500 animate-pulse" />
          <div>
            <p className="text-sm font-bold text-gray-700">جارٍ المزامنة مع الخادم...</p>
            <p className="text-xs text-gray-500">يمكنك الاستمرار في الاستخدام بينما يكتمل التحميل.</p>
          </div>
        </div>
      )}
    </div>
  );
};

export default App;