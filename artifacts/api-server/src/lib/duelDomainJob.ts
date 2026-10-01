/**
 * توليدُ أسئلة المبارزة من مجال الدروس وكتابتُها في `duel_questions`.
 *
 * يستدعيه موضعان، والحسابُ واحد:
 *   - جسرُ المزامنة بعد أن يحفظ المعلمُ درساً — للدروس المحفوظة وحدها.
 *   - زرُّ «توليد الأسئلة لكل الدروس» في لوحة المشرف — للدروس كلّها، مرّةً
 *     لما كُتب قبل أن يوجد التوليد. انظر `routes/duelQuestions.ts`.
 *
 * ── متى يُولَّد لدرس ──
 * حين لا يكون له أسئلةٌ ببصمة نصّه الحالي. فإعادةُ التشغيل رخيصة: ما وُلّد
 * يُتخطّى بلا نداءٍ للنموذج، وما فشل يُجرَّب من جديد. ودرسٌ تغيّر نصُّه تُضاف له
 * أسئلةٌ ولا تُحذف القديمة: هي في المادة نفسها وما زالت تصلح، ومن أراد إخراجَ
 * واحدٍ منها عطّله من اللوحة.
 *
 * ومادّةٌ لا يُعرف مفتاحُها لا يُولَّد لها: الفنيّة والبدنية تقعان معاً تحت
 * `other`، فيُسأل طالبُ الرسم عن كرة القدم.
 */

import { logger } from "./logger";
import { generateDuelDomainQuestions } from "./geminiBank";
import {
  DOMAIN_MIN_ACCEPTED,
  domainRows,
  duelSubjectKey,
  lessonOwner,
  lessonStamp,
  parseDomainQuestions,
  type DomainRow,
} from "./duelDomainBank";

type Config = { url: string; key: string };

function config(): Config | null {
  const url = process.env.SUPABASE_URL?.trim().replace(/\/+$/, "");
  const key = process.env.SUPABASE_SERVICE_ROLE_KEY?.trim();
  return url && key ? { url, key } : null;
}

async function rest(settings: Config, path: string, init: RequestInit = {}): Promise<unknown> {
  const response = await fetch(`${settings.url}/rest/v1/${path}`, {
    ...init,
    headers: {
      apikey: settings.key,
      Authorization: `Bearer ${settings.key}`,
      Accept: "application/json",
      ...(init.body ? { "Content-Type": "application/json" } : {}),
      ...(init.headers as Record<string, string> | undefined),
    },
  });
  const body = await response.text();
  if (!response.ok) throw new Error(body || `Supabase ${response.status}`);
  return body ? JSON.parse(body) : null;
}

function text(value: unknown): string {
  return typeof value === "string" ? value.trim() : "";
}

function records(value: unknown): Record<string, unknown>[] {
  return Array.isArray(value)
    ? value.filter((item): item is Record<string, unknown> => Boolean(item) && typeof item === "object")
    : [];
}

/** هل يستطيع الخادمُ التوليدَ أصلاً؟ القاعدةُ والنموذجُ معاً. */
export function duelDomainReady(): boolean {
  return config() !== null && Boolean(process.env.GEMINI_API_KEY?.trim());
}

/** حصيلةُ تشغيلة. */
export interface DomainRunSummary {
  /** دروسٌ تصلح للتوليد: لها نصٌّ ومادّةٌ معروفة. */
  total: number;
  /** ما فُحص منها حتى الآن. */
  processed: number;
  /** وُلّد لها في هذه التشغيلة. */
  generated: number;
  /** لها أسئلةٌ بنصّها الحالي من قبل. */
  skipped: number;
  /** فشل النموذج، أو خرجت دفعتُه أفقرَ من أن تُكتب. */
  failed: number;
  /** الأسئلةُ المكتوبة. */
  questions: number;
}

/**
 * يولّد للدروس [rows] ما ليس لها، ويعيد الحصيلة.
 *
 * [onProgress] يُستدعى بعد كل درس — لشريط التقدّم في لوحة المشرف.
 */
