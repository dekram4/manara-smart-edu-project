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

// ── المصافحة ──

const { roomStateOf, DUEL_INVITE_SECONDS, DUEL_JOIN_SECONDS, DUEL_START_DELAY_MS } = mod;
const T0 = Date.parse("2026-10-01T10:00:00Z");
const iso = (ms) => new Date(T0 + ms).toISOString();
const times = (over = {}) => ({
  status: "pending",
  createdAt: iso(0),
  acceptedAt: null,
  hostJoinedAt: null,
  guestJoinedAt: null,
  ...over,
});
const now = (ms) => new Date(T0 + ms);

test("الدعوةُ تنتظر الردّ في مهلتها، وبعدها منتهية", () => {
  assert.equal(roomStateOf(times(), now(5_000)).phase, "invited");
  assert.equal(roomStateOf(times(), now(DUEL_INVITE_SECONDS * 1000 + 1)).phase, "expired");
});

test("قُبلت: الغرفةُ تنتظر الاثنين، ولا موعدَ قبل دخولهما", () => {
  const state = roomStateOf(times({ acceptedAt: iso(3_000), hostJoinedAt: iso(4_000) }), now(5_000));
  assert.equal(state.phase, "accepted");
  assert.equal(state.startAt, null);
  assert.equal(state.hostJoined, true);
  assert.equal(state.guestJoined, false);
});

test("دخلا: الموعدُ بعد دخول الثاني بمهلة البدء", () => {
  const state = roomStateOf(
    times({ acceptedAt: iso(3_000), hostJoinedAt: iso(4_000), guestJoinedAt: iso(6_500) }),
    now(7_000),
  );
  assert.equal(state.phase, "ready");
  assert.equal(state.startAt.getTime(), T0 + 6_500 + DUEL_START_DELAY_MS);
});

test("قُبلت ولم يدخل أحدُهما في مهلته: منتهية — لا يبدأ وحده", () => {
  const state = roomStateOf(
    times({ acceptedAt: iso(3_000), guestJoinedAt: iso(4_000) }),
    now(3_000 + DUEL_JOIN_SECONDS * 1000 + 1),
  );
  assert.equal(state.phase, "expired");
});

test("ومهلةُ الدعوة لا تُنهي مباراةً قُبلت ودخلها الاثنان", () => {
  const state = roomStateOf(
    times({ acceptedAt: iso(3_000), hostJoinedAt: iso(4_000), guestJoinedAt: iso(5_000) }),
    now(10 * 60_000),
  );
  assert.equal(state.phase, "ready");
});

test("الملغاةُ والمحسومة كما هي", () => {
  assert.equal(roomStateOf(times({ status: "expired" }), now(1)).phase, "expired");
  assert.equal(roomStateOf(times({ status: "done" }), now(1)).phase, "done");
});

test("مفتاحُ الجائزة: الدرسُ واللعبة معاً", () => {
  const { duelRewardActivity } = mod;
  assert.equal(duelRewardActivity("L1", "tug"), "L1:tug");
  assert.notEqual(duelRewardActivity("L1", "tug"), duelRewardActivity("L1", "sprint"));
  assert.notEqual(duelRewardActivity("L1", "tug"), duelRewardActivity("L2", "tug"));
});
