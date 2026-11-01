-- ═══════════════════════════════════════════════════════════════════════
-- «القاعدة النورانية» مادّةً مستقلّة في روضة منارة المعرفة — للمعلّم داود سيد اكرام
-- يُلصق كلُّه في Supabase → SQL Editor ويُشغَّل مرّةً واحدة.
--
-- ما يفعله:
--   ١. يُخرج فصل «تعليم القاعدة النورانية» (ووحدة «القاعدة النورانية» أينما
--      كانت) من «القرآن الكريم» في الروضة.
--   ٢. يضعه بأسمائه كما هي في مادّة «القاعدة النورانية» — التي أنشأها المعلّم
--      إن وُجدت — في مدخل الروضة الذي مالكُه معرّفُ داود، بعد «القرآن الكريم»:
--        القاعدة النورانية ← تعليم القاعدة النورانية ← القاعدة النورانية
--                         ← تعليم القراءة والقاعدة النورانية
--   ٣. الدروس والاختبارات: تتغيّر المادّةُ والمالكُ وحدهما. الفصلُ والوحدةُ
--      واسمُ الدرس والشرحُ والصوت والأسئلة والروابط والألعاب كما هي، ومعرّفُ
--      الدرس لا يتغيّر.
--   ٤. طلابُ الروضة الذين لهم «القرآن الكريم» تُسند إليهم المادّة، وسجلُّ
--      المعلّم، والقوائم المسطّحة، وختمُ المحتوى.
--
-- الأمان:
--   • كلُّ صفٍّ يُعدَّل تُحفظ نسختُه قبل التعديل في manara_backup.noorania_split.
--   • العمليّةُ كلُّها كتلةٌ واحدة (DO): إن فشل التحقّقُ في آخرها لم يُكتب شيء.
--   • تشغيلُها مرّةً ثانية لا يكرّر شيئاً.
-- ═══════════════════════════════════════════════════════════════════════

create schema if not exists manara_backup;
create table if not exists manara_backup.noorania_split (
  taken_at timestamptz not null default now(),
  source   text not null,
  row_id   text,
  payload  jsonb
);
-- ‏النسخةُ فيها بياناتُ طلاب: خارج ما تعرضه واجهةُ Supabase العامّة.
revoke all on schema manara_backup from public;

-- ── أدوات (مؤقّتة: تزول بانتهاء الجلسة) ──

-- تسويةٌ عربية للمقارنة وحدها.
create or replace function pg_temp.nrm(t text) returns text language sql immutable as $f$
  select btrim(regexp_replace(
    translate(regexp_replace(lower(coalesce(t, '')), '[ً-ْٰـ]', '', 'g'), 'أإآٱىة', 'اااايه'),
    '\s+', ' ', 'g'))
$f$;

-- المالكُ كما تقرؤه شاشاتُ الويب: teacher_id ?? teacherId ?? createdBy.
create or replace function pg_temp.owner_raw(j jsonb) returns text language sql immutable as $f$
  select btrim(coalesce(j->>'teacher_id', j->>'teacherId', j->>'createdBy', ''))
$f$;

create or replace function pg_temp.arr(j jsonb) returns jsonb language sql immutable as $f$
  select case when jsonb_typeof(j) = 'array' then j else '[]'::jsonb end
$f$;

create or replace function pg_temp.obj(j jsonb) returns jsonb language sql immutable as $f$
  select case when jsonb_typeof(j) = 'object' then j else '{}'::jsonb end
$f$;

-- وحداتُ فصل: قائمةُ units ومفاتيحُ خريطة lessons.
create or replace function pg_temp.units_of(t jsonb) returns text[] language plpgsql immutable as $f$
declare
  r text[] := '{}';
  u text;
begin
  for u in select btrim(x) from jsonb_array_elements_text(pg_temp.arr(t->'units')) as x loop
    if u <> '' and not (u = any(r)) then r := r || u; end if;
  end loop;
  for u in select jsonb_object_keys(pg_temp.obj(t->'lessons')) loop
    if btrim(u) <> '' and not (u = any(r)) then r := r || u; end if;
  end loop;
  return r;
