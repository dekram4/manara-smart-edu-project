#!/usr/bin/env node
/**
 * يحذف الشهادات الصادرة باسم معلّمٍ من جدول `certificates`.
 *
 * ── لماذا سكربت ──
 * الشهادة يملكها من أصدرها: معلّمٌ آخر يُمنع من حذفها (الجسر يردّ ٤٠٣)، وهذا
 * صحيح. فشهاداتُ معلّمٍ قديمٍ لم يعد يدخل تبقى، ولا يحذفها إلا من يملك مفتاح
 * الخدمة.
 *
 * ── ما يُطابق ──
 * شهادةٌ اسمُ معلّمها (`teacherName`) أحدُ الأسماء الممرّرة بـ `--teacher`، أو
 * مالكُها (`teacherId`/`teacher_id`/`createdBy`) أحدُ هذه الأسماء أو معرّفُ معلّمٍ
 * في جدول `teachers` يحمل أحدَها. بتسويةٍ عربية (انظر `norm`): الهمزة والتاء
 * المربوطة والألف المقصورة لا تُخفي اسماً.
 *
 * ── الضمانة ──
 * بلا `--apply` لا يُحذف شيء: تُعرض كل شهادةٍ مطابقة باسم الطالب ونوعها، وما
 * يبقى من غيرها. وبعد الحذف يُرفع ختم المحتوى (`smartEdu_contentEpoch`) — فكلُّ
 * جهازٍ يُسقط نسخته المحلية مرّةً ويأخذ ما في الخادم، ولا يُعيد رفعَ المحذوف —
 * ثم يُقرأ الجدول من جديد للتحقّق.
 *
 * التشغيل (من artifacts/api-server، والمتغيّران في بيئة Replit):
 *   node scripts/purge-teacher-certificates.mjs --teacher "بكر برناوي"
 *   node scripts/purge-teacher-certificates.mjs --teacher "بكر برناوي" --apply
 */
import { norm } from "./purge-owner.mjs";

const EPOCH_KEY = "smartEdu_contentEpoch";
const TYPE_LABELS = { excellence: "تفوّق", appreciation: "شكر وتقدير", participation: "مشاركة" };

const text = (value) => (value == null ? "" : String(value).trim());

/**
 * ما يُحذف وما يبقى من صفوف الشهادات.
 *
 * [teacherRows] صفوف `teachers` ({ id, data }) — يُؤخذ منها معرّفُ كلِّ معلّمٍ
 * اسمُه (أو اسمُ مستخدمه) أحدُ [names]، فتُطابَق الشهاداتُ المسجّلة بمعرّفه.
 */
export function selectTeacherCertificates(certificateRows, teacherRows, names) {
  const wanted = new Set(names.map(norm).filter(Boolean));
  const owners = new Set(wanted);
  for (const row of teacherRows) {
    const teacher = row?.data ?? {};
    const labels = [teacher.name, teacher.username, teacher.fullName].map(norm);
    if (labels.some((label) => label && wanted.has(label))) {
      for (const id of [row?.id, teacher.id]) if (norm(id)) owners.add(norm(id));
    }
  }
  const matches = [];
  const kept = [];
  for (const row of certificateRows) {
    const cert = row?.data ?? {};
    const byName = wanted.has(norm(cert.teacherName ?? cert.teacher_name));
    const byOwner = [cert.teacherId, cert.teacher_id, cert.createdBy].some((value) => owners.has(norm(value)));
    (byName || byOwner ? matches : kept).push(row);
  }
  return { matches, kept, owners: [...owners] };
}

function describe(row) {
  const cert = row?.data ?? {};
  const date = text(cert.date).slice(0, 10) || "—";
  return `${text(row?.id).padEnd(16)} ${text(cert.studentName) || "—"} · ${TYPE_LABELS[cert.type] ?? text(cert.type)} · ${text(cert.subject) || "—"} · ${date} · المعلّم: ${text(cert.teacherName) || text(cert.teacherId) || "—"}`;
}

