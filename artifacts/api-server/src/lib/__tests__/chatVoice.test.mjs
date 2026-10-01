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

test("الصيغ: m4a وAAC خام وmp3 وogg وwav وwebm تُعرف بنوعها", () => {
  const withHead = (head) => {
    const bytes = Buffer.alloc(2000, 5);
    Buffer.from(head).copy(bytes, 0);
    return bytes.toString("base64");
  };
  const cases = [
    [m4a(2000), "audio/mp4"],
    [withHead([0xff, 0xf1, 0x50, 0x80]), "audio/aac"],
    [withHead([0x49, 0x44, 0x33, 0x04]), "audio/mpeg"],
    [withHead([0xff, 0xfb, 0x90, 0x00]), "audio/mpeg"],
    [withHead([0x4f, 0x67, 0x67, 0x53]), "audio/ogg"],
    [withHead([0x52, 0x49, 0x46, 0x46, 0, 0, 0, 0, 0x57, 0x41, 0x56, 0x45]), "audio/wav"],
    [withHead([0x1a, 0x45, 0xdf, 0xa3]), "audio/webm"],
  ];
  for (const [audio, mime] of cases) {
    const note = parseChatVoice(audio, 1000);
    assert.equal(note.ok, true, mime);
    assert.equal(note.mime, mime);
  }
});

test("data: URL تُقبل كما يكتبها بعض العملاء", () => {
  const note = parseChatVoice(`data:audio/mp4;base64,${m4a(3000)}`, 1000);
  assert.equal(note.ok, true);
  assert.equal(note.mime, "audio/mp4");
});
