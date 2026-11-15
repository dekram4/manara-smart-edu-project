import test from "node:test";
import assert from "node:assert/strict";
import { gzipSync } from "node:zlib";
import {
  CHAT_FILE_MAX_BYTES,
  cleanFileName,
  isChatFileId,
  parseChatFile,
  sniffFile,
  storedFileBytes,
} from "../../../dist/lib/chatFile.mjs";

const pdf = () => Buffer.concat([Buffer.from("%PDF-1.7\n"), Buffer.alloc(4000, 32)]);
const zip = () => Buffer.concat([Buffer.from([0x50, 0x4b, 0x03, 0x04]), Buffer.alloc(3000, 7)]);

test("المستنداتُ بنوعها من بايتاتها: PDF وأوفيس والنصوص والصور", () => {
  assert.equal(sniffFile(pdf(), "درس.pdf"), "application/pdf");
  assert.equal(sniffFile(zip(), "واجب.docx"), "application/vnd.openxmlformats-officedocument.wordprocessingml.document");
  assert.equal(sniffFile(zip(), "جدول.xlsx"), "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet");
  assert.equal(sniffFile(Buffer.from([0xd0, 0xcf, 0x11, 0xe0, 1, 2, 3, 4]), "قديم.doc"), "application/msword");
  assert.equal(sniffFile(Buffer.from("مرحبا يا صف\nسطر ثان", "utf8"), "ملاحظات.txt"), "text/plain");
  assert.equal(sniffFile(Buffer.from([0x89, 0x50, 0x4e, 0x47, 0, 0, 0, 0]), "x.png"), "image/png");
});

test("ما ليس مستنداً معروفاً يُرفض ولو سُمّي باسم مستند", () => {
  assert.equal(sniffFile(Buffer.from([0x4d, 0x5a, 0x90, 0, 3, 0]), "درس.pdf"), null, "تنفيذيّ");
  assert.equal(sniffFile(zip(), "تطبيق.apk"), null, "حزمةُ تطبيق");
  assert.equal(sniffFile(Buffer.from([0, 1, 2, 3, 0]), "x.txt"), null, "ثنائيّ باسم نصّ");
  assert.equal(parseChatFile(Buffer.from([0x4d, 0x5a, 0x90, 0, 3, 0, 1, 1]).toString("base64"), "a.pdf").error, "format");
});

test("الملفُّ المضغوط يُفكّ ليُفحص، ويُخزَّن مضغوطاً، ويعود كما كان", () => {
  const text = Buffer.from("سطرٌ يتكرّر\n".repeat(4000), "utf8");
  const packed = gzipSync(text);
  assert.ok(packed.length < text.length / 10);
  const file = parseChatFile(packed.toString("base64"), "c:\\مجلد\\ملاحظات.txt", true);
  assert.equal(file.ok, true);
  assert.equal(file.gzip, true);
  assert.equal(file.bytes, text.length);
  assert.equal(file.name, "ملاحظات.txt");
  assert.deepEqual(storedFileBytes({ file: file.base64, gzip: true }), text);
});

test("السقف: بعد الفكّ لا قبله", () => {
  const big = Buffer.alloc(CHAT_FILE_MAX_BYTES + 100, 32);
  Buffer.from("%PDF-").copy(big);
  assert.equal(parseChatFile(gzipSync(big).toString("base64"), "x.pdf", true).error, "tooBig");
  assert.equal(parseChatFile(undefined, "x").error, "missing");
  assert.equal(parseChatFile("@@", "x").error, "encoding");
});

test("الاسمُ بلا مسارٍ ولا محارف خطرة، والمعرّفُ بشكله", () => {
  assert.equal(cleanFileName("../../etc/passwd"), "passwd");
  assert.equal(cleanFileName('a"<b>.pdf'), "ab.pdf");
  assert.equal(cleanFileName(""), "ملف");
  assert.equal(isChatFileId("chatfile_1700000000_abcdefgh"), true);
  assert.equal(isChatFileId("chatimage_1700000000_abcdefgh"), false);
});
