-- بنكُ أسئلة المبارزة الحيّ، وحزمةٌ تُثبَّت مرّةً لكل مباراة.
--
-- التشغيل: الصقه كاملاً في محرّر SQL في Supabase. آمنٌ على قاعدةٍ فيها
-- مباريات، ويُعاد تشغيلُه بلا ضرر. يحتاج `challenge-matches.sql` و
-- `duel-upgrade.sql` قبله.
--
-- ── ما يحلّه ──
-- كان البنكُ واحداً وثابتاً: ٥١ سؤالاً لكل المواد. فصار الزميلان يريان الأسئلة
-- نفسها بعد جولاتٍ قليلة، ولا شيءَ منها يتّصل بما يدرسانه.
--
-- فالحزمةُ الآن عشرة: ستّةٌ من مجال الدرس (مادّته، ووحدته أوّلاً) وأربعةٌ
-- ذكاءٌ وسرعةُ بديهة. والبنكُ جدولٌ يكبر: يملؤه التوليدُ في الخادم بعد أن يحفظ
-- المعلمُ درساً، ويُعطّل المعلمُ منه ما لا يريد.
--
-- ── ولماذا تُختار الحزمةُ هنا لا في التطبيق ──
-- لو اختار كلُّ جهازٍ حزمتَه من بنكٍ يكبر، لقرأ الجهازان بنكين مختلفين في
-- لحظتين ورأى كلٌّ أسئلةً غيرَ أسئلة زميله — بلا خطأٍ يظهر. فالاختيارُ في
-- `claim_duel_pack` مرّةً واحدةً تحت قفل الصفّ، ويُكتب في المباراة؛ ومن جاء
-- ثانياً يقرأ ما كُتب.
--
-- ── ولماذا لا يختار التطبيقُ الأسئلةَ ولا يرسلها ──
-- الطالبُ يدخل بمفتاح anon بلا جلسة Supabase — لا `auth.uid()` يُعرف به —
-- ومفتاحُ anon يُستخرج من أي APK. فالدالّةُ لا تقبل منه إلا معرّفَ المباراة،
-- وتختار الأسئلةَ بنفسها من البنك. وأقصى ما يفعله حاملُ المفتاح أن يُثبّت
-- حزمةً كانت ستُثبَّت على كل حال، من البنك نفسه، لمباراةٍ يعرف معرّفها.

begin;

-- ════════════════════════════════════════════════════════════════════════
-- ١. البنك
-- ════════════════════════════════════════════════════════════════════════

create table if not exists public.duel_questions (
  -- `<الباب>:<بصمة السؤال>`، وللمجال `domain:<المادة>:<البصمة>`. وأسئلةُ
  -- البنك المكتوب تحمل المعرّفَ نفسه الذي يحمله البنكُ المحليّ في التطبيق.
  id text primary key,

  -- مفتاحُ المادة كما تُخرجه `duel_subject_key`. و`*` للعامّ.
  subject_key text not null default '*',

  -- الوحدةُ إن عُرفت: تُقدَّم أسئلتُها على بقية المادة.
  unit text,

  -- all: لكل الابتدائي. low: الأول إلى الثالث. high: الرابع إلى السادس.
  grade_band text not null default 'all',

  -- domain: من مجال الدرس. والبقيّةُ عامّة.
  category text not null,

  prompt text not null,

  -- الجوابُ أوّلاً ثم المشتّتات. يُخلط الترتيبُ عند بناء الحزمة.
  choices text[] not null,

  -- seed: مكتوبٌ هنا. ai: من التوليد. teacher: كتبه معلم.
  source text not null default 'seed',

  -- ── والتعطيلُ لا الحذف ──
  -- سؤالٌ يُحذف يختفي من حزمٍ حُفظت فيها معرّفاتُه، ولا يُعرف لماذا غاب.
  active boolean not null default true,
  disabled_by text,
  disabled_at timestamptz,

  created_at timestamptz not null default now(),

  constraint duel_questions_category
    check (category in ('domain', 'general', 'logic', 'quick', 'school')),
  constraint duel_questions_band check (grade_band in ('all', 'low', 'high')),
  constraint duel_questions_source check (source in ('seed', 'ai', 'teacher')),
  constraint duel_questions_prompt check (char_length(btrim(prompt)) between 4 and 220),
  constraint duel_questions_choices check (array_length(choices, 1) between 3 and 4)
);

