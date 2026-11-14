import test from "node:test";
import assert from "node:assert/strict";
import {
  CHAT_IMAGE_MAX_BYTES,
  imageRecipientAllowed,
  isChatImageId,
  parseChatImage,
  teacherRecipient,
} from "../../../dist/lib/chatImage.mjs";

function png(size) {
  const bytes = Buffer.alloc(size, 3);
  Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]).copy(bytes, 0);
  return bytes.toString("base64");
}

test("لوحةٌ PNG سليمة تُقبل بنوعها", () => {
  const image = parseChatImage(png(5000));
  assert.equal(image.ok, true);
  assert.equal(image.mime, "image/png");
  assert.equal(image.bytes, 5000);
  assert.equal(parseChatImage(`data:image/png;base64,${png(5000)}`).ok, true);
});

test("ما ليس صورةً، أو أكبرُ من السقف، أو بلا ترميز: يُرفض", () => {
  assert.deepEqual(parseChatImage(undefined), { ok: false, error: "missing" });
  assert.equal(parseChatImage("@@@").error, "encoding");
  assert.equal(parseChatImage(Buffer.alloc(4000, 1).toString("base64")).error, "format");
  assert.equal(parseChatImage(png(CHAT_IMAGE_MAX_BYTES + 10)).error, "tooBig");
  assert.equal(parseChatImage(png(20)).error, "tooShort");
});

test("معرّفُ الصورة بشكله وحده، ومستلمُ المعلّم باسمه", () => {
  assert.equal(isChatImageId("chatimage_1700000000_abcdefgh"), true);
  assert.equal(isChatImageId("chatvoice_1700000000_abcdefgh"), false);
  assert.equal(isChatImageId("chatimage_x'); drop"), false);
  assert.equal(teacherRecipient("t1"), "teacher:t1");
  assert.equal(teacherRecipient(""), "");
});

test("الصورُ بين الطلاب وحدهم: الصفُّ أو زميل، لا المعلّم", () => {
  assert.equal(imageRecipientAllowed("all"), true);
  assert.equal(imageRecipientAllowed("student_42"), true);
  assert.equal(imageRecipientAllowed(teacherRecipient("t1")), false);
  assert.equal(imageRecipientAllowed(""), false);
});
