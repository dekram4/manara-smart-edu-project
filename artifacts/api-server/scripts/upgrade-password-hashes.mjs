/**
 * يرقّي كلَّ كلمة مرورٍ مخزّنة بصيغةٍ قديمة (SHA-256 بلا ملح، أو نصٍّ صريح)
 * إلى scrypt بملحٍ لكل حساب — في الطلاب والمعلمين وأولياء الأمور — بلا انتظار
 * أن يدخل أحد.
 *
 * ممكنٌ بلا كلمات المرور لأن الصيغة الآمنة scrypt فوق بصمة SHA-256: البصمةُ
 * المخزّنة هي مدخلُ scrypt نفسه، فتُلفّ في مكانها (انظر src/lib/passwords.ts).
 * والدخولُ بعدها كما كان بالكلمة نفسها.
 *
 * ⚠ يُشغَّل بعد نشر خادمٍ يعرف الصيغة الجديدة — وإلا رفض الخادمُ القديم كلَّ دخول.
 *
 * التشغيل (بمتغيّرات الخادم، بلا طباعة سرّ):
 *   node ./build.mjs && railway run node ./scripts/upgrade-password-hashes.mjs
 * ويُعاد تشغيله بأمان: ما رُقّي يُترك.
 */

const { isStrongHash, isSha256Hex, sha256Hex, upgradeStoredValue, verifyPrehash } = await import(new URL("../dist/lib/passwords.mjs", import.meta.url).href);

const url = process.env.SUPABASE_URL;
const key = process.env.SUPABASE_SERVICE_ROLE_KEY;
if (!url || !key) {
  console.error("SUPABASE_URL / SUPABASE_SERVICE_ROLE_KEY مطلوبة");
  process.exit(1);
}
const headers = { apikey: key, Authorization: `Bearer ${key}`, "Content-Type": "application/json" };

const report = {};
for (const table of ["students", "teachers", "parents"]) {
  const response = await fetch(`${url}/rest/v1/${table}?select=id,data&limit=5000`, { headers });
  if (!response.ok) {
    console.error(`${table}: read failed (${response.status})`);
    process.exitCode = 1;
    continue;
  }
  const rows = await response.json();
  const stats = { total: rows.length, upgraded: 0, alreadyStrong: 0, noPassword: 0, failed: 0 };
  for (const row of rows) {
    const password = row.data?.password;
    if (typeof password !== "string" || !password) { stats.noPassword += 1; continue; }
    if (isStrongHash(password)) { stats.alreadyStrong += 1; continue; }
    const upgraded = upgradeStoredValue(password);
    // ‏قبل الكتابة: القيمةُ الجديدة تقبل ما كانت تقبله القديمة بالضبط — وإلا
    // ‏لا تُكتب، فلا يُقفل حسابٌ بخطأٍ هنا.
    const prehash = isSha256Hex(password) ? password.toLowerCase() : sha256Hex(password);
    if (!isStrongHash(upgraded) || !verifyPrehash(prehash, upgraded)) {
      stats.failed += 1;
      process.exitCode = 1;
      continue;
    }
    const patch = await fetch(`${url}/rest/v1/${table}?id=eq.${encodeURIComponent(row.id)}`, {
      method: "PATCH",
      headers: { ...headers, Prefer: "return=minimal" },
      body: JSON.stringify({ data: { ...row.data, password: upgraded }, updated_at: new Date().toISOString() }),
    });
    if (patch.ok) stats.upgraded += 1;
    else { stats.failed += 1; process.exitCode = 1; }
  }
  report[table] = stats;
}
console.log(JSON.stringify(report));