-- السؤالُ نفسه لا يُكتب مرّتين في المادة نفسها — والتوليدُ يُعاد كثيراً.
create unique index if not exists duel_questions_prompt_uq
  on public.duel_questions (subject_key, prompt);

create index if not exists duel_questions_pick_idx
  on public.duel_questions (subject_key, category)
  where active;

-- ── الصلاحيات ──
-- البنكُ فيه الأجوبة، فلا يقرؤه التطبيقُ مباشرة. يكتبه الخادمُ بدور الخدمة،
-- ويُقرأ منه عبر `claim_duel_pack` وحدها.
alter table public.duel_questions enable row level security;
revoke all on table public.duel_questions from public, anon, authenticated;
grant all on table public.duel_questions to service_role;

comment on table public.duel_questions is
  'بنكُ أسئلة المبارزة: مجالُ الدرس وذكاءٌ وسرعة بديهة. يكتبه الخادم، ويُختار منه في claim_duel_pack.';

-- ════════════════════════════════════════════════════════════════════════
-- ٢. مفتاحُ المادة وشريحةُ الصفّ
-- ════════════════════════════════════════════════════════════════════════

-- اسمُ المادة يكتبه المعلم كما يشاء: «العلوم»، «علوم»، «Science». والمفتاحُ
-- يجمعها. والترتيبُ مقصود: «اللغة الإنجليزية» تُفحص قبل «العربية».
create or replace function public.duel_subject_key(raw text)
returns text
language sql
immutable
as $$
  select case
    when raw is null or btrim(raw) = '' then 'other'
    when raw ~* '(رياضيات|رياضيّات|math)' then 'math'
    when raw ~* '(علوم|science)' then 'science'
    when raw ~* '(انجليز|إنجليز|انكليز|english)' then 'english'
    when raw ~* '(اسلام|إسلام|قرآن|قران|توحيد|فقه|حديث|تجويد|تفسير|islamic)' then 'islamic'
    when raw ~* '(اجتماع|وطني|تاريخ|جغراف|social)' then 'social'
    when raw ~* '(عربي|لغتي|arabic)' then 'arabic'
    else 'other'
  end
$$;

-- low للأول إلى الثالث، وhigh لما بعده، وall إن لم يُعرف — فلا يُختار إلا
-- ما يصلح لكل الابتدائي.
create or replace function public.duel_grade_band(raw text)
returns text
language sql
immutable
as $$
  select case
    when raw is null or btrim(raw) = '' then 'all'
    when raw ~* '(الأول|الاول|الثاني|الثالث|\m[1-3]\M|grade\s*[1-3])' then 'low'
    else 'high'
  end
$$;

-- ════════════════════════════════════════════════════════════════════════
-- ٣. تثبيتُ حزمة المباراة
-- ════════════════════════════════════════════════════════════════════════

-- تعيد حزمةَ المباراة: المكتوبةَ إن كانت، وإلا تبنيها وتكتبها وتعيدها.
-- و`null` لمباراةٍ لا تُعرف، أو انتهت ولا حزمةَ لها — والتطبيقُ عندها يلعب
-- بالبنك المحليّ.
--
-- ── وتوزيعُها ──
-- ستّةٌ من مجال الدرس: الوحدةُ أوّلاً ثم المادة، وإن لم يكفِ المجالُ أُكمل من
-- المعلومات العامّة والثقافة المدرسية. وأربعةٌ: سؤالا منطقٍ وسؤالا سرعة. وتتناوب
-- على النمط D B D D B D D B D B فلا يأتي بابٌ واحدٌ متتابعاً طويلاً.
--
-- ── ومنعُ التكرار ──
-- ما لُعب في آخر خمس مبارياتٍ بين الزميلين أنفسهما يُؤخَّر: ما لم يُلعب أوّلاً، ثم الأقدم، والأحدثُ آخراً —
-- لا يُمنع: يُختار إن لم يبقَ غيرُه، فلا تقصر حزمةٌ لأنّ البنك صغير.
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
  v_brain text[];
  v_pattern constant text := 'DBDDBDDBDB';
  v_slot text;
  v_id text;
  v_row public.duel_questions%rowtype;
  v_options text[];
  v_questions jsonb := '[]'::jsonb;
  v_pack jsonb;
  d int := 1;
  b int := 1;
