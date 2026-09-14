#!/usr/bin/env node
/**
 * حملة ترحيل: ملء `parentId` لكل طالب مربوط برقم جوال وليّ أمره.
 *
 * السياق: كان ربط الطالب بوليّه يرتدّ إلى مطابقة رقم الجوال عند غياب
 * `parentId`. وهو ثغرة على حدّ أمني — وليّا أمرٍ يحملان الرقم نفسه يرى كلٌّ
 * منهما أبناء الآخر — وقد أُسقط الارتداد من الكود. هذا السكريبت يملأ الربط
 * الصريح قبل أن يُحدث الإسقاطُ انقطاعاً.
 *
 * القاعدة الحاكمة: **لا يخمّن**. رقم يطابق أكثر من وليّ أمر يُبلَّغ كتعارض
 * ويُترك بلا ربط. التخمين هنا يثبّت الثغرة في البيانات بدل أن يزيلها.
 *
 * التشغيل:
 *   SUPABASE_URL=... SUPABASE_SERVICE_ROLE_KEY=... node scripts/migrate-parent-links.mjs
 *
 * وبلا كتابة (معاينة فقط):
 *   ... node scripts/migrate-parent-links.mjs --dry-run
 *
 * ملاحظة: التشغيل اليدوي ليس إلزامياً. الترحيل نفسه يقع آلياً أول مرة يفتح
 * فيها مشرف أو معلم لوحته (`backfillParentLinks` في طبقة المزامنة). هذا
 * السكريبت للتنفيذ الفوري ولرؤية التعارضات مجتمعة.
 */

const DRY_RUN = process.argv.includes("--dry-run");

const SUPABASE_URL = process.env.SUPABASE_URL?.trim().replace(/\/+$/, "");
const SERVICE_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY?.trim();

if (!SUPABASE_URL || !SERVICE_KEY) {
  console.error("SUPABASE_URL و SUPABASE_SERVICE_ROLE_KEY مطلوبان.");
  process.exit(1);
}

const headers = {
  apikey: SERVICE_KEY,
  Authorization: `Bearer ${SERVICE_KEY}`,
  "Content-Type": "application/json",
};

const text = (value) =>
  typeof value === "string" ? value.trim() : value == null ? "" : String(value).trim();

/** نفس التطبيع المستعمل في الواجهة، حتى تتطابق نتيجة السكريبت مع نتيجتها. */
const normalize = (value) => text(value).toLowerCase();

async function readAll(table) {
  const url = new URL(`/rest/v1/${table}`, SUPABASE_URL);
  url.searchParams.set("select", "id,data");
  const response = await fetch(url, { headers });
  if (!response.ok) {
    throw new Error(`تعذّر قراءة ${table}: ${response.status} ${await response.text()}`);
  }
  return response.json();
}

async function writeStudent(id, data) {
  const url = new URL(`/rest/v1/students`, SUPABASE_URL);
  url.searchParams.set("id", `eq.${id}`);
  const response = await fetch(url, {
    method: "PATCH",
    headers: { ...headers, Prefer: "return=minimal" },
    body: JSON.stringify({ data, updated_at: new Date().toISOString() }),
  });
  if (!response.ok) {
    throw new Error(`تعذّر تحديث الطالب ${id}: ${response.status} ${await response.text()}`);
  }
}

