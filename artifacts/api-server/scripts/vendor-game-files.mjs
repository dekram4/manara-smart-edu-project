/**
 * يولّد نسخَ ملفّات الألعاب المُعادةِ كتابتُها في static-games/<معرّف>/<مسار>.
 *
 * هذه النسخُ تُقدَّم كما هي (انظر REWRITTEN_GAME_FILES في src/lib/gameEmbed.ts):
 * يُشغَّل هذا حين يحدّث GameDistribution لعبةً فتتوقّف، ثم تُراجع النسخُ الجديدة
 * (git diff) قبل رفعها.
 *
 *   node build.mjs && node scripts/vendor-game-files.mjs
 */
import fs from "node:fs";
import path from "node:path";
import crypto from "node:crypto";
import { fileURLToPath } from "node:url";
import {
  GAME_HOST,
  rewriteGameHtml,
  rewriteGameScript,
  rewrittenGameFileList,
} from "../dist/lib/gameEmbed.mjs";

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "../static-games");

for (const [gameId, file] of rewrittenGameFileList()) {
  const response = await fetch(`${GAME_HOST}/${gameId}/${file}`);
  if (!response.ok) throw new Error(`${gameId}/${file}: HTTP ${response.status}`);
  const source = await response.text();
  const rewritten = file.endsWith(".html")
    ? rewriteGameHtml(gameId, source)
    : rewriteGameScript(gameId, source);
  const target = path.join(root, gameId, file);
  fs.mkdirSync(path.dirname(target), { recursive: true });
  fs.writeFileSync(target, rewritten, "utf8");
  const hash = crypto.createHash("sha256").update(rewritten).digest("hex").slice(0, 16);
  console.log(`${gameId}/${file}  ${Buffer.byteLength(rewritten)} bytes  sha256:${hash}`);
}
