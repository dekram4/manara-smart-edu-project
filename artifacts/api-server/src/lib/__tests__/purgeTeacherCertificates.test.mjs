import test from "node:test";
import assert from "node:assert/strict";
import { selectTeacherCertificates } from "../../../scripts/purge-teacher-certificates.mjs";

const cert = (id, data) => ({ id, data: { id, ...data } });

test("يطابق باسم المعلّم في الشهادة، وبتسويةٍ عربية", () => {
  const rows = [
    cert("c1", { teacherName: "بكر برناوي", studentName: "روز داود" }),
    cert("c2", { teacherName: "  بكر   برناوى ", studentName: "سادن داود" }),
    cert("c3", { teacherName: "test", teacherId: "t-test", studentName: "جوري داود" }),
  ];
  const { matches, kept } = selectTeacherCertificates(rows, [], ["بكر برناوي"]);
  assert.deepEqual(matches.map((r) => r.id), ["c1", "c2"]);
  assert.deepEqual(kept.map((r) => r.id), ["c3"]);
});

test("يطابق بمعرّف المعلّم من جدول teachers وإن خلت الشهادة من اسمه", () => {
  const teachers = [
    { id: "t-bakr", data: { id: "t-bakr", name: "بكر برناوي", username: "bakr" } },
    { id: "t-test", data: { id: "t-test", name: "test" } },
  ];
  const rows = [
    cert("c1", { teacherId: "t-bakr", studentName: "جوري داود" }),
    cert("c2", { createdBy: "t-bakr" }),
    cert("c3", { teacherId: "t-test", teacherName: "test" }),
    cert("c4", { studentName: "بلا معلّم" }),
  ];
  const { matches, kept, owners } = selectTeacherCertificates(rows, teachers, ["بكر برناوي"]);
  assert.deepEqual(matches.map((r) => r.id), ["c1", "c2"]);
  assert.deepEqual(kept.map((r) => r.id), ["c3", "c4"]);
  assert.ok(owners.includes("t-bakr"));
  assert.ok(!owners.includes("t-test"));
});

test("لا يطابق شيئاً بلا اسم، ولا اسماً يحوي المطلوب جزءاً منه", () => {
  const rows = [cert("c1", { teacherName: "بكر برناوي الثاني" }), cert("c2", { teacherName: "" })];
  assert.equal(selectTeacherCertificates(rows, [], []).matches.length, 0);
  assert.equal(selectTeacherCertificates(rows, [], ["بكر برناوي"]).matches.length, 0);
});