async function main() {
  const [studentRows, parentRows] = await Promise.all([
    readAll("students"),
    readAll("parents"),
  ]);

  // فهرس أرقام أولياء الأمور. القيمة قائمة لا قيمة مفردة: تعدّد الأولياء على
  // رقم واحد هو الحالة التي جاء الترحيل من أجلها.
  const byPhone = new Map();
  const knownParentIds = new Set();
  for (const row of parentRows) {
    const data = row?.data && typeof row.data === "object" ? row.data : {};
    const id = text(data.id) || text(row?.id);
    if (!id) continue;
    knownParentIds.add(id);
    const phone = normalize(data.phoneNumber);
    if (!phone) continue;
    const bucket = byPhone.get(phone);
    if (bucket) {
      if (!bucket.includes(id)) bucket.push(id);
    } else {
      byPhone.set(phone, [id]);
    }
  }

  const updates = [];
  const conflicts = [];
  const unmatched = [];
  let alreadyLinked = 0;
  let withoutParent = 0;

  for (const row of studentRows) {
    const data = row?.data && typeof row.data === "object" ? row.data : {};
    const studentId = text(data.id) || text(row?.id);
    if (!studentId) continue;

    const existing = text(data.parentId);
    if (existing && knownParentIds.has(existing)) {
      alreadyLinked++;
      continue;
    }

    const phone = normalize(data.parentPhoneNumber);
    if (!phone) {
      withoutParent++;
      continue;
    }

    const candidates = byPhone.get(phone) ?? [];
    if (candidates.length === 1) {
      updates.push({ rowId: text(row.id) || studentId, data, parentId: candidates[0], name: text(data.name) });
    } else if (candidates.length > 1) {
      conflicts.push({ studentId, name: text(data.name), phone, candidates });
    } else {
      unmatched.push({ studentId, name: text(data.name), phone });
    }
  }

  console.log("──────── خطة الترحيل ────────");
  console.log(`إجمالي الطلاب              : ${studentRows.length}`);
  console.log(`مربوطون سلفاً بـ parentId  : ${alreadyLinked}`);
  console.log(`سيُربطون الآن              : ${updates.length}`);
  console.log(`بلا وليّ أمر أصلاً          : ${withoutParent}`);
  console.log(`أرقام لا تطابق أي وليّ     : ${unmatched.length}`);
  console.log(`تعارضات (لن تُربط)         : ${conflicts.length}`);

  for (const c of conflicts) {
    console.log(
      `  ⚠️  ${c.name || c.studentId}: الرقم ${c.phone} يطابق ${c.candidates.length} أولياء ` +
        `(${c.candidates.join(", ")}) — يحتاج ربطاً يدوياً`,
    );
  }
  for (const u of unmatched) {
    console.log(`  ℹ️  ${u.name || u.studentId}: الرقم ${u.phone} بلا وليّ أمر مسجّل`);
  }

  if (DRY_RUN) {
    console.log("\n(معاينة فقط — لم يُكتب شيء)");
    return;
  }
  if (updates.length === 0) {
    console.log("\nلا شيء ليُكتب.");
  } else {
    let done = 0;
    for (const update of updates) {
      await writeStudent(update.rowId, { ...update.data, parentId: update.parentId });
      done++;
    }
    console.log(`\n✅ رُبط ${done} طالباً بوليّ أمره عبر parentId.`);
  }

  // التحقق بعد الكتابة: لا طالب كان مربوطاً بالرقم وبقي بلا `parentId`.
  const after = await readAll("students");
  const stillOrphaned = after.filter((row) => {
    const data = row?.data && typeof row.data === "object" ? row.data : {};
    const phone = normalize(data.parentPhoneNumber);
    if (!phone) return false;
    if (text(data.parentId)) return false;
    const candidates = byPhone.get(phone) ?? [];
    return candidates.length === 1; // كان قابلاً للربط بلا لبس ومع ذلك لم يُربط
  });

  if (stillOrphaned.length) {
    console.error(`\n❌ ${stillOrphaned.length} طالباً كان قابلاً للربط ولم يُربط — راجع الأخطاء أعلاه.`);
    process.exit(1);
  }
  console.log("✅ تحقّق بعد الترحيل: لا طالب قابل للربط بقي منقطعاً.");
  if (conflicts.length) {
    console.log(
      `\n⚠️ يبقى ${conflicts.length} طالباً بحاجة إلى ربط يدوي من «إدارة الحسابات».\n` +
        "   هؤلاء لن يظهروا لأي وليّ أمر حتى يُربطوا — وهو المقصود: الانقطاع\n" +
        "   المرئي أهون من ربط خاطئ صامت.",
    );
  }
}

main().catch((error) => {
  console.error("فشل الترحيل:", error.message);
  process.exit(1);
});
