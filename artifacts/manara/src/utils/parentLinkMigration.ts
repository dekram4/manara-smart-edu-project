import type { ParentInfo, StudentInfo } from '../types';
import { normalizeScopeValue } from './scope';

/**
 * ترحيل ربط الطالب بولي أمره من رقم الجوال إلى `parentId` الصريح.
 *
 * الخلفية: كان الربط يقع على `parentId` أولاً ثم يرتدّ إلى مطابقة رقم
 * الجوال. الارتداد ثغرة على حدّ أمني: وليّا أمرٍ يحملان الرقم نفسه — وهو
 * خطأ إدخال وارد جداً — يرى كلٌّ منهما أبناء الآخر.
 *
 * الترحيل يملأ `parentId` لكل طالب يمكن ربطه **بلا لبس**، ثم يُسقط الارتداد.
 *
 * وأهم قرار هنا هو ما لا تفعله هذه الدالة: حين يطابق رقمُ جوالٍ أكثرَ من
 * وليّ أمر، **لا تخمّن**. التخمين يثبّت الثغرة في البيانات نفسها بدل أن
 * يزيلها، ويصير الخطأ دائماً وغير مرئي. تُبلَّغ الحالة كتعارض يُحسم يدوياً.
 */

export type ParentLinkConflict = {
  studentId: string;
  studentName: string;
  phone: string;
  /** معرّفات أولياء الأمور الذين يتقاسمون هذا الرقم. */
  candidateParentIds: string[];
};

export type ParentLinkPlan = {
  /** طلاب سيُملأ لهم `parentId` من مطابقة رقم واحدة لا لبس فيها. */
  updates: { studentId: string; parentId: string }[];
  /** طلاب لهم رقم يطابق أكثر من وليّ — تُترك بلا ربط عمداً. */
  conflicts: ParentLinkConflict[];
  /** طلاب لهم رقم لا يطابق أي وليّ أمر مسجّل. */
  unmatched: { studentId: string; studentName: string; phone: string }[];
  /** طلاب مربوطون سلفاً بـ `parentId` — لا يمسّهم الترحيل. */
  alreadyLinked: number;
  /** طلاب بلا أي إشارة إلى وليّ أمر — خارج نطاق الترحيل. */
  withoutParent: number;
};

const text = (value: unknown): string =>
  typeof value === 'string' ? value.trim() : value == null ? '' : String(value).trim();

/**
 * يبني خطة الترحيل دون تنفيذها.
 *
 * الفصل بين التخطيط والتنفيذ مقصود: الخطة تُقرأ وتُراجَع قبل أن تُكتب، وهي
 * أيضاً ما يجعل القاعدة قابلة للاختبار دون قاعدة بيانات.
 */
export function planParentLinkMigration(
  students: StudentInfo[],
  parents: ParentInfo[],
): ParentLinkPlan {
  // فهرس الأرقام. القيمة قائمة لا قيمة مفردة، لأن تعدّد أولياء الأمور على
  // رقم واحد هو الحالة التي جاء الترحيل من أجلها أصلاً.
  const byPhone = new Map<string, string[]>();
  for (const parent of parents) {
    if (!parent || typeof parent !== 'object') continue;
    const phone = normalizeScopeValue(parent.phoneNumber);
    const id = text(parent.id);
    if (!phone || !id) continue;
    const bucket = byPhone.get(phone);
    if (bucket) {
      if (!bucket.includes(id)) bucket.push(id);
    } else {
      byPhone.set(phone, [id]);
    }
  }

  const knownParentIds = new Set(parents.map((parent) => text(parent?.id)).filter(Boolean));

  const plan: ParentLinkPlan = {
    updates: [],
    conflicts: [],
    unmatched: [],
    alreadyLinked: 0,
    withoutParent: 0,
  };

  for (const student of students) {
    if (!student || typeof student !== 'object') continue;
    const studentId = text(student.id);
    if (!studentId) continue;

    const existing = text(student.parentId);
    // المربوط سلفاً بمعرّف معروف لا يُمسّ. أما معرّف يشير إلى وليّ غير موجود
    // فليس ربطاً صحيحاً، ويُعاد حسمه من الرقم كبقية الحالات.
    if (existing && knownParentIds.has(existing)) {
      plan.alreadyLinked++;
      continue;
    }

    const phone = normalizeScopeValue(student.parentPhoneNumber);
    if (!phone) {
      plan.withoutParent++;
      continue;
    }

    const candidates = byPhone.get(phone) ?? [];
    if (candidates.length === 1) {
      plan.updates.push({ studentId, parentId: candidates[0] });
    } else if (candidates.length > 1) {
      plan.conflicts.push({
        studentId,
        studentName: text(student.name),
        phone,
        candidateParentIds: [...candidates],
      });
    } else {
      plan.unmatched.push({ studentId, studentName: text(student.name), phone });
    }
  }

  return plan;
}

/** يطبّق الخطة على نسخة من مصفوفة الطلاب ويعيدها. */
export function applyParentLinkPlan(
  students: StudentInfo[],
  plan: ParentLinkPlan,
): StudentInfo[] {
  if (plan.updates.length === 0) return students;
  const byStudent = new Map(plan.updates.map((update) => [update.studentId, update.parentId]));
  return students.map((student) => {
    const parentId = byStudent.get(text(student?.id));
    return parentId ? { ...student, parentId } : student;
  });
}

/** ملخّص قابل للطباعة، للسكريبت وللكونسول. */
export function describeParentLinkPlan(plan: ParentLinkPlan): string {
  const lines = [
    `مربوطون سلفاً: ${plan.alreadyLinked}`,
    `سيُربطون الآن: ${plan.updates.length}`,
    `بلا وليّ أمر أصلاً: ${plan.withoutParent}`,
    `أرقام لا تطابق أي وليّ: ${plan.unmatched.length}`,
    `تعارضات تحتاج حسماً يدوياً: ${plan.conflicts.length}`,
  ];
  for (const conflict of plan.conflicts) {
    lines.push(
      `  ⚠️ ${conflict.studentName || conflict.studentId} — الرقم ${conflict.phone} ` +
        `يطابق ${conflict.candidateParentIds.length} أولياء: ${conflict.candidateParentIds.join(', ')}`,
    );
  }
  for (const item of plan.unmatched) {
    lines.push(`  ℹ️ ${item.studentName || item.studentId} — الرقم ${item.phone} بلا وليّ مسجّل`);
  }
  return lines.join('\n');
}
