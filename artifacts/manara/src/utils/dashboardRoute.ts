/**
 * صفحةُ اللوحة في عنوان المتصفّح، فلا يُعيد التحديثُ (F5) صاحبَها إلى الرئيسية.
 *
 * ── لماذا ──
 * كانت الصفحةُ المفتوحة (إدارة الحسابات، التقارير، ملفُّ ابنٍ…) حالةً في
 * الذاكرة وحدها: الدورُ يُستعاد بعد التحديث من الجلسة المحفوظة، لكن اللوحة
 * تُبنى من جديد على «الرئيسية»، فيعود المشرفُ والمعلمُ ووليُّ الأمر إليها
 * ويبحثون عن الصفحة التي كانوا فيها.
 *
 * فصارت تُكتب في الـhash: `#/admin/STUDENT_MANAGEMENT`، و`#/parent/CHILDREN/<الابن>/<المادة>`.
 * الـhash لكلّ تبويبٍ وحده، ويبقى مع التحديث، ولا يصل الخادم. ويُكتب بـ
 * `replaceState` فلا يملأ سجلَّ زرّ الرجوع بكل نقرةٍ في القائمة.
 *
 * وما في العنوان اقتراحٌ لا صلاحية: الصفحةُ تُقبل إن كانت من قائمة اللوحة،
 * والجلسةُ يتحقّق منها الخادم كما كان.
 */
export type DashboardRole = 'admin' | 'teacher' | 'parent';

export interface DashboardRoute {
  page: string;
  params: string[];
}

const decode = (part: string): string => {
  try {
    return decodeURIComponent(part);
  } catch {
    return part;
  }
};

/** يقرأ `#/<الدور>/<الصفحة>/<…>`، أو `null` إن كان لدورٍ آخر أو فارغاً. */
export function parseDashboardHash(hash: string, role: DashboardRole): DashboardRoute | null {
  const parts = hash.replace(/^#\/?/, '').split('/').filter(Boolean).map(decode);
  if (parts[0] !== role || !parts[1]) return null;
  return { page: parts[1], params: parts.slice(2) };
}

export function formatDashboardHash(
  role: DashboardRole,
  page: string,
  params: ReadonlyArray<string | null | undefined> = [],
): string {
  // مُعاملٌ فارغ يقطع ما بعده: مادةٌ بلا ابنٍ لا معنى لها.
  const kept: string[] = [];
  for (const param of params) {
    if (!param) break;
    kept.push(param);
  }
  return `#/${[role, page, ...kept].map(encodeURIComponent).join('/')}`;
}

/** الصفحةُ المحفوظة إن كانت من صفحات اللوحة، وإلا `fallback`. */
export function readDashboardRoute<T extends string>(
  role: DashboardRole,
  pages: readonly T[],
  fallback: T,
): { page: T; params: string[] } {
  if (typeof window === 'undefined') return { page: fallback, params: [] };
  const route = parseDashboardHash(window.location.hash, role);
  if (!route || !pages.includes(route.page as T)) return { page: fallback, params: [] };
  return { page: route.page as T, params: route.params };
}

export function writeDashboardRoute(
  role: DashboardRole,
  page: string,
  params: ReadonlyArray<string | null | undefined> = [],
): void {
  if (typeof window === 'undefined') return;
  const hash = formatDashboardHash(role, page, params);
  if (window.location.hash === hash) return;
  try {
    const { pathname, search } = window.location;
    window.history.replaceState(window.history.state, '', `${pathname}${search}${hash}`);
  } catch {
    // متصفّحٌ يمنع تعديلَ العنوان: يبقى كلُّ شيءٍ كما كان، بلا حفظٍ للصفحة.
  }
}

/** يمحو صفحةَ اللوحة من العنوان — عند الخروج، كي لا يُفتح بها حسابٌ آخر. */
export function clearDashboardRoute(): void {
  if (typeof window === 'undefined' || !window.location.hash.startsWith('#/')) return;
  try {
    const { pathname, search } = window.location;
    window.history.replaceState(window.history.state, '', `${pathname}${search}`);
  } catch {
    // كما في الكتابة.
  }
}
