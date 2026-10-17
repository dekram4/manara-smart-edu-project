-- ‏ما طُبّق فعلاً على Supabase في 17 أكتوبر 2026: البنيةُ والصلاحياتُ من apply-supabase.sql بلا تعليقاتٍ ولا صفوف أسئلة
-- ‏(الأسئلة تُدرجها scripts/seed-knowledge-questions.mjs بمفتاح الخدمة). يُعاد تشغيله بأمان.

begin;

do $$
declare
  t text;
  pol record;
begin
  for t in select tablename from pg_tables where schemaname = 'public' loop
    execute format('alter table public.%I enable row level security', t);
    for pol in
      select policyname from pg_policies
      where schemaname = 'public' and tablename = t
        and roles && array['anon', 'authenticated', 'public']::name[]
    loop
      execute format('drop policy %I on public.%I', pol.policyname, t);
    end loop;
    execute format('revoke all on public.%I from anon, authenticated', t);
    execute format('grant all on public.%I to service_role', t);
  end loop;
end $$;

do $$
declare
  v text;
begin
  for v in select viewname from pg_views where schemaname = 'public' loop
    execute format('revoke all on public.%I from anon, authenticated', v);
    execute format('grant select on public.%I to service_role', v);
  end loop;
end $$;

grant select on public.lesson_configs to anon, authenticated;
create policy "anon_read_lesson_configs" on public.lesson_configs
  for select to anon, authenticated using (true);

grant select on public.created_quizzes to anon, authenticated;
create policy "anon_read_created_quizzes" on public.created_quizzes
  for select to anon, authenticated using (true);

grant select on public.app_kv to anon, authenticated;
create policy "anon_read_public_app_kv" on public.app_kv
  for select to anon, authenticated
  using (key in (
    'smartEdu_hierarchicalConfigs',
    'smartEdu_videos',
    'smartEdu_deletedVideos',
    'smartEdu_deletedQuizzes',
    'smartEdu_quizQuestions',
    'smartEdu_cardPermissions'
  ));

do $$
declare
  f record;
begin
  for f in
    select p.oid::regprocedure as sig, p.proname
    from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.prokind = 'f'
      and p.proname in ('record_duel_answer', 'cleanup_expired_ephemeral_chat',
                        'match_qa_cache', 'duel_subject_key', 'duel_grade_band')
  loop
    execute format('revoke all on function %s from public, anon, authenticated', f.sig);
    execute format('grant execute on function %s to service_role', f.sig);
  end loop;
end $$;

commit;

do $$
declare
  f record;
begin
  for f in
    select p.oid::regprocedure as sig
    from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.proname = 'match_qa_cache'
  loop
    execute format('drop function %s', f.sig);
  end loop;
end $$;

create extension if not exists vector;

alter table public.ai_qa_cache
  add column if not exists embedding vector(768);

create index if not exists ai_qa_cache_embedding_idx
  on public.ai_qa_cache
  using hnsw (embedding vector_cosine_ops)
  where embedding is not null;

create or replace function public.match_qa_cache(
  query_embedding vector(768),
  p_lesson_id text,

  match_threshold double precision default 0.95
)
returns table (
  id text,
  question text,
  answer text,
  similarity double precision
)
language sql
stable
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

revoke all on function public.match_qa_cache(vector, text, double precision)
  from public, anon, authenticated;

grant execute on function public.match_qa_cache(vector, text, double precision)
  to service_role;

comment on function public.match_qa_cache is
  'أقربُ سؤالٍ محفوظٍ معنىً في درسٍ معيَّن، إن بلغ عتبةَ التشابه. ينادِيها الخادم وحده.';

comment on column public.ai_qa_cache.embedding is
  'متّجهُ السؤال المطبَّع بنموذج text-embedding-004 (٧٦٨ بُعداً). فارغٌ في الصفوف المحفوظة قبل ترقية المتّجهات.';

begin;

alter table public.duel_questions drop constraint if exists duel_questions_category;
alter table public.duel_questions add constraint duel_questions_category
  check (category in (
    'domain', 'general', 'logic', 'quick', 'school',
    'culture', 'sports', 'geography', 'history', 'science'
  ));

create or replace function public.claim_duel_pack(p_match_id text)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_match public.challenge_matches%rowtype;
  v_lesson jsonb;
  v_subject text;
  v_band text;
  v_unit text;
  v_recent text[];
  v_domain text[];
  v_know text[];
  v_brain text[];
  v_pattern constant text := 'DKBDKDKBDK';
  v_slot text;
  v_try text;
  v_id text;
  v_row public.duel_questions%rowtype;
  v_options text[];
  v_questions jsonb := '[]'::jsonb;
  v_pack jsonb;
  d int := 1;
  k int := 1;
  b int := 1;
