import React, { useEffect, useState } from 'react';
import { motion, AnimatePresence } from 'framer-motion';
import TouchCarousel from './TouchCarousel';
import VideoThumbnail from './VideoThumbnail';
import {
  getVideoEmbedUrl,
  getVideoSourceType,
  isMp4VideoUrl,
  isSafeVideoUrl,
  VideoSourceType,
} from '../utils/video';

export interface CarouselVideo {
  id: string;
  url: string;
  sourceType?: VideoSourceType;
  title?: string;
  description?: string;
  teacherName?: string;
  createdAt?: string;
}

interface VideoCarouselProps {
  videos: CarouselVideo[];
  activeIndex: number;
  onActiveIndexChange: (index: number) => void;
  title: string;
  subtitle?: string;
  accent?: 'rose' | 'amber';
  isLocked?: (video: CarouselVideo, index: number) => boolean;
  onPlay?: (video: CarouselVideo, index: number) => boolean | void;
  watchedIds?: string[];
  emptyMessage?: string;
  compact?: boolean;
}

export const VideoMedia: React.FC<{
  video: CarouselVideo;
  autoPlay?: boolean;
  className?: string;
}> = ({ video, autoPlay = false, className = 'h-full w-full' }) => {
  const sourceType = getVideoSourceType(video.sourceType, video.url);
  if (!isSafeVideoUrl(video.url)) {
    return <div className="flex h-full items-center justify-center bg-slate-900 text-slate-400">رابط فيديو غير صالح</div>;
  }
  if (sourceType === 'mp4' || isMp4VideoUrl(video.url)) {
    return (
      <video
        className={className}
        src={video.url}
        title={video.title || 'فيديو'}
        controls
        autoPlay={autoPlay}
        playsInline
        preload="metadata"
      />
    );
  }
  const embedUrl = getVideoEmbedUrl(video.url);
  return embedUrl ? (
    <iframe
      className={className}
      src={embedUrl}
      title={video.title || 'فيديو'}
      allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture"
      allowFullScreen
    />
  ) : (
    <div className="flex h-full items-center justify-center bg-slate-900 text-slate-400">تعذر تجهيز رابط الفيديو</div>
  );
};

