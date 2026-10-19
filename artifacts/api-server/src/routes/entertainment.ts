import crypto from "node:crypto";
import { Router, type Request, type Response } from "express";
import rateLimit from "express-rate-limit";
import { requireAdmin } from "../middleware/adminAuth";
import { requireStudentSession } from "../middleware/studentAuth";
import { forwardedClientKey } from "../middleware/rateLimiter";
import { logger } from "../lib/logger";
import type { StudentActor } from "../lib/studentAccess";
import { GAME_CATALOG, catalogJson } from "../lib/gameEmbed";
import {
  adminGame,
  applyBuiltinOverrides,
  buildGame,
  builtinDefaults,
  builtinGameUrl,
  isBuiltinId,
  publicCatalog,
  fromKvRecord,
  fromTableRow,
  isVisibleToStudent,
  mergeGames,
  studentGame,
  toKvRecord,
  toTableRow,
  type EntertainmentGame,
} from "../lib/entertainment";
import {
  asRecords,
  listTeachers,
  readKv,
  rest,
  storeConfig,
  teacherIdentities,
  withTableFallback,
  writeKv,
  type StoreConfig,
} from "../lib/supabaseStore";
import { isCardOpenForStudent } from "./cardPermissions";

/**
 * «الترفيه والألعاب»: يديرها المشرف من لوحته، ويراها طلابُ المعلم المسند.
 *
 * ومعها ألعابُ الفهرس الأساسية الستّ: تظهر في القائمة نفسها بأصلها، ويُحفظ
 * ما يغيّره المشرف فيها صفّاً بمعرّفها — انظر `lib/entertainment`.
 *
 * المصدرُ جدول `entertainment_games`. وإن لم يُنشأ بعد حُفظت الألعاب في
 * `app_kv/smartEdu_entertainmentGames` وعملت كاملة، ويُقرأ المكانان معاً دائماً —
 * فما حُفظ قبل تشغيل `entertainment-games.sql` يبقى ظاهراً بعده.
 */
const router = Router();

const TABLE = "entertainment_games";
const KV_KEY = "smartEdu_entertainmentGames";

const RATE_LIMIT_SHARED = {
  windowMs: 60_000,
  standardHeaders: "draft-8" as const,
  legacyHeaders: false,
  keyGenerator: (req: Request) => forwardedClientKey(req),
  message: { error: "تجاوزت الحد المسموح به من الطلبات. يرجى الانتظار دقيقة." },
};
const readLimit = rateLimit({ ...RATE_LIMIT_SHARED, limit: 120 });
const writeLimit = rateLimit({ ...RATE_LIMIT_SHARED, limit: 30 });

function failureDetail(error: unknown): string {
  return error instanceof Error ? error.message.slice(0, 300) : "";
}

function text(value: unknown): string {
  return typeof value === "string" ? value.trim() : "";
}

async function readKvGames(config: StoreConfig): Promise<EntertainmentGame[]> {
  return asRecords(await readKv(config, KV_KEY))
    .map(fromKvRecord)
    .filter((game): game is EntertainmentGame => Boolean(game));
}

async function loadGames(
  config: StoreConfig,
): Promise<{ games: EntertainmentGame[]; storage: "table" | "kv" }> {
  const [kv, table] = await Promise.all([
    readKvGames(config),
    withTableFallback(
      TABLE,
      async () => asRecords(await rest(config, `${TABLE}?select=*&order=created_at.asc&limit=2000`))
        .map(fromTableRow)
        .filter((game): game is EntertainmentGame => Boolean(game)),
      async () => [] as EntertainmentGame[],
    ),
  ]);
  return { games: mergeGames(table.value, kv), storage: table.storage };
}

/**
 * كلُّ ألعاب الشاشة: الأساسيةُ بترتيب الفهرس وتعديلاتِ المشرف، ثم المضافة.
 */
