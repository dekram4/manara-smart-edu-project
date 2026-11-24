-- مواءمةُ الجداول الموجودة مسبقاً في manara-open-app مع بنية منارة.
--
-- ── لماذا ──
-- في القاعدة الجديدة جداولُ أُنشئت قبل هذا الملف بأنواعٍ غيرِ أنواعنا: مثلاً
-- `ai_qa_cache.data` من النوع text بدل jsonb. و`create table if not exists`
-- لا يمسّ جدولاً موجوداً، فيفشل ما بعده:
--   ERROR 42883: operator does not exist: text ->> unknown
-- فيمرّ هذا الجزء أوّلاً على كل جدولٍ موجود من جداولنا، فيضيف الناقص من
-- الأعمدة، ويحوّل النوعَ المختلف بلا فقدٍ للبيانات (النصُّ الذي ليس JSON
-- يصير قيمةً نصّية في jsonb)، ويضيف المفتاحَ الأساسي إن غاب.
-- والجدولُ غيرُ الموجود يُترك لـ `create table` بعده. ويُعاد تشغيله بلا ضرر.
--
-- ⚠️ لـ manara-open-app وحده. لا يُشغَّل على القاعدة القديمة.

-- ‏تحويلاتٌ آمنة: القيمةُ التي لا تتحوّل لا توقف الملفّ.
create or replace function pg_temp.manara_jsonb(v text) returns jsonb
language plpgsql immutable as $f$
begin
  if v is null then return null; end if;
  return v::jsonb;
exception when others then
  return to_jsonb(v);
end $f$;

create or replace function pg_temp.manara_ts(v text) returns timestamptz
language plpgsql stable as $f$
begin
  if v is null or btrim(v) = '' then return null; end if;
  if v ~ '^\d{12,13}$' then return to_timestamp(v::bigint / 1000.0); end if;
  return v::timestamptz;
exception when others then
  return null;
end $f$;

create or replace function pg_temp.manara_int(v text) returns integer
language plpgsql immutable as $f$
begin
  return round(v::numeric)::integer;
exception when others then
  return null;
end $f$;

create or replace function pg_temp.manara_bool(v text) returns boolean
language plpgsql immutable as $f$
begin
  return v::boolean;
exception when others then
  return null;
end $f$;

create or replace function pg_temp.manara_text_array(v text) returns text[]
language plpgsql immutable as $f$
declare j jsonb;
begin
  if v is null then return null; end if;
  begin
    j := v::jsonb;
    if jsonb_typeof(j) = 'array' then
      return array(select jsonb_array_elements_text(j));
    end if;
  exception when others then null;
  end;
  begin
    return v::text[];
  exception when others then
    return array[v];
  end;
end $f$;

create or replace function pg_temp.manara_uuid(v text) returns uuid
language plpgsql volatile as $f$
begin
  return v::uuid;
exception when others then
  return gen_random_uuid();
end $f$;