async function main() {
  const args = process.argv.slice(2);
  const apply = args.includes("--apply");
  const names = args
    .map((value, index) => (value === "--teacher" ? args[index + 1] : null))
    .filter(Boolean);
  const SUPABASE_URL = process.env.SUPABASE_URL?.trim().replace(/\/+$/, "");
  const SERVICE_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY?.trim();
  if (!names.length) throw new Error('حدّد المعلّم: --teacher "الاسم"');
  if (!SUPABASE_URL || !SERVICE_KEY) throw new Error("SUPABASE_URL و SUPABASE_SERVICE_ROLE_KEY مطلوبان في البيئة");

  const headers = { apikey: SERVICE_KEY, Authorization: `Bearer ${SERVICE_KEY}`, "Content-Type": "application/json" };
  const readJson = async (path) => {
    const response = await fetch(`${SUPABASE_URL}${path}`, { headers });
    if (!response.ok) throw new Error(`${path}: HTTP ${response.status} ${await response.text()}`);
    return response.json();
  };
  const readAll = async () => {
    const [certificates, teachers] = await Promise.all([
      readJson("/rest/v1/certificates?select=id,data&limit=10000"),
      readJson("/rest/v1/teachers?select=id,data&limit=10000"),
    ]);
    return selectTeacherCertificates(certificates, teachers, names);
  };

  const { matches, kept, owners } = await readAll();
  console.log(`المطلوب: ${names.join("، ")} — يُطابَق أيضاً بالمالك: ${owners.join("، ")}`);
  console.log(`\nالشهادات المطابقة (${matches.length}):`);
  for (const row of matches) console.log("  ✗ " + describe(row));
  console.log(`\nتبقى (${kept.length}):`);
  for (const row of kept) console.log("  ✓ " + describe(row));

  if (!apply) {
    console.log("\nمعاينةٌ فقط — لم يُحذف شيء. للتنفيذ أضف --apply");
    return;
  }
  if (!matches.length) {
    console.log("\nلا شيء يُحذف.");
    return;
  }

  const ids = matches.map((row) => text(row.id));
  for (let i = 0; i < ids.length; i += 50) {
    const batch = ids.slice(i, i + 50).map(encodeURIComponent).join(",");
    const response = await fetch(`${SUPABASE_URL}/rest/v1/certificates?id=in.(${batch})`, {
      method: "DELETE",
      headers: { ...headers, Prefer: "return=minimal" },
    });
    if (!response.ok) throw new Error(`تعذّر الحذف: HTTP ${response.status} ${await response.text()}`);
  }
  console.log(`\nحُذفت ${ids.length} شهادة.`);

  const stamp = new Date().toISOString();
  const epoch = await fetch(`${SUPABASE_URL}/rest/v1/app_kv?on_conflict=key`, {
    method: "POST",
    headers: { ...headers, Prefer: "resolution=merge-duplicates,return=minimal" },
    body: JSON.stringify({ key: EPOCH_KEY, value: stamp, updated_at: stamp }),
  });
  if (!epoch.ok) throw new Error(`حُذفت الشهادات، لكن تعذّر رفع ختم المحتوى: HTTP ${epoch.status}`);
  console.log(`رُفع ختم المحتوى: ${stamp} — تُسقط الأجهزةُ نسخَها المحلية القديمة عند فتحها التالي.`);

  const after = await readAll();
  if (after.matches.length) {
    console.error(`\n❌ التحقّق فشل — بقيت ${after.matches.length} شهادة مطابقة.`);
    process.exit(1);
  }
  console.log(`\n✅ تأكّد بالقراءة: لا شهادة باسم ${names.join("، ")}. الباقي في الجدول: ${after.kept.length}.`);
}

if (process.argv[1] && process.argv[1].endsWith("purge-teacher-certificates.mjs")) {
  main().catch((error) => {
    console.error("فشل:", error.message);
    process.exit(1);
  });
}