begin
  if p_match_id is null or btrim(p_match_id) = '' then
    return null;
  end if;

  -- القفلُ يجعل نداءين متزامنين من الجهازين يتتاليان: الثاني يجد ما كتبه الأول.
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

  -- حزمةٌ جديدةٌ لمباراةٍ جاريةٍ وحدها.
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
        (m.host_id = v_match.host_id and m.guest_id = v_match.guest_id)
        or (m.host_id = v_match.guest_id and m.guest_id = v_match.host_id)
      )
    order by m.created_at desc
    limit 5
  ) recent
  cross join lateral jsonb_array_elements(
    case
      when jsonb_typeof(recent.questions -> 'questions') = 'array'
        then recent.questions -> 'questions'
      else '[]'::jsonb
    end
  ) q;

  -- ── ستّةٌ من مجال الدرس ──
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
  where pick <= 6;

  -- مادّةٌ لا مجالَ لها بعد: يُكمَل من المعلومات العامّة والثقافة المدرسية.
  if cardinality(v_domain) < 6 then
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
      where pick <= 6 - cardinality(v_domain)
    ), '{}');
  end if;

  -- ── وأربعةٌ ذكاءٌ وسرعة: اثنان من كلٍّ، متناوبين ──
  select coalesce(array_agg(id order by rn, category), '{}')
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
  where rn <= 2;

  if cardinality(v_domain) + cardinality(v_brain) < 8 then
    return null;
  end if;

  -- ── التناوب، وما نقص من بابٍ يُكمله الآخر ──
  foreach v_slot in array regexp_split_to_array(v_pattern, '') loop
    if (v_slot = 'D' and d <= cardinality(v_domain)) or b > cardinality(v_brain) then
      v_id := v_domain[d];
      d := d + 1;
    else
      v_id := v_brain[b];
      b := b + 1;
    end if;
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

comment on function public.claim_duel_pack(text) is
  'حزمةُ المباراة: تُبنى من duel_questions مرّةً وتُكتب في challenge_matches.questions، ويقرؤها الجهازان.';

-- ════════════════════════════════════════════════════════════════════════
-- ٤. البنكُ الأوّل
-- ════════════════════════════════════════════════════════════════════════
-- الأسئلةُ العامّة الـ٥١ — بمعرّفاتها في البنك المحليّ للتطبيق — وأسئلةُ مجالٍ
-- مكتوبةٌ لستّ مواد، فيعمل المجالُ من اليوم الأول قبل أن يملأه التوليد.

