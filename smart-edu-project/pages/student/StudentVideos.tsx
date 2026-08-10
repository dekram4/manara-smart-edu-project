import React, { useState, useEffect } from 'react';
import { motion, AnimatePresence } from 'framer-motion';
import { STORAGE_KEYS } from '../../constants';
import { playLamsaSound } from '../../utils/sounds';
import { filterTeacherOwnedRecords, matchesAcademicScope } from '../../utils/scope';
import { StudentInfo } from '../../types';
import { getGems, hasCompletedActivity, rewardVideoComplete } from '../../utils/gamification';
import { GameAudioEngine } from '../../utils/gameAudioEngine';
import { getVideoSourceType, isMp4VideoUrl } from '../../utils/video';
import EducationalCardEffects from '../../components/effects/EducationalCardEffects';

const GEMS_PER_VIDEO = 2;

interface VideoRecord {
  id: string;
  title: string;
  description: string;
  url: string;
  sourceType?: 'embed' | 'mp4';
  grade: string;
  subject: string;
  term: string;
  unit: string;
  teacherName: string;
  createdAt: string;
}

interface StudentVideosProps {
  grade: string;
  atram: string;
  subject: string;
  term: string;
  unit: string;
}

const StudentVideos: React.FC<StudentVideosProps> = ({ grade, atram, subject, term, unit }) => {
  const [videos, setVideos] = useState<VideoRecord[]>([]);
  const [playingVideo, setPlayingVideo] = useState<string | null>(null);
  const [watchedVideos, setWatchedVideos] = useState<string[]>([]);
  const [activeIndex, setActiveIndex] = useState(0);
  const [isAutoPlaying, setIsAutoPlaying] = useState(true);
  const [touchStartX, setTouchStartX] = useState<number | null>(null);
  const [previewVideoId, setPreviewVideoId] = useState<string | null>(null);
  const [currentGems, setCurrentGems] = useState(0);
  const [lockMessage, setLockMessage] = useState('');

  useEffect(() => {
    loadVideos();
    const refreshTimer = window.setInterval(loadVideos, 1500);
    return () => window.clearInterval(refreshTimer);
  }, [grade, atram, subject, term, unit]);

  useEffect(() => {
    setCurrentGems(getGems());
    const timer = window.setInterval(() => setCurrentGems(getGems()), 1500);
    return () => window.clearInterval(timer);
  }, []);

  useEffect(() => {
    if (!isAutoPlaying || videos.length <= 1) return;

    const timer = window.setInterval(() => {
      setActiveIndex(prev => (prev + 1 < videos.length ? prev + 1 : 0));
    }, 4000);

    return () => window.clearInterval(timer);
  }, [isAutoPlaying, videos.length]);

  const loadVideos = () => {
    const saved = localStorage.getItem(STORAGE_KEYS.VIDEOS);
    if (!saved) return;
    const all: VideoRecord[] = JSON.parse(saved);
    const student = JSON.parse(
      localStorage.getItem(STORAGE_KEYS.ACTIVE_STUDENT) || 'null',
    ) as StudentInfo | null;
    if (!student) {
      setVideos([]);
      return;
    }

    const scoped = filterTeacherOwnedRecords(all, student);
    const filtered = scoped.filter(video =>
      matchesAcademicScope(video, { grade, atram, subject, term, unit }),
    );

    setActiveIndex(current => Math.min(current, Math.max(filtered.length - 1, 0)));
    setVideos(filtered);
    setWatchedVideos(filtered.filter(video => hasCompletedActivity('video', video.id)).map(video => video.id));
  };

  const extractVideoId = (url: string) => {
    const regExp = /^.*(youtu.be\/|v\/|u\/\w\/|embed\/|watch\?v=|\&v=)([^#\&\?]*).*/;
    const match = url.match(regExp);
    return (match && match[2].length === 11) ? match[2] : null;
  };

  const visibleVideos = videos.length > 0 ? videos.slice(activeIndex, activeIndex + 3) : [];
  const unlockedVideoCount = Math.floor(currentGems / GEMS_PER_VIDEO);

  useEffect(() => {
    if (!lockMessage) return;
    const timer = window.setTimeout(() => setLockMessage(''), 2200);
    return () => window.clearTimeout(timer);
  }, [lockMessage]);

  useEffect(() => {
    if (!previewVideoId) return;
    const timer = window.setTimeout(() => setPreviewVideoId(null), 3000);
    return () => window.clearTimeout(timer);
  }, [previewVideoId]);

  const activeVideo = playingVideo
    ? videos.find(video => video.id === playingVideo) || null
    : null;

  useEffect(() => {
    if (!playingVideo) return;

    const handleKeyDown = (event: KeyboardEvent) => {
      if (event.key === 'Escape') setPlayingVideo(null);
    };
    const previousOverflow = document.body.style.overflow;
    document.body.style.overflow = 'hidden';
    window.addEventListener('keydown', handleKeyDown);

    return () => {
      document.body.style.overflow = previousOverflow;
      window.removeEventListener('keydown', handleKeyDown);
    };
  }, [playingVideo]);

  const handleTouchStart = (e: React.TouchEvent) => {
    setTouchStartX(e.touches[0].clientX);
  };

  const handleTouchEnd = (e: React.TouchEvent) => {
    if (touchStartX === null) return;
    const delta = e.changedTouches[0].clientX - touchStartX;
    if (delta > 60) {
      setActiveIndex(prev => (prev > 0 ? prev - 1 : Math.max(videos.length - 3, 0)));
    } else if (delta < -60) {
      setActiveIndex(prev => (prev + 1 < videos.length ? prev + 1 : 0));
    }
    setTouchStartX(null);
  };

  const handleVideoSelect = (video: VideoRecord) => {
    const videoIndex = videos.findIndex(item => item.id === video.id);
    const isUnlocked = videoIndex > -1 && videoIndex < unlockedVideoCount;
    if (!isUnlocked) {
      playLamsaSound('error');
      setLockMessage(`هذا الفيديو مقفول. تحتاج ${GEMS_PER_VIDEO} جواهر لكل فيديو جديد.`);
      return;
    }

    GameAudioEngine.play('portalTransition');
    setPlayingVideo(video.id);
    const reward = rewardVideoComplete(video.id);
    setWatchedVideos(current => current.includes(video.id) ? current : [...current, video.id]);
    setCurrentGems(getGems());
     if (reward.alreadyRewarded) {
       playLamsaSound('click');
     } else {
        GameAudioEngine.playRewardSequence({ gems: reward.gems });
     }
  };

  return (
    <motion.div
      initial={{ opacity: 0, y: 18 }}
      animate={{ opacity: 1, y: 0 }}
      className="rounded-[40px] border border-rose-200/70 bg-gradient-to-br from-rose-50 via-white to-amber-50 p-6 md:p-10 shadow-[0_30px_90px_-20px_rgba(244,63,94,0.35)]"
    >
      <EducationalCardEffects accent="#f43f5e" compact />
      <div className="flex flex-col md:flex-row md:items-end md:justify-between gap-4 mb-8">
        <div>
          <h2 className="text-3xl md:text-4xl font-black text-rose-800">🎬 سينما منارة</h2>
          <p className="text-rose-500 font-medium mt-2">استعرض الفيديوهات كـ كروت تفاعلية ثلاثية الأبعاد</p>
        </div>
        <div className="inline-flex items-center gap-2 rounded-full bg-rose-600 px-4 py-2 text-sm font-black text-white shadow-lg">
          <span>💎</span> الجواهر: {currentGems} | المفتوح: {unlockedVideoCount}
        </div>
      </div>

      {lockMessage && (
        <div className="mb-4 rounded-2xl border border-amber-300 bg-amber-50 px-4 py-3 text-sm font-bold text-amber-700">
          🔒 {lockMessage}
        </div>
      )}

      {videos.length > 0 ? (
        <div className="space-y-5">
          <div
            className="overflow-hidden rounded-[32px] bg-slate-950/95 p-3 md:p-4"
            onMouseEnter={() => setIsAutoPlaying(false)}
            onMouseLeave={() => setIsAutoPlaying(true)}
            onTouchStart={handleTouchStart}
            onTouchEnd={handleTouchEnd}
          >
            <div className="grid gap-4 md:grid-cols-3">
              {visibleVideos.map((video, index) => {
                const vid = extractVideoId(video.url);
                const isMp4 = getVideoSourceType(video.sourceType, video.url) === 'mp4' || isMp4VideoUrl(video.url);
                const isCenter = index === 1;
                const videoIndex = videos.findIndex(item => item.id === video.id);
                const isUnlocked = videoIndex > -1 && videoIndex < unlockedVideoCount;

                const showPreview = previewVideoId === video.id && !playingVideo && isUnlocked;

                return (
                  <motion.div
                    key={video.id}
                    initial={{ opacity: 0, y: 20, rotateY: -10 }}
                    animate={{ opacity: 1, y: 0, rotateY: isCenter ? 0 : -6, scale: isCenter ? 1.03 : 0.96 }}
                    whileHover={{ scale: 1.06, rotateY: 6, y: -8, boxShadow: '0 24px 55px rgba(244,63,94,0.24)' }}
                    transition={{ duration: 0.35 }}
                    onMouseEnter={() => isUnlocked ? setPreviewVideoId(video.id) : setPreviewVideoId(null)}
                    onMouseLeave={() => setPreviewVideoId(null)}
                    className={`relative overflow-hidden rounded-[28px] border bg-rose-50 shadow-2xl ${isCenter ? 'border-amber-300 ring-2 ring-amber-200' : 'border-rose-100'} ${!isUnlocked ? 'opacity-80' : ''}`}
                  >
                    <EducationalCardEffects accent="#fb7185" compact />
                    {vid ? (
                      <div className={`relative aspect-video ${isUnlocked ? 'cursor-pointer' : 'cursor-not-allowed'}`} onClick={() => handleVideoSelect(video)}>
                        {showPreview ? (
                          <iframe
                            className="h-full w-full"
                            src={`https://www.youtube.com/embed/${vid}?autoplay=1&mute=1&controls=0&modestbranding=1&rel=0`}
                            title={video.title}
                            allow="autoplay; encrypted-media"
                          />
                        ) : (
                          <img src={`https://img.youtube.com/vi/${vid}/mqdefault.jpg`} alt={video.title} className="h-full w-full object-cover" />
                        )}
                        <div className="pointer-events-none absolute inset-0 flex items-center justify-center bg-black/35 transition-all">
                          <div className="flex h-16 w-16 items-center justify-center rounded-full bg-white/90 shadow-2xl transition-transform hover:scale-110">
                            <span className="text-3xl">▶️</span>
                          </div>
                        </div>
                        <div className="pointer-events-none absolute left-3 top-3 rounded-full border border-white/40 bg-black/40 px-3 py-1 text-[10px] font-black uppercase tracking-[0.25em] text-white">
                          {isUnlocked ? 'Preview' : 'Locked'}
                        </div>
                        {!isUnlocked && (
                          <div className="pointer-events-none absolute inset-0 flex items-center justify-center bg-black/55">
                            <div className="rounded-full border border-white/25 bg-black/55 px-4 py-2 text-xs font-black tracking-wide text-white">
                              🔒 يحتاج {GEMS_PER_VIDEO} جواهر لكل فيديو
                            </div>
                          </div>
                        )}
                      </div>
                    ) : isMp4 ? (
                      <div className={`relative aspect-video bg-black ${isUnlocked ? 'cursor-pointer' : 'cursor-not-allowed'}`} onClick={() => handleVideoSelect(video)}>
                        <video src={video.url} className="h-full w-full object-cover" muted preload="metadata" />
                        <div className="pointer-events-none absolute inset-0 flex items-center justify-center bg-black/35">
                          <div className="flex h-16 w-16 items-center justify-center rounded-full bg-white/90 shadow-2xl">
                            <span className="text-3xl">▶️</span>
                          </div>
                        </div>
                        <div className="pointer-events-none absolute left-3 top-3 rounded-full border border-white/40 bg-black/40 px-3 py-1 text-[10px] font-black uppercase tracking-[0.25em] text-white">
                          {isUnlocked ? 'MP4' : 'Locked'}
                        </div>
                        {!isUnlocked && (
                          <div className="pointer-events-none absolute inset-0 flex items-center justify-center bg-black/55">
                            <div className="rounded-full border border-white/25 bg-black/55 px-4 py-2 text-xs font-black tracking-wide text-white">
                              🔒 يحتاج {GEMS_PER_VIDEO} جواهر لكل فيديو
                            </div>
                          </div>
                        )}
                      </div>
                    ) : (
                      <div className="flex aspect-video items-center justify-center bg-rose-100">
                        <span className="text-5xl">🎬</span>
                      </div>
                    )}

                    <div className="p-5">
                      {watchedVideos.includes(video.id) && (
                        <div className="mb-3 inline-flex items-center gap-1 rounded-full bg-emerald-100 px-3 py-1 text-xs font-black text-emerald-700">
                          ✅ تمت المشاهدة +20 XP
                        </div>
                      )}
                      <h3 className="text-lg font-black text-rose-900">{video.title}</h3>
                      <p className="mt-2 text-sm font-medium text-rose-600 line-clamp-2">{video.description}</p>
                      <div className="mt-3 flex flex-wrap gap-2">
                        {video.grade && <span className="rounded-lg bg-orange-100 px-2 py-1 text-xs font-bold text-orange-700">📚 {video.grade}</span>}
                        {video.subject && <span className="rounded-lg bg-amber-100 px-2 py-1 text-xs font-bold text-amber-700">📖 {video.subject}</span>}
                      </div>
                      <div className="mt-3 flex items-center gap-2 text-xs font-bold text-rose-400">
                        <span>👨‍🏫</span>
                        <span>المعلم: {video.teacherName}</span>
                      </div>
                    </div>
                  </motion.div>
                );
              })}
            </div>
          </div>

          <div className="flex items-center justify-center gap-3">
            <button
              onClick={() => {
                setIsAutoPlaying(false);
                setActiveIndex(prev => (prev > 0 ? prev - 1 : Math.max(videos.length - 3, 0)));
              }}
              className="rounded-full border border-rose-300 bg-white px-4 py-2 text-sm font-black text-rose-700 shadow-md"
            >
              ⬅ السابق
            </button>
            <div className="text-sm font-bold text-rose-600">المعروض {Math.min(activeIndex + 1, videos.length)} / {videos.length}</div>
            <button
              onClick={() => setActiveIndex(prev => (prev + 1 < videos.length ? prev + 1 : 0))}
              className="rounded-full border border-rose-300 bg-white px-4 py-2 text-sm font-black text-rose-700 shadow-md"
            >
              التالي ➡
            </button>
          </div>
        </div>
      ) : (
        <div className="rounded-[40px] border-2 border-dashed border-rose-300 bg-rose-50 p-16 text-center">
          <div className="mb-6 text-7xl">🎬</div>
          <h3 className="mb-3 text-2xl font-black text-rose-800">لا توجد فيديوهات مشابهة</h3>
          <p className="font-bold text-rose-600">راجِ المعلم بإضافة فيديوهات جديدة للمادة والمستوى الذي تدرسه ✍️</p>
        </div>
      )}

      <AnimatePresence>
        {activeVideo && (extractVideoId(activeVideo.url) || isMp4VideoUrl(activeVideo.url)) && (
          <motion.div
            key="cinema-video-modal"
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            exit={{ opacity: 0 }}
            className="fixed inset-0 z-[100] flex items-center justify-center bg-slate-950/85 p-4 backdrop-blur-md md:p-8"
            role="dialog"
            aria-modal="true"
            aria-label={`تشغيل فيديو ${activeVideo.title}`}
            onMouseDown={(event) => {
              if (event.target === event.currentTarget) setPlayingVideo(null);
            }}
          >
            <motion.div
              initial={{ opacity: 0, y: 24, scale: 0.94 }}
              animate={{ opacity: 1, y: 0, scale: 1 }}
              exit={{ opacity: 0, y: 24, scale: 0.94 }}
              transition={{ type: 'spring', stiffness: 260, damping: 24 }}
              className="relative w-full max-w-5xl overflow-hidden rounded-[28px] border border-white/20 bg-black shadow-[0_30px_100px_rgba(0,0,0,0.65)]"
            >
              <div className="aspect-video w-full">
                {getVideoSourceType(activeVideo.sourceType, activeVideo.url) === 'mp4' || isMp4VideoUrl(activeVideo.url) ? (
                  <video className="h-full w-full" src={activeVideo.url} title={activeVideo.title} controls autoPlay playsInline />
                ) : (
                  <iframe
                    className="h-full w-full"
                    src={`https://www.youtube.com/embed/${extractVideoId(activeVideo.url)}?autoplay=1&rel=0`}
                    title={activeVideo.title}
                    allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture"
                    allowFullScreen
                  />
                )}
              </div>
              <div className="flex items-center justify-between gap-3 bg-slate-950 px-4 py-3 text-white md:px-6">
                <p className="truncate text-sm font-black md:text-base">{activeVideo.title}</p>
                <button
                  type="button"
                  onClick={() => setPlayingVideo(null)}
                  className="shrink-0 rounded-xl bg-white/15 px-4 py-2 text-sm font-black text-white transition hover:bg-rose-500 focus:outline-none focus:ring-2 focus:ring-rose-300"
                >
                  ✕ إغلاق الفيديو
                </button>
              </div>
            </motion.div>
          </motion.div>
        )}
      </AnimatePresence>
    </motion.div>
  );
};

export default StudentVideos;
