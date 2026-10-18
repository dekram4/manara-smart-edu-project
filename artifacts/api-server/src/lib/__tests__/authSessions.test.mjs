/**
 * جلساتُ الأدوار عبر HTTP حقيقي: الدخولُ حصريّ لدورٍ واحد، والخروجُ يمحو
 * الكلّ، والجلستان معاً لا تمنحان صلاحيةَ المشرف.
 *
 * يُشغَّل الخادمُ المبنيّ (dist/index.mjs) بسرٍّ وبيانات مشرفٍ تجريبية، بلا
 * قاعدة بيانات: لا يمسّ شيئاً حقيقياً.
 *
 * ── العطبُ الذي يحرسه ──
 * كعكةُ المشرف تعيش ١٤ يوماً، والخادمُ كان يقدّمها على كعكة المعلم. فمعلمٌ دخل
 * على متصفّحٍ بقيت فيه كعكةُ مشرف كان يكتب بصلاحية المشرف، وتُفتح لوحةُ المشرف
 * بعده بلا كلمة مرور.
 *
 * التشغيل: node ./build.mjs && node --test src/lib/__tests__/authSessions.test.mjs
 */

import test from "node:test";
import assert from "node:assert/strict";
import { spawn } from "node:child_process";
import crypto from "node:crypto";
import { fileURLToPath } from "node:url";

const SECRET = "test-session-secret-not-real";
const PORT = 41000 + Math.floor(Math.random() * 2000);
const BASE = `http://127.0.0.1:${PORT}`;
const entry = fileURLToPath(new URL("../../../dist/index.mjs", import.meta.url));

const server = spawn(process.execPath, [entry], {
  env: {
    PATH: process.env.PATH,
    SYSTEMROOT: process.env.SYSTEMROOT,
    PORT: String(PORT),
    NODE_ENV: "test",
    LOG_LEVEL: "silent",
    SESSION_SECRET: SECRET,
    ADMIN_USERNAME: "admin-test",
    ADMIN_PASSWORD: "admin-pass-test",
  },
  stdio: "ignore",
});

test.after(() => server.kill());

async function ready() {
  for (let i = 0; i < 100; i += 1) {
    try {
      const r = await fetch(`${BASE}/api/healthz`);
      if (r.ok) return;
    } catch {
      // ما زال يقلع
    }
    await new Promise((resolve) => setTimeout(resolve, 100));
  }
  throw new Error("server did not start");
}

/** كعكةٌ موقَّعةٌ بالصيغة التي يتحقّق منها الخادم. */
function signed(payload) {
  const encoded = Buffer.from(JSON.stringify(payload)).toString("base64url");
  const signature = crypto.createHmac("sha256", SECRET).update(encoded).digest("base64url");
  return encodeURIComponent(`${encoded}.${signature}`);
}
const in1h = () => Date.now() + 3_600_000;
const adminCookie = () => `manara_admin_session=${signed({ role: "admin", expiresAt: in1h() })}`;
const teacherCookie = () => `manara_teacher_session=${signed({ role: "teacher", teacherId: "t1", expiresAt: in1h() })}`;

const setCookies = (response) => response.headers.getSetCookie();
const cleared = (cookies, name) => cookies.some((c) => c.startsWith(`${name}=;`) && /Max-Age=0/.test(c));

test("دخولُ المشرف حصريّ: كعكتُه، ومحوُ كعكتَي المعلم ووليّ الأمر في الردّ نفسه", async () => {
  await ready();
  const r = await fetch(`${BASE}/api/auth/admin`, {
    method: "POST",
    headers: { "Content-Type": "application/json", Cookie: teacherCookie() },
    body: JSON.stringify({ username: "admin-test", password: "admin-pass-test" }),
  });
  assert.equal(r.status, 200);
  assert.deepEqual(await r.json(), { ok: true, role: "admin" });
  const cookies = setCookies(r);
  assert.ok(cookies.some((c) => c.startsWith("manara_admin_session=") && !/Max-Age=0/.test(c)));
  assert.ok(cleared(cookies, "manara_teacher_session"), "كعكةُ المعلم تُمحى");
  assert.ok(cleared(cookies, "manara_parent_session"), "كعكةُ وليّ الأمر تُمحى");
});

test("ودخولٌ خاطئ لا يمحو شيئاً ولا يمنح دوراً", async () => {
  await ready();
  const r = await fetch(`${BASE}/api/auth/admin`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ username: "admin-test", password: "wrong" }),
  });
  assert.equal(r.status, 401);
  assert.equal(setCookies(r).length, 0);
});

test("whoami: الدورُ من الكعكات — مشرف، أو معلم، أو لا أحد", async () => {
  await ready();
  const ask = async (cookie) => (await (await fetch(`${BASE}/api/auth/whoami`, { headers: cookie ? { Cookie: cookie } : {} })).json()).role;
  assert.equal(await ask(adminCookie()), "admin");
  assert.equal(await ask(teacherCookie()), "teacher");
  assert.equal(await ask(""), null);
  // كعكةٌ مزوّرة التوقيع لا تُحسب.
  assert.equal(await ask(`manara_admin_session=${encodeURIComponent("eyJyb2xlIjoiYWRtaW4ifQ.fake")}`), null);
});

test("جلستان معاً: لا دور، وتُمحى الكعكات، ولا تُفتح لوحةُ المشرف ولا مساراتُه", async () => {
  await ready();
  const mixed = `${adminCookie()}; ${teacherCookie()}`;
  const who = await fetch(`${BASE}/api/auth/whoami`, { headers: { Cookie: mixed } });
  assert.deepEqual(await who.json(), { role: null, conflict: true });
  const cookies = setCookies(who);
  for (const name of ["manara_admin_session", "manara_teacher_session", "manara_parent_session"]) {
    assert.ok(cleared(cookies, name), `${name} تُمحى`);
  }
  const session = await (await fetch(`${BASE}/api/auth/admin/session`, { headers: { Cookie: mixed } })).json();
  assert.equal(session.authenticated, false, "لوحةُ المشرف لا تُفتح بجلسةٍ مختلطة");
  const adminOnly = await fetch(`${BASE}/api/app-settings/student-apk`, {
    method: "PUT",
    headers: { "Content-Type": "application/json", Cookie: mixed },
    body: JSON.stringify({ url: "https://example.com/a.apk" }),
  });
  assert.equal(adminOnly.status, 401, "مسارُ المشرف يرفض الجلسة المختلطة");
});

test("والمشرفُ وحده تُفتح له لوحتُه", async () => {
  await ready();
  const session = await (await fetch(`${BASE}/api/auth/admin/session`, { headers: { Cookie: adminCookie() } })).json();
  assert.equal(session.authenticated, true);
});

test("الخروجُ الموحّد يمحو كعكات الأدوار الثلاثة", async () => {
  await ready();
  const r = await fetch(`${BASE}/api/auth/logout`, { method: "POST", headers: { Cookie: `${adminCookie()}; ${teacherCookie()}` } });
  assert.equal(r.status, 200);
  const cookies = setCookies(r);
  for (const name of ["manara_admin_session", "manara_teacher_session", "manara_parent_session"]) {
    assert.ok(cleared(cookies, name), `${name} تُمحى`);
  }
  assert.equal(r.headers.get("cache-control"), "no-store");
});