function allGames(stored: EntertainmentGame[]): EntertainmentGame[] {
  return [
    ...applyBuiltinOverrides(builtinDefaults(GAME_CATALOG), stored),
    ...stored.filter((game) => !isBuiltinId(game.id)),
  ];
}

/** اتجاهُ اللعبة الأساسية وأبعادُها من الفهرس — لمسار الطالب. */
function catalogShape(game: EntertainmentGame) {
  const entry = GAME_CATALOG.find((item) => builtinGameUrl(item.id) === game.embedUrl);
  return entry ? { orientation: entry.orientation, width: entry.width, height: entry.height } : {};
}

// ── الفهرس العامّ ──
// `/api/game-catalog` يُطلب بلا جلسة عند كل فتحٍ للبطاقة، فتُحفظ التعديلاتُ
// المقروءة دقيقةً، وتُمحى عند كل حفظٍ من اللوحة على هذا الخادم.
let storedCache: { at: number; games: EntertainmentGame[] } | null = null;
const STORED_CACHE_MS = 60_000;

/**
 * الفهرسُ كما يُرسل للتطبيق، بعد تعديلات المشرف على الأساسية. وأيُّ تعذّرٍ
 * في القراءة يُرسل الفهرسَ بأصله: البطاقةُ لا تتعطّل لأن الجدول لم يُقرأ.
 */
export async function catalogForStudents(): Promise<Array<Record<string, unknown>>> {
  const config = storeConfig();
  if (!config) return catalogJson();
  try {
    if (!storedCache || Date.now() - storedCache.at > STORED_CACHE_MS) {
      storedCache = { at: Date.now(), games: (await loadGames(config)).games };
    }
    return publicCatalog(GAME_CATALOG, storedCache.games).map((game) => ({
      ...game,
      url: builtinGameUrl(game.id),
    }));
  } catch (error) {
    logger.warn({ err: error }, "[entertainment] catalog overrides unavailable");
    return catalogJson();
  }
}

async function removeFromKv(config: StoreConfig, id: string): Promise<void> {
  const records = asRecords(await readKv(config, KV_KEY));
  const kept = records.filter((record) => text(record.id) !== id);
  if (kept.length !== records.length) await writeKv(config, KV_KEY, kept);
}

async function saveGame(config: StoreConfig, game: EntertainmentGame): Promise<"table" | "kv"> {
  storedCache = null;
  const { storage } = await withTableFallback(
    TABLE,
    async () => {
      await rest(config, `${TABLE}?on_conflict=id`, {
        method: "POST",
        headers: { Prefer: "resolution=merge-duplicates,return=minimal" },
        body: JSON.stringify(toTableRow(game)),
      });
      // لعبةٌ حُفظت قبل الجدول ثم عُدّلت: صارت فيه، فلا تبقى نسختُها القديمة.
      await removeFromKv(config, game.id);
    },
    async () => {
      const records = asRecords(await readKv(config, KV_KEY));
      const index = records.findIndex((item) => text(item.id) === game.id);
      if (index >= 0) records[index] = toKvRecord(game);
      else records.push(toKvRecord(game));
      await writeKv(config, KV_KEY, records);
    },
  );
  return storage;
}

async function deleteGame(config: StoreConfig, id: string): Promise<void> {
  storedCache = null;
  await withTableFallback(
    TABLE,
    async () => {
      await rest(config, `${TABLE}?id=eq.${encodeURIComponent(id)}`, {
        method: "DELETE",
        headers: { Prefer: "return=minimal" },
      });
    },
    async () => undefined,
  );
  await removeFromKv(config, id);
}

function requireStore(res: Response): StoreConfig | null {
  const config = storeConfig();
  if (!config) res.status(503).json({ error: "Supabase غير مُعدّ على الخادم" });
  return config;
}

// ── لوحة المشرف ──────────────────────────────────────────────────────────

