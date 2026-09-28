-- ترقيةُ ذاكرة الإجابات إلى مطابقةٍ بالمعنى.
--
-- ── ما تُضيفه على ما قبلها ──
-- المطابقةُ الحرفية تُصيب السؤالَ المعادَ بحرفه، ومقياسُ الكلمات يُصيب
-- المقلوبَ ترتيبُه والمخطوءَ حرفُه. وكلاهما يخيب حين تختلف الكلماتُ
-- نفسها: «ما وظيفة الخلية» و«ماذا تفعل الخلية» سؤالٌ واحد لا كلمةَ
-- مفتاحيةً مشتركةً بينهما. والمتّجهُ يقرّب ما تباعدت حروفُه واتّحد معناه.
--
-- ── ولماذا يبقى ما قبلها ──
-- هذه تحتاج نداءً شبكياً لحساب متّجه السؤال. فتُجرَّب أخيراً: الحرفيةُ
-- استعلامٌ مفهرَسٌ بلا شبكة، والمقياسُ استعلامٌ واحد بلا شبكة، وهذه
-- وحدها تدفع ثمن الشبكة. فالشائعُ يبقى في جزءٍ من الثانية والنادرُ
-- يُصاب بكلفته.
--
-- التشغيل: الصقه في محرّر SQL في Supabase، بعد `ai-qa-cache.sql`.

-- ١ ── الإضافة.
create extension if not exists vector;

-- ٢ ── عمودُ المتّجه.
--
-- ٧٦٨ بُعداً: مقاسُ `text-embedding-004`. وتغييرُ النموذج يعني تغييرَ
-- المقاس، وعمودٌ بمقاسٍ آخر يرفض المتّجهَ الجديد صراحةً — وهو خيرٌ من
-- أن يُقارَن متّجهٌ بمتّجهٍ من فضاءٍ آخر فتخرج نسبةٌ لا تعني شيئاً.
alter table public.ai_qa_cache
  add column if not exists embedding vector(768);

-- ٣ ── الفهرس.
--
-- جزئيٌّ على ما له متّجه: الصفوفُ المحفوظة قبل هذه الترقية متّجهُها
-- فارغ، وهي تبقى تُصاب بالمطابقة الحرفية. وفهرسةُ الفراغ عملٌ بلا ثمرة.
--
-- و`hnsw` لا `ivfflat`: الثاني يحتاج صفوفاً كثيرةً قبل بنائه ليختار
-- مراكزَه، وجدولٌ يبدأ فارغاً ويكبر صفاً صفاً لا يُعطيه ذلك. والأول
-- يبني نفسه مع الإضافة.
create index if not exists ai_qa_cache_embedding_idx
  on public.ai_qa_cache
  using hnsw (embedding vector_cosine_ops)
  where embedding is not null;

-- ٤ ── دالّةُ البحث.
--
-- المقارنةُ في قاعدة البيانات لا في الخادم: جلبُ متّجهات الدرس كلِّها
-- إلى Node ليقيسها يعني نقل ٧٦٨ رقماً لكل صفٍّ محفوظ عبر الشبكة، وهو
-- أبطأ من الحساب نفسه بمراتب.
--
-- و`<=>` مسافةُ الجيب في pgvector، فالتشابهُ `1 - المسافة`.
create or replace function public.match_qa_cache(
  query_embedding vector(768),
  p_lesson_id text,
  match_threshold double precision default 0.88
)
returns table (
  id text,
  question text,
  answer text,
  similarity double precision
)
language sql
stable
-- الدرسُ شرطٌ لا ترتيب: «ما الفكرة الرئيسية؟» سؤالٌ صالحٌ لكل درس
-- وإجابتُه تختلف بينها، فأقربُ متّجهٍ في درسٍ آخر جوابٌ عن درسٍ لم
-- يفتحه الطالب.
set search_path = public
as $$
  select
    c.id,
    c.data->>'question' as question,
    c.data->>'answer' as answer,
    1 - (c.embedding <=> query_embedding) as similarity
  from public.ai_qa_cache c
  where c.embedding is not null
    and c.data->>'lessonId' = p_lesson_id
    and c.data->>'answer' is not null
    and 1 - (c.embedding <=> query_embedding) >= match_threshold
  order by c.embedding <=> query_embedding
  limit 1;
$$;

-- ٥ ── الصلاحيات.
--
-- الدوالُّ في Postgres تُمنح لـ`public` تلقائياً عند إنشائها. فلولا
-- السحبُ أدناه لاستطاع أيُّ حاملِ مفتاحِ anon — وهو يُستخرج من أي APK
-- بفكّ ضغطه — أن ينادي هذه الدالّة ويقرأ بها أسئلةَ الأطفال وأجوبتَهم
-- صفاً صفاً، وRLS لا يمنعه لأنها `stable` تُنفَّذ بصلاحية المنادي على
-- جدولٍ لا سياسةَ له.
revoke all on function public.match_qa_cache(vector, text, double precision)
  from public, anon, authenticated;

grant execute on function public.match_qa_cache(vector, text, double precision)
  to service_role;

comment on function public.match_qa_cache is
  'أقربُ سؤالٍ محفوظٍ معنىً في درسٍ معيَّن، إن بلغ عتبةَ التشابه. ينادِيها الخادم وحده.';

comment on column public.ai_qa_cache.embedding is
  'متّجهُ السؤال المطبَّع بنموذج text-embedding-004 (٧٦٨ بُعداً). فارغٌ في الصفوف المحفوظة قبل ترقية المتّجهات.';
