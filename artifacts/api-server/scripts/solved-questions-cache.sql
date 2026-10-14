-- ════════════════════════════════════════════════════════════════════════
-- ذاكرةُ «حل المسائل» الدائمة: لا تُحذف ولا تُمحى
-- ════════════════════════════════════════════════════════════════════════
--
-- ── ما القائم ──
-- كلُّ سؤالٍ يُجاب في «حل المسائل» يُحفظ في `ai_qa_cache` (انظر
-- ai-qa-cache.sql)، ويُبحث فيه قبل استدعاء الذكاء الاصطناعي على ثلاث درجات:
-- حرفياً، ثم بالكلمات، ثم بالمعنى (ai-qa-cache-vectors.sql). والإصابةُ لا
-- تُحسب من حصّة الطفل ولا تكلّف جوهرة. ولا شيءَ في الخادم يحذف منه: لا مدّةَ
-- صلاحية ولا تنظيفٌ دوريّ.
--
-- ── وما يضيفه هذا الملفّ ──
-- ١. ضمانٌ في القاعدة نفسها لا في الكود وحده: حذفُ صفٍّ أو تفريغُ الجدول
--    يُرفض لكل دور — الخادمِ ولوحةِ Supabase ومن يكتب SQL بيده. فخطأٌ في
--    استعلامٍ أو زرٌّ ضُغط بالخطأ لا يمحو ما جمعته المنصّة من إجابات.
--    والتحديثُ مسموح: الخادم يُثري الصفَّ بمتّجه المعنى حين يُحسب.
-- ٢. `solved_questions_cache`: عرضٌ مقروءٌ للجدول نفسه — الدرس والسؤال
--    والإجابة وتاريخها — لمن يتصفّح الذاكرة. عرضٌ لا جدولٌ ثانٍ: جدولان
--    يعني ذاكرتين تفترقان، وإجاباتٍ تُحفظ في واحدٍ ويُبحث عنها في الآخر.
--
-- ومن أراد يوماً حذفاً مقصوداً (سؤالٌ أُجيب خطأً) فبإيقاف الحارس صراحةً في
-- جلسته، وهو أثرٌ مكتوبٌ لا يقع سهواً:
--   alter table public.ai_qa_cache disable trigger ai_qa_cache_keep_rows;
--   delete from public.ai_qa_cache where id = '...';
--   alter table public.ai_qa_cache enable trigger ai_qa_cache_keep_rows;
--
-- التشغيل: بعد ai-qa-cache.sql، في محرّر SQL في Supabase. يُعاد تشغيلُه بأمان.

begin;

create or replace function public.ai_qa_cache_refuse_delete()
returns trigger
language plpgsql
as $$
begin
  raise exception 'ai_qa_cache is permanent: solved questions are never deleted'
    using errcode = 'P0001',
          hint = 'ذاكرة حل المسائل دائمة. انظر scripts/solved-questions-cache.sql';
end;
$$;

drop trigger if exists ai_qa_cache_keep_rows on public.ai_qa_cache;
create trigger ai_qa_cache_keep_rows
  before delete on public.ai_qa_cache
  for each row execute function public.ai_qa_cache_refuse_delete();

drop trigger if exists ai_qa_cache_keep_table on public.ai_qa_cache;
create trigger ai_qa_cache_keep_table
  before truncate on public.ai_qa_cache
  for each statement execute function public.ai_qa_cache_refuse_delete();

create or replace view public.solved_questions_cache
with (security_invoker = true)
as
select
  c.id,
  c.data ->> 'lessonId' as lesson_id,
  c.data ->> 'question' as question,
  c.data ->> 'answer' as answer,
  -- ‏يُقرأ هكذا ليعمل العرضُ وإن لم يُطبَّق ai-qa-cache-vectors.sql بعد.
  (to_jsonb(c) ->> 'embedding') is not null as searchable_by_meaning,
  coalesce((c.data ->> 'createdAt')::timestamptz, c.updated_at) as created_at,
  c.updated_at
from public.ai_qa_cache c;

-- كالجدول: للخادم وحده. مفتاحُ anon في كل APK، ولا تُقرأ به أسئلةُ الأطفال.
revoke all on public.solved_questions_cache from public, anon, authenticated;
grant select on public.solved_questions_cache to service_role;

comment on view public.solved_questions_cache is
  'ذاكرة حل المسائل الدائمة (عرضٌ لـ ai_qa_cache): كل سؤالٍ أُجيب وإجابته، لا تُحذف.';

commit;
