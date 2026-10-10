export type VideoSourceType = 'embed' | 'mp4';

export interface Mp4UploadResult {
  url: string;
  fileName: string;
  size: number;
  storage?: 'supabase' | 'local';
  warning?: string;
}

export interface LessonVideoEntry {
  id: string;
  url: string;
  sourceType: VideoSourceType;
  title?: string;
  createdAt?: string;
}

export const establishTeacherMediaSession = async (
  username: string,
  password: string,
): Promise<void> => {
  const response = await fetch('/api/auth/teacher/session', {
    method: 'POST',
    credentials: 'same-origin',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ username, password }),
  });
  const payload = await response.json().catch(() => ({}));
  if (!response.ok) {
    throw new Error(payload?.error || 'تعذر تأكيد جلسة رفع الفيديو للمعلم');
  }
};

const BLOCKED_SCHEME = /^(?:javascript|data|vbscript|blob|file):/i;

/**
 * رابطُ فيديو آمنٌ مُحلَّلاً — أو `null`.
 *
 * يُقبل نوعان فقط:
 *   • مسارٌ محليٌّ يبدأ بـ `/` — لا `//` ولا `/\` (فالمتصفّح يقرؤهما رابطاً لموقعٍ
 *     آخر)، ويبقى بعد التحليل على أصل المنصّة نفسه؛
 *   • رابطٌ مطلقٌ بـ `https:`، أو `http:` على أصل المنصّة نفسه.
 * وكلُّ ما سواهما مرفوض — ومنه `javascript:` و`data:` و`vbscript:` و`blob:` بأيّ
 * حالةِ أحرف، وبمحارف تحكّمٍ قبلها أو داخلها، وأيُّ رابطٍ نسبيٍّ آخر.
 */
const parseSafeVideoUrl = (value?: string | null): URL | null => {
  const raw = (value || '').trim();
  // محارفُ التحكّم يُسقطها المتصفّح من الرابط فتُخفي البروتوكول (`java\tscript:`)
  // — ولا مكان لها في رابط فيديو.
  if (!raw || /[\u0000-\u001f\u007f]/.test(raw) || BLOCKED_SCHEME.test(raw)) return null;
  const origin = window.location.origin;
  try {
    if (raw.startsWith('/')) {
      if (raw.startsWith('//') || raw.startsWith('/\\')) return null;
      const parsed = new URL(raw, origin);
      return parsed.origin === origin ? parsed : null;
    }
    const parsed = new URL(raw);
    if (parsed.protocol === 'https:') return parsed;
    if (parsed.protocol === 'http:' && parsed.origin === origin) return parsed;
    return null;
  } catch {
    return null;
  }
};

export const isSafeVideoUrl = (value?: string | null): boolean => parseSafeVideoUrl(value) !== null;

/** البروتوكولاتُ الوحيدةُ التي يصل بها رابطٌ إلى مكوّن عرض. */
const DISPLAY_PROTOCOLS: ReadonlySet<string> = new Set(['https:', 'http:']);

/**
 * رابطٌ مطلقٌ آمنٌ لما يُمرَّر إلى مكوّن عرض — أو `''`.
 *
 * يُعاد الرابطُ المحلَّلُ نفسه (`href`) لا النصُّ الوارد، وبروتوكولُه http/https
 * حصراً؛ والمسارُ المحليُّ (`/api/media/videos/…`) يصير رابطاً كاملاً على أصل المنصّة.
 */
export const safeVideoUrl = (value?: string | null): string => {
  const parsed = parseSafeVideoUrl(value);
  return parsed && DISPLAY_PROTOCOLS.has(parsed.protocol) ? parsed.href : '';
};

/**
 * ملفُّ MP4 — يُعرض في `<video src>`، فلا يكون إلا رابطاً آمناً (انظر parseSafeVideoUrl).
 * والامتدادُ من مسار الرابط نفسه، لا من أيّ موضعٍ فيه (`javascript:…//.mp4`).
 */
export const isMp4VideoUrl = (value?: string | null): boolean => {
  const parsed = parseSafeVideoUrl(value);
  if (!parsed) return false;
  const pathname = parsed.pathname.toLowerCase();
  return pathname.startsWith('/uploads/videos/') || pathname.endsWith('.mp4');
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

export const uploadMp4Video = async (file: File): Promise<Mp4UploadResult> => {
  const response = await fetch('/api/media/upload', {
    method: 'POST',
    credentials: 'same-origin',
    headers: {
      'Content-Type': 'video/mp4',
      // مرمَّزاً: رؤوس HTTP لا تقبل إلا ISO-8859-1، فاسمُ ملفٍ عربيّ («درس
      // الكسور.mp4») كان يُسقط الطلب في المتصفح قبل أن يخرج. والخادم يفكّه.
      'X-File-Name': encodeURIComponent(file.name),
    },
    body: file,
  });
  const payload = await response.json().catch(() => ({}));
  if (!response.ok) {
    if (response.status === 401) {
      throw new Error(
        'انتهت جلسة رفع الفيديو. سجّل الخروج ثم ادخل بحساب المعلم مرة أخرى.',
      );
    }
    throw new Error(payload?.error || 'فشل رفع ملف الفيديو');
  }
  return payload;
};

export const showVideoStorageNotice = (upload: Mp4UploadResult): void => {
  if (upload.storage !== 'local' || typeof window === 'undefined') return;
  window.alert(
    `✅ تم رفع ملف MP4 بنجاح.\n\n${upload.warning || 'التخزين الحالي مؤقت على خادم التطبيق؛ احفظ الدرس الآن.'}`,
  );
};

export const deleteUploadedVideo = async (url?: string | null): Promise<void> => {
  if (!isMp4VideoUrl(url)) return;
  await fetch('/api/media/delete', {
    method: 'POST',
    credentials: 'same-origin',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ url }),
  });
};