begin
  if p_match_id is null or btrim(p_match_id) = '' then
    return null;
  end if;

  select * into v_match
  from public.challenge_matches
  where id = p_match_id
  for update;
  if not found then
    return null;
  end if;

  if v_match.questions is not null
     and jsonb_typeof(v_match.questions -> 'questions') = 'array'
     and jsonb_array_length(v_match.questions -> 'questions') >= 8 then
    return v_match.questions;
  end if;

  if v_match.status <> 'pending' or v_match.expires_at < now() then
    return null;
  end if;

  select data into v_lesson
  from public.lesson_configs
  where id = v_match.lesson_id
  limit 1;

  v_subject := public.duel_subject_key(v_lesson ->> 'subject');
  v_band := public.duel_grade_band(v_lesson ->> 'grade');
  v_unit := lower(btrim(coalesce(v_lesson ->> 'unit', '')));

  select coalesce(array_agg(q ->> 'id' order by recent.created_at desc), '{}')
  into v_recent
  from (
    select m.questions, m.created_at
    from public.challenge_matches m
    where m.id <> v_match.id
      and m.questions is not null
      and (
        m.host_id in (v_match.host_id, v_match.guest_id)
        or m.guest_id in (v_match.host_id, v_match.guest_id)
      )
    order by m.created_at desc
    limit 10
  ) recent
  cross join lateral jsonb_array_elements(
    case
      when jsonb_typeof(recent.questions -> 'questions') = 'array'
        then recent.questions -> 'questions'
      else '[]'::jsonb
    end
  ) q;

  select coalesce(array_agg(id order by pick), '{}')
  into v_domain
  from (
    select id, row_number() over (
      order by
        coalesce(1000 - array_position(v_recent, id), 0),
        (v_unit <> '' and lower(btrim(coalesce(unit, ''))) = v_unit) desc,
        random()
    ) as pick
    from public.duel_questions
    where active
      and category = 'domain'
      and subject_key = v_subject
      and grade_band in ('all', v_band)
  ) s
  where pick <= 4;

  if cardinality(v_domain) < 4 then
    v_domain := v_domain || coalesce((
      select array_agg(id order by pick)
      from (
        select id, row_number() over (
          order by coalesce(1000 - array_position(v_recent, id), 0), random()
        ) as pick
        from public.duel_questions
        where active
          and subject_key = '*'
          and category in ('general', 'school')
          and grade_band in ('all', v_band)
      ) s
      where pick <= 4 - cardinality(v_domain)
    ), '{}');
  end if;

  select coalesce(array_agg(id order by pick), '{}')
  into v_know
  from (
    select id, row_number() over (order by recency, random()) as pick
    from (
      select
        id,
        coalesce(1000 - array_position(v_recent, id), 0) as recency,
        row_number() over (
          partition by category
          order by coalesce(1000 - array_position(v_recent, id), 0), random()
        ) as rn
      from public.duel_questions
      where active
        and subject_key = '*'
        and category in ('culture', 'sports', 'geography', 'history', 'science')
        and grade_band in ('all', v_band)
    ) per_category
    where rn = 1
  ) s
  where pick <= 4;

  select coalesce(array_agg(id order by category), '{}')
  into v_brain
  from (
    select id, category, row_number() over (
      partition by category
      order by coalesce(1000 - array_position(v_recent, id), 0), random()
    ) as rn
    from public.duel_questions
    where active
      and subject_key = '*'
      and category in ('logic', 'quick')
      and grade_band in ('all', v_band)
  ) s
  where rn = 1;

  if cardinality(v_domain) + cardinality(v_know) + cardinality(v_brain) < 8 then
    return null;
  end if;

  foreach v_slot in array regexp_split_to_array(v_pattern, '') loop
    v_id := null;
    foreach v_try in array (
      case v_slot
        when 'D' then array['D', 'K', 'B']
        when 'K' then array['K', 'D', 'B']
        else array['B', 'K', 'D']
      end
    ) loop
      if v_try = 'D' and d <= cardinality(v_domain) then
        v_id := v_domain[d];
        d := d + 1;
      elsif v_try = 'K' and k <= cardinality(v_know) then
        v_id := v_know[k];
        k := k + 1;
      elsif v_try = 'B' and b <= cardinality(v_brain) then
        v_id := v_brain[b];
        b := b + 1;
      end if;
      exit when v_id is not null;
    end loop;
    exit when v_id is null;

    select * into v_row from public.duel_questions where id = v_id;
    v_options := array(select c from unnest(v_row.choices) c order by random());
    v_questions := v_questions || jsonb_build_array(jsonb_build_object(
      'id', v_row.id,
      'category', v_row.category,
      'prompt', v_row.prompt,
      'options', to_jsonb(v_options),
      'answerAt', array_position(v_options, v_row.choices[1]) - 1
    ));
  end loop;

  v_pack := jsonb_build_object(
    'version', 1,
    'builtAt', now(),
    'source', 'bank',
    'subject', v_subject,
    'questions', v_questions
  );

  update public.challenge_matches
  set questions = v_pack,
      updated_at = now()
  where id = v_match.id;

  return v_pack;
end;
$$;

revoke all on function public.claim_duel_pack(text) from public;
grant execute on function public.claim_duel_pack(text) to anon, authenticated, service_role;

commit;

notify pgrst, 'reload schema';

select
  (select count(*) from pg_proc p join pg_namespace n on n.oid = p.pronamespace
     where n.nspname = 'public' and p.proname = 'match_qa_cache'
       and pg_get_function_identity_arguments(p.oid) like 'query_embedding vector%') as match_qa_cache_expected_1,
  (select count(*) from pg_constraint where conname = 'duel_questions_category'
     and pg_get_constraintdef(oid) like '%culture%') as knowledge_categories_expected_1,
  (select count(*) from information_schema.role_table_grants
     where table_schema = 'public' and grantee in ('anon', 'authenticated')
       and privilege_type <> 'SELECT') as anon_write_grants_expected_0,
  (select string_agg(distinct table_name, ', ' order by table_name)
     from information_schema.role_table_grants
     where table_schema = 'public' and grantee = 'anon' and privilege_type = 'SELECT') as anon_readable;