const VideoCarousel: React.FC<VideoCarouselProps> = ({
  videos,
  activeIndex,
  onActiveIndexChange,
  title,
  subtitle = 'اضغط على بطاقة لتشغيل الفيديو وتكبيره',
  accent = 'rose',
  isLocked,
  onPlay,
  watchedIds = [],
  emptyMessage = 'لا توجد فيديوهات متاحة',
  compact = false,
}) => {
  const [playingVideo, setPlayingVideo] = useState<CarouselVideo | null>(null);
  const safeIndex = Math.min(Math.max(activeIndex, 0), Math.max(videos.length - 1, 0));
  const activeVideo = videos[safeIndex];
  const locked = (video: CarouselVideo, index: number) => Boolean(isLocked?.(video, index));

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

  if (videos.length === 0) {
    return (
      <div className={`rounded-[28px] border-2 border-dashed p-10 text-center ${
        accent === 'amber' ? 'border-amber-300 bg-amber-50 text-amber-700' : 'border-rose-300 bg-rose-50 text-rose-700'
      }`}>
        <div className="mb-3 text-5xl">🎬</div>
        <p className="font-black">{emptyMessage}</p>
      </div>
    );
  }

  const palette = accent === 'amber'
    ? { border: 'border-amber-300', ring: 'ring-amber-200', panel: 'bg-amber-400/15', text: 'text-amber-200', card: 'bg-amber-400/20' }
    : { border: 'border-rose-300', ring: 'ring-rose-200', panel: 'bg-rose-600', text: 'text-rose-700', card: 'bg-rose-50' };

  return (
    <>
      <div className={`space-y-4 rounded-[28px] ${compact ? 'p-1' : 'p-1'}`}>
        <div className="flex flex-wrap items-end justify-between gap-3">
          <div>
            <h3 className={`text-xl font-black ${accent === 'amber' ? 'text-white' : 'text-rose-800'}`}>{title}</h3>
            <p className={`mt-1 text-xs font-bold ${accent === 'amber' ? 'text-slate-400' : 'text-rose-500'}`}>{subtitle}</p>
          </div>
          <span className={`rounded-full px-3 py-1 text-xs font-black ${accent === 'amber' ? 'bg-amber-400/15 text-amber-200' : 'bg-rose-600 text-white'}`}>
            {safeIndex + 1} / {videos.length}
          </span>
        </div>

        <div className={`overflow-hidden rounded-[28px] ${accent === 'amber' ? 'bg-slate-950/60 p-3' : 'bg-slate-950/95 p-3'}`}>
          <TouchCarousel
            label={title}
            nested
            activeIndex={safeIndex}
            onActiveIndexChange={onActiveIndexChange}
            itemCount={videos.length}
            trackClassName="sm:grid sm:grid-cols-2 lg:grid-cols-3"
          >
            {videos.map((video, index) => {
              const isSelected = index === safeIndex;
              const videoLocked = locked(video, index);
              return (
                <button
                  key={video.id}
                  type="button"
                  disabled={videoLocked}
                  onClick={() => {
                    if (videoLocked) return;
                    onActiveIndexChange(index);
                    const result = onPlay?.(video, index);
                    if (result !== false) setPlayingVideo(video);
                  }}
                  className={`group relative min-h-[140px] overflow-hidden rounded-[24px] border-2 p-4 text-right transition-all duration-300 ${
                    isSelected
                      ? `${palette.border} ${palette.card} shadow-xl ring-2 ${palette.ring}`
                      : accent === 'amber'
                        ? 'border-white/10 bg-white/[0.06] hover:border-amber-200/60 hover:bg-white/[0.11]'
                        : 'border-rose-100 bg-rose-50 hover:-translate-y-1 hover:border-rose-300'
                  } ${videoLocked ? 'cursor-not-allowed opacity-70' : 'cursor-pointer'}`}
                >
                  <div className="relative mb-4 aspect-video w-full overflow-hidden rounded-[20px] border border-white/15 bg-slate-950 shadow-lg">
                    <VideoThumbnail
                      url={video.url}
                      sourceType={video.sourceType}
                      alt=""
                      className="transition duration-500 group-hover:scale-105"
                    />
                    <span className="pointer-events-none absolute inset-0 flex items-center justify-center bg-slate-950/20">
                      <span className="flex h-14 w-14 items-center justify-center rounded-full bg-white/95 text-2xl text-slate-950 shadow-2xl transition group-hover:scale-110">
                        ▶
                      </span>
                    </span>
                    <span className={`absolute right-3 top-3 rounded-full px-3 py-1.5 text-[11px] font-black shadow ${
                      videoLocked ? 'bg-slate-950/80 text-slate-200' : isSelected ? palette.panel + ' text-white' : 'bg-white/90 text-slate-800'
                    }`}>
                      {videoLocked ? '🔒 مقفول' : isSelected ? '▶ يعمل الآن' : `فيديو ${index + 1}`}
                    </span>
                  </div>
                  <p className={`truncate text-base font-black sm:text-lg ${accent === 'amber' ? 'text-white' : 'text-rose-900'}`}>
                    {video.title || `فيديو ${index + 1}`}
                  </p>
                  {watchedIds.includes(video.id) && <p className="mt-1 text-[11px] font-black text-emerald-500">✅ تمت المشاهدة</p>}
                </button>
              );
            })}
          </TouchCarousel>
        </div>

        <div className="flex items-center justify-center gap-3">
          <button type="button" onClick={() => onActiveIndexChange(safeIndex > 0 ? safeIndex - 1 : videos.length - 1)} className={`rounded-full border bg-white px-4 py-2 text-sm font-black shadow-md ${accent === 'amber' ? 'border-amber-300 text-amber-700' : 'border-rose-300 text-rose-700'}`}>⬅ السابق</button>
          <button type="button" onClick={() => activeVideo && !locked(activeVideo, safeIndex) && setPlayingVideo(activeVideo)} className={`rounded-full px-4 py-2 text-sm font-black text-white shadow-md ${accent === 'amber' ? 'bg-amber-500' : 'bg-rose-600'}`}>▶ تشغيل وتكبير</button>
          <button type="button" onClick={() => onActiveIndexChange(safeIndex + 1 < videos.length ? safeIndex + 1 : 0)} className={`rounded-full border bg-white px-4 py-2 text-sm font-black shadow-md ${accent === 'amber' ? 'border-amber-300 text-amber-700' : 'border-rose-300 text-rose-700'}`}>التالي ➡</button>
        </div>
      </div>

      <AnimatePresence>
        {playingVideo && (
          <motion.div
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            exit={{ opacity: 0 }}
            className="fixed inset-0 z-[100] flex items-center justify-center bg-slate-950/85 p-3 backdrop-blur-md sm:p-6"
            role="dialog"
            aria-modal="true"
            aria-label={`تشغيل فيديو ${playingVideo.title || ''}`}
            onMouseDown={(event) => {
              if (event.target === event.currentTarget) setPlayingVideo(null);
            }}
          >
            <motion.div initial={{ opacity: 0, y: 24, scale: 0.94 }} animate={{ opacity: 1, y: 0, scale: 1 }} className="relative w-full max-w-5xl overflow-hidden rounded-[26px] border border-white/20 bg-black shadow-2xl">
              <button
                type="button"
                onClick={() => setPlayingVideo(null)}
                aria-label="إغلاق الفيديو"
                className="absolute right-3 top-3 z-20 flex h-12 w-12 items-center justify-center rounded-full border-2 border-white/70 bg-slate-950/85 text-3xl font-black leading-none text-white shadow-2xl transition hover:scale-105 hover:bg-rose-600 focus:outline-none focus:ring-4 focus:ring-rose-300"
              >
                <span aria-hidden="true">×</span>
              </button>
              <div className="aspect-video w-full">
                <VideoMedia video={playingVideo} autoPlay />
              </div>
              <div className="bg-slate-950 px-4 py-3 text-white">
                <p className="truncate text-sm font-black">{playingVideo.title || 'فيديو'}</p>
              </div>
            </motion.div>
          </motion.div>
        )}
      </AnimatePresence>
    </>
  );
};

export default VideoCarousel;