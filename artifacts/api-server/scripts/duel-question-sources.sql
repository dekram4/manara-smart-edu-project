-- مصدرُ أسئلة المبارزة المولَّدة: من أيّ درسٍ ولأيّ معلم.
--
-- التشغيل: الصقه في محرّر SQL في Supabase بعد `duel-question-bank.sql`. آمنٌ
-- على بنكٍ فيه أسئلة، ويُعاد تشغيلُه بلا ضرر.
--
-- ── لماذا ──
-- التوليدُ يكتب أسئلةً لكل درسٍ يحفظه المعلم. وبلا هذه الأعمدة لا يُعرف:
--   - أيُّ الأسئلة من دروس هذا المعلم — فيراها في لوحته ويعطّلها هو؛
--   - ولا أيُّ نصٍّ وُلّدت منه — فيُولَّد للدرس مرّةً عند كل حفظ، لا عند تغيّره.
--
-- وأسئلةُ البنك المكتوب تبقى بلا درسٍ ولا معلم: هي مشتركةٌ بين الصفوف، فلا
-- يعطّلها إلا المشرف.

begin;

alter table public.duel_questions
  add column if not exists lesson_id text,
  add column if not exists teacher_id text,
  add column if not exists lesson_stamp text;

comment on column public.duel_questions.lesson_id is
  'الدرسُ الذي وُلّد منه السؤال. فارغٌ في البنك المكتوب.';
comment on column public.duel_questions.teacher_id is
  'مالكُ الدرس: يعطّل أسئلتَه من لوحته. والمشتركُ (فارغ) يعطّله المشرف وحده.';
comment on column public.duel_questions.lesson_stamp is
  'بصمةُ نصّ الدرس عند التوليد. تتغيّر بتغيّره فيُولَّد له من جديد.';

-- ما يُستعلَم فعلاً: هل وُلّد لهذا الدرس بنصّه الحالي؟ وما أسئلةُ هذا المعلم؟
create index if not exists duel_questions_lesson_idx
  on public.duel_questions (lesson_id, lesson_stamp);
create index if not exists duel_questions_teacher_idx
  on public.duel_questions (teacher_id);

commit;
