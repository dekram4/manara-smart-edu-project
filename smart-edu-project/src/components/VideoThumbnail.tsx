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
  const [mp4Poster, setMp4Poster] = useState<string | null>(null);

  useEffect(() => {
    if (source !== 'mp4' && !isMp4VideoUrl(url)) return;
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
  }, [source, url]);

  if (youtubeThumbnail) {
    return <img src={youtubeThumbnail} alt={alt} loading="lazy" className={`h-full w-full object-cover ${className}`} />;
  }

  if (source === 'mp4' || isMp4VideoUrl(url)) {
    return mp4Poster ? (
      <img src={mp4Poster} alt={alt} className={`h-full w-full object-cover ${className}`} />
    ) : (
      <video
        ref={videoRef}
        src={url}
        className={`h-full w-full object-cover ${className}`}
        muted
        playsInline
        preload="metadata"
        aria-label={alt}
      />
    );
  }

  return (
    <div className={`flex h-full w-full items-center justify-center bg-gradient-to-br from-sky-400 via-indigo-500 to-violet-700 text-6xl ${className}`}>
      🔗
    </div>
  );
};

export default VideoThumbnail;