end $f$;

create or replace function pg_temp.lessons_of(t jsonb, p_unit text) returns text[] language plpgsql immutable as $f$
declare
  r text[] := '{}';
  l text;
begin
  for l in select btrim(x) from jsonb_array_elements_text(pg_temp.arr(pg_temp.obj(t->'lessons')->p_unit)) as x loop
    if l <> '' then r := r || l; end if;
  end loop;
  return r;
end $f$;

-- يضيف وحدةً (إن لم تكن) ودروساً (ما لم يكن منها) إلى فصل.
create or replace function pg_temp.add_lessons(p_term jsonb, p_unit text, p_lessons text[]) returns jsonb language plpgsql immutable as $f$
declare
  v_units jsonb := pg_temp.arr(p_term->'units');
  v_map   jsonb := pg_temp.obj(p_term->'lessons');
  v_name  text;
  v_have  jsonb;
  l       text;
begin
  select x into v_name from jsonb_array_elements_text(v_units) as x where pg_temp.nrm(x) = pg_temp.nrm(p_unit) limit 1;
  if v_name is null then
    v_name := p_unit;
    v_units := v_units || to_jsonb(p_unit);
  end if;
  v_have := pg_temp.arr(v_map->v_name);
  foreach l in array coalesce(p_lessons, '{}') loop
    if not exists (select 1 from jsonb_array_elements_text(v_have) as h where pg_temp.nrm(h) = pg_temp.nrm(l)) then
      v_have := v_have || to_jsonb(l);
    end if;
  end loop;
  return p_term || jsonb_build_object('units', v_units, 'lessons', v_map || jsonb_build_object(v_name, v_have));
end $f$;

-- يضمّ مادّةً إلى مادّةٍ باسمها: الفصولُ والوحداتُ والدروسُ اتّحاداً.
create or replace function pg_temp.merge_subject(p_into jsonb, p_src jsonb) returns jsonb language plpgsql immutable as $f$
declare
  v_terms jsonb := pg_temp.arr(p_into->'terms');
  st      jsonb;
  tt      jsonb;
  v_idx   int;
  u       text;
begin
  for st in select x from jsonb_array_elements(pg_temp.arr(p_src->'terms')) as x loop
    if jsonb_typeof(st) <> 'object' or btrim(coalesce(st->>'term', '')) = '' then continue; end if;
    select (a.n - 1)::int into v_idx
      from jsonb_array_elements(v_terms) with ordinality as a(x, n)
     where pg_temp.nrm(a.x->>'term') = pg_temp.nrm(st->>'term')
     limit 1;
    if v_idx is null then
      v_terms := v_terms || jsonb_build_array(st || jsonb_build_object('term', btrim(st->>'term'), 'units', '[]'::jsonb, 'lessons', '{}'::jsonb));
      v_idx := jsonb_array_length(v_terms) - 1;
    end if;
    tt := v_terms->v_idx;
    foreach u in array pg_temp.units_of(st) loop
      tt := pg_temp.add_lessons(tt, u, pg_temp.lessons_of(st, u));
    end loop;
    v_terms := jsonb_set(v_terms, array[v_idx::text], tt);
  end loop;
  return p_into || jsonb_build_object('terms', v_terms);
end $f$;

create or replace function pg_temp.lesson_count(p_subject jsonb) returns int language plpgsql immutable as $f$
declare
  n  int := 0;
  t  jsonb;
  u  text;
begin
  for t in select x from jsonb_array_elements(pg_temp.arr(p_subject->'terms')) as x loop
    foreach u in array pg_temp.units_of(t) loop
      n := n + coalesce(array_length(pg_temp.lessons_of(t, u), 1), 0);
    end loop;
  end loop;
  return n;
end $f$;

