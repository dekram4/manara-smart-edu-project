import crypto from "node:crypto";

const baseUrl = (process.env.MEDIA_TEST_BASE_URL || `http://127.0.0.1:${process.env.PORT || "8080"}`).replace(
  /\/+$/,
  "",
);
const sessionSecret = process.env.SESSION_SECRET;

if (!sessionSecret) {
  throw new Error("SESSION_SECRET is required for the media integration test");
}

const testVideo = Buffer.from(
  // A minimal MP4 ftyp box is sufficient for the storage and HTTP checks.
  "000000186674797069736F6D0000020069736F6D69736F3261766331",
  "hex",
);

function teacherCookie(teacherId) {
  const payload = Buffer.from(
    JSON.stringify({
      role: "teacher",
      teacherId,
      expiresAt: Date.now() + 5 * 60 * 1000,
    }),
  ).toString("base64url");
  const signature = crypto
    .createHmac("sha256", sessionSecret)
    .update(payload)
    .digest("base64url");
  return `manara_teacher_session=${payload}.${signature}`;
}

async function expectResponse(response, expectedStatus, description) {
  if (response.status !== expectedStatus) {
    const detail = await response.text().catch(() => "");
    throw new Error(
      `${description}: expected ${expectedStatus}, got ${response.status}${detail ? ` (${detail.slice(0, 200)})` : ""}`,
    );
  }
  return response;
}

async function upload(cookie) {
  const response = await fetch(`${baseUrl}/api/media/upload`, {
    method: "POST",
    headers: {
      Cookie: cookie,
      "Content-Type": "video/mp4",
      "X-File-Name": "media-integration-test.mp4",
    },
    body: testVideo,
  });
  await expectResponse(response, 201, "MP4 upload");
  const result = await response.json();
  if (
    result.storage !== "supabase" ||
    typeof result.url !== "string" ||
    !result.url.includes("/storage/v1/object/public/") ||
    typeof result.storagePath !== "string"
  ) {
    throw new Error("Upload did not return a public Supabase Storage URL");
  }
  return result;
}

async function deleteVideo(cookie, url) {
  return fetch(`${baseUrl}/api/media/delete`, {
    method: "POST",
    headers: {
      Cookie: cookie,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({ url }),
  });
}

const ownerCookie = teacherCookie("media-integration-owner");
const otherTeacherCookie = teacherCookie("media-integration-other");
let uploaded = null;

try {
  uploaded = await upload(ownerCookie);

  const rangeResponse = await fetch(uploaded.url, {
    headers: { Range: "bytes=0-15" },
  });
  await expectResponse(rangeResponse, 206, "Public MP4 Range request");
  const contentRange = rangeResponse.headers.get("content-range") || "";
  if (!contentRange.startsWith("bytes 0-") || (await rangeResponse.arrayBuffer()).byteLength === 0) {
    throw new Error("Public MP4 Range response did not contain the requested bytes");
  }

  const forbiddenDelete = await deleteVideo(otherTeacherCookie, uploaded.url);
  await expectResponse(
    forbiddenDelete,
    403,
    "Deleting another teacher's video",
  );

  const ownerDelete = await deleteVideo(ownerCookie, uploaded.url);
  await expectResponse(ownerDelete, 204, "Owner video deletion");
  uploaded = null;
  console.log("Media integration passed: upload, public Range playback, ownership check, and cleanup.");
} finally {
  if (uploaded) {
    const cleanup = await deleteVideo(ownerCookie, uploaded.url);
    if (!cleanup.ok && cleanup.status !== 404) {
      console.error(`Test cleanup failed with HTTP ${cleanup.status}`);
      process.exitCode = 1;
    }
  }
}