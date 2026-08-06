import React, { useState, useEffect, useRef, Suspense } from 'react';
import { motion } from 'framer-motion';
import Spline from '@splinetool/react-spline';
import useSound from 'use-sound';
import { gsap } from 'gsap';
import RoleSelection from './pages/RoleSelection';
import AdminDashboard from './pages/admin/AdminDashboard';
import TeacherDashboard from './pages/teacher/TeacherDashboard';
import StudentDashboard from './pages/student/StudentDashboard';
import ParentDashboard from './pages/parent/ParentDashboard';
import { STORAGE_KEYS } from './constants';
import { initSupabaseSync } from './db/sync';
import { migratePasswordsToHash } from './db/migratePasswords';
import { GameControls } from './components/GameControls';

// ✅ الاستدعاء المباشر والمحلي للمكتبات (Game Engine Infrastructure)
import { playLamsaSound, playNavigationSound, playEncouragementSound } from './utils/sounds';

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
    if (soundEnabled) playNavigationSound();
  },
};

export const soundClick = {
  play: () => {
    const { soundEnabled } = readControlState();
    if (soundEnabled) playNavigationSound();
  },
};

export const triggerCelebration = () => {
  playEncouragementSound();
};

type MainView = 'role' | 'admin' | 'teacher' | 'student' | 'parent';

const BootLoader: React.FC = () => {
  const loaderRef = useRef<HTMLDivElement | null>(null);
  const [playIntro] = useSound('/audio/welcome-student.mp3', { volume: 0.06, interrupt: true });

  useEffect(() => {
    playIntro();
  }, [playIntro]);

  useEffect(() => {
    if (!loaderRef.current) return;
    const tl = gsap.timeline({ repeat: -1, yoyo: true });
    tl.to(loaderRef.current, { scale: 1.04, duration: 1.2, ease: 'power2.inOut' });
    return () => tl.kill();
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
      className="fixed bottom-5 left-5 z-50 rounded-full border border-cyan-300/40 bg-slate-900/85 px-4 py-3 text-sm font-black text-cyan-100 shadow-2xl backdrop-blur-md"
    >
      ↓ للأسفل
    </motion.button>
  );
};

const App: React.FC = () => {
  const [mainView, setMainView] = useState<MainView>('role');
  const [booting, setBooting] = useState(true);
  const [syncing, setSyncing] = useState(true);

  const clearActiveSessions = () => {
    localStorage.removeItem(STORAGE_KEYS.ACTIVE_STUDENT);
    localStorage.removeItem(STORAGE_KEYS.ACTIVE_PARENT);
    localStorage.removeItem(STORAGE_KEYS.CURRENT_TEACHER);
  };

  const enterRole = (role: MainView) => {
    clearActiveSessions();
    setMainView(role);
  };

  const leaveRole = () => {
    clearActiveSessions();
    setMainView('role');
  };

  // عند الإقلاع: نحمّل البيانات من Supabase
  useEffect(() => {
    let mounted = true;
    (async () => {
      migratePasswordsToHash();
      await new Promise((resolve) => setTimeout(resolve, 800));
      if (mounted) setBooting(false);
      if (mounted) setSyncing(false);
      await initSupabaseSync();
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

  if (booting) {
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
      {renderView()}
      {syncing && (
        <div className="fixed bottom-4 right-4 bg-white/90 border border-gray-300 rounded-3xl shadow-xl px-5 py-3 backdrop-blur-md flex items-center gap-3">
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