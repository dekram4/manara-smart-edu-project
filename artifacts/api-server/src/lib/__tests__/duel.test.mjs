/**
 * اختبارات منطق مباراة التحدي.
 *
 * ── لماذا تُختبر بشدّة ──
 * الفوزُ تُصرف عليه جوهرة، فكلُّ ثغرةٍ هنا بابٌ إلى رصيدٍ يُجمع بلا لعب:
 * نتيجةٌ مدّعاة، أو نتيجةٌ تُكتب مرّتين، أو تعادلٌ يُربح فيه الطرفان،
 * أو طالبٌ يتحدّى نفسه.
 *
 * والتطبيقُ هو من يدّعي النتيجة، فهذه الدوالُّ هي الحارس.
 *
 * التشغيل:
 *   npm run build && node --test src/lib/__tests__/duel.test.mjs
 */

import test from "node:test";
import assert from "node:assert/strict";

const target = process.env.DUEL_MODULE ?? "../../../dist/lib/duel.mjs";
let mod;
try {
  mod = await import(target);
} catch (error) {
  throw new Error(
    `تعذّر استيراد ${target} — شغّل npm run build أولاً. (${error?.message ?? error})`,
  );
}

const {
  DUEL_GAMES,
  DUEL_MAX_SCORE,
  DUEL_POINTS_PER_QUESTION,
  DUEL_QUESTION_SECONDS,
  DUEL_ROUNDS,
  DUEL_WIN_GEMS,
  scoresFromAnswers,
  canSubmit,
  classKey,
  isDuelGame,
  matchId,
  outcomeOf,
  parseScore,
  sideOf,
  standingsOf,
} = mod;

const row = ({ host = 4, guest = 2 } = {}) => ({
  hostId: "s_host",
  guestId: "s_guest",
  hostScore: host,
  guestScore: guest,
});

test("خمسُ جواهرَ للفائز — وتُمنع إعادتُها بمفتاح الدرس في awardDuelWin", () => {
  assert.equal(DUEL_WIN_GEMS, 5);
});

test("والألعابُ أربعٌ معروفةٌ بأسمائها", () => {
  assert.deepEqual([...DUEL_GAMES], ["sprint", "balloons", "tug", "gems"]);
  assert.ok(isDuelGame("sprint"));
  assert.ok(!isDuelGame("chess"));
  assert.ok(!isDuelGame(""));
  assert.ok(!isDuelGame(null));
});

// ── النتيجة ──

test("النتيجةُ محصورةٌ بعدد الأسئلة", () => {
  assert.equal(parseScore(0), 0);
  assert.equal(parseScore(DUEL_MAX_SCORE), DUEL_MAX_SCORE);
  assert.equal(parseScore("3"), 3);
});

test("وما فوق السقف يُردّ لا يُقصّ", () => {
  // القصُّ يقبل طلباً مدّعىً ويسجّله صحيحاً، والردُّ يُظهر الخطأ لمن أرسله.
  assert.equal(parseScore(DUEL_MAX_SCORE + 1), null);
  assert.equal(parseScore(99999), null);
  assert.equal(parseScore(-1), null);
  assert.equal(parseScore(2.5), null);
  for (const bad of [null, undefined, "", "كثير", {}, []]) {
    assert.equal(parseScore(bad), null, `${bad}`);
  }
});

// ── من فاز ──

test("يفوز الأعلى نتيجةً", () => {
  assert.deepEqual(outcomeOf(row({ host: 5, guest: 3 })), {
    settled: true,
    winnerId: "s_host",
    draw: false,
  });
  assert.deepEqual(outcomeOf(row({ host: 1, guest: 4 })), {
    settled: true,
    winnerId: "s_guest",
    draw: false,
  });
});

