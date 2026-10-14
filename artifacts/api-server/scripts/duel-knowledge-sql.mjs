/**
 * يولّد `duel-knowledge-bank.sql` من `src/lib/knowledgeBank.ts`.
 *
 * البنكُ يُكتب مرّةً في TypeScript، ومنه يُولَّد ما يُلصق في محرّر SQL في
 * Supabase. واختبارُ `knowledgeBank.test.mjs` يُعيد التوليد ويقارنه بالملفّ،
 * فلا يُضاف سؤالٌ هنا وينسى هناك.
 *
 * التشغيل:
 *   node ./build.mjs && node ./scripts/duel-knowledge-sql.mjs
 */

import { writeFile } from "node:fs/promises";
import path from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";

const here = path.dirname(fileURLToPath(import.meta.url));
export const OUTPUT = path.resolve(here, "duel-knowledge-bank.sql");

const sql = (value) => `'${String(value).replace(/'/g, "''")}'`;

const HEADER = `-- ════════════════════════════════════════════════════════════════════════
-- بطاقة «تحدَّ زملاءكَ»: أبوابُ المعرفة العامّة
-- ════════════════════════════════════════════════════════════════════════
--
-- مولَّدٌ من src/lib/knowledgeBank.ts بـ scripts/duel-knowledge-sql.mjs —
-- لا يُعدَّل باليد.
--
-- ثلاثةُ أشياء، ويُعاد تشغيلُه بأمان:
--   ١. أبوابٌ جديدة في duel_questions: ثقافة، رياضة، جغرافيا، تاريخ، علوم.
--   ٢. أسئلتُها.
--   ٣. claim_duel_pack بتوزيعٍ جديد: أربعةٌ من مجال الدرس، وأربعةٌ من المعرفة
--      العامّة (بابٌ واحدٌ لكل سؤال، فلا يتكرّر بابٌ في المباراة)، واثنان ذكاءٌ
--      وسرعة. وما لُعب في آخر عشر مبارياتٍ لأيٍّ من اللاعبَين يُؤخَّر.
--
-- يُشغَّل بعد duel-question-bank.sql، في محرّر SQL في Supabase.

begin;

-- ── ١. الأبواب ──
alter table public.duel_questions drop constraint if exists duel_questions_category;
alter table public.duel_questions add constraint duel_questions_category
  check (category in (
    'domain', 'general', 'logic', 'quick', 'school',
    'culture', 'sports', 'geography', 'history', 'science'
  ));
`;

const CLAIM = `
-- ── ٣. اختيارُ الحزمة ──
--
-- النمط D K B D K D K B D K: لا يتتابع بابٌ واحد، وما نقص من بابٍ يُكمله
-- غيرُه. و«آخر عشر مباريات» لكلٍّ من اللاعبَين لا للزوج وحده: الطفلُ يلعب
-- مع زملاءَ كثيرين، والسؤالُ الذي رآه أمس مع غيره يُملّ اليوم أيضاً.
-- والتأخيرُ لا المنع: يُختار المكرَّر إن لم يبقَ غيرُه، فلا تقصر حزمة.
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

  -- الأحدثُ أوّلاً: موضعُ السؤال في القائمة هو قربُ آخر مرّةٍ لُعب فيها.
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

  -- ── أربعةٌ من مجال الدرس ──
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

  -- ── وأربعةٌ من المعرفة العامّة: الأوّلُ من كل باب، ثم أربعةٌ من الخمسة ──
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

  -- ── واثنان: ذكاءٌ وسرعة ──
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
`;

/** نصُّ الملفّ كاملاً لهذه الأسئلة. */
export function renderKnowledgeSql(seeds, idOf) {
  const values = seeds.map(
    (seed) =>
      `  (${sql(idOf(seed))}, '*', ${sql(seed.category)}, ${sql(seed.prompt)}, array[${seed.choices
        .map(sql)
        .join(", ")}])`,
  );
  return `${HEADER}
-- ── ٢. الأسئلة (${seeds.length}) ──
insert into public.duel_questions (id, subject_key, category, prompt, choices)
values
${values.join(",\n")}
on conflict do nothing;
${CLAIM}`;
}

if (import.meta.url === pathToFileURL(process.argv[1] ?? "").href) {
  const bank = await import(pathToFileURL(path.resolve(here, "../dist/lib/knowledgeBank.mjs")).href);
  await writeFile(OUTPUT, renderKnowledgeSql(bank.KNOWLEDGE_SEEDS, bank.knowledgeId), "utf8");
  console.log(`wrote ${OUTPUT} (${bank.KNOWLEDGE_SEEDS.length} questions)`);
}
