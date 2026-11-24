/**
 * أدواتٌ مشتركة لسكربتات النسخة المفتوحة: قراءةُ `.env.open`، والاتصالُ
 * بالقاعدتين — القديمةُ للقراءة وحدها، والجديدةُ `manara-open-app`.
 *
 * بلا اعتماداتٍ خارجية: Node 20 وحده (fetch مدمج).
 */

import { readFileSync, existsSync } from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

export const here = path.dirname(fileURLToPath(import.meta.url));
export const editionRoot = path.resolve(here, "..");
export const repoRoot = path.resolve(editionRoot, "..");

/** يقرأ `.env.open` من جذر المستودع (أو [file]) دون أن يطغى على بيئةٍ مضبوطة. */
export function loadEnvOpen(file = path.join(repoRoot, ".env.open")) {
  if (!existsSync(file)) return false;
  for (const line of readFileSync(file, "utf8").split(/\r?\n/)) {
    const m = line.match(/^\s*([A-Z0-9_]+)\s*=\s*(.*?)\s*$/);
    if (!m || line.trim().startsWith("#")) continue;
    const value = m[2].replace(/^(['"])(.*)\1$/, "$2");
    if (process.env[m[1]] === undefined) process.env[m[1]] = value;
  }
  return true;
}

export function arg(name, fallback = undefined) {
  const flag = `--${name}`;
  const i = process.argv.indexOf(flag);
  if (i === -1) {
    const eq = process.argv.find((a) => a.startsWith(`${flag}=`));
    return eq ? eq.slice(flag.length + 1) : fallback;
  }
  const next = process.argv[i + 1];
  return next && !next.startsWith("--") ? next : true;
}

export const cleanUrl = (u) => String(u || "").trim().replace(/\/+$/, "");

export function required(name) {
  const value = process.env[name]?.trim();
  if (!value) {
    console.error(`✖ المتغيّر ${name} غير مضبوط (في .env.open أو البيئة).`);
    process.exit(2);
  }
  return value;
}

/**
 * عميلُ REST لقاعدةٍ واحدة. و[readOnly] يمنع كلَّ طلبٍ غير GET قبل أن يخرج —
 * القاعدةُ القديمة لا تُكتب من هنا ولو أخطأ مَن يعدّل السكربت.
 */
export function client({ url, key, readOnly = false, label }) {
  const base = cleanUrl(url);
  async function call(resource, init = {}) {
    const method = (init.method || "GET").toUpperCase();
    if (readOnly && method !== "GET") {
      throw new Error(`[${label}] قاعدةٌ للقراءة وحدها: رُفض ${method} ${resource}`);
    }
    const response = await fetch(`${base}/rest/v1/${resource}`, {
      ...init,
      method,
      headers: {
        apikey: key,
        Authorization: `Bearer ${key}`,
        Accept: "application/json",
        ...(init.body ? { "Content-Type": "application/json" } : {}),
        ...(init.headers || {}),
      },
    });
    const text = await response.text();
    if (!response.ok) {
      const error = new Error(`[${label}] ${method} ${resource.split("?")[0]} → ${response.status}: ${text.slice(0, 300)}`);
      error.status = response.status;
      throw error;
    }
    return text ? JSON.parse(text) : null;
  }
  /** كلُّ الصفوف، صفحةً صفحة: PostgREST يقف عند ألف صفٍّ في الطلب الواحد. */
  async function all(table, query = "select=*") {
    const rows = [];
    const page = 1000;
    for (let offset = 0; ; offset += page) {
      const batch = await call(`${table}?${query}&limit=${page}&offset=${offset}`);
      rows.push(...batch);
      if (batch.length < page) return rows;
    }
  }
  return { call, all, url: base, label };
}
