import test from "node:test";
import assert from "node:assert/strict";
import {
  isDemoStudent,
  parseJoinRequest,
  planCards,
  planOf,
  schoolTierFor,
} from "../../../dist/lib/subscriptionPlans.mjs";
import { effectiveCards } from "../../../dist/lib/cardPermissions.mjs";

const student = { id: "s1", grade: "الرابع", teacherIdentities: new Set(["t1"]) };

test("الباقة الفردية: الدردشةُ والتحدّي واللقاءُ والمعلمُ الافتراضي وحلُّ المسائل مغلقة", () => {
  const cards = effectiveCards([], student, planCards("individual"));
  for (const id of ["chat", "challenge", "meeting", "tutor", "solver"]) assert.equal(cards[id], false, id);
  for (const id of ["lesson", "cinema", "games", "quiz", "study", "personality"]) assert.equal(cards[id], true, id);
});

test("باقة المجموعات: الفردية + الدردشة وتحدَّ زملاءك؛ والمؤسسية كلُّها مفتوحة", () => {
  const family = effectiveCards([], student, planCards("family"));
  assert.equal(family.chat, true);
  assert.equal(family.challenge, true);
  for (const id of ["meeting", "tutor", "solver"]) assert.equal(family[id], false, id);
  for (const plan of ["school_small", "school_medium", "school_large", null]) {
    const cards = effectiveCards([], student, planCards(plan));
    assert.ok(Object.values(cards).every(Boolean), String(plan));
  }
});

test("تحكّمُ المشرف اليدوي يغلب الباقة: يفتح المغلقَ ويغلق المفتوح", () => {
  const rules = [{
    id: "student:s1", scope: "student", studentId: "s1", teacherId: "admin", gradeId: null,
    cards: { solver: true, lesson: false }, updatedBy: "admin", updatedAt: "2026-11-16T10:00:00Z",
  }];
  const cards = effectiveCards(rules, student, planCards("individual"));
  assert.equal(cards.solver, true);
  assert.equal(cards.lesson, false);
  assert.equal(cards.chat, false, "ما لم يذكره المشرفُ يبقى للباقة");
});

test("الباقةُ من السجلّ، والحسابُ القديم بلا باقة", () => {
  assert.equal(planOf({ subscriptionPlan: "family" }), "family");
  assert.equal(planOf({ subscriptionPlan: "gold" }), null);
  assert.equal(planOf({}), null);
});

test("حسابا العرض: بالباقة أو باسم الدخول", () => {
  assert.equal(isDemoStudent({ plan: "demo" }), true);
  assert.equal(isDemoStudent({ username: "demo_kg" }), true);
  assert.equal(isDemoStudent({ username: "sara", plan: "individual" }), false);
});

test("طلبُ الانضمام: يُتحقّق منه، والفئةُ المؤسسيةُ بالعدد", () => {
  const ok = parseJoinRequest({ plan: "school_medium", name: " روضة النور ", grade: "روضة", students: "40", phone: "+966 50 123 4567" });
  assert.equal(ok.plan, "school_medium");
  assert.equal(ok.name, "روضة النور");
  assert.equal(ok.students, 40);
  assert.equal(ok.phone, "+966501234567");
  assert.equal(ok.status, "new");
  assert.ok(parseJoinRequest({ plan: "demo", name: "x", phone: "0501234567" }).error);
  assert.ok(parseJoinRequest({ plan: "individual", name: "سارة", phone: "12" }).error);
  assert.ok(parseJoinRequest({ plan: "family", name: "آل محمد", phone: "0501234567", students: 2 }).error);
  assert.equal(parseJoinRequest({ plan: "family", name: "آل محمد", phone: "0501234567", students: 3 }).plan, "family");
  assert.equal(schoolTierFor(20), "school_small");
  assert.equal(schoolTierFor(50), "school_medium");
  assert.equal(schoolTierFor(300), "school_large");
});