-- قائمةُ موادّ (نصوصٌ أو كائنات {name|subject}) فيها اسمٌ ما؟
create or replace function pg_temp.list_has(p_list jsonb, p_name text) returns boolean language sql immutable as $f$
  select exists (
    select 1 from jsonb_array_elements(pg_temp.arr(p_list)) as x
     where pg_temp.nrm(case when jsonb_typeof(x) = 'string' then x #>> '{}' else coalesce(x->>'name', x->>'subject') end) = pg_temp.nrm(p_name))
$f$;

-- ── التنفيذ ──
do $main$
declare
  c_grade   constant text := 'روضة منارة المعرفة';
  c_teacher constant text := 'داود سيد اكرام';
  c_quran   constant text := 'القرآن الكريم';
  c_subject constant text := 'القاعدة النورانية';
  c_tree    constant text := 'smartEdu_hierarchicalConfigs';

  v_tid text; v_tname text; v_trow text; v_ids text[]; v_n int;
  v_cfgs jsonb; v_final jsonb := '[]'; cfg jsonb; subj jsonb; term jsonb; v_terms jsonb; v_subjects jsonb;
  i int; j int; k int; u text; v_changed boolean;
  v_extracted jsonb := '{"terms": []}'; v_moved int := 0; v_qgrade text;
  v_mine int[] := '{}'; v_t int; v_best int := -1; v_score int; v_drop int[] := '{}';
  v_placed boolean; v_collected jsonb := '[]'; v_sub jsonb; v_sidx int; v_qidx int;
  r record; v_data jsonb; v_new text; v_lesson_ids text[] := '{}';
  v_has_upd boolean; v_key text; v_list jsonb; v_next jsonb; v_present text[] := '{}';
  v_count_lessons int := 0; v_count_quiz int := 0; v_count_students int := 0;
begin
  -- ١. المعلّم.
  select count(*) into v_n from public.teachers t
   where pg_temp.nrm(t.data->>'name') like '%' || pg_temp.nrm(c_teacher) || '%';
  if v_n <> 1 then
    raise exception 'وُجد % معلّماً باسم «%» — يلزم واحدٌ بالضبط.', v_n, c_teacher;
  end if;
  select coalesce(nullif(btrim(t.data->>'id'), ''), t.id::text), coalesce(t.data->>'name', ''), t.id::text,
         array_remove(array[pg_temp.nrm(t.id::text), pg_temp.nrm(t.data->>'id'), pg_temp.nrm(t.data->>'username'), pg_temp.nrm(t.data->>'name')], '')
    into v_tid, v_tname, v_trow, v_ids
    from public.teachers t
   where pg_temp.nrm(t.data->>'name') like '%' || pg_temp.nrm(c_teacher) || '%';
  raise notice 'المعلّم: % — المعرّف «%»', v_tname, v_tid;

  -- ٢. الشجرة (مع نسختها).
  select case when jsonb_typeof(a.value::jsonb) = 'string' then (a.value::jsonb #>> '{}')::jsonb else a.value::jsonb end
    into v_cfgs from public.app_kv a where a.key = c_tree for update;
  if v_cfgs is null or jsonb_typeof(v_cfgs) <> 'array' then
    raise exception 'لم توجد الشجرة % في app_kv.', c_tree;
  end if;
  insert into manara_backup.noorania_split (source, row_id, payload)
  select 'app_kv', a.key, to_jsonb(a) from public.app_kv a
   where a.key in (c_tree, 'smartEdu_subjects', 'smartEdu_terms', 'smartEdu_units');

  -- ٢-أ. نزعُ النورانية من «القرآن الكريم» في كل مدخلٍ للروضة.
  for i in 0 .. jsonb_array_length(v_cfgs) - 1 loop
    cfg := v_cfgs->i;
    if jsonb_typeof(cfg) <> 'object' or jsonb_typeof(cfg->'subjects') <> 'array'
       or pg_temp.nrm(cfg->>'grade') not like '%روضه%' then continue; end if;
    for j in 0 .. jsonb_array_length(cfg->'subjects') - 1 loop
      subj := cfg->'subjects'->j;
      if pg_temp.nrm(subj->>'subject') <> pg_temp.nrm(c_quran) or jsonb_typeof(subj->'terms') <> 'array' then continue; end if;
      v_terms := '[]';
      v_changed := false;
      for term in select x from jsonb_array_elements(subj->'terms') as x loop
        if pg_temp.nrm(term->>'term') like '%نوراني%' then
          -- ‏الفصلُ كلُّه بأسمائه: وحداتُه ودروسُه كما هي.
          v_extracted := pg_temp.merge_subject(v_extracted, jsonb_build_object('terms', jsonb_build_array(term)));
          v_moved := v_moved + 1;
          v_changed := true;
          raise notice 'يُنزع من القرآن (%): الفصل «%»', cfg->>'grade', term->>'term';
          continue;
        end if;
        foreach u in array pg_temp.units_of(term) loop
          if pg_temp.nrm(u) like '%نوراني%' then
            -- ‏وحدةٌ وحدها تحت فصلٍ آخر: تنتقل تحت فصلٍ بالاسم نفسه.
            v_extracted := pg_temp.merge_subject(v_extracted, jsonb_build_object('terms', jsonb_build_array(
              jsonb_build_object('term', term->>'term', 'units', jsonb_build_array(u),
                                 'lessons', jsonb_build_object(u, to_jsonb(pg_temp.lessons_of(term, u)))))));
            v_moved := v_moved + 1;
            term := term || jsonb_build_object(
              'units', coalesce((select jsonb_agg(x) from jsonb_array_elements(pg_temp.arr(term->'units')) as x
                                  where pg_temp.nrm(x #>> '{}') <> pg_temp.nrm(u)), '[]'::jsonb),
              'lessons', pg_temp.obj(term->'lessons') - u);
            v_changed := true;
            raise notice 'يُنزع من القرآن (%): الوحدة «%» من الفصل «%»', cfg->>'grade', u, term->>'term';
          end if;
        end loop;
        v_terms := v_terms || jsonb_build_array(term);
      end loop;
      if v_changed then
        v_cfgs := jsonb_set(v_cfgs, array[i::text, 'subjects', j::text, 'terms'], v_terms);
        v_qgrade := coalesce(v_qgrade, cfg->>'grade');
      end if;
    end loop;
  end loop;

  raise notice 'المنقولُ بأسمائه: %', v_extracted->'terms';

  -- ٢-ب. مدخلُ داود للروضة: مالكُه معرّفُه (ويُفضَّل اسمُ الصفّ نفسه).
  for i in 0 .. jsonb_array_length(v_cfgs) - 1 loop
    cfg := v_cfgs->i;
    if jsonb_typeof(cfg) = 'object' and jsonb_typeof(cfg->'subjects') = 'array'
       and pg_temp.nrm(cfg->>'grade') like '%روضه%'
       and pg_temp.nrm(pg_temp.owner_raw(cfg)) = any(v_ids) then
      v_mine := v_mine || i;
      v_score := (case when lower(pg_temp.owner_raw(cfg)) = lower(v_tid) then 2 else 0 end)
               + (case when pg_temp.nrm(cfg->>'grade') = pg_temp.nrm(c_grade) then 1 else 0 end);
      if v_score > v_best then v_best := v_score; v_t := i; end if;
    end if;
  end loop;

  if v_t is null then
    v_cfgs := v_cfgs || jsonb_build_array(jsonb_build_object(
      'grade', coalesce(v_qgrade, c_grade), 'subjects', '[]'::jsonb,
      'teacher_id', v_tid, 'createdBy', v_tid, 'createdByName', v_tname, 'createdAt', now()::text));
    v_t := jsonb_array_length(v_cfgs) - 1;
    raise notice 'لا مدخلَ لداود في الروضة — أُنشئ له.';
  elsif lower(pg_temp.owner_raw(v_cfgs->v_t)) <> lower(v_tid) then
    raise notice 'مدخلُ داود مالكُه «%» — صار «%» ليظهر في شاشاته.', pg_temp.owner_raw(v_cfgs->v_t), v_tid;
    cfg := (v_cfgs->v_t) || jsonb_build_object('teacher_id', v_tid);
    if cfg ? 'teacherId' then cfg := cfg || jsonb_build_object('teacherId', v_tid); end if;
    v_cfgs := jsonb_set(v_cfgs, array[v_t::text], cfg);
  end if;
  v_placed := exists (select 1 from jsonb_array_elements(v_cfgs->v_t->'subjects') as x
                       where pg_temp.nrm(x->>'subject') = pg_temp.nrm(c_subject));

  -- ‏مدخلاتُه الأخرى للصفّ نفسه تُدمج فيه.
  foreach i in array v_mine loop
    if i = v_t or pg_temp.nrm(v_cfgs->i->>'grade') <> pg_temp.nrm(v_cfgs->v_t->>'grade') then continue; end if;
    for subj in select x from jsonb_array_elements(v_cfgs->i->'subjects') as x loop
      if btrim(coalesce(subj->>'subject', '')) = '' then continue; end if;
      v_subjects := v_cfgs->v_t->'subjects';
      select (a.n - 1)::int into k from jsonb_array_elements(v_subjects) with ordinality as a(x, n)
       where pg_temp.nrm(a.x->>'subject') = pg_temp.nrm(subj->>'subject') limit 1;
      if k is null then
        v_subjects := v_subjects || jsonb_build_array(jsonb_build_object('subject', btrim(subj->>'subject'), 'terms', '[]'::jsonb));
        k := jsonb_array_length(v_subjects) - 1;
      end if;
      v_subjects := jsonb_set(v_subjects, array[k::text], pg_temp.merge_subject(v_subjects->k, subj));
      v_cfgs := jsonb_set(v_cfgs, array[v_t::text, 'subjects'], v_subjects);
    end loop;
    v_drop := v_drop || i;
    raise notice 'دُمج مدخلٌ لداود بمالك «%» في مدخله.', pg_temp.owner_raw(v_cfgs->i);
  end loop;

  -- ٢-ج. نسخُ المادّة خارج مدخله: تُضمّ إن كانت له في الروضة أو فارغة.
  for i in 0 .. jsonb_array_length(v_cfgs) - 1 loop
    cfg := v_cfgs->i;
    if i = v_t or i = any(v_drop) or jsonb_typeof(cfg) <> 'object' or jsonb_typeof(cfg->'subjects') <> 'array' then continue; end if;
    v_subjects := '[]';
    v_changed := false;
    for subj in select x from jsonb_array_elements(cfg->'subjects') as x loop
      if pg_temp.nrm(subj->>'subject') = pg_temp.nrm(c_subject)
         and ((pg_temp.nrm(cfg->>'grade') like '%روضه%' and i = any(v_mine)) or pg_temp.lesson_count(subj) = 0) then
        v_collected := v_collected || jsonb_build_array(subj);
        v_changed := true;
        raise notice 'تُنقل «%» من «%» (%) إلى مدخل داود.', c_subject, cfg->>'grade', pg_temp.owner_raw(cfg);
      else
        if pg_temp.nrm(subj->>'subject') = pg_temp.nrm(c_subject) then
          raise notice '«%» في «%» لـ«%» فيها % درساً — بقيت مكانها.', c_subject, cfg->>'grade', pg_temp.owner_raw(cfg), pg_temp.lesson_count(subj);
        end if;
        v_subjects := v_subjects || jsonb_build_array(subj);
      end if;
    end loop;
    if v_changed then
      v_cfgs := jsonb_set(v_cfgs, array[i::text, 'subjects'], v_subjects);
      if i = any(v_mine) and jsonb_array_length(v_subjects) = 0 then v_drop := v_drop || i; end if;
    end if;
  end loop;

  -- ٢-د. المادّةُ في مدخل داود: ما أنشأه المعلّم فيها، وما نُقل من القرآن بأسمائه.
  v_subjects := v_cfgs->v_t->'subjects';
  select (a.n - 1)::int into v_sidx from jsonb_array_elements(v_subjects) with ordinality as a(x, n)
   where pg_temp.nrm(a.x->>'subject') = pg_temp.nrm(c_subject) limit 1;
  v_sub := coalesce(v_subjects->v_sidx, jsonb_build_object('subject', c_subject, 'terms', '[]'::jsonb));
  for subj in select x from jsonb_array_elements(v_collected) as x loop
    v_sub := pg_temp.merge_subject(v_sub, subj);
  end loop;
  v_sub := pg_temp.merge_subject(v_sub, v_extracted);

  if v_placed then
    v_subjects := jsonb_set(v_subjects, array[v_sidx::text], v_sub);
  else
    if v_sidx is not null then v_subjects := v_subjects - v_sidx; end if;
    select (a.n - 1)::int into v_qidx from jsonb_array_elements(v_subjects) with ordinality as a(x, n)
     where pg_temp.nrm(a.x->>'subject') = pg_temp.nrm(c_quran) limit 1;
    if v_qidx is null then
      v_subjects := v_subjects || jsonb_build_array(v_sub);
    else
      v_subjects := jsonb_insert(v_subjects, array[v_qidx::text], v_sub, true);
    end if;
  end if;
  v_cfgs := jsonb_set(v_cfgs, array[v_t::text, 'subjects'], v_subjects);

  for i in 0 .. jsonb_array_length(v_cfgs) - 1 loop
    if not (i = any(v_drop)) then v_final := v_final || jsonb_build_array(v_cfgs->i); end if;
  end loop;
  update public.app_kv set value = v_final, updated_at = now() where key = c_tree;

  -- ٣. الدروس: المسارُ والمالكُ وحدهما.
  select exists (select 1 from information_schema.columns
                  where table_schema = 'public' and table_name = 'lesson_configs' and column_name = 'updated_at')
    into v_has_upd;

  for r in
    select lc.id::text as id, lc.data from public.lesson_configs lc
     where jsonb_typeof(lc.data) = 'object'
       and pg_temp.nrm(lc.data->>'grade') like '%روضه%'
       and ((pg_temp.nrm(lc.data->>'subject') = pg_temp.nrm(c_quran)
             and (pg_temp.nrm(lc.data->>'term') like '%نوراني%' or pg_temp.nrm(lc.data->>'unit') like '%نوراني%'))
         or (pg_temp.nrm(lc.data->>'subject') = pg_temp.nrm(c_subject)
             and pg_temp.nrm(pg_temp.owner_raw(lc.data)) = any(v_ids)
             and lower(pg_temp.owner_raw(lc.data)) <> lower(v_tid)))
     for update
  loop
    v_data := r.data;
    if pg_temp.nrm(v_data->>'subject') = pg_temp.nrm(c_quran) then
      -- ‏المادّةُ وحدها تتغيّر؛ الفصلُ والوحدةُ واسمُ الدرس كما هي.
      v_data := v_data || jsonb_build_object('subject', c_subject);
      raise notice 'درس %: «%» ← مادّة «%»', r.id, coalesce(v_data->>'lesson', v_data->>'lessonName'), c_subject;
    end if;
    v_data := v_data || jsonb_build_object('teacher_id', v_tid);
    if v_data ? 'teacherId' then v_data := v_data || jsonb_build_object('teacherId', v_tid); end if;

    insert into manara_backup.noorania_split (source, row_id, payload) values ('lesson_configs', r.id, r.data);
    update public.lesson_configs set data = v_data where id::text = r.id;
    v_lesson_ids := v_lesson_ids || r.id;
    v_count_lessons := v_count_lessons + 1;
  end loop;
  if v_has_upd and v_count_lessons > 0 then
    execute 'update public.lesson_configs set updated_at = now() where id::text = any($1)' using v_lesson_ids;
  end if;

  -- ٤. الاختبارات المنشأة.
  if to_regclass('public.created_quizzes') is not null then
    for r in execute
      'select q.id::text as id, q.data from public.created_quizzes q where jsonb_typeof(q.data) = ''object'' for update'
    loop
      v_data := r.data;
      if pg_temp.nrm(v_data->>'subject') = pg_temp.nrm(c_quran)
         and ((pg_temp.nrm(v_data->>'grade') like '%روضه%'
               and (pg_temp.nrm(v_data->>'term') like '%نوراني%' or pg_temp.nrm(v_data->>'unit') like '%نوراني%'))
           or coalesce(v_data->>'lessonId', v_data->>'lesson_id', '') = any(v_lesson_ids)) then
        v_data := v_data || jsonb_build_object('subject', c_subject);
      elsif not (coalesce(v_data->>'lessonId', v_data->>'lesson_id', '') = any(v_lesson_ids)) then
        continue;
      end if;
      v_data := v_data || jsonb_build_object('teacher_id', v_tid);
      if v_data ? 'teacherId' then v_data := v_data || jsonb_build_object('teacherId', v_tid); end if;
      if v_data = r.data then continue; end if;
      insert into manara_backup.noorania_split (source, row_id, payload) values ('created_quizzes', r.id, r.data);
      execute 'update public.created_quizzes set data = $1 where id::text = $2' using v_data, r.id;
      v_count_quiz := v_count_quiz + 1;
    end loop;
  end if;

  -- ٥. الطلاب: طالبُ الروضة الذي له «القرآن الكريم» تُسند إليه المادّة، ويُنقل مسارُه.
  if to_regclass('public.students') is not null then
    for r in execute 'select s.id::text as id, s.data from public.students s where jsonb_typeof(s.data) = ''object'' for update'
    loop
      v_data := r.data;
      if btrim(coalesce(v_data->>'grade', '')) = '' or pg_temp.nrm(v_data->>'grade') like '%روضه%' then
        foreach v_key in array array['assignedSubjects', 'assigned_subjects'] loop
          v_list := v_data->v_key;
          if jsonb_typeof(v_list) = 'array' and pg_temp.list_has(v_list, c_quran) and not pg_temp.list_has(v_list, c_subject) then
            v_data := v_data || jsonb_build_object(v_key, v_list || jsonb_build_array(
              case when jsonb_typeof(v_list->0) = 'string' then to_jsonb(c_subject)
                   else pg_temp.obj(v_list->0) || jsonb_build_object('name', c_subject, 'subject', c_subject) end));
          end if;
        end loop;
      end if;
      v_next := v_data->'lastPath';
      if jsonb_typeof(v_next) = 'object'
         and pg_temp.nrm(v_next->>'grade') like '%روضه%'
         and pg_temp.nrm(v_next->>'subject') = pg_temp.nrm(c_quran)
         and (pg_temp.nrm(v_next->>'term') like '%نوراني%' or pg_temp.nrm(v_next->>'unit') like '%نوراني%') then
        v_data := v_data || jsonb_build_object('lastPath', v_next || jsonb_build_object('subject', c_subject));
      end if;
      if pg_temp.nrm(v_data->>'grade') like '%روضه%'
         and pg_temp.nrm(v_data->>'subject') = pg_temp.nrm(c_quran)
         and (pg_temp.nrm(v_data->>'term') like '%نوراني%' or pg_temp.nrm(v_data->>'unit') like '%نوراني%') then
        v_data := v_data || jsonb_build_object('subject', c_subject);
      end if;
      if v_data = r.data then continue; end if;
      insert into manara_backup.noorania_split (source, row_id, payload) values ('students', r.id, r.data);
      execute 'update public.students set data = $1 where id::text = $2' using v_data, r.id;
      v_count_students := v_count_students + 1;
    end loop;
  end if;

  -- ٦. سجلُّ المعلّم: المادّةُ في قوائم موادّه.
  select t.data into v_data from public.teachers t where t.id::text = v_trow for update;
  v_next := v_data;
  foreach v_key in array array['subjects', 'assignedSubjects'] loop
    v_list := v_next->v_key;
    if jsonb_typeof(v_list) = 'array' and not pg_temp.list_has(v_list, c_subject) then
      v_next := v_next || jsonb_build_object(v_key, v_list || jsonb_build_array(
        case when jsonb_array_length(v_list) > 0 and jsonb_typeof(v_list->0) <> 'string'
             then jsonb_build_object('name', c_subject, 'subject', c_subject)
             else to_jsonb(c_subject) end));
    end if;
  end loop;
  if v_next <> v_data then
    insert into manara_backup.noorania_split (source, row_id, payload) values ('teachers', v_trow, v_data);
    update public.teachers set data = v_next where id::text = v_trow;
  end if;

  -- ٧. القائمةُ المسطّحة للموادّ (إن كانت مخزونة): تُضاف المادّة. والفصولُ
  -- ‏والوحداتُ بأسمائها فلا تتغيّر قوائمُها.
  select case when jsonb_typeof(a.value::jsonb) = 'string' then (a.value::jsonb #>> '{}')::jsonb else a.value::jsonb end
    into v_list from public.app_kv a where a.key = 'smartEdu_subjects';
  if jsonb_typeof(v_list) = 'array' and not pg_temp.list_has(v_list, c_subject) then
    update public.app_kv set value = v_list || to_jsonb(c_subject), updated_at = now() where key = 'smartEdu_subjects';
  end if;

  -- ٨. ختمُ المحتوى: كلُّ جهازٍ يأخذ النسخةَ الجديدة.
  insert into public.app_kv (key, value, updated_at)
  values ('smartEdu_contentEpoch', to_jsonb(now()::text), now())
  on conflict (key) do update set value = excluded.value, updated_at = excluded.updated_at;

  -- ٩. التحقّق — وإن فشل لم يُكتب شيءٌ ممّا سبق.
  if exists (
    select 1 from jsonb_array_elements(v_final) as c, jsonb_array_elements(pg_temp.arr(c->'subjects')) as s,
                  jsonb_array_elements(pg_temp.arr(s->'terms')) as t
     where pg_temp.nrm(c->>'grade') like '%روضه%'
       and pg_temp.nrm(s->>'subject') = pg_temp.nrm(c_quran)
       and (pg_temp.nrm(t->>'term') like '%نوراني%'
            or exists (select 1 from unnest(pg_temp.units_of(t)) as uu where pg_temp.nrm(uu) like '%نوراني%'))
  ) then
    raise exception 'التحقّق: ما زال للنورانية أثرٌ تحت «القرآن الكريم» في الشجرة.';
  end if;
  if not exists (
    select 1 from jsonb_array_elements(v_final) as c, jsonb_array_elements(pg_temp.arr(c->'subjects')) as s
     where pg_temp.nrm(c->>'grade') like '%روضه%'
       and lower(pg_temp.owner_raw(c)) = lower(v_tid)
       and pg_temp.nrm(s->>'subject') = pg_temp.nrm(c_subject)
  ) then
    raise exception 'التحقّق: «%» ليست في مدخل الروضة الذي مالكُه «%».', c_subject, v_tid;
  end if;
  if pg_temp.lesson_count(v_sub) < pg_temp.lesson_count(v_extracted) then
    raise exception 'التحقّق: دروسُ المادّة (%) أقلُّ ممّا نُقل (%).', pg_temp.lesson_count(v_sub), pg_temp.lesson_count(v_extracted);
  end if;
  if exists (
    select 1 from public.lesson_configs lc
     where pg_temp.nrm(lc.data->>'grade') like '%روضه%'
       and pg_temp.nrm(lc.data->>'subject') = pg_temp.nrm(c_quran)
       and (pg_temp.nrm(lc.data->>'term') like '%نوراني%' or pg_temp.nrm(lc.data->>'unit') like '%نوراني%')
  ) then
    raise exception 'التحقّق: ما زالت دروسٌ تحت نورانية «القرآن الكريم».';
  end if;

  raise notice '✓ تمّ: % درساً، % اختباراً، % طالباً. النسخة الاحتياطية في manara_backup.noorania_split.',
    v_count_lessons, v_count_quiz, v_count_students;
end
$main$;

-- النتيجة: مادّةُ «القاعدة النورانية» في مدخل الروضة كما صارت.
select c->>'grade' as grade,
       pg_temp.owner_raw(c) as owner,
       s->>'subject' as subject,
       jsonb_pretty(s->'terms') as terms
  from public.app_kv a,
       jsonb_array_elements(case when jsonb_typeof(a.value::jsonb) = 'array' then a.value::jsonb else '[]'::jsonb end) as c,
       jsonb_array_elements(pg_temp.arr(c->'subjects')) as s
 where a.key = 'smartEdu_hierarchicalConfigs'
   and pg_temp.nrm(c->>'grade') like '%روضه%'
   and pg_temp.nrm(s->>'subject') in (pg_temp.nrm('القرآن الكريم'), pg_temp.nrm('القاعدة النورانية'));
