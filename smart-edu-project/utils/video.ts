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

export const getVideoSourceType = (
  sourceType?: VideoSourceType,
  url?: string | null,
): VideoSourceType => sourceType || (isMp4VideoUrl(url) ? 'mp4' : 'embed');

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
      .filter(video => video.url)
    : [];
  const legacyUrl = typeof lesson.explanationVideoUrl === 'string'
    ? lesson.explanationVideoUrl.trim()
    : '';

  if (legacyUrl && !videos.some(video => video.url === legacyUrl)) {
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