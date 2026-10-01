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
  DUEL_POINTS_CORRECT,
  DUEL_POINTS_SPEED_MAX,
  DUEL_QUESTION_SECONDS,
  DUEL_ROUNDS,
  DUEL_WIN_GEMS,
  speedPoints,
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

test("جوهرةٌ واحدة للفوز، لا أكثر", () => {
  // مباراةٌ دقيقةٌ أو دقيقتان، وطالبان يتحدّيان عشرين مرّةً في حصّة.
  // فأكثرُ من واحدة تجعل الرصيدَ يُجمع بالتحدّي لا بالدرس.
  assert.equal(DUEL_WIN_GEMS, 1);
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

test("أقصى نتيجةٍ هي كلُّ سؤالٍ صحيحٌ وفي أسرع وقت", () => {
  assert.equal(
    DUEL_MAX_SCORE,
    DUEL_ROUNDS * (DUEL_POINTS_CORRECT + DUEL_POINTS_SPEED_MAX),
  );
});

test("والسرعةُ تُحسب نسبةً مما بقي من وقت السؤال", () => {
  const window = DUEL_QUESTION_SECONDS * 1000;
  // أجاب في اللحظة الأولى: الحدُّ الأقصى.
  assert.equal(speedPoints(window, window), DUEL_POINTS_SPEED_MAX);
  // في منتصف الوقت: النصف.
  assert.equal(speedPoints(window / 2, window), Math.round(DUEL_POINTS_SPEED_MAX / 2));
});

test("ولا نقاطَ سرعةٍ لمن انتهى وقتُه", () => {
  const window = DUEL_QUESTION_SECONDS * 1000;
  assert.equal(speedPoints(0, window), 0);
  assert.equal(speedPoints(-500, window), 0);
});

test("وما لا يُحسب لا يُعطي نقاطاً ولا يرفع", () => {
  // ── وهذا موضعُ سقوطٍ محتمل ──
  // الوقتُ المتبقّي يُحسب في التطبيق من فرقِ ساعتين، وساعةٌ تغيّرت أو إطارٌ
  // تأخّر يُخرج `NaN`. و`NaN` يمرّ في الحساب فيصير سقفاً لا يُقارَن.
  const window = DUEL_QUESTION_SECONDS * 1000;
  for (const bad of [NaN, Infinity, -Infinity]) {
    assert.equal(speedPoints(bad, window), 0, `${bad}`);
  }
  assert.equal(speedPoints(500, 0), 0, "نافذةٌ صفرٌ لا تُقسم عليها");
});

test("ولا تزيد نقاطُ السرعة على سقفها لو تجاوز المتبقّي النافذة", () => {
  // ساعةُ الجهاز قد تُقدّم، فيبدو المتبقّي أكثرَ من النافذة كلّها.
  const window = DUEL_QUESTION_SECONDS * 1000;
  assert.equal(speedPoints(window * 5, window), DUEL_POINTS_SPEED_MAX);
});

test("والنتيجةُ الممكنةُ من المحرّك تبقى داخل ما يقبله الخادم", () => {
  // كلُّ سؤالٍ صحيحٌ وأسرعُ ما يمكن: هذا ما يرسله التطبيق في أفضل حال،
  // ورفضُه يعني مباراةً كاملةً تُلعب ثم تُردّ نتيجتُها.
  const window = DUEL_QUESTION_SECONDS * 1000;
  const best = DUEL_ROUNDS * (DUEL_POINTS_CORRECT + speedPoints(window, window));
  assert.equal(parseScore(best), best);
});