do $$
declare
  -- ‏(الجدول، العمود، النوع، القيمة الافتراضية أو null، not null؟)
  -- ‏بأنواع format_type كما يكتبها Postgres، ومن create table في الأجزاء التالية.
  spec text[][] := array[
    ['students','id','text',null,'1'], ['students','data','jsonb',null,'1'], ['students','updated_at','timestamp with time zone','now()','1'],
    ['parents','id','text',null,'1'], ['parents','data','jsonb',null,'1'], ['parents','updated_at','timestamp with time zone','now()','1'],
    ['teachers','id','text',null,'1'], ['teachers','data','jsonb',null,'1'], ['teachers','updated_at','timestamp with time zone','now()','1'],
    ['lesson_configs','id','text',null,'1'], ['lesson_configs','data','jsonb',null,'1'], ['lesson_configs','updated_at','timestamp with time zone','now()','1'],
    ['created_quizzes','id','text',null,'1'], ['created_quizzes','data','jsonb',null,'1'], ['created_quizzes','updated_at','timestamp with time zone','now()','1'],
    ['quiz_results','id','text',null,'1'], ['quiz_results','data','jsonb',null,'1'], ['quiz_results','updated_at','timestamp with time zone','now()','1'],
    ['interactions','id','text',null,'1'], ['interactions','data','jsonb',null,'1'], ['interactions','updated_at','timestamp with time zone','now()','1'],
    ['private_messages','id','text',null,'1'], ['private_messages','data','jsonb',null,'1'], ['private_messages','updated_at','timestamp with time zone','now()','1'],
    ['public_messages','id','text',null,'1'], ['public_messages','data','jsonb',null,'1'], ['public_messages','updated_at','timestamp with time zone','now()','1'],
    ['certificates','id','text',null,'1'], ['certificates','data','jsonb',null,'1'], ['certificates','updated_at','timestamp with time zone','now()','1'],
    ['app_kv','key','text',null,'1'], ['app_kv','value','jsonb',null,'1'], ['app_kv','updated_at','timestamp with time zone','now()','1'],
    ['ai_qa_cache','id','text',null,'1'], ['ai_qa_cache','data','jsonb','''{}''::jsonb','1'], ['ai_qa_cache','updated_at','timestamp with time zone','now()','1'],
    -- ‏أعمدةُ الإنتاج المقروءة (انظر ai-qa-cache-columns.sql)، وعليها يقوم عرضُ solved_questions_cache.
    ['ai_qa_cache','question_hash','text',null,'0'], ['ai_qa_cache','question_text','text',null,'0'],
    ['ai_qa_cache','answer_json','jsonb',null,'0'], ['ai_qa_cache','domain','text',null,'0'],
    ['ai_qa_cache','created_at','timestamp with time zone','now()','1'],
    ['challenge_matches','id','text',null,'1'], ['challenge_matches','lesson_id','text',null,'0'], ['challenge_matches','game','text',null,'0'],
    ['challenge_matches','host_id','text',null,'0'], ['challenge_matches','guest_id','text',null,'0'], ['challenge_matches','class_key','text',null,'0'],
    ['challenge_matches','mode','text','''ghost''','1'], ['challenge_matches','status','text','''pending''','1'],
    ['challenge_matches','host_score','integer',null,'0'], ['challenge_matches','guest_score','integer',null,'0'], ['challenge_matches','winner_id','text',null,'0'],
    ['challenge_matches','created_at','timestamp with time zone','now()','1'], ['challenge_matches','updated_at','timestamp with time zone','now()','1'],
    ['challenge_matches','expires_at','timestamp with time zone','now() + interval ''7 days''','1'],
    ['challenge_matches','questions','jsonb',null,'0'], ['challenge_matches','reward_paid','boolean',null,'0'],
    ['challenge_matches','accepted_at','timestamp with time zone',null,'0'], ['challenge_matches','host_joined_at','timestamp with time zone',null,'0'],
    ['challenge_matches','guest_joined_at','timestamp with time zone',null,'0'],
    ['match_messages','id','uuid','gen_random_uuid()','1'], ['match_messages','match_id','text',null,'0'], ['match_messages','sender_id','text',null,'0'],
    ['match_messages','kind','text','''text''','1'], ['match_messages','body','text',null,'0'], ['match_messages','created_at','timestamp with time zone','now()','1'],
    ['duel_questions','id','text',null,'1'], ['duel_questions','subject_key','text','''*''','1'], ['duel_questions','unit','text',null,'0'],
    ['duel_questions','grade_band','text','''all''','1'], ['duel_questions','category','text',null,'0'], ['duel_questions','prompt','text',null,'0'],
    ['duel_questions','choices','text[]',null,'0'], ['duel_questions','source','text','''seed''','1'], ['duel_questions','active','boolean','true','1'],
    ['duel_questions','disabled_by','text',null,'0'], ['duel_questions','disabled_at','timestamp with time zone',null,'0'],
    ['duel_questions','created_at','timestamp with time zone','now()','1'],
    ['duel_questions','lesson_id','text',null,'0'], ['duel_questions','teacher_id','text',null,'0'], ['duel_questions','lesson_stamp','text',null,'0'],
    ['match_answers','match_id','text',null,'1'], ['match_answers','question_index','integer',null,'1'], ['match_answers','student_id','text',null,'1'],
    ['match_answers','correct','boolean',null,'0'], ['match_answers','won','boolean','false','1'], ['match_answers','answered_at','timestamp with time zone','now()','1'],
    ['cinema_videos','id','text',null,'1'], ['cinema_videos','title','text',null,'0'], ['cinema_videos','embed_url','text',null,'0'],
    ['cinema_videos','source_type','text','''embed''','1'], ['cinema_videos','description','text','''''','1'], ['cinema_videos','grade_id','text',null,'0'],
    ['cinema_videos','teacher_id','text',null,'0'], ['cinema_videos','teacher_name','text','''''','1'], ['cinema_videos','created_by','text','''''','1'],
    ['cinema_videos','created_at','timestamp with time zone','now()','1'], ['cinema_videos','updated_at','timestamp with time zone','now()','1'],
    ['student_card_permissions','id','text',null,'1'], ['student_card_permissions','scope','text',null,'0'], ['student_card_permissions','student_id','text',null,'0'],
    ['student_card_permissions','teacher_id','text',null,'0'], ['student_card_permissions','grade_id','text',null,'0'],
    ['student_card_permissions','cards','jsonb','''{}''::jsonb','1'], ['student_card_permissions','updated_by','text',null,'0'],
    ['student_card_permissions','updated_at','timestamp with time zone','now()','1'],
    ['entertainment_games','id','text',null,'1'], ['entertainment_games','title','text',null,'0'], ['entertainment_games','description','text','''''','1'],
    ['entertainment_games','embed_url','text',null,'0'], ['entertainment_games','teacher_id','text',null,'0'], ['entertainment_games','teacher_name','text','''''','1'],
    ['entertainment_games','is_active','boolean','true','1'],
    ['entertainment_games','created_at','timestamp with time zone','now()','1'], ['entertainment_games','updated_at','timestamp with time zone','now()','1']
  ];
  -- ‏المفتاحُ الأساسي لكل جدول (عمودٌ أو أكثر).
  pk text[][] := array[
    ['students','id'], ['parents','id'], ['teachers','id'], ['lesson_configs','id'], ['created_quizzes','id'],
    ['quiz_results','id'], ['interactions','id'], ['private_messages','id'], ['public_messages','id'],
    ['certificates','id'], ['app_kv','key'], ['ai_qa_cache','id'], ['challenge_matches','id'],
    ['match_messages','id'], ['duel_questions','id'], ['match_answers','match_id, question_index, student_id'],
    ['cinema_videos','id'], ['student_card_permissions','id'], ['entertainment_games','id']
  ];
  t text; c text; want text; def text; req boolean;
  have text; expr text; src text; pol record; tbl text; ident "char"; extra record;
  pk_have text; pk_name text;
  i int;
begin
  -- ‏العرضُ يُعاد إنشاؤه في solved-questions-cache.sql، ووجودُه يمنع تغيير نوع ai_qa_cache.data.
  drop view if exists public.solved_questions_cache;

  -- ‏السياساتُ القديمة قد تشير إلى أعمدةٍ يتغيّر نوعها، وكلُّها يُعاد إنشاؤه في الأجزاء التالية
  -- ‏(security-lockdown.sql يحذف ما سوى سياساته على أيّ حال).
  for i in 1 .. array_length(pk, 1) loop
    tbl := pk[i][1];
    if to_regclass(format('public.%I', tbl)) is not null then
      for pol in select policyname from pg_policies where schemaname = 'public' and tablename = tbl loop
        execute format('drop policy %I on public.%I', pol.policyname, tbl);
      end loop;
    end if;
  end loop;

  for i in 1 .. array_length(spec, 1) loop
    t := spec[i][1]; c := spec[i][2]; want := spec[i][3]; def := spec[i][4]; req := spec[i][5] = '1';
    continue when to_regclass(format('public.%I', t)) is null;

    select format_type(a.atttypid, a.atttypmod), a.attidentity into have, ident
      from pg_attribute a
     where a.attrelid = format('public.%I', t)::regclass and a.attname = c
       and a.attnum > 0 and not a.attisdropped;

    if have is null then
      -- ‏عمودٌ ناقص: بقيمته الافتراضية، و not null إن كانت له قيمةٌ تملأ الصفوف الموجودة.
      execute format('alter table public.%I add column %I %s%s%s', t, c, want,
        case when def is not null then ' default ' || def else '' end,
        case when def is not null and req then ' not null' else '' end);
      raise notice 'manara: أُضيف %.%  (%)', t, c, want;
      continue;
    end if;

    if have <> want then
      src := case when have in ('json', 'jsonb') then format('(%I #>> ''{}'')', c) else format('%I::text', c) end;
      expr := case want
        when 'jsonb' then case when have = 'json' then format('%I::jsonb', c) else format('pg_temp.manara_jsonb(%s)', src) end
        when 'text' then src
        when 'timestamp with time zone' then
          case when def = 'now()' then format('coalesce(pg_temp.manara_ts(%s), now())', src) else format('pg_temp.manara_ts(%s)', src) end
        when 'integer' then format('pg_temp.manara_int(%s)', src)
        when 'boolean' then
          case when def is not null then format('coalesce(pg_temp.manara_bool(%s), %s)', src, def) else format('pg_temp.manara_bool(%s)', src) end
        when 'text[]' then
          case when have = 'jsonb' then format('pg_temp.manara_text_array(%I::text)', c)
               when have = 'json' then format('pg_temp.manara_text_array(%I::text)', c)
               else format('pg_temp.manara_text_array(%s)', src) end
        when 'uuid' then format('pg_temp.manara_uuid(%s)', src)
        else format('%s::%s', src, want)
      end;
      -- ‏عمودُ identity (int8 من محرّر الجداول) لا يُحذف افتراضيُّه بـ drop default.
      if ident in ('a', 'd') then
        execute format('alter table public.%I alter column %I drop identity if exists', t, c);
      end if;
      execute format('alter table public.%I alter column %I drop default', t, c);
      begin
        execute format('alter table public.%I alter column %I type %s using %s', t, c, want, expr);
      exception when others then
        raise exception 'manara: تعذّر تحويل %.% من % إلى %: %', t, c, have, want, sqlerrm;
      end;
      raise notice 'manara: حُوِّل %.%  % ← %', t, c, want, have;
    end if;

    if def is not null then
      execute format('alter table public.%I alter column %I set default %s', t, c, def);
    end if;
    if def is not null and req then
      execute format('update public.%I set %I = %s where %I is null', t, c, def, c);
      execute format('alter table public.%I alter column %I set not null', t, c);
    end if;
  end loop;

  -- ‏أعمدةٌ زائدة ليست من بنيتنا (مثل app_kv.id) تبقى، لكن بلا not null إن لم تكن لها
  -- ‏قيمةٌ افتراضية، وإلا رُفض كلُّ صفٍّ يكتبه الخادم لأنه لا يعرفها.
  for extra in
    select c2.relname as t, a.attname as c
      from pg_attribute a
      join pg_class c2 on c2.oid = a.attrelid
      join pg_namespace n on n.oid = c2.relnamespace
     where n.nspname = 'public' and c2.relkind = 'r'
       and c2.relname in (select pk[k][1] from generate_subscripts(pk, 1) as k)
       and a.attnum > 0 and not a.attisdropped and a.attnotnull
       and not a.atthasdef and a.attidentity = ''
       and not exists (select 1 from generate_subscripts(spec, 1) as k
                        where spec[k][1] = c2.relname and spec[k][2] = a.attname)
  loop
    execute format('alter table public.%I alter column %I drop not null', extra.t, extra.c);
    raise notice 'manara: صار %.% (عمودٌ زائد) يقبل الفراغ', extra.t, extra.c;
  end loop;

  -- ‏المفتاحُ الأساسي: عليه تقوم الكتابةُ بـ upsert (on_conflict). والمفتاحُ الذي على عمودٍ
  -- ‏آخر (app_kv.id مثلاً) يُستبدل، فـ on_conflict=key لا يعمل إلا بمفتاحٍ على key.
  for i in 1 .. array_length(pk, 1) loop
    tbl := pk[i][1];
    continue when to_regclass(format('public.%I', tbl)) is null;
    pk_name := null; pk_have := null;
    select con.conname, string_agg(a.attname, ', ' order by k.ord) into pk_name, pk_have
      from pg_constraint con
      cross join lateral unnest(con.conkey) with ordinality as k(attnum, ord)
      join pg_attribute a on a.attrelid = con.conrelid and a.attnum = k.attnum
     where con.conrelid = format('public.%I', tbl)::regclass and con.contype = 'p'
     group by con.conname;
    if pk_name is not null and pk_have <> pk[i][2] then
      execute format('alter table public.%I drop constraint %I cascade', tbl, pk_name);
      raise notice 'manara: أُزيل مفتاحُ % على (%)، ومفتاحُه (%)', tbl, pk_have, pk[i][2];
      pk_name := null;
    end if;
    if pk_name is null then
      begin
        execute format('alter table public.%I add primary key (%s)', tbl, pk[i][2]);
        raise notice 'manara: أُضيف المفتاحُ الأساسي لـ % (%)', tbl, pk[i][2];
      exception when others then
        raise exception 'manara: تعذّرت إضافة المفتاح الأساسي لـ % (%): % — في الجدول قيمٌ مكرّرة أو فارغة', tbl, pk[i][2], sqlerrm;
      end;
    end if;
  end loop;
end $$;
