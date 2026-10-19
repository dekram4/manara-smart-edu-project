/**
 * «الترفيه والألعاب»: قواعدُ اللعبة، ومن يراها، وحمايةُ مساراتها عبر HTTP.
 *
 * التشغيل: node ./build.mjs && node --test src/lib/__tests__/entertainment.test.mjs
 */

import test from "node:test";
import assert from "node:assert/strict";
import { spawn } from "node:child_process";
import { fileURLToPath } from "node:url";

const games = await import(process.env.ENTERTAINMENT_MODULE ?? "../../../dist/lib/entertainment.mjs");

const teachers = [
  { id: "t1", name: "أ. سارة" },
  { id: "t2", name: "أ. نورة" },
];
let counter = 0;
const options = (extra = {}) => ({ newId: () => `g${++counter}`, now: "2026-10-19T10:00:00.000Z", teachers, ...extra });
const valid = { title: "مغامرة الكسور", description: "لعبة قصيرة", embedUrl: "https://example.com/game/", teacherId: "t1" };

// ── الحفظ ────────────────────────────────────────────────────────────────

test("لعبةٌ صالحة: اسمُ المعلم من سجلّه لا من الطلب، ومفعّلةٌ افتراضياً", () => {
  const built = games.buildGame({ ...valid, teacherName: "اسمٌ مزوّر" }, options());
  assert.equal(built.ok, true);
  assert.equal(built.game.teacherId, "t1");
  assert.equal(built.game.teacherName, "أ. سارة");
  assert.equal(built.game.isActive, true);
  assert.equal(built.game.createdAt, "2026-10-19T10:00:00.000Z");
});

test("المعلمُ إلزاميّ، ويجب أن يكون مسجّلاً", () => {
  assert.equal(games.buildGame({ ...valid, teacherId: "" }, options()).ok, false);
  const ghost = games.buildGame({ ...valid, teacherId: "t9" }, options());
  assert.equal(ghost.ok, false);
  assert.equal(ghost.status, 400);
});

test("العنوانُ والرابطُ إلزاميّان، والرابطُ http(s) أو صفحةُ وكيل الألعاب فقط", () => {
  assert.equal(games.buildGame({ ...valid, title: " " }, options()).ok, false);
  assert.equal(games.buildGame({ ...valid, embedUrl: "" }, options()).ok, false);
  for (const bad of ["javascript:alert(1)", "data:text/html,x", "//evil.com/x", "/api/media/x", "ftp://x.com/g", "https://", "https://a.com/x y"]) {
    assert.equal(games.isSafeGameUrl(bad), false, bad);
  }
  for (const good of ["https://html5.gamedistribution.com/abc/", "http://games.example.com/play", "/api/game-embed/d4a3629101574bc39bd8f9d1888ca58e/index.html"]) {
    assert.equal(games.isSafeGameUrl(good), true, good);
  }
});

test("التعديلُ يُبقي المعرّفَ وتاريخَ الإنشاء، ويقبل التعطيل", () => {
  const first = games.buildGame(valid, options()).game;
  const edited = games.buildGame(
    { ...valid, title: "جديد", teacherId: "t2", isActive: false },
    options({ existing: first, now: "2026-10-20T00:00:00.000Z" }),
  );
  assert.equal(edited.ok, true);
  assert.equal(edited.game.id, first.id);
  assert.equal(edited.game.createdAt, first.createdAt);
  assert.equal(edited.game.updatedAt, "2026-10-20T00:00:00.000Z");
  assert.equal(edited.game.teacherName, "أ. نورة");
  assert.equal(edited.game.isActive, false);
  // وتعديلٌ بلا isActive لا يُعيد تفعيل لعبةٍ معطّلة.
  const again = games.buildGame({ ...valid }, options({ existing: edited.game }));
  assert.equal(again.game.isActive, false);
});

// ── من يراها ────────────────────────────────────────────────────────────

