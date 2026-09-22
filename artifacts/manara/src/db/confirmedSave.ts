import { supabase } from './remoteSupabase';

/**
 * كتابة مؤكَّدة: تُرسَل، ثم تُقرأ من الخادم للتحقّق.
 *
 * المزامنة العادية تكتب محلياً أولاً ثم ترسل، وإن فشل الإرسال دخل الطابور
 * بصمت. فالمعلم يرى شجرته أمامه ويظنّها محفوظة، بينما `app_kv` في Supabase
 * فارغة — وهذا ما وقع فعلاً: السكربت قرأ صفر إعدادات وصفّاً قديماً.
 *
 * هذه الدوال لا تكتفي بإرسال الطلب: تقرأ ما وصل فعلاً وتقارنه، فتقول
 * «محفوظ» عن يقين أو تذكر السبب. تُستعمل حيث يجب أن يعرف المستخدم بيقين:
 * زر تثبيت الإعدادات الأكاديمية، وحفظ بيانات الطالب.
 */

export type SaveOutcome =
  | { ok: true; verified: boolean }
  | { ok: false; reason: string };

function describe(error: unknown): string {
  if (!error) return 'سبب غير معروف';
  if (typeof error === 'object' && error !== null && 'message' in error) {
    const message = String((error as { message?: unknown }).message ?? '').trim();
    if (message) return message;
  }
  return String(error);
}

/**
 * يحفظ مفتاحاً في `app_kv` ثم يقرأه ليتأكّد من وصوله.
 *
 * و[arrived] هو ما يُسأل عمّا وصل. افتراضه التطابق الحرفي، وهو الصواب
 * لمفتاح يُكتب كما هو. لكن شجرة الإعدادات لا تُكتب كما هي: الخادم يدمجها
 * بالمالك — يُبقي إعدادات غير هذا المعلم كما هي في قاعدة البيانات ويضع
 * فوقها إعداداته هو — فما يعود مختلفٌ عمّا أُرسل ترتيباً ومحتوى، ولو
 * وصل كل حرف من عمل المعلم.
 *
 * فكان الشريط يقول «أُرسلت وتعذّر التحقق» بعد كل حفظ ناجح: إنذارٌ دائم
 * لا يدلّ على خلل، وهو أسوأ من لا إنذار — يعتاده المعلم فيتجاهل الحقيقي
 * حين يقع.
 */
export async function saveKvConfirmed(
  key: string,
  value: unknown,
  arrived: (stored: unknown, sent: unknown) => boolean = (stored, sent) =>
    JSON.stringify(stored ?? null) === JSON.stringify(sent ?? null),
): Promise<SaveOutcome> {
  const written = await supabase.from('app_kv').upsert({ key, value });
  if (written.error) return { ok: false, reason: describe(written.error) };

  const readBack = await supabase.from('app_kv').select('key,value');
  if (readBack.error) {
    // وصلت الكتابة بلا خطأ، لكن التحقّق تعذّر. لا نَعِد بما لم نره.
    return { ok: true, verified: false };
  }
  const rows = Array.isArray(readBack.data) ? readBack.data : [];
  const stored = rows.find(row => row?.key === key)?.value;
  return { ok: true, verified: arrived(stored, value) };
}

/**
 * هل وصل كل ما يملكه هذا المعلم من الشجرة؟
 *
 * يُقاس بالمعرّف لا بالاسم: الاسم يتغيّر — يُعاد تسمية المعلم فتبقى
 * سجلّاته باسمه القديم — والمعرّف لا يتغيّر. ويُقارن الصفّ بالصفّ، فترتيب
 * المصفوفة بعد الدمج لا يعني شيئاً.
 *
 * وما يملكه غيره لا يُسأل عنه: لم يُرسله ولا يملك تغييره.
 */
export function ownedTreeArrived(
  teacherId: string,
  ownerOf: (config: unknown) => string,
): (stored: unknown, sent: unknown) => boolean {
  const owner = teacherId.trim().toLowerCase();
  return (stored, sent) => {
    if (!owner) {
      return JSON.stringify(stored ?? null) === JSON.stringify(sent ?? null);
    }
    const mine = (value: unknown) =>
      (Array.isArray(value) ? value : [])
        .filter(config => ownerOf(config) === owner)
        .map(config => JSON.stringify(config))
        .sort();
    const sentMine = mine(sent);
    const storedMine = new Set(mine(stored));
    return sentMine.every(config => storedMine.has(config));
  };
}

/** يحفظ صفوفاً في جدول ثم يقرأ الجدول ليتأكّد من وجودها. */
export async function saveRowsConfirmed(
  table: string,
  rows: { id: string; data: unknown }[],
): Promise<SaveOutcome> {
  if (rows.length === 0) return { ok: true, verified: true };
  const written = await supabase.from(table).upsert(rows);
  if (written.error) return { ok: false, reason: describe(written.error) };

  const readBack = await supabase.from(table).select('id,data');
  if (readBack.error) return { ok: true, verified: false };
  const stored = new Map(
    (Array.isArray(readBack.data) ? readBack.data : []).map(row => [
      String(row?.id),
      JSON.stringify(row?.data ?? null),
    ]),
  );
  const verified = rows.every(
    row => stored.get(String(row.id)) === JSON.stringify(row.data ?? null),
  );
  return { ok: true, verified };
}

/** ما تحمله قاعدة البيانات الآن تحت مفتاح، أو `undefined` إن تعذّرت القراءة. */
export async function readKv(key: string): Promise<unknown | undefined> {
  const result = await supabase.from('app_kv').select('key,value');
  if (result.error) return undefined;
  const rows = Array.isArray(result.data) ? result.data : [];
  return rows.find(row => row?.key === key)?.value;
}

/** الحقول التي لا يُعدّ سجلّ الطالب محفوظاً بدونها. */
export type StudentAcademicFields = {
  id: string;
  grade?: string;
  primaryGrade?: string;
  subject?: string;
  teacherId?: string;
};

/**
 * يحفظ سجلّ طالب في قاعدة البيانات ويقرأه للتأكيد.
 *
 * نقطة واحدة يمرّ منها حفظ الطالب من لوحة المعلم ومن لوحة المشرف، فيبقى
 * السلوك واحداً: الصفّ يُكتب في `grade` و`primaryGrade` معاً — الشاشات
 * القديمة تقرأ أحدهما والتطبيق يقرأ الآخر — ويُختم السجلّ بوقت التعديل،
 * وهو ما يجعل نسخة المتصفح الأحدث تغلب النسخة البعيدة الأقدم عند الدمج
 * بدل أن تُمحى.
 *
 * ولا يُعلَن النجاح إلا بعد قراءة الصفّ من الخادم ومطابقة الصفّ المحفوظ.
 */
export async function saveStudentConfirmed<T extends StudentAcademicFields>(
  student: T,
): Promise<SaveOutcome> {
  const grade = (student.primaryGrade || student.grade || '').trim();
  const record = {
    ...student,
    grade,
    primaryGrade: grade,
    lastActivity: new Date().toISOString(),
  };

  const written = await supabase.from('students').upsert([{ id: student.id, data: record }]);
  if (written.error) return { ok: false, reason: describe(written.error) };

  const readBack = await supabase.from('students').select('id,data');
  if (readBack.error) return { ok: true, verified: false };
  const rows = Array.isArray(readBack.data) ? readBack.data : [];
  const stored = rows.find(row => String(row?.id) === String(student.id))?.data as
    | Record<string, unknown>
    | undefined;
  const storedGrade = String(stored?.primaryGrade ?? stored?.grade ?? '').trim();
  return { ok: true, verified: storedGrade === grade };
}