insert into public.duel_questions (id, subject_key, category, prompt, choices)
values
  ('general:ivp27c', '*', 'general', 'ما أكبر كوكب في المجموعة الشمسية؟', array['المشتري', 'الأرض', 'المريخ', 'عطارد']),
  ('general:p8n9o0', '*', 'general', 'كم عدد أيام السنة الميلادية؟', array['365', '360', '350', '375']),
  ('general:4m3f03', '*', 'general', 'ما أكبر محيط في العالم؟', array['الهادي', 'الأطلسي', 'الهندي', 'المتجمد']),
  ('general:i6dj2k', '*', 'general', 'ما عاصمة المملكة العربية السعودية؟', array['الرياض', 'جدة', 'مكة', 'الدمام']),
  ('general:77aux', '*', 'general', 'ما أسرع حيوان بري في العالم؟', array['الفهد', 'الأسد', 'الحصان', 'الغزال']),
  ('general:93h81p', '*', 'general', 'كم عدد قارات العالم؟', array['سبع', 'خمس', 'ست', 'ثماني']),
  ('general:5g32sa', '*', 'general', 'ما الحيوان الذي يُلقّب بسفينة الصحراء؟', array['الجمل', 'الحصان', 'الحمار', 'الثور']),
  ('general:p8ya3w', '*', 'general', 'أي هذه الكائنات يتنفس بالرئتين؟', array['الحوت', 'السمكة', 'القريدس', 'المحار']),
  ('general:d5lkpy', '*', 'general', 'ما أكبر حيوان على وجه الأرض؟', array['الحوت الأزرق', 'الفيل', 'الزرافة', 'القرش']),
  ('general:svdrrg', '*', 'general', 'ما اللون الذي ينتج من خلط الأزرق والأصفر؟', array['الأخضر', 'البرتقالي', 'البنفسجي', 'البني']),
  ('general:nnpanw', '*', 'general', 'كم عدد أضلاع المثلث؟', array['ثلاثة', 'أربعة', 'اثنان', 'خمسة']),
  ('general:iosq11', '*', 'general', 'ما الكوكب الذي نعيش عليه؟', array['الأرض', 'الزهرة', 'المشتري', 'زحل']),
  ('general:dbsjk', '*', 'general', 'أي هذه الفصول يأتي بعد الربيع؟', array['الصيف', 'الشتاء', 'الخريف', 'لا شيء']),
  ('general:jt59l1', '*', 'general', 'ما الحاسة التي نستخدمها لنعرف طعم الطعام؟', array['التذوق', 'السمع', 'البصر', 'اللمس']),
  ('general:5tixu5', '*', 'general', 'من أين تحصل النباتات على طاقتها؟', array['الشمس', 'التراب فقط', 'الهواء فقط', 'القمر']),
  ('logic:3pr3s9', '*', 'logic', 'إذا كان عمر أحمد ضعف عمر سارة، وسارة عمرها ٥، فكم عمر أحمد؟', array['10', '7', '15', '5']),
  ('logic:70s0q4', '*', 'logic', 'أكمل النمط: ٢، ٤، ٦، ٨، ...', array['10', '9', '12', '11']),
  ('logic:tl906l', '*', 'logic', 'أكمل النمط: ١، ٤، ٩، ١٦، ...', array['25', '20', '24', '18']),
  ('logic:lqf1cu', '*', 'logic', 'ما العدد الذي لا يشبه البقية: ٢، ٤، ٧، ٨؟', array['7', '2', '4', '8']),
  ('logic:n3kbkl', '*', 'logic', 'عند أمي ٣ تفاحات وأعطتني واحدة، كم بقي عندها؟', array['2', '3', '4', '1']),
  ('logic:1fazts', '*', 'logic', 'إذا كان كل الطيور لها أجنحة، والعصفور طائر، فماذا نستنتج؟', array['للعصفور أجنحة', 'العصفور لا يطير', 'العصفور سمكة', 'لا نستنتج شيئاً']),
  ('logic:3i8j6e', '*', 'logic', 'أكمل النمط: أحد، ثلاثاء، أربعاء، خميس، ...', array['جمعة', 'سبت', 'اثنين', 'أحد']),
  ('logic:gtuvj9', '*', 'logic', 'في الصف ٥ صفوف وفي كل صف ٤ طلاب، كم طالباً في الصف؟', array['20', '9', '16', '25']),
  ('logic:99wfpj', '*', 'logic', 'ما نصف العدد ١٨؟', array['9', '8', '10', '6']),
  ('logic:b060xz', '*', 'logic', 'أي هذه الأعداد أكبر: ٣/٤ أم ١/٢؟', array['٣/٤', '١/٢', 'متساويان', 'لا يُقارنان']),
  ('logic:fok88p', '*', 'logic', 'إذا بدأ الدرس ٨:٠٠ وانتهى ٨:٤٥، كم دقيقة طوله؟', array['45', '30', '60', '15']),
  ('logic:6riw45', '*', 'logic', 'أكمل النمط: ١٠، ٨، ٦، ٤، ...', array['2', '3', '0', '5']),
  ('quick:rc62ik', '*', 'quick', 'بسرعة! ما ناتج ٧ + ٦؟', array['13', '12', '14', '11']),
  ('quick:sdb4z5', '*', 'quick', 'بسرعة! ما ناتج ٩ × ٣؟', array['27', '24', '21', '30']),
  ('quick:vryrli', '*', 'quick', 'بسرعة! ما ناتج ١٥ − ٨؟', array['7', '6', '8', '9']),
  ('quick:y8i2ri', '*', 'quick', 'بسرعة! كم حرفاً في كلمة «مدرسة»؟', array['5', '6', '4', '7']),
  ('quick:890k', '*', 'quick', 'بسرعة! ما أول حرف في الأبجدية العربية؟', array['الألف', 'الباء', 'التاء', 'الياء']),
  ('quick:4e9exo', '*', 'quick', 'بسرعة! ما ناتج ٢٠ ÷ ٤؟', array['5', '4', '6', '8']),
  ('quick:eve0cq', '*', 'quick', 'بسرعة! كم يوماً في الأسبوع؟', array['7', '6', '5', '30']),
  ('quick:n8f37f', '*', 'quick', 'بسرعة! ما العدد الذي يأتي قبل ١٠٠؟', array['99', '101', '90', '98']),
  ('quick:qy69v5', '*', 'quick', 'بسرعة! ما ناتج ٦ × ٦؟', array['36', '30', '42', '32']),
  ('quick:9g34ck', '*', 'quick', 'بسرعة! كم ساعة في اليوم؟', array['24', '12', '60', '30']),
  ('quick:ytakwx', '*', 'quick', 'بسرعة! ما ضعف العدد ١٢؟', array['24', '22', '26', '14']),
  ('quick:vgue3r', '*', 'quick', 'بسرعة! ما ناتج ١٠٠ − ٥٥؟', array['45', '55', '35', '50']),
  ('school:gp5sin', '*', 'school', 'ما الذي نستخدمه لمحو ما كتبناه بالقلم الرصاص؟', array['الممحاة', 'المسطرة', 'المبراة', 'الدفتر']),
  ('school:xeefth', '*', 'school', 'ماذا نفعل قبل أن نتكلم في الصف؟', array['نرفع أيدينا', 'نصرخ', 'نقف', 'نخرج']),
  ('school:we6oa7', '*', 'school', 'أين نجد الكتب في المدرسة؟', array['المكتبة', 'المقصف', 'الملعب', 'المختبر']),
  ('school:gtkwsi', '*', 'school', 'ما الأداة التي نرسم بها الخطوط المستقيمة؟', array['المسطرة', 'الممحاة', 'المقص', 'الفرشاة']),
  ('school:ueqbp7', '*', 'school', 'أين نجري التجارب العلمية في المدرسة؟', array['المختبر', 'المكتبة', 'المقصف', 'الإدارة']),
  ('school:28vmaj', '*', 'school', 'ما الذي نرمي فيه الأوراق التي لا نحتاجها؟', array['سلة المهملات', 'الحقيبة', 'الدرج', 'النافذة']),
  ('school:kamjcp', '*', 'school', 'من يشرح الدرس في الصف؟', array['المعلم', 'الطالب', 'الحارس', 'السائق']),
  ('school:21paha', '*', 'school', 'ماذا نقول عندما يساعدنا أحد؟', array['شكراً', 'لا شيء', 'اذهب', 'بسرعة']),
  ('school:j474l2', '*', 'school', 'ما الذي نحمل فيه كتبنا إلى المدرسة؟', array['الحقيبة', 'الكرسي', 'السبورة', 'القلم']),
  ('school:t7kcsg', '*', 'school', 'أين نلعب في وقت الفسحة؟', array['الملعب', 'المختبر', 'المكتبة', 'الصف']),
  ('school:ndf2ft', '*', 'school', 'ما الذي يكتب عليه المعلم أمام الصف؟', array['السبورة', 'الدفتر', 'المسطرة', 'الحقيبة']),
  ('school:o8udqt', '*', 'school', 'ماذا نفعل عند سماع جرس نهاية الحصة؟', array['ننظّم أدواتنا', 'نجري', 'نصرخ', 'ننام']),
  ('domain:math:61rabg', 'math', 'domain', 'كم ضلعاً للمربع؟', array['4', '3', '5', '6']),
  ('domain:math:rw9ioe', 'math', 'domain', 'بسرعة! ما ناتج ٨ × ٧؟', array['56', '54', '48', '63']),
  ('domain:math:bga8v0', 'math', 'domain', 'كم سنتيمتراً في المتر الواحد؟', array['100', '10', '1000', '60']),
  ('domain:math:6u0bhr', 'math', 'domain', 'أي هذه الأعداد زوجي؟', array['14', '9', '21', '7']),
  ('domain:math:wgl1rl', 'math', 'domain', 'كم دقيقة في الساعة؟', array['60', '100', '30', '24']),
  ('domain:math:99wihf', 'math', 'domain', 'ما نصف العدد ٥٠؟', array['25', '20', '30', '15']),
  ('domain:math:8dnjrz', 'math', 'domain', 'ما الشكل الذي ليس له أضلاع ولا زوايا؟', array['الدائرة', 'المربع', 'المثلث', 'المستطيل']),
  ('domain:math:hlgd31', 'math', 'domain', 'ما ناتج ١٠٠٠ − ١؟', array['999', '990', '1001', '900']),
  ('domain:math:abusd', 'math', 'domain', 'أي كسر يساوي النصف؟', array['٢/٤', '١/٣', '٣/٤', '١/٤']),
  ('domain:math:irz26j', 'math', 'domain', 'كم زاوية قائمة في المستطيل؟', array['4', '2', '3', '0']),
  ('domain:math:8jq79f', 'math', 'domain', 'ما العدد الذي يأتي بعد ٩٩٩؟', array['1000', '998', '1001', '9999']),
  ('domain:math:llec2m', 'math', 'domain', 'ما ناتج ١٢ ÷ ٣؟', array['4', '3', '6', '9']),
  ('domain:science:adtb0o', 'science', 'domain', 'ما الغاز الذي نتنفسه لنعيش؟', array['الأكسجين', 'ثاني أكسيد الكربون', 'النيتروجين', 'الهيليوم']),
  ('domain:science:7e4j1l', 'science', 'domain', 'في أي حالة يكون الجليد؟', array['صلبة', 'سائلة', 'غازية']),
  ('domain:science:w029t5', 'science', 'domain', 'ما العضو الذي يضخ الدم في الجسم؟', array['القلب', 'الرئة', 'المعدة', 'الكبد']),
  ('domain:science:vic6lb', 'science', 'domain', 'كم عدد أرجل الحشرة؟', array['6', '8', '4', '10']),
  ('domain:science:3o83eg', 'science', 'domain', 'أي جزء من النبات يمتص الماء من التربة؟', array['الجذر', 'الورقة', 'الزهرة', 'الثمرة']),
  ('domain:science:zh11dj', 'science', 'domain', 'ما أقرب نجم إلى الأرض؟', array['الشمس', 'القمر', 'المريخ', 'الشعرى']),
  ('domain:science:yy2kh3', 'science', 'domain', 'عند كم درجة يغلي الماء النقي؟', array['١٠٠ درجة مئوية', '٥٠ درجة مئوية', 'صفر درجة مئوية', '٢٠٠ درجة مئوية']),
  ('domain:science:db6uxd', 'science', 'domain', 'ما القوة التي تجذب الأجسام نحو الأرض؟', array['الجاذبية', 'الرياح', 'الاحتكاك', 'الضوء']),
  ('domain:science:t26pm6', 'science', 'domain', 'أي هذه الحيوانات من الثدييات؟', array['الدلفين', 'السمكة', 'الضفدع', 'النسر']),
  ('domain:science:x5c2om', 'science', 'domain', 'كم عدد كواكب المجموعة الشمسية؟', array['8', '9', '7', '10']),
  ('domain:science:yzd1bh', 'science', 'domain', 'بأي حاسة نشمّ الروائح؟', array['الشم', 'التذوق', 'السمع', 'اللمس']),
  ('domain:science:dlfgb3', 'science', 'domain', 'ماذا تصنع النباتات الخضراء في أوراقها؟', array['غذاءها', 'التربة', 'الصخور', 'الرمال']),
  ('domain:arabic:l938mo', 'arabic', 'domain', 'ما جمع كلمة «كتاب»؟', array['كتب', 'كتابان', 'مكتبة', 'كاتب']),
  ('domain:arabic:aaiuc3', 'arabic', 'domain', 'ما ضد كلمة «طويل»؟', array['قصير', 'كبير', 'عريض', 'بعيد']),
  ('domain:arabic:9rw9ga', 'arabic', 'domain', 'ما مفرد كلمة «أقلام»؟', array['قلم', 'قلمان', 'مقلمة', 'أقلمة']),
  ('domain:arabic:q709a0', 'arabic', 'domain', 'كم عدد حروف الهجاء العربية؟', array['28', '24', '26', '32']),
  ('domain:arabic:1u6k74', 'arabic', 'domain', 'ما مرادف كلمة «سعيد»؟', array['فرحان', 'حزين', 'غاضب', 'متعب']),
  ('domain:arabic:eivpqn', 'arabic', 'domain', 'أي هذه الكلمات تبدأ بحرف الميم؟', array['مدرسة', 'كتاب', 'قلم', 'سبورة']),
  ('domain:arabic:hd0n0z', 'arabic', 'domain', 'ما ضد كلمة «نهار»؟', array['ليل', 'صباح', 'ظهر', 'شمس']),
  ('domain:arabic:kfa4nz', 'arabic', 'domain', 'ما مثنى كلمة «ولد»؟', array['ولدان', 'أولاد', 'مولود', 'والد']),
  ('domain:arabic:kjclpx', 'arabic', 'domain', 'أي هذه الكلمات اسم حيوان؟', array['أرنب', 'شجرة', 'باب', 'وردة']),
  ('domain:arabic:8qee1b', 'arabic', 'domain', 'ما الحرف الأخير في كلمة «شمس»؟', array['السين', 'الميم', 'الشين', 'النون']),
  ('domain:arabic:h5eej5', 'arabic', 'domain', 'ما ضد كلمة «نظيف»؟', array['متّسخ', 'جميل', 'جديد', 'واسع']),
  ('domain:arabic:rpsp', 'arabic', 'domain', 'أكمل المثل: «العلمُ ...»', array['نور', 'ظلام', 'بعيد', 'صعب']),
  ('domain:english:e73xi9', 'english', 'domain', 'What color is the sky on a clear day?', array['blue', 'green', 'red', 'black']),
  ('domain:english:ankc1i', 'english', 'domain', 'How many days are in a week?', array['seven', 'five', 'six', 'eight']),
  ('domain:english:us8n7s', 'english', 'domain', 'Which one is an animal?', array['cat', 'chair', 'book', 'pen']),
  ('domain:english:hr2w42', 'english', 'domain', 'What is the opposite of "big"?', array['small', 'tall', 'long', 'fast']),
  ('domain:english:hf8ax4', 'english', 'domain', 'Which word is a fruit?', array['apple', 'table', 'car', 'shoe']),
  ('domain:english:rwxlkf', 'english', 'domain', 'Which letter comes after "C"?', array['D', 'B', 'E', 'F']),
  ('domain:english:jjwy7f', 'english', 'domain', 'Which word is a number?', array['nine', 'nice', 'nose', 'name']),
  ('domain:english:uxpb6f', 'english', 'domain', 'What do we use to write?', array['pencil', 'spoon', 'cup', 'ball']),
  ('domain:english:yb8aqe', 'english', 'domain', 'What is the plural of "box"?', array['boxes', 'boxs', 'boxies', 'boxen']),
  ('domain:english:4oi5ir', 'english', 'domain', 'Which one is a color?', array['yellow', 'happy', 'quick', 'under']),
  ('domain:english:li6gcb', 'english', 'domain', 'What do we say in the morning? "Good ..."', array['morning', 'night', 'bye', 'sleep']),
  ('domain:english:1y2yx8', 'english', 'domain', 'Which animal says "moo"?', array['cow', 'cat', 'dog', 'duck']),
  ('domain:islamic:sghn2o', 'islamic', 'domain', 'كم عدد أركان الإسلام؟', array['خمسة', 'ستة', 'أربعة', 'ثلاثة']),
  ('domain:islamic:hr9pbb', 'islamic', 'domain', 'كم عدد الصلوات المفروضة في اليوم والليلة؟', array['خمس', 'ثلاث', 'أربع', 'ست']),
  ('domain:islamic:rm6kce', 'islamic', 'domain', 'ما أول سورة في المصحف الشريف؟', array['الفاتحة', 'البقرة', 'الناس', 'الإخلاص']),
  ('domain:islamic:q1bg1m', 'islamic', 'domain', 'في أي شهر يصوم المسلمون؟', array['رمضان', 'شعبان', 'رجب', 'شوال']),
  ('domain:islamic:yzw8rl', 'islamic', 'domain', 'إلى أين يتجه المسلمون في صلاتهم؟', array['الكعبة المشرفة', 'جبل عرفات', 'المسجد النبوي', 'جبل أحد']),
  ('domain:islamic:st5jqd', 'islamic', 'domain', 'كم عدد أركان الإيمان؟', array['ستة', 'خمسة', 'سبعة', 'أربعة']),
  ('domain:islamic:rg9puy', 'islamic', 'domain', 'ما آخر سورة في المصحف الشريف؟', array['الناس', 'الفلق', 'الإخلاص', 'الكوثر']),
  ('domain:islamic:uz8rh4', 'islamic', 'domain', 'ماذا نقول قبل أن نبدأ الأكل؟', array['بسم الله', 'الحمد لله', 'سبحان الله', 'أستغفر الله']),
  ('domain:islamic:q1563e', 'islamic', 'domain', 'في أي مدينة وُلد النبي محمد ﷺ؟', array['مكة المكرمة', 'المدينة المنورة', 'الطائف', 'القدس']),
  ('domain:islamic:gqadlk', 'islamic', 'domain', 'كم عدد سور القرآن الكريم؟', array['١١٤', '١٠٠', '١٢٠', '٩٩']),
  ('domain:islamic:9cdd4o', 'islamic', 'domain', 'كم ركعة في صلاة الفجر؟', array['ركعتان', 'ثلاث ركعات', 'أربع ركعات', 'ركعة واحدة']),
  ('domain:islamic:kpsll2', 'islamic', 'domain', 'في أي شهر يحجّ المسلمون؟', array['ذو الحجة', 'رمضان', 'محرم', 'صفر']),
  ('domain:social:exqesf', 'social', 'domain', 'في أي قارة تقع المملكة العربية السعودية؟', array['آسيا', 'أفريقيا', 'أوروبا', 'أستراليا']),
  ('domain:social:ycjk4k', 'social', 'domain', 'ما الأداة التي تحدد لنا الاتجاهات؟', array['البوصلة', 'الميزان', 'الساعة', 'المسطرة']),
  ('domain:social:qaoh4e', 'social', 'domain', 'كم عدد الاتجاهات الأصلية؟', array['أربعة', 'اثنان', 'ثلاثة', 'ستة']),
  ('domain:social:cscrc2', 'social', 'domain', 'من أي اتجاه تشرق الشمس؟', array['الشرق', 'الغرب', 'الشمال', 'الجنوب']),
  ('domain:social:tow32z', 'social', 'domain', 'ماذا يمثّل اللون الأزرق غالباً في الخريطة؟', array['الماء', 'الجبال', 'الصحراء', 'المدن']),
  ('domain:social:ijw6zn', 'social', 'domain', 'أين تُعرض الآثار القديمة ليراها الناس؟', array['المتحف', 'المصنع', 'المستشفى', 'السوق']),
  ('domain:social:cfx3k', 'social', 'domain', 'ما أكبر قارات العالم مساحةً؟', array['آسيا', 'أفريقيا', 'أوروبا', 'أستراليا']),
  ('domain:social:uvjn9v', 'social', 'domain', 'ما العملة الرسمية في المملكة العربية السعودية؟', array['الريال', 'الدينار', 'الدرهم', 'الجنيه']),
  ('domain:social:2xtz3t', 'social', 'domain', 'أي هذه وسيلة نقل بحرية؟', array['السفينة', 'القطار', 'الطائرة', 'الحافلة']),
  ('domain:social:ae3bc3', 'social', 'domain', 'أي محيط يقع بين أمريكا وأوروبا؟', array['الأطلسي', 'الهادي', 'الهندي', 'المتجمد الشمالي']),
  ('domain:social:htmpbh', 'social', 'domain', 'ما عاصمة جمهورية مصر العربية؟', array['القاهرة', 'الإسكندرية', 'الجيزة', 'أسوان']),
  ('domain:social:tnehqo', 'social', 'domain', 'ما الذي يرسمه الجغرافيون ليمثّلوا الأرض على الورق؟', array['الخريطة', 'الجدول', 'الصورة الشخصية', 'الرسم البياني'])
on conflict (id) do nothing;

commit;
