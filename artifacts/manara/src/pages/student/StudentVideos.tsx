import React, { useEffect, useState } from 'react';
import { STORAGE_KEYS } from '../../constants';
import { playLamsaSound } from '../../utils/sounds';
import { filterTeacherOwnedRecords, matchesAcademicScope } from '../../utils/scope';
import { StudentInfo } from '../../types';
import { getGems, hasCompletedActivity, rewardVideoComplete } from '../../utils/gamification';
import { GameAudioEngine } from '../../utils/gameAudioEngine';
import EducationalCardEffects from '../../components/effects/EducationalCardEffects';
import VideoCarousel, { CarouselVideo } from '../../components/VideoCarousel';
import { readActiveSession, readStorageArray } from '../../utils/storage';
import { isSafeVideoUrl } from '../../utils/video';

const GEMS_PER_VIDEO = 2;

interface VideoRecord extends CarouselVideo {
  grade: string;
  atram: string;
  subject: string;
  term: string;
  unit: string;
  teacherName: string;
  updatedAt?: string;
  createdBy?: string;
  teacherId?: string;
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
  const [watchedVideos, setWatchedVideos] = useState<string[]>([]);
  const [activeIndex, setActiveIndex] = useState(0);
  const [currentGems, setCurrentGems] = useState(0);
  const [lockMessage, setLockMessage] = useState('');

  useEffect(() => {
    const loadVideos = () => {
      try {
        const all = readStorageArray<VideoRecord>(STORAGE_KEYS.VIDEOS);
        const student = readActiveSession<StudentInfo>(STORAGE_KEYS.ACTIVE_STUDENT);
        if (!student) {
          setVideos([]);
          setActiveIndex(0);
          return;
        }
        const teacherVideos = filterTeacherOwnedRecords(all, student);
        const generalVideos = all.filter(video => {
          const owner = (video.createdBy || video.teacherId || '').toString().trim().toLowerCase();
          return !owner || owner === 'admin';
        });
        const scoped = Array.from(
          new Map([...teacherVideos, ...generalVideos].map(video => [video.id, video])).values(),
        );
        const filtered = scoped.filter(video =>
          isSafeVideoUrl(video.url) && matchesAcademicScope(video, { grade, atram, subject, term, unit }),
        );
        setActiveIndex(current => Math.min(current, Math.max(filtered.length - 1, 0)));
        setVideos(current => {
          const currentSignature = current.map(video => `${video.id}:${video.url}:${video.updatedAt || video.createdAt}`).join('|');
          const nextSignature = filtered.map(video => `${video.id}:${video.url}:${video.updatedAt || video.createdAt}`).join('|');
          return currentSignature === nextSignature ? current : filtered;
        });
        setWatchedVideos(filtered.filter(video => hasCompletedActivity('video', video.id)).map(video => video.id));
      } catch {
        setVideos([]);
        setActiveIndex(0);
      }
    };

    loadVideos();
    const refreshTimer = window.setInterval(loadVideos, 5000);
    return () => window.clearInterval(refreshTimer);
  }, [grade, atram, subject, term, unit]);

  useEffect(() => {
    setCurrentGems(getGems());
    const timer = window.setInterval(() => setCurrentGems(getGems()), 5000);
    return () => window.clearInterval(timer);
  }, []);

  useEffect(() => {
    if (!lockMessage) return;
    const timer = window.setTimeout(() => setLockMessage(''), 2200);
    return () => window.clearTimeout(timer);
  }, [lockMessage]);

  const unlockedVideoCount = Math.floor(currentGems / GEMS_PER_VIDEO);
  const handlePlay = (video: CarouselVideo, index: number) => {
    if (index >= unlockedVideoCount) {
      playLamsaSound('error');
      setLockMessage(`هذا الفيديو مقفول. تحتاج ${GEMS_PER_VIDEO} جواهر لكل فيديو جديد.`);
      return false;
    }
    GameAudioEngine.play('portalTransition');
    const reward = rewardVideoComplete(video.id);
    setWatchedVideos(current => current.includes(video.id) ? current : [...current, video.id]);
    setCurrentGems(getGems());
    if (reward.alreadyRewarded) playLamsaSound('click');
    else GameAudioEngine.playRewardSequence({ gems: reward.gems });
    return true;
  };

  return (
    <div className="rounded-[28px] border border-rose-200/70 bg-gradient-to-br from-rose-50 via-white to-amber-50 p-4 shadow-[0_30px_90px_-20px_rgba(244,63,94,0.35)] sm:rounded-[40px] sm:p-6 md:p-10">
      <EducationalCardEffects accent="#f43f5e" compact />
      <div className="mb-8 flex flex-col gap-4 md:flex-row md:items-end md:justify-between">
        <div>
          <h2 className="text-2xl font-black text-rose-800 sm:text-3xl md:text-4xl">🎬 سينما منارة</h2>
          <p className="mt-2 font-medium text-rose-500">فيديوهات تعليمية تفاعلية مرتبطة بمسارك الأكاديمي</p>
        </div>
        <div className="inline-flex max-w-full items-center gap-2 self-start rounded-full bg-rose-600 px-3 py-2 text-xs font-black text-white shadow-lg sm:px-4 sm:text-sm md:self-auto">
          <span>💎</span> الجواهر: {currentGems} | المفتوح: {unlockedVideoCount}
        </div>
      </div>

      {lockMessage && (
        <div className="mb-4 rounded-2xl border border-amber-300 bg-amber-50 px-4 py-3 text-sm font-bold text-amber-700">
          🔒 {lockMessage}
        </div>
      )}

      <VideoCarousel
        videos={videos}
        activeIndex={activeIndex}
        onActiveIndexChange={setActiveIndex}
        title="🎞️ فيديوهات سينما منارة"
        subtitle="اختر فيديو لفتحه وتشغيله بكامل الشاشة"
        isLocked={(_, index) => index >= unlockedVideoCount}
        onPlay={handlePlay}
        watchedIds={watchedVideos}
        emptyMessage="لا توجد فيديوهات مشابهة لمسارك الأكاديمي"
      />
    </div>
  );
};

export default StudentVideos;