test("لا يراها إلا طلابُ معلّمها، وما دامت مفعّلة", () => {
  const game = games.buildGame(valid, options()).game;
  assert.equal(games.isVisibleToStudent(game, new Set(["t1"])), true);
  assert.equal(games.isVisibleToStudent(game, new Set(["t2"])), false);
  assert.equal(games.isVisibleToStudent(game, new Set()), false);
  assert.equal(games.isVisibleToStudent({ ...game, isActive: false }, new Set(["t1"])), false);
  assert.equal(games.isVisibleToStudent({ ...game, teacherId: "" }, new Set([""])), false);
});

test("للطالب بصيغة فهرس الألعاب، بلا معلّمٍ ولا حالة", () => {
  const game = games.buildGame(valid, options()).game;
  const out = games.studentGame(game);
  assert.equal(out.url, valid.embedUrl);
  assert.equal(out.title, valid.title);
  assert.equal(out.subtitle, valid.description);
  assert.ok(String(out.id).startsWith("teacher-game-"));
  assert.equal("teacherId" in out, false);
  assert.equal("isActive" in out, false);
});

test("الجدولُ و app_kv: ذهابٌ وإياب، بلا تكرار، والأقدمُ أولاً", () => {
  const a = { ...games.buildGame(valid, options({ now: "2026-10-02T00:00:00.000Z" })).game };
  const b = { ...games.buildGame(valid, options({ now: "2026-10-01T00:00:00.000Z" })).game };
  assert.deepEqual(games.fromTableRow(games.toTableRow(a)), a);
  assert.deepEqual(games.fromKvRecord(games.toKvRecord(b)), b);
  const staleA = { ...a, title: "قديم" };
  const merged = games.mergeGames([a], [staleA, b]);
  assert.deepEqual(merged.map((g) => g.id), [b.id, a.id]);
  assert.equal(merged[1].title, a.title, "نسخةُ الجدول تغلب نسخةَ app_kv");
  assert.equal(games.fromTableRow({ id: "x", embed_url: "https://a.com", is_active: "false" }).isActive, false);
});

// ── الحماية عبر HTTP ─────────────────────────────────────────────────────

const PORT = 43000 + Math.floor(Math.random() * 2000);
const BASE = `http://127.0.0.1:${PORT}`;
const entry = fileURLToPath(new URL("../../../dist/index.mjs", import.meta.url));
const server = spawn(process.execPath, [entry], {
  env: {
    PATH: process.env.PATH,
    SYSTEMROOT: process.env.SYSTEMROOT,
    PORT: String(PORT),
    NODE_ENV: "test",
    LOG_LEVEL: "silent",
    SESSION_SECRET: "test-session-secret-not-real",
    ADMIN_USERNAME: "admin-test",
    ADMIN_PASSWORD: "admin-pass-test",
  },
  stdio: "ignore",
});
test.after(() => server.kill());

async function ready() {
  for (let i = 0; i < 100; i += 1) {
    try {
      if ((await fetch(`${BASE}/api/healthz`)).ok) return;
    } catch {
      // ما زال يقلع
    }
    await new Promise((resolve) => setTimeout(resolve, 100));
  }
  throw new Error("server did not start");
}

test("مساراتُ الإدارة للمشرف وحده، ومسارُ الطالب بجلسته", async () => {
  await ready();
  const json = { "Content-Type": "application/json" };
  const calls = [
    ["GET", "/api/entertainment"],
    ["POST", "/api/entertainment"],
    ["PUT", "/api/entertainment/g1"],
    ["DELETE", "/api/entertainment/g1"],
    ["GET", "/api/student/entertainment"],
  ];
  for (const [method, path] of calls) {
    const r = await fetch(`${BASE}${path}`, { method, headers: json, body: method === "GET" || method === "DELETE" ? undefined : JSON.stringify(valid) });
    assert.equal(r.status, 401, `${method} ${path}`);
  }
});
