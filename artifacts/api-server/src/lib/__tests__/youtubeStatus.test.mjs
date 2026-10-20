/**
 * حالُ فيديو يوتيوب: المعرّفُ من الرابط، والتصنيفُ من ردّ oEmbed.
 */
import test from "node:test";
import assert from "node:assert/strict";

const { youtubeIdFromUrl, youtubeStatusFor } = await import("../../../dist/lib/youtubeStatus.mjs");

test("المعرّفُ من كل صيغ الرابط", () => {
  for (const url of [
    "https://www.youtube.com/embed/9_CqQ1z1K3E",
    "https://www.youtube.com/watch?v=9_CqQ1z1K3E&t=3",
    "https://youtu.be/9_CqQ1z1K3E",
    "https://m.youtube.com/shorts/9_CqQ1z1K3E",
  ]) assert.equal(youtubeIdFromUrl(url), "9_CqQ1z1K3E", url);
  assert.equal(youtubeIdFromUrl("https://example.com/video.mp4"), null);
  assert.equal(youtubeIdFromUrl("https://www.youtube.com/embed/short"), null);
});

test("ردُّ oEmbed: 404 محذوف، 401 ممنوعُ التضمين، والخطأُ العابر لا يُحكم به", () => {
  assert.equal(youtubeStatusFor(200), "available");
  assert.equal(youtubeStatusFor(404), "unavailable");
  assert.equal(youtubeStatusFor(401), "embed_blocked");
  assert.equal(youtubeStatusFor(500), "unknown");
});
