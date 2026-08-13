import React, { useEffect, useRef, useState } from 'react';
import { getVideoSourceType, getVideoThumbnailUrl, isMp4VideoUrl } from '../../utils/video';
import { VideoSourceType } from '../../utils/video';

interface VideoThumbnailProps {
  url: string;
  sourceType?: VideoSourceType;
  alt?: string;
  className?: string;
}

const VideoThumbnail: React.FC<VideoThumbnailProps> = ({
  url,
  sourceType,
  alt = '',
  className = '',
}) => {
  const source = getVideoSourceType(sourceType, url);
  const youtubeThumbnail = getVideoThumbnailUrl(url);
  const videoRef = useRef<HTMLVideoElement | null>(null);
  const touchPreviewTimerRef = useRef<number | null>(null);
  const [mp4Poster, setMp4Poster] = useState<string | null>(null);
  const [isPreviewing, setIsPreviewing] = useState(false);
  const isMp4 = source === 'mp4' || isMp4VideoUrl(url);

  const getPreviewEmbedUrl = (value: string): string => {
    const embedUrl = getVideoEmbedUrl(value);
    if (!embedUrl) return '';
    try {
      const parsed = new URL(embedUrl, window.location.origin);
      parsed.searchParams.set('autoplay', '1');
      parsed.searchParams.set('mute', '1');
      parsed.searchParams.set('muted', '1');
      parsed.searchParams.set('controls', '0');
      parsed.searchParams.set('playsinline', '1');
      parsed.searchParams.set('rel', '0');
      return parsed.toString();
    } catch {
      return embedUrl;
    }
  };

  const previewEmbedUrl = !isMp4 ? getPreviewEmbedUrl(url) : '';

  const startPreview = () => {
    if (!isMp4 && !previewEmbedUrl) return;
    if (touchPreviewTimerRef.current !== null) {
      window.clearTimeout(touchPreviewTimerRef.current);
      touchPreviewTimerRef.current = null;
    }
    setIsPreviewing(true);
  };

  const stopPreview = () => {
    if (touchPreviewTimerRef.current !== null) {
      window.clearTimeout(touchPreviewTimerRef.current);
      touchPreviewTimerRef.current = null;
    }
    setIsPreviewing(false);
    videoRef.current?.pause();
  };

  const handleTouchPreview = () => {
    startPreview();
    touchPreviewTimerRef.current = window.setTimeout(() => {
      setIsPreviewing(false);
      touchPreviewTimerRef.current = null;
    }, 2800);
  };

  useEffect(() => {
    if (!isMp4) return;
    const video = videoRef.current;
    if (!video) return;
    let cancelled = false;

    const captureFrame = () => {
      if (cancelled || !video.videoWidth || !video.videoHeight) return;
      try {
        const canvas = document.createElement('canvas');
        canvas.width = video.videoWidth;
        canvas.height = video.videoHeight;
        const context = canvas.getContext('2d');
        if (!context) return;
        context.drawImage(video, 0, 0, canvas.width, canvas.height);
        setMp4Poster(canvas.toDataURL('image/jpeg', 0.82));
      } catch {
        // Some remote storage providers do not allow canvas extraction.
        // The visible MP4 element remains the graceful fallback.
      }
    };

    const seekToPreview = () => {
      try {
        video.currentTime = Number.isFinite(video.duration)
          ? Math.min(0.2, Math.max(0, video.duration - 0.05))
          : 0.2;
      } catch {
        // Keep the video frame fallback.
      }
    };

    video.addEventListener('loadedmetadata', seekToPreview);
    video.addEventListener('seeked', captureFrame, { once: true });
    video.load();
    return () => {
      cancelled = true;
      video.removeEventListener('loadedmetadata', seekToPreview);
      video.removeEventListener('seeked', captureFrame);
    };
  }, [isMp4, url]);

  useEffect(() => () => {
    if (touchPreviewTimerRef.current !== null) {
      window.clearTimeout(touchPreviewTimerRef.current);
    }
  }, []);

  let media: React.ReactNode;
  if (isMp4) {
    media = (
      <video
        ref={videoRef}
        src={url}
        poster={mp4Poster || undefined}
        className={`h-full w-full object-cover ${className}`}
        muted
        loop
        playsInline
        autoPlay={isPreviewing}
        preload="metadata"
        aria-label={alt}
      />
    );
  } else if (isPreviewing && previewEmbedUrl) {
    media = (
      <iframe
        key={previewEmbedUrl}
        className={`pointer-events-none h-full w-full ${className}`}
        src={previewEmbedUrl}
        title={alt || 'معاينة الفيديو'}
        allow="autoplay; encrypted-media; picture-in-picture"
        aria-label={alt || 'معاينة الفيديو'}
      />
    );
  } else if (youtubeThumbnail) {
    media = <img src={youtubeThumbnail} alt={alt} loading="lazy" className={`h-full w-full object-cover ${className}`} />;
  } else {
    media = (
      <div className={`flex h-full w-full items-center justify-center bg-gradient-to-br from-sky-400 via-indigo-500 to-violet-700 text-6xl ${className}`}>
        🔗
      </div>
    );
  }

  return (
    <div
      className="relative h-full w-full"
      onMouseEnter={startPreview}
      onMouseLeave={stopPreview}
      onTouchStart={handleTouchPreview}
      onTouchCancel={stopPreview}
      onTouchEnd={() => {
        if (isMp4) return;
        touchPreviewTimerRef.current = window.setTimeout(stopPreview, 600);
      }}
    >
      {media}
      {isPreviewing && (
        <span className="pointer-events-none absolute bottom-2 left-2 rounded-full bg-slate-950/75 px-2 py-1 text-[10px] font-black text-white">
          ▶ معاينة
        </span>
      )}
    </div>
  );
};

export default VideoThumbnail;