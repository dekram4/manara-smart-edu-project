export type VideoSourceType = 'embed' | 'mp4';

export const isMp4VideoUrl = (value?: string | null): boolean => {
  const url = (value || '').trim().toLowerCase();
  return url.startsWith('/uploads/videos/') || url.includes('.mp4');
};

export const getVideoSourceType = (
  sourceType?: VideoSourceType,
  url?: string | null,
): VideoSourceType => sourceType || (isMp4VideoUrl(url) ? 'mp4' : 'embed');

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