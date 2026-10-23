/**
 * صفحةُ لوحات الويب في العنوان: التحديثُ (F5) يُبقي المشرفَ والمعلمَ ووليَّ
 * الأمر في صفحتهم — `artifacts/manara/src/utils/dashboardRoute.ts`.
 *
 * الملفُّ من لوحة الويب، فيُترجَم هنا بـesbuild (وهو أداةُ بناء الخادم نفسُها)
 * ويُستورد، بلا React: الخطّافُ في ملفٍّ آخر، وما هنا قراءةُ العنوان وكتابتُه.
 *
 * التشغيل: node --test src/lib/__tests__/dashboardRoute.test.mjs
 */

import test from "node:test";
import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import { transform } from "esbuild";

const source = await readFile(
  new URL("../../../../manara/src/utils/dashboardRoute.ts", import.meta.url),
  "utf8",
);
const { code } = await transform(source, { loader: "ts", format: "esm" });
const route = await import(`data:text/javascript;base64,${Buffer.from(code).toString("base64")}`);

/** متصفّحٌ صغير: عنوانٌ يُقرأ ويُبدَّل بـreplaceState، وسجلٌّ يُعدّ. */
function fakeWindow(href) {
  const url = new URL(href);
  const replaced = [];
  globalThis.window = {
    location: {
      get hash() { return url.hash; },
      get pathname() { return url.pathname; },
      get search() { return url.search; },
    },
    history: {
      state: { kept: true },
      replaceState(state, _title, next) {
        replaced.push({ state, next });
        const target = new URL(next, url);
        url.hash = target.hash;
        url.search = target.search;
        url.pathname = target.pathname;
      },
    },
  };
  return { url, replaced };
}

test.afterEach(() => {
  delete globalThis.window;
});

const ADMIN_PAGES = ["DASHBOARD", "STUDENT_MANAGEMENT", "REPORTS", "ENTERTAINMENT"];

test("صفحةُ المشرف تُقرأ من العنوان بعد التحديث", () => {
  fakeWindow("https://manara-aiedu.com/#/admin/STUDENT_MANAGEMENT");
  assert.deepEqual(route.readDashboardRoute("admin", ADMIN_PAGES, "DASHBOARD"), {
    page: "STUDENT_MANAGEMENT",
    params: [],
  });
});

test("لا عنوان، أو عنوانُ دورٍ آخر، أو صفحةٌ ليست من القائمة: الرئيسية", () => {
  for (const href of [
    "https://manara-aiedu.com/",
    "https://manara-aiedu.com/#",
    "https://manara-aiedu.com/#/teacher/REPORTS",
    "https://manara-aiedu.com/#/admin/",
    "https://manara-aiedu.com/#/admin/NOT_A_PAGE",
    "https://manara-aiedu.com/#/admin/__proto__",
    "https://manara-aiedu.com/#section",
  ]) {
    fakeWindow(href);
    assert.deepEqual(
      route.readDashboardRoute("admin", ADMIN_PAGES, "DASHBOARD"),
      { page: "DASHBOARD", params: [] },
      href,
    );
  }
});

test("صفحةُ ولي الأمر تحمل الابنَ والمادة، بالعربية", () => {
  const hash = route.formatDashboardHash("parent", "CHILDREN", ["1792771749569", "الرياضيات"]);
  fakeWindow(`https://manara-aiedu.com/${hash}`);
  assert.deepEqual(route.readDashboardRoute("parent", ["DASHBOARD", "CHILDREN"], "DASHBOARD"), {
    page: "CHILDREN",
    params: ["1792771749569", "الرياضيات"],
  });
});

test("مُعاملٌ فارغ يقطع ما بعده: لا مادةَ بلا ابن", () => {
  assert.equal(route.formatDashboardHash("parent", "CHILDREN", [null, "الرياضيات"]), "#/parent/CHILDREN");
  assert.equal(route.formatDashboardHash("parent", "CHILDREN", ["c1", null]), "#/parent/CHILDREN/c1");
  assert.equal(route.formatDashboardHash("admin", "REPORTS"), "#/admin/REPORTS");
});

test("مُعاملٌ فيه / لا يكسر المسار", () => {
  const hash = route.formatDashboardHash("parent", "CHILDREN", ["c1", "علوم/عملي"]);
  assert.deepEqual(route.parseDashboardHash(hash, "parent"), {
    page: "CHILDREN",
    params: ["c1", "علوم/عملي"],
  });
});

test("الكتابةُ بـreplaceState، وتُبقي المسارَ والاستعلامَ وحالةَ السجلّ", () => {
  const { url, replaced } = fakeWindow("https://manara-aiedu.com/app?x=1");
  route.writeDashboardRoute("teacher", "ACCOUNT_MANAGEMENT");
  assert.equal(url.href, "https://manara-aiedu.com/app?x=1#/teacher/ACCOUNT_MANAGEMENT");
  assert.deepEqual(replaced[0].state, { kept: true });

  // العنوانُ نفسُه: لا كتابةَ ثانية.
  route.writeDashboardRoute("teacher", "ACCOUNT_MANAGEMENT");
  assert.equal(replaced.length, 1);
});

test("الخروجُ يمحو صفحةَ اللوحة، ولا يمسّ hashاً ليس لها", () => {
  const { url } = fakeWindow("https://manara-aiedu.com/#/admin/REPORTS");
  route.clearDashboardRoute();
  assert.equal(url.href, "https://manara-aiedu.com/");

  const other = fakeWindow("https://manara-aiedu.com/#section");
  route.clearDashboardRoute();
  assert.equal(other.url.hash, "#section");
  assert.equal(other.replaced.length, 0);
});

test("متصفّحٌ يرفض تعديلَ العنوان: لا استثناء", () => {
  fakeWindow("https://manara-aiedu.com/");
  globalThis.window.history.replaceState = () => {
    throw new Error("SecurityError");
  };
  assert.doesNotThrow(() => route.writeDashboardRoute("admin", "REPORTS"));
  assert.doesNotThrow(() => route.clearDashboardRoute());
});

test("ترميزٌ معطوب في العنوان لا يُسقط اللوحة", () => {
  assert.deepEqual(route.parseDashboardHash("#/parent/CHILDREN/%E0%A4%A", "parent"), {
    page: "CHILDREN",
    params: ["%E0%A4%A"],
  });
});
