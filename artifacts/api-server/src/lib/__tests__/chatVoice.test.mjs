import test from "node:test";
import assert from "node:assert/strict";
import {
  CHAT_VOICE_MAX_BYTES,
  CHAT_VOICE_MAX_MS,
  isChatVoiceId,
  parseChatVoice,
} from "../../../dist/lib/chatVoice.mjs";

/** مقطعُ MPEG-4 مصطنع: «ftyp» في البايت الرابع، ثم حشو. */
function m4a(size) {
  const bytes = Buffer.alloc(size, 7);
  bytes.writeUInt32BE(24, 0);
  bytes.write("ftypM4A ", 4, "latin1");
  return bytes.toString("base64");
}

test("مقطعٌ سليم يُقبل بمدّته", () => {
  const note = parseChatVoice(m4a(4000), 3200.4);
  assert.equal(note.ok, true);
  assert.equal(note.bytes, 4000);
  assert.equal(note.durationMs, 3200);
});

test("المدّةُ تُحصر: سالبةٌ صفر، وطويلةٌ ثلاثون ثانية، ونصٌّ صفر", () => {
  assert.equal(parseChatVoice(m4a(4000), -5).durationMs, 0);
  assert.equal(parseChatVoice(m4a(4000), 999999).durationMs, CHAT_VOICE_MAX_MS);
  assert.equal(parseChatVoice(m4a(4000), "abc").durationMs, 0);
});

test("ضغطةٌ عابرةٌ وملفٌّ ضخم يُرفضان", () => {
  assert.deepEqual(parseChatVoice(m4a(100), 500), { ok: false, error: "tooShort" });
  assert.deepEqual(
    parseChatVoice(m4a(CHAT_VOICE_MAX_BYTES + 1), 500),
    { ok: false, error: "tooBig" },
  );
});

test("ليس صوتاً: ليس MPEG-4، أو ليس base64، أو لا شيء", () => {
  const png = Buffer.alloc(2000, 1);
  png.write("\x89PNG", 0, "latin1");
  assert.deepEqual(parseChatVoice(png.toString("base64"), 1), { ok: false, error: "format" });
  assert.deepEqual(parseChatVoice("not base64!!", 1), { ok: false, error: "encoding" });
  assert.deepEqual(parseChatVoice(undefined, 1), { ok: false, error: "missing" });
  assert.deepEqual(parseChatVoice(42, 1), { ok: false, error: "missing" });
});

test("معرّفُ المقطع: شكلُه وحده يُقبل", () => {
  assert.equal(isChatVoiceId("chatvoice_1700000000000_6f1c2d7e-1111-4222-8333-944445555666"), true);
  assert.equal(isChatVoiceId("chat_1700000000000_abc"), false);
  assert.equal(isChatVoiceId("chatvoice_../../etc"), false);
  assert.equal(isChatVoiceId("chatvoice_a,b"), false);
  assert.equal(isChatVoiceId(null), false);
});