test("ولا تنتهي المباراةُ بنتيجةٍ واحدة", () => {
  // نصفُ المباراة ليس مباراة: المتحدّي الذي لعب وحده ينتظر زميلَه — وهي
  // المباراةُ المؤجَّلة بعينها.
  assert.deepEqual(outcomeOf(row({ host: 5, guest: null })), { settled: false });
  assert.deepEqual(outcomeOf(row({ host: null, guest: 5 })), { settled: false });
  assert.deepEqual(outcomeOf(row({ host: null, guest: null })), {
    settled: false,
  });
  // وصفرٌ نتيجةٌ حاضرة لا غائبة: من أخطأ في كل سؤالٍ لعب.
  assert.equal(outcomeOf(row({ host: 0, guest: 0 })).settled, true);
});

test("والتعادلُ لا فائزَ له، فلا جوهرة", () => {
  // جوهرةٌ لكلٍّ في التعادل تجعله مقصوداً: يتّفق زميلان أن يُصيبا واحداً
  // فيربحا معاً في كل مباراة.
  const outcome = outcomeOf(row({ host: 3, guest: 3 }));
  assert.equal(outcome.settled, true);
  assert.equal(outcome.draw, true);
  assert.equal(outcome.winnerId, null);
});

// ── من يكتب ──

test("لا يكتب في المباراة إلا طرفاها", () => {
  const match = row();
  assert.equal(sideOf(match, "s_host"), "host");
  assert.equal(sideOf(match, "s_guest"), "guest");
  assert.equal(sideOf(match, "s_other"), null);
  assert.equal(canSubmit(match, "s_other"), false);
});

test("ولا تُكتب نتيجةٌ مرّتين", () => {
  // إعادةُ الإرسال — ضغطةٌ مكرّرة أو شبكةٌ أعادت الطلب — كانت ستُبدّل
  // النتيجةَ بعد أن حُسب الفوز وصُرفت الجوهرة.
  const fresh = { ...row({ host: null, guest: null }) };
  assert.equal(canSubmit(fresh, "s_host"), true);
  assert.equal(canSubmit({ ...fresh, hostScore: 3 }, "s_host"), false);
  assert.equal(canSubmit({ ...fresh, hostScore: 3 }, "s_guest"), true);
  // وصفرٌ نتيجةٌ كُتبت: لا يُعاد إرسالُها.
  assert.equal(canSubmit({ ...fresh, hostScore: 0 }, "s_host"), false);
});

// ── الصفّ ──

test("مفتاحُ الصفّ يجمع المعلم والصفّ", () => {
  assert.equal(classKey("t_7", "الرابع"), "t_7:الرابع");
  // وناقصٌ يعني لا نطاق: فلا تُرسل دعوةٌ بلا حدّ.
  assert.equal(classKey("", "الرابع"), "");
  assert.equal(classKey("t_7", ""), "");
  assert.equal(classKey(null, null), "");
});

test("ومعرّفُ المباراة لا يتصادم", () => {
  const ids = new Set(Array.from({ length: 500 }, () => matchId()));
  assert.equal(ids.size, 500);
  assert.match(matchId(), /^duel_/);
});

// ── الصدارة ──

test("الصدارةُ تُحسب من المباريات لا من عدّاد", () => {
  // عدّادٌ يُزاد عند كل فوز يفترق عن السجلّ عند أوّل طلبٍ يُعاد أو صفٍّ
  // يُصحَّح بيد.
  const standings = standingsOf([
    { hostId: "a", guestId: "b", hostScore: 5, guestScore: 1 },
    { hostId: "a", guestId: "c", hostScore: 4, guestScore: 2 },
    { hostId: "b", guestId: "c", hostScore: 1, guestScore: 5 },
    // معلّقةٌ لا تُحسب.
    { hostId: "a", guestId: "b", hostScore: 5, guestScore: null },
    // وتعادلٌ يُحسب لعباً لا فوزاً.
    { hostId: "b", guestId: "c", hostScore: 3, guestScore: 3 },
  ]);
  assert.deepEqual(standings, [
    { studentId: "a", wins: 2, played: 2 },
    { studentId: "c", wins: 1, played: 3 },
    { studentId: "b", wins: 0, played: 3 },
  ]);
});