export async function refreshDuelDomainQuestions(
  rows: Record<string, unknown>[],
  onProgress?: (summary: DomainRunSummary) => void,
): Promise<DomainRunSummary> {
  const summary: DomainRunSummary = {
    total: 0,
    processed: 0,
    generated: 0,
    skipped: 0,
    failed: 0,
    questions: 0,
  };
  const settings = config();
  if (!settings || !process.env.GEMINI_API_KEY?.trim()) return summary;

  const lessons = rows
    .map((row) => {
      const data = row.data && typeof row.data === "object"
        ? (row.data as Record<string, unknown>)
        : null;
      const lessonText = data
        ? text(data.lessonContent) || text(data.lessonText)
        : "";
      return { id: text(row.id), data, lessonText };
    })
    .filter((lesson) =>
      lesson.id &&
      lesson.data &&
      lesson.lessonText &&
      duelSubjectKey(lesson.data.subject) !== "other",
    );
  summary.total = lessons.length;
  onProgress?.({ ...summary });
  if (!lessons.length) return summary;

  // ── ما وُلّد من قبل، بقراءةٍ لكل ثمانين درساً ──
  // المعلمُ يحفظ دروسَه كلَّها معاً، وزرُّ المشرف يمرّ على المدرسة كلّها:
  // سؤالٌ لكل درسٍ عشراتٌ أو مئاتٌ من الطلبات.
  const done = new Set<string>();
  for (let i = 0; i < lessons.length; i += 80) {
    const ids = lessons
      .slice(i, i + 80)
      .map((lesson) => `"${lesson.id.replace(/["\\]/g, "")}"`)
      .join(",");
    const existing = records(await rest(
      settings,
      `duel_questions?select=lesson_id,lesson_stamp&lesson_id=in.(${encodeURIComponent(ids)})`,
    ));
    for (const row of existing) {
      done.add(`${text(row.lesson_id)}|${text(row.lesson_stamp)}`);
    }
  }

  for (const lesson of lessons) {
    const data = lesson.data!;
    if (done.has(`${lesson.id}|${lessonStamp(lesson.lessonText)}`)) {
      summary.skipped += 1;
      summary.processed += 1;
      onProgress?.({ ...summary });
      continue;
    }
    try {
      const subject = text(data.subject);
      const raw = await generateDuelDomainQuestions({
        subject,
        unit: text(data.unit),
        lesson: text(data.lesson),
        grade: text(data.grade),
        lessonText: lesson.lessonText,
      });
      const { accepted, rejected } = parseDomainQuestions(raw, {
        subject,
        lessonText: lesson.lessonText,
      });
      if (accepted.length < DOMAIN_MIN_ACCEPTED) {
        summary.failed += 1;
        logger.warn(
          { id: lesson.id, got: accepted.length, rejected },
          "[duel-domain] batch too small to save",
        );
      } else {
        const written = await insertDomainRows(settings, domainRows(accepted, {
          id: lesson.id,
          subject,
          unit: text(data.unit),
          grade: text(data.grade),
          teacherId: lessonOwner(data),
          lessonText: lesson.lessonText,
        }));
        summary.generated += 1;
        summary.questions += written;
        logger.info({ id: lesson.id, written, rejected }, "[duel-domain] generated");
      }
    } catch (error) {
      summary.failed += 1;
      logger.error({ err: error, id: lesson.id }, "[duel-domain] generation failed");
    }
    summary.processed += 1;
    onProgress?.({ ...summary });
  }
  return summary;
}

/**
 * يكتب الصفوف، ويتجاوز ما في البنك منها.
 *
 * دفعةً واحدةً أوّلاً. فإن ردّها الفهرسُ الفريد على (المادة، نصّ السؤال) — سؤالٌ
 * ولّده النموذجُ كما هو في البنك المكتوب بمعرّفٍ آخر — كُتبت واحداً واحداً،
 * فلا يُسقط سؤالٌ مكرّرٌ أربعةَ عشرَ سؤالاً سليماً معه.
 */
async function insertDomainRows(settings: Config, rows: DomainRow[]): Promise<number> {
  const write = (body: DomainRow[]) =>
    rest(settings, "duel_questions?on_conflict=id", {
      method: "POST",
      headers: { Prefer: "resolution=ignore-duplicates,return=minimal" },
      body: JSON.stringify(body),
    });
  try {
    await write(rows);
    return rows.length;
  } catch {
    let written = 0;
    for (const row of rows) {
      try {
        await write([row]);
        written += 1;
      } catch {
        // مكرّرٌ في المادة: البنكُ فيه السؤالُ نفسه.
      }
    }
    return written;
  }
}

/**
 * كلُّ الدروس بنصوصها، للتشغيلة الشاملة. صفحةً صفحة: جدولُ الدروس فيه الشروحُ
 * كاملةً، وطلبٌ واحدٌ له كلّه قد يتجاوز ما يُرسل في ردّ.
 */
export async function allLessonRows(): Promise<Record<string, unknown>[]> {
  const settings = config();
  if (!settings) return [];
  const out: Record<string, unknown>[] = [];
  for (let offset = 0; ; offset += 200) {
    const page = records(await rest(
      settings,
      `lesson_configs?select=id,data&order=id.asc&limit=200&offset=${offset}`,
    ));
    out.push(...page);
    if (page.length < 200) break;
  }
  return out;
}
