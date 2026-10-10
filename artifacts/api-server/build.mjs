import { createRequire } from "node:module";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { build as esbuild } from "esbuild";
import esbuildPluginPino from "esbuild-plugin-pino";
import { rm } from "node:fs/promises";

// Plugins (e.g. 'esbuild-plugin-pino') may use `require` to resolve dependencies
globalThis.require = createRequire(import.meta.url);

const artifactDir = path.dirname(fileURLToPath(import.meta.url));

async function buildAll() {
  const distDir = path.resolve(artifactDir, "dist");
  await rm(distDir, { recursive: true, force: true });

  await esbuild({
    // ── الخادمُ نقطةُ دخول، والوحداتُ النقيّة نقاطٌ إلى جانبه ──
    //
    // هذا البناء يحزم كل شيء في `dist/index.mjs`، فلا مجلّد `dist/lib`
    // فيه أصلاً. وهذه الوحدات تُخرَج إليه لسببين:
    //
    // `challengeBank` ليستوردها سكربتُ التوليد. والبديل — أن يكرّر
    // السكربت قواعد القبول — يجعل تصفيةَ الدفعة تفترق عن تصفية الخادم
    // عند أوّل تعديل في إحداهما، فيُحفظ في البنك ما يردّه المسار.
    //
    // ── والباقيةُ ليُختبر ما بُني لا ما كُتب ──
    //
    // اختباراتُ `src/lib/__tests__` تستورد من `dist/lib/*.mjs`: تُشغّل
    // بـ`node --test` بلا مُحوِّلٍ في المسار، فلا تقرأ TypeScript. وكانت
    // تستورد وحداتٍ لا يُخرجها هذا البناء، فيفشل الاستيراد ويطبع الملفُّ
    // «تُخطّى» ويخرج بصفر — أخضرَ دائماً على كل جهاز وفي كل مرّة.
    //
    // فما يُختبر يُخرَج. وزيادتُها لا تثقل الخادم: `dist/index.mjs` يحزم
    // نسخته منها كما كان، وهذه ملفّاتٌ إلى جانبه لا تُستورد في الإنتاج.
    entryPoints: [
      path.resolve(artifactDir, "src/index.ts"),
      path.resolve(artifactDir, "src/lib/challengeBank.ts"),
      path.resolve(artifactDir, "src/lib/aiQuota.ts"),
      path.resolve(artifactDir, "src/lib/embeddings.ts"),
      path.resolve(artifactDir, "src/lib/questionMath.ts"),
      path.resolve(artifactDir, "src/lib/arabicText.ts"),
      path.resolve(artifactDir, "src/lib/trustedOrigin.ts"),
      path.resolve(artifactDir, "src/lib/interactiveStudy.ts"),
      path.resolve(artifactDir, "src/lib/duel.ts"),
      path.resolve(artifactDir, "src/lib/chatVoice.ts"),
      path.resolve(artifactDir, "src/lib/chatLifecycle.ts"),
      path.resolve(artifactDir, "src/lib/gameEmbed.ts"),
      path.resolve(artifactDir, "src/lib/safePath.ts"),
      path.resolve(artifactDir, "src/lib/duelQuestions.ts"),
      path.resolve(artifactDir, "src/lib/duelDomainBank.ts"),
      path.resolve(artifactDir, "src/lib/challengeQuestions.ts"),
      path.resolve(artifactDir, "src/lib/leaderboard.ts"),
      path.resolve(artifactDir, "src/lib/cinema.ts"),
      path.resolve(artifactDir, "src/lib/cardPermissions.ts"),
    ],
    platform: "node",
    bundle: true,
    format: "esm",
    outdir: distDir,
    outExtension: { ".js": ".mjs" },
    logLevel: "info",
    // Some packages may not be bundleable, so we externalize them, we can add more here as needed.
    // Some of the packages below may not be imported or installed, but we're adding them in case they are in the future.
    // Examples of unbundleable packages:
    // - uses native modules and loads them dynamically (e.g. sharp)
    // - use path traversal to read files (e.g. @google-cloud/secret-manager loads sibling .proto files)
    external: [
      "*.node",
      "sharp",
      "better-sqlite3",
      "sqlite3",
      "canvas",
      "bcrypt",
      "argon2",
      "fsevents",
      "re2",
      "farmhash",
      "xxhash-addon",
      "bufferutil",
      "utf-8-validate",
      "ssh2",
      "cpu-features",
      "dtrace-provider",
      "isolated-vm",
      "lightningcss",
      "pg-native",
      "oracledb",
      "mongodb-client-encryption",
      "nodemailer",
      "handlebars",
      "knex",
      "typeorm",
      "protobufjs",
      "onnxruntime-node",
      "@tensorflow/*",
      "@prisma/client",
      "@mikro-orm/*",
      "@grpc/*",
      "@swc/*",
      "@aws-sdk/*",
      "@azure/*",
      "@opentelemetry/*",
      "@google-cloud/*",
      "@google/*",
      "googleapis",
      "firebase-admin",
      "@parcel/watcher",
      "@sentry/profiling-node",
      "@tree-sitter/*",
      "aws-sdk",
      "classic-level",
      "dd-trace",
      "ffi-napi",
      "grpc",
      "hiredis",
      "kerberos",
      "leveldown",
      "miniflare",
      "mysql2",
      "newrelic",
      "odbc",
      "piscina",
      "realm",
      "ref-napi",
      "rocksdb",
      "sass-embedded",
      "sequelize",
      "serialport",
      "snappy",
      "tinypool",
      "usb",
      "workerd",
      "wrangler",
      "zeromq",
      "zeromq-prebuilt",
      "playwright",
      "puppeteer",
      "puppeteer-core",
      "electron",
    ],
    sourcemap: "linked",
    plugins: [
      // pino relies on workers to handle logging, instead of externalizing it we use a plugin to handle it
      esbuildPluginPino({ transports: ["pino-pretty"] })
    ],
    // Make sure packages that are cjs only (e.g. express) but are bundled continue to work in our esm output file
    banner: {
      js: `import { createRequire as __bannerCrReq } from 'node:module';
import __bannerPath from 'node:path';
import __bannerUrl from 'node:url';

globalThis.require = __bannerCrReq(import.meta.url);
globalThis.__filename = __bannerUrl.fileURLToPath(import.meta.url);
globalThis.__dirname = __bannerPath.dirname(globalThis.__filename);
    `,
    },
  });
}

buildAll().catch((err) => {
  console.error(err);
  process.exit(1);
});
