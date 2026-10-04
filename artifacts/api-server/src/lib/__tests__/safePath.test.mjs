import test from "node:test";
import assert from "node:assert/strict";
import path from "node:path";
import os from "node:os";
import { safeFilePath, VIDEO_FILE_NAME } from "../../../dist/lib/safePath.mjs";

const root = path.join(os.tmpdir(), "manara-uploads", "videos");
const opts = { pattern: VIDEO_FILE_NAME };

test("اسمُ فيديو سليم: مسارُه داخل المجلد", () => {
  const p = safeFilePath(root, "3f2a9c1e-1111-4222-8333-944445555666.mp4", opts);
  assert.equal(p, path.resolve(root, "3f2a9c1e-1111-4222-8333-944445555666.mp4"));
});

test("ملفُّ المالك: باللاحقة، وداخل المجلد", () => {
  const p = safeFilePath(root, "abc-1.mp4", { ...opts, suffix: ".owner.json" });
  assert.equal(p, path.resolve(root, "abc-1.mp4.owner.json"));
});

test("محاولاتُ الخروج من المجلد تُرفض كلُّها", () => {
  for (const name of [
    "../secret.mp4",
    "../../etc/passwd",
    "..\\..\\windows\\win.ini",
    "videos/../../x.mp4",
    "/etc/passwd",
    "C:\\Windows\\win.ini",
    "..",
    ".",
    "",
    "a.mp4\0.png",
    "%2e%2e%2fsecret.mp4",
  ]) {
    assert.equal(safeFilePath(root, name, opts), null, JSON.stringify(name));
  }
});

test("اسمٌ لا يطابق شكلَ الفيديو يُرفض وإن كان داخل المجلد", () => {
  assert.equal(safeFilePath(root, "notes.txt", opts), null);
  assert.equal(safeFilePath(root, "a b.mp4", opts), null);
  assert.equal(safeFilePath(root, "x.mp4.owner.json", opts), null);
});

test("لاحقةٌ تحاول الخروج تُرفض", () => {
  assert.equal(safeFilePath(root, "abc.mp4", { suffix: "/../../x" }), null);
});
