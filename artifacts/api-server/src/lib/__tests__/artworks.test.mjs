import test from "node:test";
import assert from "node:assert/strict";
import { gzipSync } from "node:zlib";
import {
  ARTWORK_DOC_MAX_CHARS,
  ARTWORK_IMAGE_MAX_BYTES,
  artworkTitle,
  isArtworkId,
  parseArtworkDoc,
  parseArtworkImage,
} from "../../../dist/lib/artworks.mjs";

function png(size) {
  const bytes = Buffer.alloc(size, 3);
  Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]).copy(bytes, 0);
  return bytes.toString("base64");
}

test("صورةُ اللوحة: سليمةٌ تُقبل، وأكبرُ من سقف اللوحات تُرفض", () => {
  assert.equal(parseArtworkImage(png(20_000)).ok, true);
  assert.equal(parseArtworkImage(png(ARTWORK_IMAGE_MAX_BYTES + 1)).error, "tooBig");
  assert.equal(parseArtworkImage("not-an-image").ok, false);
});

test("خطواتُ اللوحة: gzip بسقف، أو لا شيء", () => {
  const doc = gzipSync(Buffer.from(JSON.stringify({ id: "free:1", o: [] }))).toString("base64");
  assert.deepEqual(parseArtworkDoc(doc), { ok: true, doc });
  assert.deepEqual(parseArtworkDoc(undefined), { ok: true, doc: "" });
  assert.equal(parseArtworkDoc(Buffer.from("plain json").toString("base64")).ok, false);
  assert.equal(parseArtworkDoc("A".repeat(ARTWORK_DOC_MAX_CHARS + 4)).error, "docTooBig");
  assert.equal(parseArtworkDoc(42).ok, false);
});

test("المعرّفُ بشكله، والاسمُ مقصوصٌ وله بديل", () => {
  assert.equal(isArtworkId("artwork_1700000000_abcdefgh"), true);
  assert.equal(isArtworkId("chatimage_1700000000_abcdefgh"), false);
  assert.equal(isArtworkId("artwork_x&id=eq.y"), false);
  assert.equal(artworkTitle("  القطة   اللطيفة "), "القطة اللطيفة");
  assert.equal(artworkTitle(""), "لوحتي");
  assert.equal(artworkTitle("x".repeat(100)).length, 60);
});
