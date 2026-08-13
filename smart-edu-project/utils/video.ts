export type VideoSourceType = 'embed' | 'mp4';

export interface LessonVideoEntry {
  id: string;
  url: string;
  sourceType: VideoSourceType;
  title?: string;
  createdAt?: string;
}

export const isMp4VideoUrl = (value?: string | null): boolean => {
  const url = (value || '').trim().toLowerCase();
  return url.startsWith('/uploads/videos/') || url.includes('.mp4');
};

export const isSafeVideoUrl = (value?: string | null): boolean => {
  const raw = (value || '').trim();
  if (!raw || raw.startsWith('javascript:') || raw.startsWith('data:') || raw.startsWith('blob:')) {
    return false;
  }
  if (raw.startsWith('/uploads/videos/')) return true;
  try {
    const parsed = new URL(raw, window.location.origin);
    return parsed.protocol === 'https:' || (parsed.protocol === 'http:' && parsed.origin === window.location.origin);
  } catch {
    return false;
  }
};

export const getVideoSourceType = (
  sourceType?: VideoSourceType,
  url?: string | null,
): VideoSourceType => sourceType || (isMp4VideoUrl(url) ? 'mp4' : 'embed');

export const getVideoThumbnailUrl = (value?: string | null): string | null => {
  const raw = (value || '').trim();
  const match = raw.match(
    /(?:youtu\.be\/|youtube\.com\/(?:watch\?v=|embed\/|shorts\/|live\/))([^?&#/]+)/i,
  );
  return match?.[1] ? `https://img.youtube.com/vi/${match[1]}/hqdefault.jpg` : null;
};

export const getVideoEmbedUrl = (value?: string | null): string => {
  const raw = (value || '').trim();
  if (!raw || !isSafeVideoUrl(raw)) return '';

  try {
    const parsed = new URL(raw, window.location.origin);
    const host = parsed.hostname.toLowerCase().replace(/^www\./, '');

    if (host === 'youtu.be') {
      const id = parsed.pathname.split('/').filter(Boolean)[0];
      return id ? `https://www.youtube.com/embed/${encodeURIComponent(id)}?autoplay=1&rel=0` : raw;
    }
    if (host.endsWith('youtube.com')) {
      const id = parsed.searchParams.get('v')
        || parsed.pathname.match(/\/(?:embed|shorts|live)\/([^/?]+)/)?.[1];
      return id
        ? `https://www.youtube.com/embed/${encodeURIComponent(id)}?autoplay=1&rel=0`
        : raw;
    }
    if (host === 'vimeo.com' || host.endsWith('.vimeo.com')) {
      const id = parsed.pathname.match(/\/(?:video\/)?(\d+)/)?.[1];
      return id ? `https://player.vimeo.com/video/${id}?autoplay=1` : raw;
    }
  } catch {
    return '';
  }

  return raw;
};

export const getLessonExplanationVideos = (lesson: {
  explanationVideos?: LessonVideoEntry[];
  explanationVideoUrl?: string;
  explanationVideoType?: VideoSourceType;
} | null | undefined): LessonVideoEntry[] => {
  if (!lesson) return [];

  const videos = Array.isArray(lesson.explanationVideos)
    ? lesson.explanationVideos
      .filter((video): video is LessonVideoEntry => Boolean(video && typeof video === 'object'))
      .map((video, index) => ({
        ...video,
        id: typeof video.id === 'string' && video.id.trim()
          ? video.id
          : `lesson-video-${index}`,
        url: typeof video.url === 'string' ? video.url.trim() : '',
        sourceType: getVideoSourceType(
          video.sourceType === 'mp4' || video.sourceType === 'embed' ? video.sourceType : undefined,
          typeof video.url === 'string' ? video.url : '',
        ),
        title: typeof video.title === 'string' ? video.title.trim() : '',
      }))
      .filter(video => video.url && isSafeVideoUrl(video.url))
    : [];
  const legacyUrl = typeof lesson.explanationVideoUrl === 'string'
    ? lesson.explanationVideoUrl.trim()
    : '';

  if (legacyUrl && isSafeVideoUrl(legacyUrl) && !videos.some(video => video.url === legacyUrl)) {
    videos.unshift({
      id: `legacy-${encodeURIComponent(legacyUrl)}`,
      url: legacyUrl,
      sourceType: getVideoSourceType(
        lesson.explanationVideoType === 'mp4' || lesson.explanationVideoType === 'embed'
          ? lesson.explanationVideoType
          : undefined,
        legacyUrl,
      ),
      title: 'فيديو الشرح',
    });
  }

  return videos.map((video, index) => ({
    ...video,
    id: video.id || `lesson-video-${index}-${encodeURIComponent(video.url)}`,
    sourceType: getVideoSourceType(video.sourceType, video.url),
    title: video.title || `فيديو الشرح ${index + 1}`,
  }));
};

export const uploadMp4Video = async (file: File): Promise<{ url: string; fileName: string; size: number }> => {
  const response = await fetch('/api/media/upload', {
    method: 'POST',
    headers: {
      'Content-Type': 'video/mp4',
      'X-File-Name': file.name,
    },
    body: file,
  });
  const payload = await response.json().catch(() => ({}));
  if (!response.ok) {
    throw new Error(payload?.error || 'فشل رفع ملف الفيديو');
  }
  return payload;
};

export const deleteUploadedVideo = async (url?: string | null): Promise<void> => {
  if (!isMp4VideoUrl(url)) return;
  await fetch('/api/media/delete', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ url }),
  });
};