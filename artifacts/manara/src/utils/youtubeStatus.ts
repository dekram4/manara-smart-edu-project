import { useEffect, useState } from 'react';
import { LessonConfig } from '../types';
import { getLessonExplanationVideos } from './video';

/**
 * أيُّ فيديوهات يوتيوب في المحتوى لم تعد تعمل — ليراها المعلم ويستبدلها.
 *
 * الخادمُ يسأل يوتيوب (`/api/media/youtube-status`) ويحفظ الجواب؛ واللوحةُ تعرض
 * تنبيهاً على الدرس الذي فيه فيديو محذوفٌ أو ممنوعُ التضمين. كان فيديو «تعليم
 * الألوان والأشكال وتمييزها» الثامن محذوفاً من يوتيوب ويظهر رمادياً عند الطالب
 * والمعلمُ لا يعلم.
 */
export type YoutubeStatus = 'available' | 'unavailable' | 'embed_blocked' | 'unknown';

const ID = /^[A-Za-z0-9_-]{11}$/;

export function youtubeIdFromUrl(value: unknown): string | null {
  if (typeof value !== 'string') return null;
  try {
    const url = new URL(value.trim());
    const host = url.hostname.replace(/^www\.|^m\./, '');
    let id = '';
    if (host === 'youtu.be') id = url.pathname.split('/')[1] ?? '';
    else if (host.endsWith('youtube.com') || host.endsWith('youtube-nocookie.com')) {
      const parts = url.pathname.split('/').filter(Boolean);
      id = url.searchParams.get('v') ?? (['embed', 'shorts', 'live', 'v'].includes(parts[0]) ? parts[1] ?? '' : '');
    }
    return ID.test(id) ? id : null;
  } catch {
    return null;
  }
}

/** معرّفاتُ يوتيوب في درس، بلا تكرار. */
export function youtubeIdsOf(lesson: LessonConfig): string[] {
  const urls = [lesson.explanationVideoUrl, ...getLessonExplanationVideos(lesson).map(video => video.url)];
  return [...new Set(urls.map(youtubeIdFromUrl).filter((id): id is string => Boolean(id)))];
}

/** حالُ كل معرّفٍ في الدروس المعروضة، يُسأل عنه الخادم دفعاتٍ من خمسين. */
export function useYoutubeStatuses(lessons: LessonConfig[]): Record<string, YoutubeStatus> {
  const [statuses, setStatuses] = useState<Record<string, YoutubeStatus>>({});
  const ids = [...new Set(lessons.flatMap(youtubeIdsOf))].sort();
  const key = ids.join(',');
  useEffect(() => {
    if (!ids.length) return;
    let cancelled = false;
    (async () => {
      const result: Record<string, YoutubeStatus> = {};
      for (let i = 0; i < ids.length; i += 50) {
        try {
          const response = await fetch(`/api/media/youtube-status?ids=${ids.slice(i, i + 50).join(',')}`, {
            credentials: 'include',
          });
          if (!response.ok) continue;
          const body = await response.json();
          Object.assign(result, body?.statuses ?? {});
        } catch {
          // تعذّر السؤال: لا تنبيه — لا يُتّهم فيديو سليم.
        }
      }
      if (!cancelled) setStatuses(result);
    })();
    return () => {
      cancelled = true;
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [key]);
  return statuses;
}

/** فيديوهاتُ الدرس التي لا تعمل: المحذوفة والممنوعة من التضمين. */
export function brokenVideosOf(lesson: LessonConfig, statuses: Record<string, YoutubeStatus>): number {
  return youtubeIdsOf(lesson).filter(id => statuses[id] === 'unavailable' || statuses[id] === 'embed_blocked').length;
}
