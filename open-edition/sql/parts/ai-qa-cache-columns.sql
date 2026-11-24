-- أعمدةُ ai_qa_cache المقروءة كما في قاعدة الإنتاج.
--
-- أُضيفت هناك يدوياً، فلا يُنشئها ai-qa-cache.sql، وعليها يقوم عرضُ
-- `solved_questions_cache` (solved-questions-cache.sql). والخادمُ يكتبها مع
-- `data` في كل حفظ (cacheReadableColumns في src/lib/solverPolicy.ts).
-- فبدونها يفشل إنشاءُ العرض في قاعدةٍ جديدة.

alter table public.ai_qa_cache
  add column if not exists question_hash text,
  add column if not exists question_text text,
  add column if not exists answer_json jsonb,
  add column if not exists domain text,
  add column if not exists created_at timestamptz not null default now();
