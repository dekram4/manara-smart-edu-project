-- عمودُ `ai_qa_cache.embedding` من النوع الصحيح قبل جزء المتّجهات.
--
-- في manara-open-app وُجد العمودُ نصّاً (text). و`add column if not exists`
-- في ai-qa-cache-vectors.sql يتركه كما هو، ثم يفشل فهرسُ hnsw عليه.
-- والمتّجهاتُ ذاكرةٌ تُحسب من جديد عند أوّل سؤال، ولا تُنقل من نصّ، فيُحذف
-- العمودُ ذو النوع الآخر ويُنشئه الجزءُ التالي vector(768). والعمودُ الذي نوعُه
-- vector أصلاً لا يُمسّ. ويُعاد تشغيله بلا ضرر.

create extension if not exists vector;

do $$
begin
  if exists (
    select 1
      from pg_attribute a
      join pg_type ty on ty.oid = a.atttypid
     where a.attrelid = 'public.ai_qa_cache'::regclass
       and a.attname = 'embedding' and a.attnum > 0 and not a.attisdropped
       and ty.typname <> 'vector'
  ) then
    drop index if exists public.ai_qa_cache_embedding_idx;
    alter table public.ai_qa_cache drop column embedding;
    raise notice 'manara: حُذف ai_qa_cache.embedding (نوعٌ غيرُ vector)، ويُنشأ vector(768) بعده';
  end if;
end $$;