router.get("/entertainment", readLimit, requireAdmin, async (_req: Request, res: Response) => {
  const config = requireStore(res);
  if (!config) return;
  try {
    const [{ games, storage }, teachers] = await Promise.all([loadGames(config), listTeachers(config)]);
    res.set("Cache-Control", "no-store").json({ storage, teachers, games: allGames(games).map(adminGame) });
  } catch (error) {
    logger.error({ err: error }, "[entertainment] list failed");
    res.status(502).json({ error: "تعذر تحميل الألعاب", detail: failureDetail(error) });
  }
});

async function upsert(req: Request, res: Response, id: string | null): Promise<void> {
  const config = requireStore(res);
  if (!config) return;
  const body = (req.body && typeof req.body === "object" ? req.body : {}) as Record<string, unknown>;
  try {
    const [{ games }, teachers] = await Promise.all([loadGames(config), listTeachers(config)]);
    const existing = id ? allGames(games).find((game) => game.id === id) ?? null : null;
    if (id && !existing) {
      res.status(404).json({ error: "اللعبة غير موجودة" });
      return;
    }
    const built = buildGame(body, {
      newId: () => crypto.randomUUID(),
      now: new Date().toISOString(),
      teachers,
      existing,
    });
    if (!built.ok) {
      res.status(built.status).json({ error: built.error });
      return;
    }
    const storage = await saveGame(config, built.game);
    res.status(existing ? 200 : 201).json({ storage, game: adminGame(built.game) });
  } catch (error) {
    logger.error({ err: error }, "[entertainment] save failed");
    res.status(502).json({ error: "تعذر حفظ اللعبة", detail: failureDetail(error) });
  }
}

function gameIdParam(req: Request, res: Response): string | null {
  const id = text(req.params.id);
  if (!id || id.length > 200) {
    res.status(400).json({ error: "معرّف اللعبة غير صالح" });
    return null;
  }
  return id;
}

router.post("/entertainment", writeLimit, requireAdmin, (req: Request, res: Response) => upsert(req, res, null));

router.put("/entertainment/:id", writeLimit, requireAdmin, async (req: Request, res: Response) => {
  const id = gameIdParam(req, res);
  if (id) await upsert(req, res, id);
});

router.delete("/entertainment/:id", writeLimit, requireAdmin, async (req: Request, res: Response) => {
  const id = gameIdParam(req, res);
  if (!id) return;
  const config = requireStore(res);
  if (!config) return;
  try {
    await deleteGame(config, id);
    res.status(204).end();
  } catch (error) {
    logger.error({ err: error }, "[entertainment] delete failed");
    res.status(502).json({ error: "تعذر حذف اللعبة", detail: failureDetail(error) });
  }
});

// ── تطبيق الطالب ─────────────────────────────────────────────────────────

/**
 * ألعابُ معلّم الطالب المفعّلة، بصيغة فهرس الألعاب.
 *
 * المعلمُ من سجلّ الطالب على الخادم لا من الطلب: لا يطلب طالبٌ ألعابَ معلّمٍ
 * آخر بتغيير معامل. وإن كانت بطاقةُ «عالم الترفيه» مغلقةً عليه فلا ألعاب.
 */
router.get(
  "/student/entertainment",
  readLimit,
  requireStudentSession,
  async (_req: Request, res: Response) => {
    const student = res.locals.student as StudentActor;
    const config = requireStore(res);
    if (!config) return;
    try {
      const identities = await teacherIdentities(config, student.teacherId);
      if (!(await isCardOpenForStudent(config, student, identities, "games"))) {
        res.status(403).json({
          error: "عذراً، ليس لديك صلاحية لهذه البطاقة، يرجى مراجعة المشرف أو المعلم",
          code: "card_locked",
        });
        return;
      }
      const { games } = await loadGames(config);
      res.set("Cache-Control", "no-store").json({
        games: allGames(games)
          .filter((game) => isVisibleToStudent(game, identities))
          .map((game) => studentGame(game, catalogShape(game))),
      });
    } catch (error) {
      logger.error({ err: error }, "[entertainment] student list failed");
      res.status(502).json({ error: "تعذر تحميل الألعاب", detail: failureDetail(error) });
    }
  },
);

export default router;