test("وصدارةٌ بلا مباريات قائمةٌ فارغة", () => {
  assert.deepEqual(standingsOf([]), []);
});

// ── نقاطُ السرعة ──

test("طولُ المباراة ثمانيةٌ على الأقلّ وعشرةٌ المعتاد", () => {
  // ── والطلبُ المُبلَّغ: من ٨ إلى ١٠ ──
  // خمسةُ أسئلةٍ تنتهي في أربعين ثانية، فتنتهي المباراةُ قبل أن تبدأ الإثارة.
  assert.ok(DUEL_ROUNDS >= 8 && DUEL_ROUNDS <= 10, `${DUEL_ROUNDS}`);
});

test("أقصى نتيجةٍ: كلُّ سؤالٍ كُسب", () => {
  assert.equal(DUEL_MAX_SCORE, DUEL_ROUNDS * DUEL_POINTS_PER_QUESTION);
  assert.equal(parseScore(DUEL_MAX_SCORE), DUEL_MAX_SCORE);
  assert.ok(DUEL_QUESTION_SECONDS >= 5 && DUEL_QUESTION_SECONDS <= 20);
});

// ── أوّلُ صحيحٍ يكسب السؤال ──

const answer = (studentId, questionIndex, won) => ({ studentId, questionIndex, won });

test("النقاطُ لمن كسب السؤال وحده", () => {
  const { hostScore, guestScore } = scoresFromAnswers(
    [answer("h", 0, true), answer("g", 0, false), answer("g", 1, true), answer("g", 2, true)],
    "h",
    "g",
  );
  assert.equal(hostScore, DUEL_POINTS_PER_QUESTION);
  assert.equal(guestScore, 2 * DUEL_POINTS_PER_QUESTION);
});

test("الجوابُ الصحيحُ الثاني لا نقاطَ له", () => {
  // `won` تقرّره القاعدة: الثاني يُسجَّل صحيحاً غيرَ فائز.
  const { hostScore, guestScore } = scoresFromAnswers(
    [answer("h", 3, true), answer("g", 3, false)],
    "h",
    "g",
  );
  assert.deepEqual([hostScore, guestScore], [DUEL_POINTS_PER_QUESTION, 0]);
});

test("ولا يُكسب سؤالٌ مرّتين ولو وصل صفّان فائزان", () => {
  // الفهرسُ الفريدُ يمنعه في القاعدة؛ والحسابُ لا يعتمد عليه وحده.
  const { hostScore, guestScore } = scoresFromAnswers(
    [answer("h", 4, true), answer("g", 4, true), answer("h", 4, true)],
    "h",
    "g",
  );
  assert.equal(hostScore + guestScore, DUEL_POINTS_PER_QUESTION);
});

test("وإجابةُ من ليس طرفاً لا تُحسب ولا تحجز السؤال", () => {
  const { hostScore, guestScore } = scoresFromAnswers(
    [answer("stranger", 5, true), answer("g", 5, true)],
    "h",
    "g",
  );
  assert.deepEqual([hostScore, guestScore], [0, DUEL_POINTS_PER_QUESTION]);
});

test("ولا إجابات: صفرٌ لكلٍّ، فتعادلٌ بلا فائز", () => {
  const { hostScore, guestScore } = scoresFromAnswers([], "h", "g");
  const outcome = outcomeOf({ hostId: "h", guestId: "g", hostScore, guestScore });
  assert.deepEqual(outcome, { settled: true, winnerId: null, draw: true });
});

test("والأعلى نقاطاً يفوز", () => {
  const scores = scoresFromAnswers(
    [answer("h", 0, true), answer("h", 1, true), answer("g", 2, true)],
    "h",
    "g",
  );
  const outcome = outcomeOf({ hostId: "h", guestId: "g", ...scores });
  assert.equal(outcome.winnerId, "h");
});

