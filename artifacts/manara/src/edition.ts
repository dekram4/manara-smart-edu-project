/**
 * أيُّ نسخةٍ من منارة يقدّمها هذا الخادم؟ — `GET /api/edition`.
 *
 * النسخةُ العادية (النشر الحالي) تقول `standard` فلا يتغيّر شيءٌ في الواجهة.
 * و«النسخة المفتوحة» (خدمةٌ مستقلّة بقاعدة `manara-open-app`) تقول `open`،
 * فتُعرض بوابةُ معلّمها الوحيد بدل شاشة اختيار الأدوار.
 *
 * وأيُّ تعذّرٍ في السؤال (خادمٌ أقدم بلا هذا المسار، انقطاع، مهلة) يعني
 * `standard`: الواجهةُ لا تُغلق بوابةً بناءً على ردٍّ لم يصل.
 */

export type EditionInfo = {
  edition: 'standard' | 'open';
  ready?: boolean;
  teacherName?: string | null;
  grades?: string[];
};

export const STANDARD_EDITION: EditionInfo = { edition: 'standard' };

/** يفسّر ردَّ الخادم؛ وما لا يُفهم منه فهو النسخةُ العادية. */
export function parseEdition(payload: unknown): EditionInfo {
  if (!payload || typeof payload !== 'object') return STANDARD_EDITION;
  const body = payload as Record<string, unknown>;
  if (body.edition !== 'open') return STANDARD_EDITION;
  return {
    edition: 'open',
    ready: body.ready === true,
    teacherName: typeof body.teacherName === 'string' && body.teacherName.trim() ? body.teacherName.trim() : null,
    grades: Array.isArray(body.grades) ? body.grades.filter((g): g is string => typeof g === 'string') : [],
  };
}

export async function fetchEdition(timeoutMs = 4000): Promise<EditionInfo> {
  const controller = typeof AbortController !== 'undefined' ? new AbortController() : null;
  const timer = controller ? window.setTimeout(() => controller.abort(), timeoutMs) : 0;
  try {
    const response = await fetch('/api/edition', {
      credentials: 'same-origin',
      cache: 'no-store',
      signal: controller?.signal,
    });
    if (!response.ok) return STANDARD_EDITION;
    return parseEdition(await response.json());
  } catch {
    return STANDARD_EDITION;
  } finally {
    if (timer) window.clearTimeout(timer);
  }
}

export const isOpenEdition = (info: EditionInfo | null | undefined): boolean => info?.edition === 'open';
