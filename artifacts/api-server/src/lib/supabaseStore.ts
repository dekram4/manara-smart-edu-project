/**
 * وصولُ الخادم إلى Supabase بمفتاح الخدمة، لمسارات السينما وصلاحيات البطاقات.
 *
 * ── جدولٌ قد لا يكون موجوداً بعد ──
 * الجدولان الجديدان يُنشئهما `scripts/cinema-and-card-permissions.sql`، وهو
 * يُشغَّل يدوياً في Supabase. وقد سبق أن نُشرت ميزاتٌ تحتاج SQL لم يُشغَّل
 * فتعطّلت بـ «يحتاج تحديث قاعدة البيانات». فالمسارات هنا تسأل الجدولَ أولاً،
 * وإن لم تجده ارتدّت إلى مفتاحٍ في `app_kv` — الجدولُ الموجود منذ البداية —
 * فتعمل الميزةُ من أول نشر، وتنتقل إلى الجدول وحدها يومَ يُنشأ.
 */

import { scopeKey } from "./cinema";

export type StoreConfig = { url: string; key: string };

export class SupabaseRestError extends Error {
  constructor(
    readonly status: number,
    readonly body: string,
  ) {
    super(body || `Supabase request failed (${status})`);
  }
}

export function storeConfig(): StoreConfig | null {
  const url = process.env.SUPABASE_URL?.trim().replace(/\/+$/, "");
  const key = process.env.SUPABASE_SERVICE_ROLE_KEY?.trim();
  return url && key ? { url, key } : null;
}

export async function rest(
  config: StoreConfig,
  resource: string,
  init: RequestInit = {},
): Promise<unknown> {
  const response = await fetch(`${config.url}/rest/v1/${resource}`, {
    ...init,
    headers: {
      apikey: config.key,
      Authorization: `Bearer ${config.key}`,
      Accept: "application/json",
      ...(init.body ? { "Content-Type": "application/json" } : {}),
      ...(init.headers as Record<string, string> | undefined),
    },
  });
  const body = await response.text();
  if (!response.ok) throw new SupabaseRestError(response.status, body);
  return body ? JSON.parse(body) : null;
}

/**
 * هل الخطأ «الجدول غير موجود»؟
 *
 * PostgREST يقولها بـ PGRST205 (لا يجده في ذاكرة المخطط)، وPostgres بـ 42P01.
 * وما سواهما خطأٌ حقيقيّ لا يُبتلع بالارتداد.
 */
export function isMissingTable(error: unknown): boolean {
  if (!(error instanceof SupabaseRestError)) return false;
  return /PGRST205|42P01|does not exist|Could not find the table/i.test(error.body);
}

/**
 * يتذكّر غيابَ الجدول دقيقةً، فلا يسأل عنه كلُّ طلبٍ من جديد.
 * وبعد الدقيقة يُسأل ثانيةً: يومَ يُشغَّل SQL ينتقل إليه الخادم بلا إعادة نشر.
 */
const missingUntil = new Map<string, number>();
const MISSING_TTL_MS = 60_000;

export function tableKnownMissing(table: string): boolean {
  return (missingUntil.get(table) ?? 0) > Date.now();
}

export function markTableMissing(table: string): void {
  missingUntil.set(table, Date.now() + MISSING_TTL_MS);
}

/**
 * يجرّب الجدول، ويرتدّ إلى البديل إن لم يكن موجوداً.
 * يُرجع النتيجةَ ومصدرَها، فيُعرف في اللوحة أين حُفظت البيانات.
 */
export async function withTableFallback<T>(
  table: string,
  onTable: () => Promise<T>,
  onFallback: () => Promise<T>,
): Promise<{ value: T; storage: "table" | "kv" }> {
  if (!tableKnownMissing(table)) {
    try {
      return { value: await onTable(), storage: "table" };
    } catch (error) {
      if (!isMissingTable(error)) throw error;
      markTableMissing(table);
    }
  }
  return { value: await onFallback(), storage: "kv" };
}

export async function readKv(config: StoreConfig, key: string): Promise<unknown> {
  const rows = await rest(config, `app_kv?select=value&key=eq.${encodeURIComponent(key)}`);
  return Array.isArray(rows) && rows[0] ? (rows[0] as { value?: unknown }).value : null;
}

export async function writeKv(config: StoreConfig, key: string, value: unknown): Promise<void> {
  await rest(config, "app_kv?on_conflict=key", {
    method: "POST",
    headers: { Prefer: "resolution=merge-duplicates,return=minimal" },
    body: JSON.stringify({ key, value }),
  });
}

export function asRecords(value: unknown): Record<string, unknown>[] {
  return Array.isArray(value)
    ? value.filter((item): item is Record<string, unknown> => Boolean(item) && typeof item === "object")
    : [];
}

function text(value: unknown): string {
  return typeof value === "string" ? value.trim() : "";
}

/**
 * كلُّ ما يُعرف به معلّمٌ في سجلات الملكية، مسوّىً بـ [scopeKey].
 *
 * الملكية تُكتب نصّاً: معرّفاً مرة واسمَ دخول أو اسماً ظاهراً مرة. ونفسُ
 * القاعدة التي في الجسر: اسمٌ يتقاسمه معلّمان يسقط، فلا يملك أحدهما ما للآخر.
 */
export async function teacherIdentities(
  config: StoreConfig,
  teacherId: string,
): Promise<Set<string>> {
  const wanted = scopeKey(teacherId);
  const identities = new Set<string>(wanted ? [wanted] : []);
  if (!wanted) return identities;
  try {
    const rows = asRecords(await rest(config, "teachers?select=id,data&limit=2000"));
    const mine: string[] = [];
    const others = new Set<string>();
    for (const row of rows) {
      const data = (row.data && typeof row.data === "object" ? row.data : {}) as Record<string, unknown>;
      const names = [row.id, data.id, data.username, data.name, data.fullName]
        .map(scopeKey)
        .filter(Boolean);
      const isMine = names.includes(wanted);
      for (const name of names) {
        if (isMine) mine.push(name);
        else others.add(name);
      }
    }
    for (const name of mine) {
      if (!others.has(name)) identities.add(name);
    }
  } catch {
    // جدول المعلمين غير مقروء: يبقى المعرّف وحده — أضيقُ لا أوسع.
  }
  return identities;
}

/** المعلمون للوحة المشرف: المعرّف والاسم. */
export async function listTeachers(
  config: StoreConfig,
): Promise<Array<{ id: string; name: string }>> {
  const rows = asRecords(await rest(config, "teachers?select=id,data&limit=2000"));
  return rows
    .map((row) => {
      const data = (row.data && typeof row.data === "object" ? row.data : {}) as Record<string, unknown>;
      const id = text(data.id) || text(row.id);
      return { id, name: text(data.name) || text(data.fullName) || text(data.username) || id };
    })
    .filter((teacher) => teacher.id);
}