// ── الغرفة: دعوةُ زميلٍ أو أكثر ──

const {
  partyRoomOf,
  canRespond,
  partyScores,
  rankParty,
  legacyPlayers,
  DUEL_INVITE_SECONDS,
  DUEL_MAX_INVITEES,
  DUEL_START_DELAY_MS,
} = mod;
const T0 = Date.parse("2026-10-01T10:00:00Z");
const iso = (ms) => new Date(T0 + ms).toISOString();
const now = (ms) => new Date(T0 + ms);
const pending = { status: "pending", createdAt: iso(0) };
const host = { studentId: "h", role: "host", respondedAt: iso(0), accepted: true };
const guest = (id, ms = null, accepted = null) => ({
  studentId: id,
  role: "guest",
  respondedAt: ms === null ? null : iso(ms),
  accepted,
});

test("المهلةُ عشرون ثانية، وخمسةُ مدعوّين على الأكثر", () => {
  assert.equal(DUEL_INVITE_SECONDS, 20);
  assert.equal(DUEL_MAX_INVITEES, 5);
});

test("الكلُّ لم يردّ والمهلةُ قائمة: ننتظر، ولا موعد", () => {
  const room = partyRoomOf(pending, [host, guest("a"), guest("b")], now(5_000));
  assert.equal(room.phase, "invited");
  assert.equal(room.startAt, null);
  assert.deepEqual(room.statuses, { h: "host", a: "pending", b: "pending" });
  assert.equal(room.decideBy.getTime(), T0 + 20_000);
});

test("وافق الجميعُ في خمس ثوانٍ: يبدأ فوراً لا بعد العشرين", () => {
  const room = partyRoomOf(
    pending,
    [host, guest("a", 3_000, true), guest("b", 5_000, true)],
    now(5_100),
  );
  assert.equal(room.phase, "ready");
  assert.deepEqual(room.roster, ["h", "a", "b"]);
  assert.equal(room.startAt.getTime(), T0 + 5_000 + DUEL_START_DELAY_MS);
});

test("ردّ الجميعُ وبعضُهم رفض: يبدأ فوراً بمن وافق", () => {
  const room = partyRoomOf(
    pending,
    [host, guest("a", 2_000, true), guest("b", 4_000, false)],
    now(4_500),
  );
  assert.equal(room.phase, "ready");
  assert.deepEqual(room.roster, ["h", "a"]);
  assert.equal(room.statuses.b, "declined");
});

test("ما زال واحدٌ لم يردّ: ننتظره حتى المهلة", () => {
  const room = partyRoomOf(pending, [host, guest("a", 2_000, true), guest("b")], now(10_000));
  assert.equal(room.phase, "invited");
});

test("انتهت المهلة: من لم يردّ يُستبعد، ويبدأ بمن وافق من موعد المهلة", () => {
  const room = partyRoomOf(
    pending,
    [host, guest("a", 2_000, true), guest("b"), guest("c")],
    now(20_500),
  );
  assert.equal(room.phase, "ready");
  assert.deepEqual(room.roster, ["h", "a"]);
  assert.equal(room.startAt.getTime(), T0 + 20_000 + DUEL_START_DELAY_MS);
  assert.equal(room.statuses.b, "late");
});

test("لم يوافق أحد — رفضوا أو لم يردّوا: يُلغى", () => {
  assert.equal(
    partyRoomOf(pending, [host, guest("a", 1_000, false), guest("b", 2_000, false)], now(2_100)).phase,
    "expired",
  );
  assert.equal(partyRoomOf(pending, [host, guest("a"), guest("b")], now(20_001)).phase, "expired");
});

test("ردٌّ بعد المهلة لا يُحسب ولا يُقبل", () => {
  const players = [host, guest("a", 2_000, true), guest("b", 21_000, true)];
  const room = partyRoomOf(pending, players, now(22_000));
  assert.deepEqual(room.roster, ["h", "a"]);
  assert.equal(room.statuses.b, "late");
  assert.equal(canRespond(pending, [host, guest("a")], "a", now(19_000)), true);
  assert.equal(canRespond(pending, [host, guest("a")], "a", now(20_001)), false);
  assert.equal(canRespond(pending, [host, guest("a", 1_000, true)], "a", now(2_000)), false, "ردّ من قبل");
  assert.equal(canRespond(pending, [host, guest("a")], "h", now(1_000)), false, "الداعي لا يردّ");
  assert.equal(canRespond(pending, [host, guest("a")], "x", now(1_000)), false, "ليس مدعوّاً");
});

test("الملغاةُ والمحسومة كما هي", () => {
  assert.equal(partyRoomOf({ ...pending, status: "expired" }, [host, guest("a", 1_000, true)], now(2_000)).phase, "expired");
  const done = partyRoomOf({ ...pending, status: "done" }, [host, guest("a", 1_000, true)], now(60_000));
  assert.equal(done.phase, "done");
  assert.deepEqual(done.roster, ["h", "a"]);
});

test("مباراةٌ قديمةٌ بلاعبَين: قُبلت فتبدأ بعد قَبولها", () => {
  const players = legacyPlayers({ hostId: "h", guestId: "g", acceptedAt: iso(3_000), createdAt: iso(0) });
  const room = partyRoomOf(pending, players, now(3_500));
  assert.equal(room.phase, "ready");
  assert.deepEqual(room.roster, ["h", "g"]);
  assert.equal(room.startAt.getTime(), T0 + 3_000 + DUEL_START_DELAY_MS);
});

test("النتائج: أوّلُ صحيحٍ يكسب السؤال، ومن ليس في القائمة لا يُحسب", () => {
  const scores = partyScores(
    [
      { studentId: "a", questionIndex: 0, won: true },
      { studentId: "b", questionIndex: 1, won: true },
      { studentId: "a", questionIndex: 2, won: true },
      { studentId: "late", questionIndex: 3, won: true },
      { studentId: "b", questionIndex: 0, won: true }, // مكرّر: السؤالُ كُسب
    ],
    ["h", "a", "b"],
  );
  assert.deepEqual([...scores], [["h", 0], ["a", 20], ["b", 10]]);
});

test("الترتيب: الأعلى أوّلاً، والمتساويان في مركزٍ واحد، والفائزُ واحدٌ أو لا أحد", () => {
  const ranked = rankParty(new Map([["h", 10], ["a", 30], ["b", 10], ["c", 0]]));
  assert.equal(ranked.winnerId, "a");
  assert.deepEqual(ranked.standings.map((s) => [s.studentId, s.rank]), [["a", 1], ["b", 2], ["h", 2], ["c", 4]]);
  assert.equal(rankParty(new Map([["h", 20], ["a", 20], ["b", 10]])).winnerId, null, "تعادلٌ في القمّة");
});

test("الصدارة: الجماعيةُ تُحسب لكل لاعبيها، والفوزُ لمن كتبه الحسم", () => {
  const { standingsOf } = mod;
  const table = standingsOf([
    { hostId: "h", guestId: "a", hostScore: 0, guestScore: 30, players: ["h", "a", "b"], winnerId: "b" },
    { hostId: "a", guestId: "b", hostScore: 5, guestScore: 1 },
  ]);
  assert.deepEqual(table, [
    { studentId: "a", wins: 1, played: 2 },
    { studentId: "b", wins: 1, played: 2 },
    { studentId: "h", wins: 0, played: 1 },
  ]);
});

test("مفتاحُ الجائزة: الدرسُ واللعبة معاً", () => {
  const { duelRewardActivity } = mod;
  assert.equal(duelRewardActivity("L1", "tug"), "L1:tug");
  assert.notEqual(duelRewardActivity("L1", "tug"), duelRewardActivity("L1", "sprint"));
  assert.notEqual(duelRewardActivity("L1", "tug"), duelRewardActivity("L2", "tug"));
});
