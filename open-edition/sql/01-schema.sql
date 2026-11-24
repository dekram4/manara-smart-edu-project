-- مولَّدٌ بـ open-edition/scripts/build-schema-sql.mjs — لا يُعدَّل باليد.
-- ⚠️ لمشروع manara-open-app وحده: Supabase → SQL Editor → New query → الصق الملفَّ كلَّه → Run.
-- آمنٌ على قاعدةٍ فيها الجداولُ من قبل، ويُعاد تشغيله بلا ضرر.
-- قبل اللصق: محرّرٌ فارغ، ولا تحديدَ لجزءٍ من النصّ (المحرّر يشغّل المحدَّد وحده).

-- ┌──────────────────────────────────────────────────────────────
-- │ artifacts/manara/src/db/schema.sql — جداولُ الكيانات و app_kv
-- └──────────────────────────────────────────────────────────────

-- ============================================================
-- SmartEdu — مخطط قاعدة بيانات Supabase
-- شغّل هذا السكربت مرة واحدة في:
-- لوحة Supabase → SQL Editor → New query → الصق ثم Run
-- ============================================================
-- ملاحظة أمان: هذه السياسات تسمح بالوصول الكامل عبر المفتاح العام (anon)
-- لأن التطبيق يصل عبر خادم Replit إلى Supabase.
-- يمكن لاحقاً تضييق سياسات RLS بعد إضافة مصادقة Supabase للمستخدمين.
-- ============================================================

-- جداول الكيانات: كل صف = سجل واحد، والحقل data يحوي الكائن كاملاً (JSONB)
create table if not exists public.students        (id text primary key, data jsonb not null, updated_at timestamptz not null default now());
create table if not exists public.parents         (id text primary key, data jsonb not null, updated_at timestamptz not null default now());
create table if not exists public.teachers        (id text primary key, data jsonb not null, updated_at timestamptz not null default now());
create table if not exists public.lesson_configs  (id text primary key, data jsonb not null, updated_at timestamptz not null default now());
create table if not exists public.created_quizzes (id text primary key, data jsonb not null, updated_at timestamptz not null default now());
create table if not exists public.quiz_results    (id text primary key, data jsonb not null, updated_at timestamptz not null default now());
create table if not exists public.interactions    (id text primary key, data jsonb not null, updated_at timestamptz not null default now());
create table if not exists public.private_messages(id text primary key, data jsonb not null, updated_at timestamptz not null default now());
create table if not exists public.public_messages (id text primary key, data jsonb not null, updated_at timestamptz not null default now());
create table if not exists public.certificates    (id text primary key, data jsonb not null, updated_at timestamptz not null default now());

-- جدول مفتاح/قيمة للإعدادات والقوائم والبنى المتشعّبة
create table if not exists public.app_kv (key text primary key, value jsonb not null, updated_at timestamptz not null default now());

-- تفعيل RLS وإضافة سياسات وصول كامل (anon + authenticated)
do $$
declare t text;
begin
  foreach t in array array[
    'students','parents','teachers','lesson_configs','created_quizzes','quiz_results',
    'interactions','private_messages','public_messages','certificates','app_kv'
  ]
  loop
    execute format('alter table public.%I enable row level security;', t);
    execute format('drop policy if exists "allow_all_%s" on public.%I;', t, t);
    execute format(
      'create policy "allow_all_%s" on public.%I for all to anon, authenticated using (true) with check (true);',
      t, t
    );
  end loop;
end $$;

-- ┌──────────────────────────────────────────────────────────────
-- │ artifacts/api-server/scripts/ai-qa-cache.sql — ذاكرةُ إجابات الذكاء الاصطناعي
-- └──────────────────────────────────────────────────────────────

-- جدول ذاكرة إجابات الذكاء الاصطناعي.
--
-- ── لماذا ──
-- ثلاثون طفلاً في صفٍّ واحد يسألون عن الدرس نفسه، فيُسأل النموذج ثلاثين
-- مرّة عن سؤالٍ واحد وإجابتُه لا تتغيّر. فتُحفظ أوّل مرّة وتُعاد على
-- البقيّة في جزءٍ من الثانية، بلا استدعاءٍ ولا كلفة.
--
-- ── لماذا `(id, data)` كبقيّة الجداول ──
-- المنظومة كلّها على هذا الشكل: مفتاحٌ نصّي و`jsonb`. وعمودٌ لكل حقل
-- هنا يعني ترحيلاً كلّما أُضيف حقل، وجدولاً يفترق شكلُه عن أخواته.
--
-- والمفتاح هو `<معرّف الدرس>::<السؤال مطبَّعاً>` — يبنيه `src/lib/aiQuota.ts`.
-- والدرس جزءٌ منه لأن «ما الفكرة الرئيسية؟» سؤالٌ صالحٌ لكل درس
-- وإجابتُه تختلف بينها.
--
-- التشغيل: الصقه في محرّر SQL في Supabase.

create table if not exists public.ai_qa_cache (
  id text primary key,
  data jsonb not null default '{}'::jsonb,
  updated_at timestamptz not null default now()
);

-- البحث بالدرس، لمن أراد أن يرى ما سُئل عنه أو يمسح ذاكرة درسٍ عُدّل نصُّه.
create index if not exists ai_qa_cache_lesson_idx
  on public.ai_qa_cache ((data->>'lessonId'));

-- ── الصلاحيات ──
--
-- لا أحد يصل إليه إلا الخادم بمفتاح الخدمة. ومفتاح anon يُستخرج من أي
-- APK بفكّ ضغطه، فلو قرأ هذا الجدول لقُرئت أسئلةُ كل طفلٍ في المنصّة.
-- ولو كتب فيه لسُمّمت الذاكرة: إجابةٌ يكتبها مهاجم تُعاد على الصفّ كلّه.
alter table public.ai_qa_cache enable row level security;

revoke all on public.ai_qa_cache from anon, authenticated;

-- وللخادم وحده صلاحيةٌ كاملة.
--
-- تجاوزُ `service_role` لـ RLS لا يُغني عن هذا: RLS طبقةُ صفوف، وهذه
-- طبقةُ جدول. وجدولٌ يُنشأ في محرّر SQL يملكه `postgres`، فلا يرث
-- `service_role` عليه شيئاً — فيُردّ كلُّ قراءةٍ وكتابةٍ بـ401، وتبدو
-- الذاكرة كأنها لا تُصاب أبداً بينما هي لا تُقرأ ولا تُكتب أصلاً.
grant all on public.ai_qa_cache to service_role;

-- ولا سياسة تُضاف: `service_role` يتجاوز RLS، وغيرُه لا يجد ما يسمح له.

comment on table public.ai_qa_cache is
  'ذاكرة إجابات الذكاء الاصطناعي: مفتاحها الدرس والسؤال مطبَّعاً. يكتبها الخادم وحده.';

-- ┌──────────────────────────────────────────────────────────────
-- │ artifacts/api-server/scripts/challenge-matches.sql — مبارياتُ التحدي
-- └──────────────────────────────────────────────────────────────

-- مبارياتُ التحدي بين زملاء الصفّ.
--
-- ── ما يحفظه هذا الجدول ──
-- مباراةٌ واحدة: من تحدّى مَن، في أيّ لعبةٍ ودرس، ونتيجةُ كلٍّ منهما، ومن
-- فاز. وهو سجلُّ الحقيقة: الجواهرُ تُصرف منه، ولوحةُ الصدارة تُحسب منه،
-- والمباراةُ المعلّقة تُقرأ منه.
--
-- ── ولماذا صفٌّ واحد للمباراة لا صفٌّ لكل لاعب ──
-- المقارنةُ بين النتيجتين هي المباراة. ولو كُتب لكلٍّ صفُّه لاحتاج الفوزُ
-- استعلاماً يجمعهما، وصارت مباراةٌ نصفُها مكتوب حالةً يجب أن تُعالج.
-- وصفٌّ واحد يجعل «كلتا النتيجتين حاضرة» شرطاً يُقرأ في مكانه.
--
-- التشغيل: الصقه في محرّر SQL في Supabase.

create table if not exists public.challenge_matches (
  id text primary key,

  -- الدرسُ واللعبة: المباراةُ في درسٍ بعينه، فأسئلتُها منه.
  lesson_id text not null,
  game text not null,

  -- المتحدِّي والزميل. و`host` هو من أرسل الدعوة.
  host_id text not null,
  guest_id text not null,

  -- ── الصفّ، وهو حدٌّ أمنيّ لا تصنيفٌ للعرض ──
  -- الدعوةُ لا تُرسل إلا داخل الصفّ، ولوحةُ الصدارة لا تُقرأ إلا فيه.
  -- ومفتاحُه `<معرّف المعلم>:<الصفّ>` — وهو نفسُ ما تُحصَر به الصدارة
  -- القائمة، فلا يُخترع نطاقٌ ثانٍ يفترق عنه.
  class_key text not null,

  -- live: الزميلُ متصلٌ فتُلعب المباراتان معاً.
  -- ghost: غيرُ متصل، فيلعب المتحدّي جولتَه وتنتظره.
  mode text not null default 'ghost',

  -- pending: تنتظر لاعباً. done: كلتا النتيجتين حاضرة.
  status text not null default 'pending',

  host_score int,
  guest_score int,
  winner_id text,

  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  -- ── ودعوةٌ لا تُلعب تنتهي ──
  -- بلا هذا يفتح الطالبُ التطبيق بعد شهرٍ فيجد عشرين تحدّياً معلّقاً، ولا
  -- سبيلَ له إلى تفريغها. والانتهاءُ يجعل الطابور يُفرّغ نفسه.
  expires_at timestamptz not null default now() + interval '7 days',

  constraint challenge_matches_mode check (mode in ('live', 'ghost')),
  constraint challenge_matches_status check (status in ('pending', 'done', 'expired')),
  -- ولا يتحدّى الطالبُ نفسه: مباراةٌ كذلك يفوز فيها دائماً، فتكون باباً
  -- إلى جوهرةٍ بكل ضغطة.
  constraint challenge_matches_two_players check (host_id <> guest_id)
);

-- ما يُستعلَم فعلاً: مبارياتُ طالبٍ معلّقة، وصدارةُ صفّ.
create index if not exists challenge_matches_guest_idx
  on public.challenge_matches (guest_id, status);
create index if not exists challenge_matches_host_idx
  on public.challenge_matches (host_id, status);
create index if not exists challenge_matches_class_idx
  on public.challenge_matches (class_key, status);

-- ── الصلاحيات ──
--
-- لا يقرأ هذا الجدول ولا يكتبه إلا الخادم بدور الخدمة. ومفتاحُ anon
-- يُستخرج من أي APK بفكّ ضغطه، فلو مُنح القراءةَ لقرأ به أيُّ أحد نتائج
-- كل طالبٍ في كل صفّ.
--
-- والكتابةُ أخطر: صفٌّ يُكتب بيدٍ يعني فوزاً يُدَّعى وجوهرةً تُصرف عليه.
-- فالنتيجةُ تصل عبر مسارٍ في الخادم يتحقّق من هُويّة المُرسِل وحدوده.
alter table public.challenge_matches enable row level security;

revoke all on table public.challenge_matches from public, anon, authenticated;
grant all on table public.challenge_matches to service_role;

comment on table public.challenge_matches is
  'مبارياتُ التحدي بين زملاء الصفّ. يكتبها الخادم وحده بدور الخدمة.';

comment on column public.challenge_matches.class_key is
  'حدُّ الدعوة والصدارة: <معرّف المعلم>:<الصفّ>. لا تُرسل دعوةٌ عبره.';

-- ┌──────────────────────────────────────────────────────────────
-- │ artifacts/api-server/scripts/duel-upgrade.sql — حزمةُ أسئلة المباراة وسجلُّ المحادثة
-- └──────────────────────────────────────────────────────────────

-- ترقيةُ بطاقة التحدي: حزمةُ أسئلةٍ مع المباراة، وسجلُّ محادثةٍ يبقى.
--
-- التشغيل: الصقه في محرّر SQL في Supabase. آمنٌ على قاعدةٍ فيها مباريات.

-- ── ١. أسئلةُ المباراة تُحفظ معها ──
--
-- كان كلُّ جهازٍ يبني أسئلتَه من بذرةٍ هي معرّفُ المباراة، فعدلُ المباراة
-- معلّقٌ بأن يبقى الحسابُ متطابقاً على الجهازين إلى الأبد: نسخةٌ أقدمُ من
-- التطبيق، أو بنكُ درسٍ تغيّر بين القراءتين — وكلُّها تُخرج أسئلةً مختلفةً
-- بلا خطأٍ يظهر. كلُّ جهازٍ يعمل وحده صحيحاً.
--
-- فصارت الحزمةُ تُكتب هنا مرّةً عند الدعوة، والجهازان يقرآن الصفَّ نفسه.
alter table public.challenge_matches
  add column if not exists questions jsonb;

comment on column public.challenge_matches.questions is
  'حزمةُ أسئلة المباراة، تُكتب عند الدعوة. الجهازان يقرآنها فلا تتعلّق العدالةُ باتّفاق حسابين.';

-- ── ٢. سجلُّ محادثة المباراة ──
--
-- البثُّ الحيُّ يصل لمن كان على القناة في تلك اللحظة. والمبارزةُ المؤجَّلةُ
-- يلعب فيها كلٌّ في وقته، فرسالةُ من لعب أوّلاً كانت تضيع قبل أن يفتح زميلُه
-- المباراة — وهو الوقتُ الوحيد الذي يقرأ فيه.
create table if not exists public.match_messages (
  id uuid primary key default gen_random_uuid(),

  match_id text not null
    references public.challenge_matches (id) on delete cascade,

  sender_id text not null,

  -- text: نصٌّ أو إيموجي.  voice: مقطعٌ صوتيٌّ بترميز base64.
  kind text not null default 'text',

  -- ── جسمٌ واحدٌ للنوعين ──
  -- عمودان — نصٌّ وصوتٌ — أحدُهما فارغٌ دائماً، ويحتاج كلُّ قارئٍ أن يعرف
  -- أيَّهما يقرأ. والنوعُ مكتوبٌ في `kind`، فالجسمُ واحد.
  body text not null,

  created_at timestamptz not null default now(),

  constraint match_messages_kind check (kind in ('text', 'voice')),

  -- ── والحجمُ محروسٌ في القاعدة أيضاً ──
  -- المسارُ يفحصه، وجهازٌ معدَّلٌ لا يمرّ بالمسار إن فُتحت القاعدةُ يوماً.
  -- ومقطعٌ بميغابايتٍ يُقرأ في كل فتحةٍ للمباراة.
  constraint match_messages_size check (char_length(body) <= 184320)
);

-- ما يُستعلَم فعلاً: رسائلُ مباراةٍ بترتيب وقتها.
create index if not exists match_messages_match_idx
  on public.match_messages (match_id, created_at);

-- ── الصلاحيات ──
--
-- لا يقرأ الجدولَ ولا يكتبه إلا الخادم بدور الخدمة. ومفتاحُ anon يُستخرج من
-- أي APK بفكّ ضغطه، فلو مُنح القراءةَ لقرأ به أيُّ أحدٍ محادثاتِ كل طالب —
-- وفيها مقاطعُ بصوت الأطفال.
alter table public.match_messages enable row level security;

revoke all on table public.match_messages from public, anon, authenticated;
grant all on table public.match_messages to service_role;

comment on table public.match_messages is
  'سجلُّ محادثة المباراة: نصٌّ ومقاطعُ صوتٍ. يكتبه الخادم وحده بدور الخدمة.';

-- ┌──────────────────────────────────────────────────────────────
-- │ artifacts/api-server/scripts/duel-question-bank.sql — بنكُ أسئلة المبارزة
-- └──────────────────────────────────────────────────────────────

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

-- ┌──────────────────────────────────────────────────────────────
-- │ artifacts/api-server/scripts/duel-live.sql — المبارزةُ الحيّة
-- └──────────────────────────────────────────────────────────────

-- المبارزةُ الحيّة: أوّلُ جوابٍ صحيحٍ يكسب السؤال، والجائزةُ مرّةً لكل درس.
--
-- التشغيل: الصقه في محرّر SQL في Supabase بعد `duel-question-bank.sql`. آمنٌ
-- على قاعدةٍ فيها مباريات، ويُعاد تشغيلُه بلا ضرر.
--
-- ── لماذا يُحسم الأوّلُ هنا ──
-- «أوّلُ من يُجيب صحيحاً يكسب السؤال» قرارٌ بين جهازين يُرسلان في اللحظة نفسها.
-- لو حسمه كلُّ جهازٍ بما وصله من بثّ زميله، لرأى كلٌّ منهما نفسَه الأوّلَ
-- أحياناً. فالحسمُ في مكانٍ واحد: دالّةٌ تقفل السؤالَ وتكتب، وفهرسٌ فريدٌ يمنع
-- فائزين بسؤالٍ واحدٍ حتى لو فلت القفل.

begin;

-- ════════════════════════════════════════════════════════════════════════
-- ١. إجاباتُ المباراة
-- ════════════════════════════════════════════════════════════════════════

create table if not exists public.match_answers (
  match_id text not null
    references public.challenge_matches (id) on delete cascade,
  question_index int not null,
  student_id text not null,
  correct boolean not null,
  -- أوّلُ جوابٍ صحيحٍ لهذا السؤال في المباراة: له نقاطُ السؤال كلُّها.
  won boolean not null default false,
  answered_at timestamptz not null default now(),

  -- محاولةٌ واحدةٌ لكل لاعبٍ في كل سؤال: لا يُخمَّن الجوابُ بالضغط على الأربعة.
  primary key (match_id, question_index, student_id),
  constraint match_answers_index check (question_index between 0 and 49),
  constraint match_answers_won_is_correct check (not won or correct)
);

-- فائزٌ واحدٌ بكل سؤال. والقفلُ في الدالّة يمنع السباق، وهذا يمنعه لو فلت.
create unique index if not exists match_answers_one_winner
  on public.match_answers (match_id, question_index)
  where won;

alter table public.match_answers enable row level security;
revoke all on table public.match_answers from public, anon, authenticated;
grant all on table public.match_answers to service_role;

comment on table public.match_answers is
  'إجاباتُ المبارزة: محاولةٌ لكل لاعبٍ في كل سؤال، وأوّلُ صحيحٍ يكسب. يكتبها الخادم عبر record_duel_answer.';

-- ════════════════════════════════════════════════════════════════════════
-- ٢. تسجيلُ جواب
-- ════════════════════════════════════════════════════════════════════════

-- تسجّل جوابَ [p_student_id] على السؤال [p_question_index] وتعيد:
--   { correct, won, duplicate }
-- won: كان أوّلَ جوابٍ صحيحٍ لهذا السؤال. duplicate: أجاب من قبل، فتُعاد
-- محاولتُه الأولى كما هي.
--
-- والخادمُ هو من يقرّر الصحة — من حزمة المباراة المحفوظة — ويستدعيها بدور
-- الخدمة وحده.
create or replace function public.record_duel_answer(
  p_match_id text,
  p_question_index int,
  p_student_id text,
  p_correct boolean
)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_previous public.match_answers%rowtype;
  v_won boolean := false;
begin
  -- قفلٌ لهذا السؤال في هذه المباراة وحده: جوابان متزامنان يتتاليان، والثاني
  -- يرى ما كتبه الأوّل.
  perform pg_advisory_xact_lock(hashtext(p_match_id), p_question_index);

  select * into v_previous
  from public.match_answers
  where match_id = p_match_id
    and question_index = p_question_index
    and student_id = p_student_id;
  if found then
    return jsonb_build_object(
      'correct', v_previous.correct,
      'won', v_previous.won,
      'duplicate', true
    );
  end if;

  if p_correct then
    v_won := not exists (
      select 1 from public.match_answers
      where match_id = p_match_id
        and question_index = p_question_index
        and won
    );
  end if;

  insert into public.match_answers (match_id, question_index, student_id, correct, won)
  values (p_match_id, p_question_index, p_student_id, p_correct, v_won);

  return jsonb_build_object('correct', p_correct, 'won', v_won, 'duplicate', false);
end;
$$;

revoke all on function public.record_duel_answer(text, int, text, boolean) from public, anon, authenticated;
grant execute on function public.record_duel_answer(text, int, text, boolean) to service_role;

-- ════════════════════════════════════════════════════════════════════════
-- ٣. هل صُرفت الجائزة؟
-- ════════════════════════════════════════════════════════════════════════

-- null قبل الحسم أو للتعادل. true: صُرفت الجواهرُ الخمس. false: فاز، وجائزةُ هذا
-- الدرس كانت قد صُرفت له من قبل — فيقال له ذلك بدل «صفر» بلا سبب.
alter table public.challenge_matches
  add column if not exists reward_paid boolean;

commit;

-- ┌──────────────────────────────────────────────────────────────
-- │ artifacts/api-server/scripts/duel-handshake.sql — مصافحةُ النزال
-- └──────────────────────────────────────────────────────────────

-- مصافحةُ النزال: لا يبدأ إلا والطرفان فيه.
--
-- التشغيل: الصقه في محرّر SQL في Supabase بعد `duel-live.sql`. آمنٌ على قاعدةٍ
-- فيها مباريات، ويُعاد تشغيلُه بلا ضرر.
--
-- ── ما يُصلحه ──
-- كان الضيفُ يدخل غرفةَ النزال لحظةَ يضغط «اقبل»، والداعي يعرف ذلك من إشارةٍ قد
-- لا تصله ومؤقّتٍ ينتهي عنده. فرأى الداعي «لا يستطيع»، ودخل الضيفُ وحده يحلّ
-- ويدردش.
--
-- والآن ثلاثةُ أوقاتٍ في صفّ المباراة يقرؤها الجهازان، والخادمُ يحكم بها:
--   accepted_at     — كتبه الخادمُ حين قبل الضيف. لا يدخل أحدٌ قبله.
--   host_joined_at  — دخل الداعي الغرفة.
--   guest_joined_at — دخل الضيفُ الغرفة.
-- ولا عدّادَ ولا سؤالَ ولا دردشةَ حتى يُكتب الاثنان؛ وأوّلُ سؤالٍ بعد دخول الثاني
-- بأربع ثوان، عند الاثنين معاً.

begin;

alter table public.challenge_matches
  add column if not exists accepted_at timestamptz,
  add column if not exists host_joined_at timestamptz,
  add column if not exists guest_joined_at timestamptz;

comment on column public.challenge_matches.accepted_at is
  'متى قبل الضيفُ الدعوة — يكتبه الخادم. لا يدخل أحدٌ الغرفةَ قبله.';
comment on column public.challenge_matches.host_joined_at is
  'متى دخل الداعي الغرفة.';
comment on column public.challenge_matches.guest_joined_at is
  'متى دخل الضيفُ الغرفة. والنزالُ يبدأ بعد دخول الثاني منهما.';

commit;

-- ┌──────────────────────────────────────────────────────────────
-- │ artifacts/api-server/scripts/duel-question-sources.sql — مصدرُ أسئلة المبارزة
-- └──────────────────────────────────────────────────────────────

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

-- ┌──────────────────────────────────────────────────────────────
-- │ artifacts/api-server/scripts/cinema-and-card-permissions.sql — السينما وصلاحياتُ البطاقات
-- └──────────────────────────────────────────────────────────────

-- سينما منارة مستقلّةً عن الدروس، وصلاحياتُ بطاقات الطالب.
--
-- التشغيل: الصقه كلَّه في محرّر SQL في Supabase وشغّله. يُعاد تشغيله بلا ضرر.
--
-- ── ويُصلح الجدولين إن وُجدا بغير بنيتهما ──
-- كان في Supabase جدولان بالاسمين نفسيهما أُنشئا قبل هذا الملف وبأعمدةٍ
-- أخرى: `cinema_videos` بمعرّفٍ من نوع uuid وبلا `description` ولا
-- `source_type`، و`student_card_permissions` بصفٍّ لكل بطاقة (`card_key`،
-- `is_enabled`). والنسخةُ الأولى من هذا الملف كانت «create table if not
-- exists» وحدها، فتركتهما كما هما — وكلُّ حفظٍ من اللوحة رُفض بـ PGRST204
-- («تعذر حفظ فيديو السينما»).
--
-- ── وقبل تشغيله لا يتعطّل شيء ──
-- الخادمُ إن وجد الجدول غائباً أو بغير بنيته حفظ في `app_kv`
-- (`smartEdu_videos` للسينما و`smartEdu_cardPermissions` للصلاحيات)، ويقرأ
-- المكانين معاً دائماً — فما حُفظ قبل التشغيل يبقى ظاهراً بعده.
--
-- ── والوصولُ للخادم وحده ──
-- RLS مفعّل بلا سياسة: مفتاحُ anon لا يقرأ ولا يكتب. الطالبُ يصل عبر
-- `/api/student/...` بجلسته الموقّعة، والمعلمُ والمشرف عبر `/api/cinema/...`
-- و`/api/card-permissions`.

-- ═══════════════════════════════════════════════════════════════════════
-- 1) فيديوهات سينما منارة
-- ═══════════════════════════════════════════════════════════════════════
create table if not exists public.cinema_videos (
  id text primary key,

  title text not null,
  -- الرابطُ المضمَّن (YouTube…) أو رابطُ ملف MP4 المرفوع.
  embed_url text not null,
  -- embed | mp4
  source_type text not null default 'embed',
  description text not null default '',

  -- ── الربطُ الأساسيّ، ولا شيء غيره ──
  -- الصفُّ الدراسيّ كما يُكتب في سجلّ الطالب (`students.data->>'grade'`).
  -- لا مادة ولا وحدة ولا درس: الفيديو للصفّ كلّه.
  grade_id text not null,
  -- المعلمُ المسؤول: طلابُه في هذا الصفّ هم من يرونه.
  teacher_id text not null,
  teacher_name text not null default '',
  -- من أضافه فعلاً: «admin» للمشرف، أو معرّفُ المعلم.
  created_by text not null default '',

  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- إصلاحُ جدولٍ قديمٍ بالاسم نفسه: كلُّ عمودٍ ناقص يُضاف، والمعرّف يصير نصّاً
-- (الفيديوهات القديمة معرّفاتُها ليست uuid). ولا يُمسّ صفٌّ موجود.
alter table public.cinema_videos alter column id drop default;
alter table public.cinema_videos alter column id type text using id::text;
alter table public.cinema_videos add column if not exists source_type text not null default 'embed';
alter table public.cinema_videos add column if not exists description text not null default '';
alter table public.cinema_videos add column if not exists teacher_name text not null default '';
alter table public.cinema_videos add column if not exists created_by text not null default '';
alter table public.cinema_videos add column if not exists created_at timestamptz not null default now();
alter table public.cinema_videos add column if not exists updated_at timestamptz not null default now();
alter table public.cinema_videos alter column created_by set default '';

create index if not exists cinema_videos_grade_teacher_idx
  on public.cinema_videos (grade_id, teacher_id);

alter table public.cinema_videos enable row level security;

-- ═══════════════════════════════════════════════════════════════════════
-- 2) صلاحيات بطاقات الطالب
-- ═══════════════════════════════════════════════════════════════════════
-- الجدولُ القديم (صفٌّ لكل بطاقة لكل طالب، بلا قواعد صفّ) لا يُرقَّع:
-- بنيتُه غير هذه. فإن كان فارغاً حُذف، وإن كان فيه شيء نُقل جانباً باسم
-- `student_card_permissions_old` بفهارسه — لا يُحذف عملُ أحد.
do $$
declare
  idx record;
begin
  if exists (
    select 1 from information_schema.columns
    where table_schema = 'public'
      and table_name = 'student_card_permissions'
      and column_name = 'card_key'
  ) then
    if (select count(*) from public.student_card_permissions) = 0 then
      drop table public.student_card_permissions;
    else
      alter table public.student_card_permissions rename to student_card_permissions_old;
      for idx in
        select indexname from pg_indexes
        where schemaname = 'public' and tablename = 'student_card_permissions_old'
      loop
        execute format('alter index public.%I rename to %I', idx.indexname, idx.indexname || '_old');
      end loop;
    end if;
  end if;
end $$;

-- صفٌّ لكل قاعدة. نطاقان:
--   class   : لكل طلاب معلمٍ في صفّ   → id = 'class:<teacher_id>:<grade_id>'
--   student : لطالبٍ واحد             → id = 'student:<student_id>'
-- وقاعدةُ الطالب تغلب قاعدةَ صفّه في كل بطاقةٍ ذكرتها، وما لم تذكره قاعدةٌ
-- فهو مفتوح.
--
-- `cards` خريطةٌ من معرّف البطاقة إلى true/false، مثل:
--   {"tutor": false, "cinema": true}
-- والمعرّفات: lesson, cinema, games, personality, tutor, quiz, solver,
-- meeting, chat, challenge, study.
create table if not exists public.student_card_permissions (
  id text primary key,
  scope text not null check (scope in ('class', 'student')),
  student_id text,
  teacher_id text not null,
  grade_id text,
  cards jsonb not null default '{}'::jsonb,
  updated_by text not null,
  updated_at timestamptz not null default now(),
  check (
    (scope = 'student' and student_id is not null) or
    (scope = 'class' and grade_id is not null)
  )
);

create index if not exists student_card_permissions_teacher_idx
  on public.student_card_permissions (teacher_id);

alter table public.student_card_permissions enable row level security;

-- ═══════════════════════════════════════════════════════════════════════
-- 3) تطبيقُ الطالب يقرأ صلاحيات البطاقات من Supabase مباشرةً
-- ═══════════════════════════════════════════════════════════════════════
-- الخادمُ يحفظ كلَّ قاعدةٍ في الجدول وفي `app_kv/smartEdu_cardPermissions`
-- معاً. والتطبيقُ يسأل الخادمَ أولاً، فإن لم يصل إليه — نسخةٌ بُنيت بعنوان
-- خادمٍ قديم، وهو ما أبقى البطاقاتِ المقفلة مفتوحةً عند الطالبة — قرأ
-- المفتاحَ مباشرةً. وسياسةُ `anon_read_app_kv` (harden-rls.sql) قائمةُ
-- مفاتيح لا يرد فيها هذا، فتُضاف له سياسةٌ مستقلّة: سياساتُ القراءة تُجمع
-- بـ «أو»، فلا يُمسّ ما سواه. وما فيه حالةُ بطاقاتٍ ومعرّفات، لا بياناتٌ شخصية.
drop policy if exists "anon_read_card_permissions" on public.app_kv;
create policy "anon_read_card_permissions" on public.app_kv
  for select to anon, authenticated
  using (key = 'smartEdu_cardPermissions');

-- ═══════════════════════════════════════════════════════════════════════
-- 4) نقلُ فيديوهات `app_kv/smartEdu_videos` إلى الجدول
-- ═══════════════════════════════════════════════════════════════════════
-- ما حُفظ قبل وجود الجدول يُقرأ «قديماً» وتظهر عليه في اللوحة علامةُ
-- الحفظ المؤقّت. يُنقل هنا بالحقول نفسها التي يقرؤها `fromLegacyRecord`
-- في `src/lib/cinema.ts`، ثم يُحذف من المفتاح ما صار له صفٌّ في الجدول.
-- الصفُّ الموجود في الجدول يغلب (كما في `mergeCinemaVideos`)، والمحذوفُ في
-- `smartEdu_deletedVideos` لا يُنقل.
with legacy as (
  select r.value as rec
  from public.app_kv kv,
       jsonb_array_elements(
         case when jsonb_typeof(kv.value::jsonb) = 'array' then kv.value::jsonb else '[]'::jsonb end
       ) as r(value)
  where kv.key = 'smartEdu_videos' and jsonb_typeof(r.value) = 'object'
),
deleted as (
  select btrim(d.value) as id
  from public.app_kv kv,
       jsonb_array_elements_text(
         case when jsonb_typeof(kv.value::jsonb) = 'array' then kv.value::jsonb else '[]'::jsonb end
       ) as d(value)
  where kv.key = 'smartEdu_deletedVideos'
),
shaped as (
  select
    btrim(coalesce(rec->>'id', '')) as id,
    btrim(coalesce(rec->>'title', '')) as title,
    coalesce(nullif(btrim(rec->>'embedUrl'), ''), btrim(coalesce(rec->>'url', ''))) as embed_url,
    rec->>'sourceType' as source_type,
    btrim(coalesce(rec->>'description', '')) as description,
    coalesce(nullif(btrim(rec->>'gradeId'), ''), nullif(btrim(rec->>'grade_id'), ''),
             btrim(coalesce(rec->>'grade', ''))) as grade_id,
    coalesce(nullif(btrim(rec->>'teacher_id'), ''), nullif(btrim(rec->>'teacherId'), ''),
             btrim(coalesce(rec->>'createdBy', ''))) as teacher_id,
    btrim(coalesce(rec->>'teacherName', '')) as teacher_name,
    nullif(btrim(coalesce(rec->>'created_by', rec->>'addedBy', '')), '') as created_by,
    btrim(coalesce(rec->>'createdAt', '')) as created_at,
    coalesce(nullif(btrim(rec->>'updatedAt'), ''), btrim(coalesce(rec->>'createdAt', ''))) as updated_at
  from legacy
)
insert into public.cinema_videos
  (id, title, embed_url, source_type, description, grade_id, teacher_id,
   teacher_name, created_by, created_at, updated_at)
select distinct on (s.id)
  s.id,
  s.title,
  s.embed_url,
  case
    when s.source_type in ('mp4', 'embed') then s.source_type
    when s.embed_url ~* '\.mp4($|[?#])' then 'mp4'
    else 'embed'
  end,
  s.description,
  s.grade_id,
  s.teacher_id,
  s.teacher_name,
  coalesce(s.created_by, s.teacher_id),
  -- تاريخٌ ISO أو ميلي‌ثوانٍ؛ وما سواهما «الآن» بدل أن يُفشل النقلَ كله.
  case
    when s.created_at ~ '^\d{4}-\d{2}-\d{2}([T ][0-9:.]+)?(Z|[+-]\d{2}(:?\d{2})?)?$' then s.created_at::timestamptz
    when s.created_at ~ '^\d{10,13}$' then to_timestamp(s.created_at::bigint / case when length(s.created_at) > 10 then 1000.0 else 1 end)
    else now()
  end,
  case
    when s.updated_at ~ '^\d{4}-\d{2}-\d{2}([T ][0-9:.]+)?(Z|[+-]\d{2}(:?\d{2})?)?$' then s.updated_at::timestamptz
    when s.updated_at ~ '^\d{10,13}$' then to_timestamp(s.updated_at::bigint / case when length(s.updated_at) > 10 then 1000.0 else 1 end)
    else now()
  end
from shaped s
where s.id <> '' and s.embed_url <> ''
  and not exists (select 1 from deleted d where d.id = s.id)
order by s.id
on conflict (id) do nothing;

-- ما صار في الجدول يُرفع من المفتاح، فلا يُقرأ بعد اليوم نسخةً قديمة.
update public.app_kv kv
set value = coalesce((
  select jsonb_agg(r.value)
  from jsonb_array_elements(kv.value::jsonb) as r(value)
  where not exists (
    select 1 from public.cinema_videos c
    where c.id = btrim(coalesce(r.value->>'id', ''))
  )
), '[]'::jsonb)
where kv.key = 'smartEdu_videos'
  and jsonb_typeof(kv.value::jsonb) = 'array';

-- يُعلم PostgREST بالبنية الجديدة فورًا بدل انتظار تحديث ذاكرته.
notify pgrst, 'reload schema';

-- ┌──────────────────────────────────────────────────────────────
-- │ artifacts/api-server/scripts/entertainment-games.sql — الترفيهُ والألعاب
-- └──────────────────────────────────────────────────────────────

-- «الترفيه والألعاب»: ألعابٌ يضيفها المشرف ويُسندها إلى معلّم.
--
-- يُشغَّل مرةً في محرّر SQL في Supabase، وإعادةُ تشغيله آمنة.
--
-- ── وقبل تشغيله لا يتعطّل شيء ──
-- الخادمُ إن وجد الجدول غائباً حفظ الألعاب في `app_kv`
-- (`smartEdu_entertainmentGames`)، ويقرأ المكانين معاً دائماً — فما حُفظ قبل
-- التشغيل يبقى ظاهراً بعده، وينتقل إلى الجدول عند أوّل تعديل.
--
-- ── والوصولُ للخادم وحده ──
-- RLS مفعّل بلا سياسة: مفتاحُ anon لا يقرأ ولا يكتب. المشرفُ يصل عبر
-- `/api/entertainment` بجلسته، والطالبُ عبر `/api/student/entertainment`
-- بجلسته الموقّعة — ولا يرى إلا ألعابَ معلّمه المفعّلة.

create table if not exists public.entertainment_games (
  id text primary key,

  title text not null,
  description text not null default '',
  -- الرابطُ المباشر أو المضمَّن للعبة — يفتحه مشغّلُ الألعاب في التطبيق كما هو.
  embed_url text not null,

  -- المعلمُ المسؤول (إلزاميّ): طلابُه وحدهم يرون اللعبة.
  teacher_id text not null,
  teacher_name text not null default '',

  -- الإظهار: لعبةٌ معطّلة تبقى في اللوحة ولا تظهر لأحد.
  is_active boolean not null default true,

  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists entertainment_games_teacher_idx
  on public.entertainment_games (teacher_id, is_active);

alter table public.entertainment_games enable row level security;
revoke all on public.entertainment_games from anon, authenticated;

-- ┌──────────────────────────────────────────────────────────────
-- │ artifacts/api-server/scripts/solved-questions-cache.sql — ذاكرةُ «حل المسائل»
-- └──────────────────────────────────────────────────────────────

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

-- ‏بالأعمدة نفسها التي في الإنتاج: الأعمدةُ المقروءة في ai_qa_cache (يكتبها الخادم
-- ‏مع كل حفظ — انظر cacheReadableColumns في src/lib/solverPolicy.ts).
create or replace view public.solved_questions_cache
with (security_invoker = true)
as
select
  c.id,
  c.question_hash,
  c.question_text,
  c.answer_json,
  c.domain,
  c.created_at,
  c.updated_at
from public.ai_qa_cache c;

-- كالجدول: للخادم وحده. مفتاحُ anon في كل APK، ولا تُقرأ به أسئلةُ الأطفال.
revoke all on public.solved_questions_cache from public, anon, authenticated;
grant select on public.solved_questions_cache to service_role;

comment on view public.solved_questions_cache is
  'ذاكرة حل المسائل الدائمة (عرضٌ لـ ai_qa_cache): كل سؤالٍ أُجيب وإجابته، لا تُحذف.';

commit;

-- ┌──────────────────────────────────────────────────────────────
-- │ artifacts/api-server/scripts/security-lockdown.sql — إغلاقُ المفتاح العام — قراءةُ المحتوى وحده
-- └──────────────────────────────────────────────────────────────

-- ════════════════════════════════════════════════════════════════════════
-- إغلاقُ المفتاح العام (anon): لا قراءةَ لبيانات الأشخاص ولا كتابةَ لأيّ جدول
-- ════════════════════════════════════════════════════════════════════════
--
-- ── ما كان ──
-- مفتاحُ anon مضمَّنٌ في كل APK وفي لوحات الويب، فهو علنيٌّ عملياً. وكان به:
--   • قراءةُ سجلّات الطلاب كاملة (الاسم، والهوية، وجوال وليّ الأمر، وبصمة
--     كلمة المرور)، ونتائجِ الاختبارات، والتفاعلات، وذاكرةِ حل المسائل.
--   • كتابةٌ في students و teachers و parents و interactions و quiz_results:
--     أيُّ حاملٍ للمفتاح يغيّر جواهرَ طالب أو كلمةَ مرور معلّمٍ فيستولي على حسابه.
--
-- ── لماذا يصحّ إغلاقُه الآن ──
-- كلُّ قراءةٍ لهذه الجداول وكلُّ كتابةٍ صارت عبر خادم الـ API بمفتاح الخدمة:
--   • التطبيق: الدخولُ (/auth/student/session)، والملف (/student/me)،
--     والنتائج (/student/quiz-results)، ومحادثات المعلّم (/student/tutor-history)،
--     والتقدّم والمكافآت (/student/progress/*).
--   • لوحاتُ الويب: كلُّها عبر /api/supabase/* (جسر المزامنة).
-- وما يبقى للمفتاح العام: قراءةُ محتوى التعليم وحده — الدروس، واختبارات
-- المعلمين، ومفاتيحُ إعداداتٍ بعينها — ودالّةُ claim_duel_pack.
--
-- ── تنبيه ──
-- نسخةُ التطبيق v1.0.0 كانت تقرأ جدول الطلاب بالمفتاح العام لتسجيل الدخول؛
-- بعد هذا الملف لا يدخل بها أحد. الإصدار v1.1.0 فما بعده يدخل عبر الخادم.
--
-- يُعاد تشغيله بأمان.

begin;

-- ١. كلُّ جدولٍ عامّ: RLS مفعّل، ولا سياسةَ لـ anon/authenticated، ولا كتابة.
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

-- والعروض (views) كذلك: solved_questions_cache كان مقروءاً للجميع.
do $$
declare
  v text;
begin
  for v in select viewname from pg_views where schemaname = 'public' loop
    execute format('revoke all on public.%I from anon, authenticated', v);
    execute format('grant select on public.%I to service_role', v);
  end loop;
end $$;

-- ٢. ما يقرؤه التطبيق بالمفتاح العام: محتوى تعليميّ لا بيانات أشخاص.
grant select on public.lesson_configs to anon, authenticated;
create policy "anon_read_lesson_configs" on public.lesson_configs
  for select to anon, authenticated using (true);

grant select on public.created_quizzes to anon, authenticated;
create policy "anon_read_created_quizzes" on public.created_quizzes
  for select to anon, authenticated using (true);

-- ومن app_kv مفاتيحُ المحتوى والصلاحيات وحدها، لا كلُّ الجدول.
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

-- ٣. الدوالّ: claim_duel_pack وحدها للمفتاح العام (تبني حزمةَ مباراةٍ بمعرّفها).
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

-- ════════════════════════════════════════════════════════════════════════
-- match_qa_cache: حذفُ النسخة المعطوبة قبل إنشاء الصحيحة
-- ════════════════════════════════════════════════════════════════════════
-- وُجدت في الإنتاج بتوقيعٍ آخر (match_lesson, query_embedding,
-- similarity_threshold) وجسمٍ يشير إلى عمودٍ غير موجود (c.lesson_title).
-- تُحذف كلُّ نسخها، ثم يُنشئها ai-qa-cache-vectors.sql بالتوقيع الذي يناديه الخادم.
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

-- ┌──────────────────────────────────────────────────────────────
-- │ artifacts/api-server/scripts/ai-qa-cache-vectors.sql — مطابقةُ الإجابات بالمعنى
-- └──────────────────────────────────────────────────────────────

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
  -- الافتراضيُّ هنا احتياطٌ لا سياسة: الخادم يُرسل العتبة مع كل نداء
  -- من `VECTOR_THRESHOLD`، فهي مكتوبةٌ في موضعٍ واحد. وهذا لمن ينادي
  -- الدالّة من محرّر SQL ليجرّبها.
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

-- ┌──────────────────────────────────────────────────────────────
-- │ artifacts/api-server/scripts/duel-knowledge-bank.sql — أبوابُ المعرفة العامّة
-- └──────────────────────────────────────────────────────────────

-- ════════════════════════════════════════════════════════════════════════
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

-- ── ٢. الأسئلة (146) ──
insert into public.duel_questions (id, subject_key, category, prompt, choices)
values
  ('culture:ulrbnx', '*', 'culture', 'كم عدد ألوان قوس قزح؟', array['سبعة', 'خمسة', 'ستة', 'ثمانية']),
  ('culture:lpu2ar', '*', 'culture', 'ما الحيوان الذي ينام معلّقاً ورأسه إلى الأسفل؟', array['الخفاش', 'البومة', 'القرد', 'السنجاب']),
  ('culture:ozdoy2', '*', 'culture', 'ما الحيوان الذي يُلقّب بملك الغابة؟', array['الأسد', 'النمر', 'الفيل', 'الذئب']),
  ('culture:spynsz', '*', 'culture', 'كم عدد أرجل العنكبوت؟', array['ثمانية', 'ستة', 'عشرة', 'أربعة']),
  ('culture:k72w6w', '*', 'culture', 'ما الطائر الذي اشتهر العرب بتدريبه على الصيد؟', array['الصقر', 'الحمامة', 'البطريق', 'النعامة']),
  ('culture:bur97o', '*', 'culture', 'ما الشهر الذي يصوم فيه المسلمون؟', array['رمضان', 'شعبان', 'شوال', 'محرم']),
  ('culture:etqiu9', '*', 'culture', 'ما أكبر طائر في العالم؟', array['النعامة', 'النسر', 'البطريق', 'البجعة']),
  ('culture:93oq76', '*', 'culture', 'ما الأداة التي نقيس بها درجة الحرارة؟', array['ميزان الحرارة', 'المسطرة', 'البوصلة', 'الساعة']),
  ('culture:b2cip6', '*', 'culture', 'ما الأداة التي تدلّنا على الاتجاهات؟', array['البوصلة', 'الميزان', 'المنظار', 'الساعة']),
  ('culture:lpto6i', '*', 'culture', 'ما الحيوان الذي يحمل صغيره في جيبٍ على بطنه؟', array['الكنغر', 'الزرافة', 'الحصان', 'الفيل']),
  ('culture:3ro2om', '*', 'culture', 'كم دقيقة في الساعة الواحدة؟', array['60', '100', '30', '24']),
  ('culture:bkhjr', '*', 'culture', 'ما الحيوان الذي يُضرب به المثل في الصبر؟', array['الجمل', 'الأرنب', 'القط', 'الثعلب']),
  ('culture:us5byn', '*', 'culture', 'ماذا تصنع النحلة؟', array['العسل', 'الحليب', 'الحرير', 'الصوف']),
  ('culture:oaecn1', '*', 'culture', 'ما الكائن الذي يصنع خيوط الحرير الطبيعي؟', array['دودة القز', 'النحلة', 'النملة', 'الجرادة']),
  ('culture:38t0la', '*', 'culture', 'ما اسم صغير الأسد؟', array['الشبل', 'المهر', 'العجل', 'الجرو']),
  ('culture:tpekgs', '*', 'culture', 'ما اسم صغير الحصان؟', array['المهر', 'الشبل', 'العجل', 'الحمل']),
  ('culture:pduhus', '*', 'culture', 'ما اسم بيت النحل؟', array['الخلية', 'العش', 'العرين', 'الجحر']),
  ('culture:pd899e', '*', 'culture', 'ما اسم بيت الأسد؟', array['العرين', 'الخلية', 'العش', 'الإسطبل']),
  ('culture:7p02se', '*', 'culture', 'كم عدد حروف اللغة العربية؟', array['28', '26', '30', '24']),
  ('culture:vrp1nf', '*', 'culture', 'ما اليوم الذي يأتي بعد الجمعة؟', array['السبت', 'الخميس', 'الأحد', 'الاثنين']),
  ('culture:2q7i25', '*', 'culture', 'ما الحيوان الذي يغيّر لونه ليختبئ؟', array['الحرباء', 'الأرنب', 'الحمار', 'البقرة']),
  ('culture:c4k0sx', '*', 'culture', 'من أي شيءٍ يُصنع الخبز؟', array['الدقيق', 'الحليب', 'العسل', 'الزيت']),
  ('culture:98a9em', '*', 'culture', 'ما وسيلة النقل التي تطير في السماء؟', array['الطائرة', 'السفينة', 'القطار', 'الحافلة']),
  ('culture:3uaer3', '*', 'culture', 'ما اسم المسجد الذي تتوسّطه الكعبة المشرّفة؟', array['المسجد الحرام', 'المسجد النبوي', 'المسجد الأقصى', 'مسجد قباء']),
  ('culture:ybw323', '*', 'culture', 'في أي مدينةٍ يقع المسجد النبوي؟', array['المدينة المنورة', 'مكة المكرمة', 'الرياض', 'جدة']),
  ('culture:3qbyci', '*', 'culture', 'في أي يومٍ يحتفل السعوديون باليوم الوطني؟', array['٢٣ سبتمبر', '١ يناير', '١٥ مارس', '١٠ أكتوبر']),
  ('culture:mv6dv4', '*', 'culture', 'ما الشجرة التي يأتي منها التمر؟', array['النخلة', 'الزيتونة', 'التفاحة', 'البرتقالة']),
  ('culture:a74bxe', '*', 'culture', 'كم عدد أشهر السنة؟', array['12', '10', '11', '13']),
  ('culture:fqatu2', '*', 'culture', 'ما الحيوان الذي يُعطينا الصوف؟', array['الخروف', 'الدجاجة', 'السمكة', 'الأرنب']),
  ('culture:o4n2b3', '*', 'culture', 'ماذا نسمّي الشخص الذي يعالج المرضى؟', array['الطبيب', 'المهندس', 'الطيّار', 'النجّار']),
  ('sports:50e5ja', '*', 'sports', 'كم لاعباً في فريق كرة القدم داخل الملعب؟', array['11', '9', '7', '12']),
  ('sports:dkixw4', '*', 'sports', 'كم لاعباً في فريق كرة السلة داخل الملعب؟', array['5', '6', '7', '11']),
  ('sports:bl759q', '*', 'sports', 'كم لاعباً في فريق كرة الطائرة داخل الملعب؟', array['6', '5', '7', '11']),
  ('sports:nviw6t', '*', 'sports', 'كم دقيقة مدّة مباراة كرة القدم بلا وقتٍ إضافي؟', array['90', '60', '80', '120']),
  ('sports:dthff', '*', 'sports', 'في أي رياضةٍ نسمع عبارة «كش ملك»؟', array['الشطرنج', 'التنس', 'كرة السلة', 'الملاكمة']),
  ('sports:d9d4n8', '*', 'sports', 'كل كم سنةً تُقام الألعاب الأولمبية الصيفية؟', array['أربع سنوات', 'سنتين', 'ثلاث سنوات', 'خمس سنوات']),
  ('sports:y7urv3', '*', 'sports', 'كم حلقةً في شعار الألعاب الأولمبية؟', array['خمس', 'أربع', 'ست', 'سبع']),
  ('sports:866ylx', '*', 'sports', 'في أي رياضةٍ تُرمى الكرة في سلّةٍ عالية؟', array['كرة السلة', 'كرة اليد', 'البولينج', 'الهوكي']),
  ('sports:4bmza5', '*', 'sports', 'ما الرياضة التي تُسقط فيها القوارير بكرةٍ ثقيلة تتدحرج؟', array['البولينج', 'الغولف', 'البلياردو', 'الكريكيت']),
  ('sports:lmsjkz', '*', 'sports', 'ما لون البطاقة التي يُطرد بها اللاعب في كرة القدم؟', array['الحمراء', 'الصفراء', 'الخضراء', 'الزرقاء']),
  ('sports:ftbfwl', '*', 'sports', 'ما لون بطاقة الإنذار في كرة القدم؟', array['الصفراء', 'الحمراء', 'السوداء', 'البيضاء']),
  ('sports:43dad4', '*', 'sports', 'كم شوطاً في مباراة كرة القدم؟', array['2', '3', '4', '1']),
  ('sports:vz8mg4', '*', 'sports', 'ما الرياضة التي يُستعمل فيها القوس والسهم؟', array['الرماية', 'المبارزة', 'التجديف', 'الفروسية']),
  ('sports:zgnf3y', '*', 'sports', 'ما الرياضة التي يركب فيها اللاعب الخيل؟', array['الفروسية', 'الملاكمة', 'الجودو', 'التنس']),
  ('sports:8nvy5y', '*', 'sports', 'أي رياضةٍ تُلعب على طاولةٍ بمضربين صغيرين وكرةٍ خفيفة؟', array['تنس الطاولة', 'الغولف', 'الهوكي', 'البيسبول']),
  ('sports:81jnrv', '*', 'sports', 'من اللاعب الذي يحمي المرمى في كرة القدم؟', array['حارس المرمى', 'المدافع', 'المهاجم', 'الحكم']),
  ('sports:b589sv', '*', 'sports', 'من يدير المباراة ويطبّق قوانينها؟', array['الحكم', 'المدرب', 'الجمهور', 'قائد الفريق']),
  ('sports:pqntt7', '*', 'sports', 'ما اسم سباق الجري الطويل الذي يبلغ نحو ٤٢ كيلومتراً؟', array['الماراثون', 'سباق التتابع', 'الوثب العالي', 'رمي الرمح']),
  ('sports:205jcm', '*', 'sports', 'ما الرياضة التي تُمارس على الجليد بأحذيةٍ لها شفرات؟', array['التزلّج على الجليد', 'ركوب الدراجات', 'الجري', 'كرة القدم']),
  ('sports:sqqdzl', '*', 'sports', 'ما الدولة التي ستستضيف كأس العالم لكرة القدم ٢٠٣٤؟', array['السعودية', 'قطر', 'مصر', 'اليابان']),
  ('sports:qdroj8', '*', 'sports', 'كم نقطةً تُحتسب للرمية من خارج القوس في كرة السلة؟', array['3', '2', '1', '4']),
  ('sports:qku605', '*', 'sports', 'كم لاعباً في مباراة الشطرنج الواحدة؟', array['2', '4', '1', '6']),
  ('sports:ukftx5', '*', 'sports', 'ما الحيوان الذي يُتسابق عليه في سباق الهجن؟', array['الجمل', 'الحصان', 'الكلب', 'الغزال']),
  ('sports:ra4m17', '*', 'sports', 'في أي رياضةٍ توجد «ضربة الجزاء»؟', array['كرة القدم', 'السباحة', 'الشطرنج', 'الجري']),
  ('sports:jdjtmw', '*', 'sports', 'ما الرياضة التي تُمارس في المسبح؟', array['السباحة', 'الجمباز', 'التزلّج', 'الرماية']),
  ('sports:t0jqg3', '*', 'sports', 'ما الأداة التي يضرب بها لاعب التنس الكرة؟', array['المضرب', 'العصا', 'القفاز', 'القدم']),
  ('sports:69wu5i', '*', 'sports', 'في أي رياضةٍ يرتدي اللاعبان قفازين كبيرين ويتنافسان داخل حلبة؟', array['الملاكمة', 'السباحة', 'الغولف', 'التنس']),
  ('sports:oise0s', '*', 'sports', 'ما الرياضة التي يُدخل فيها اللاعب الكرةَ الصغيرة في حفرةٍ بعصا؟', array['الغولف', 'كرة السلة', 'الكرة الطائرة', 'البولينج']),
  ('geography:k32n3n', '*', 'geography', 'ما أكبر قارّةٍ في العالم مساحةً؟', array['آسيا', 'أفريقيا', 'أوروبا', 'أستراليا']),
  ('geography:ljauas', '*', 'geography', 'ما أصغر قارّةٍ في العالم مساحةً؟', array['أستراليا', 'أوروبا', 'أفريقيا', 'آسيا']),
  ('geography:vqiofv', '*', 'geography', 'ما عاصمة الإمارات العربية المتحدة؟', array['أبوظبي', 'دبي', 'الشارقة', 'العين']),
  ('geography:ef1zzz', '*', 'geography', 'ما عاصمة الأردن؟', array['عمّان', 'إربد', 'الزرقاء', 'العقبة']),
  ('geography:5mml71', '*', 'geography', 'ما عاصمة فرنسا؟', array['باريس', 'ليون', 'مرسيليا', 'نيس']),
  ('geography:3klwu5', '*', 'geography', 'ما عاصمة اليابان؟', array['طوكيو', 'أوساكا', 'كيوتو', 'بكين']),
  ('geography:exwrtk', '*', 'geography', 'ما عاصمة المغرب؟', array['الرباط', 'الدار البيضاء', 'مراكش', 'فاس']),
  ('geography:gfzxlg', '*', 'geography', 'ما عاصمة سلطنة عُمان؟', array['مسقط', 'صلالة', 'نزوى', 'صحار']),
  ('geography:vkfbah', '*', 'geography', 'ما عاصمة مملكة البحرين؟', array['المنامة', 'المحرّق', 'الرفاع', 'سترة']),
  ('geography:dxt48y', '*', 'geography', 'ما عاصمة قطر؟', array['الدوحة', 'الوكرة', 'الخور', 'الريان']),
  ('geography:u93v7h', '*', 'geography', 'ما عاصمة تركيا؟', array['أنقرة', 'إسطنبول', 'إزمير', 'بورصة']),
  ('geography:p0efdy', '*', 'geography', 'ما عاصمة إيطاليا؟', array['روما', 'ميلانو', 'البندقية', 'نابولي']),
  ('geography:eb3i3o', '*', 'geography', 'ما عاصمة المملكة المتحدة؟', array['لندن', 'مانشستر', 'ليفربول', 'باريس']),
  ('geography:ffdnau', '*', 'geography', 'ما أكبر صحراءٍ حارّةٍ في العالم؟', array['الصحراء الكبرى', 'الربع الخالي', 'صحراء النفود', 'صحراء الدهناء']),
  ('geography:vnh2ee', '*', 'geography', 'ما الصحراء الرملية الكبيرة في جنوب الجزيرة العربية؟', array['الربع الخالي', 'صحراء النفود', 'صحراء الدهناء', 'صحراء سيناء']),
  ('geography:di2hju', '*', 'geography', 'ما البحر الذي يقع غرب المملكة العربية السعودية؟', array['البحر الأحمر', 'البحر المتوسط', 'بحر العرب', 'البحر الأسود']),
  ('geography:9k377k', '*', 'geography', 'ما الخليج الذي يقع شرق المملكة العربية السعودية؟', array['الخليج العربي', 'خليج عدن', 'خليج العقبة', 'خليج المكسيك']),
  ('geography:sgjcon', '*', 'geography', 'ما أعلى جبلٍ في العالم؟', array['جبل إيفرست', 'جبل كليمنجارو', 'جبل طويق', 'جبل أحد']),
  ('geography:irthpz', '*', 'geography', 'في أي قارّةٍ تقع المملكة العربية السعودية؟', array['آسيا', 'أفريقيا', 'أوروبا', 'أمريكا الجنوبية']),
  ('geography:6l8yhz', '*', 'geography', 'ما النهر الذي يجري في مصر؟', array['النيل', 'الفرات', 'دجلة', 'الأمازون']),
  ('geography:s5ivoy', '*', 'geography', 'ما القارّة المغطّاة بالجليد عند القطب الجنوبي؟', array['أنتاركتيكا', 'آسيا', 'أوروبا', 'أفريقيا']),
  ('geography:yhfdm6', '*', 'geography', 'ما أكبر دولةٍ في العالم مساحةً؟', array['روسيا', 'الصين', 'كندا', 'البرازيل']),
  ('geography:w60inp', '*', 'geography', 'ما أكبر مدينةٍ سعوديةٍ في عدد السكان؟', array['الرياض', 'جدة', 'الدمام', 'أبها']),
  ('geography:8seis0', '*', 'geography', 'أي هذه المدن السعودية تشتهر بجبالها الخضراء في الجنوب؟', array['أبها', 'الدمام', 'حائل', 'تبوك']),
  ('geography:5kc9x', '*', 'geography', 'ما الخطّ الوهمي الذي يقسم الأرض إلى نصفٍ شمالي ونصفٍ جنوبي؟', array['خط الاستواء', 'خط غرينتش', 'مدار السرطان', 'خط الطول']),
  ('geography:khmabk', '*', 'geography', 'كم عدد محيطات العالم؟', array['خمسة', 'ثلاثة', 'سبعة', 'اثنان']),
  ('geography:rynkd6', '*', 'geography', 'أي محيطٍ يقع بين أفريقيا وأستراليا؟', array['المحيط الهندي', 'المحيط الأطلسي', 'المحيط الهادي', 'المحيط المتجمد الشمالي']),
  ('geography:5r547d', '*', 'geography', 'ما الدولة التي تشتهر بالأهرامات؟', array['مصر', 'الهند', 'اليابان', 'البرازيل']),
  ('geography:57cm5n', '*', 'geography', 'على أي بحرٍ تقع مدينة جدة؟', array['البحر الأحمر', 'الخليج العربي', 'البحر المتوسط', 'بحر العرب']),
  ('geography:kpnpl4', '*', 'geography', 'ما المدينة السعودية التي تقع على الخليج العربي؟', array['الدمام', 'جدة', 'أبها', 'المدينة المنورة']),
  ('history:frfjar', '*', 'history', 'في أي مدينةٍ وُلد النبي محمد ﷺ؟', array['مكة المكرمة', 'المدينة المنورة', 'الطائف', 'القدس']),
  ('history:sx4q5s', '*', 'history', 'إلى أي مدينةٍ هاجر النبي ﷺ؟', array['المدينة المنورة', 'الطائف', 'مكة المكرمة', 'جدة']),
  ('history:kk1jhr', '*', 'history', 'من أول الخلفاء الراشدين؟', array['أبو بكر الصديق', 'عمر بن الخطاب', 'عثمان بن عفان', 'علي بن أبي طالب']),
  ('history:rn3lfi', '*', 'history', 'من مؤسّس المملكة العربية السعودية الحديثة؟', array['الملك عبدالعزيز', 'الملك فيصل', 'الملك خالد', 'الملك فهد']),
  ('history:9i706v', '*', 'history', 'في أي سنةٍ ميلادية أُعلن توحيد المملكة العربية السعودية؟', array['1932', '1902', '1950', '1970']),
  ('history:unzk4k', '*', 'history', 'في أي يومٍ يحتفل السعوديون بيوم التأسيس؟', array['٢٢ فبراير', '٢٣ سبتمبر', '١ يناير', '١٥ مايو']),
  ('history:oczlq5', '*', 'history', 'في أي سنةٍ ميلادية استردّ الملك عبدالعزيز الرياض؟', array['1902', '1932', '1890', '1925']),
  ('history:540mgr', '*', 'history', 'ما عاصمة الدولة السعودية الأولى؟', array['الدرعية', 'الرياض', 'جدة', 'حائل']),
  ('history:tomvsv', '*', 'history', 'في أي محافظةٍ سعودية يقع موقع الحِجر الأثري (مدائن صالح)؟', array['العلا', 'الأحساء', 'جازان', 'الجوف']),
  ('history:njfzsq', '*', 'history', 'أي حضارةٍ بنت الأهرامات؟', array['المصرية القديمة', 'الرومانية', 'الصينية', 'اليونانية']),
  ('history:qnvrbb', '*', 'history', 'ما اسم السور الطويل الذي بُني لحماية الصين قديماً؟', array['سور الصين العظيم', 'سور برلين', 'سور بغداد', 'سور روما']),
  ('history:z5hqu5', '*', 'history', 'من العالِم المسلم الذي يُلقّب بأبي الجبر؟', array['الخوارزمي', 'ابن سينا', 'ابن خلدون', 'البيروني']),
  ('history:cxvt5k', '*', 'history', 'من الطبيب المسلم صاحب كتاب «القانون في الطب»؟', array['ابن سينا', 'الخوارزمي', 'ابن بطوطة', 'الفارابي']),
  ('history:gkh8id', '*', 'history', 'من الرحّالة المسلم الذي طاف بلداناً كثيرة ودوّن رحلته الشهيرة؟', array['ابن بطوطة', 'ابن سينا', 'الخوارزمي', 'الرازي']),
  ('history:pcesfr', '*', 'history', 'ما أول غزوةٍ كبرى انتصر فيها المسلمون؟', array['غزوة بدر', 'غزوة أحد', 'غزوة الخندق', 'غزوة تبوك']),
  ('history:yjhzco', '*', 'history', 'من أول إنسانٍ مشى على سطح القمر؟', array['نيل أرمسترونغ', 'يوري غاغارين', 'غاليليو', 'إسحاق نيوتن']),
  ('history:3onom4', '*', 'history', 'من أول إنسانٍ سافر إلى الفضاء؟', array['يوري غاغارين', 'نيل أرمسترونغ', 'توماس إديسون', 'غاليليو']),
  ('history:4748lb', '*', 'history', 'من أول رائد فضاءٍ عربي مسلم؟', array['الأمير سلطان بن سلمان', 'نيل أرمسترونغ', 'ابن بطوطة', 'الخوارزمي']),
  ('history:viui1q', '*', 'history', 'ما اسم الكتابة بالصور التي استعملها المصريون القدماء؟', array['الهيروغليفية', 'المسمارية', 'اللاتينية', 'الصينية']),
  ('history:2jy9nl', '*', 'history', 'من بنى الكعبة المشرّفة مع ابنه إسماعيل عليهما السلام؟', array['إبراهيم عليه السلام', 'موسى عليه السلام', 'نوح عليه السلام', 'يوسف عليه السلام']),
  ('history:bwkle4', '*', 'history', 'ما المدينة التي كانت عاصمة الدولة العباسية واشتهرت ببيت الحكمة؟', array['بغداد', 'دمشق', 'القاهرة', 'قرطبة']),
  ('history:l94nbs', '*', 'history', 'ما عاصمة الدولة الأموية؟', array['دمشق', 'بغداد', 'القاهرة', 'مكة المكرمة']),
  ('history:owwuji', '*', 'history', 'من القائد المسلم الذي حرّر القدس سنة ١١٨٧م؟', array['صلاح الدين الأيوبي', 'خالد بن الوليد', 'طارق بن زياد', 'عمرو بن العاص']),
  ('history:3c856p', '*', 'history', 'من القائد الذي عبر بالمسلمين إلى الأندلس وسُمّي مضيقٌ باسمه؟', array['طارق بن زياد', 'صلاح الدين الأيوبي', 'خالد بن الوليد', 'سعد بن أبي وقاص']),
  ('history:r6w4', '*', 'history', 'ما أول مسجدٍ بُني في الإسلام؟', array['مسجد قباء', 'المسجد النبوي', 'المسجد الأقصى', 'مسجد القبلتين']),
  ('history:tk612m', '*', 'history', 'من الخليفة الراشد الثاني؟', array['عمر بن الخطاب', 'أبو بكر الصديق', 'عثمان بن عفان', 'علي بن أبي طالب']),
  ('history:4f9mab', '*', 'history', 'من الذي اخترع المصباح الكهربائي المشهور؟', array['توماس إديسون', 'إسحاق نيوتن', 'غاليليو', 'ابن سينا']),
  ('history:q68b1w', '*', 'history', 'في أي بلادٍ قديمة ظهرت الكتابة المسمارية؟', array['بلاد الرافدين', 'مصر القديمة', 'الصين', 'اليونان']),
  ('science:yc1bpb', '*', 'science', 'ما العضو الذي يضخّ الدم في جسم الإنسان؟', array['القلب', 'الرئة', 'المعدة', 'الكبد']),
  ('science:nntz8y', '*', 'science', 'ما الغاز الذي نتنفّسه لنعيش؟', array['الأكسجين', 'ثاني أكسيد الكربون', 'الهيليوم', 'الهيدروجين']),
  ('science:ycmzx0', '*', 'science', 'ما الغاز الذي يأخذه النبات من الهواء ليصنع غذاءه؟', array['ثاني أكسيد الكربون', 'الأكسجين', 'الهيليوم', 'الهيدروجين']),
  ('science:p9xzag', '*', 'science', 'ما أقرب نجمٍ إلى الأرض؟', array['الشمس', 'القمر', 'الشعرى', 'سهيل']),
  ('science:lthnrt', '*', 'science', 'ما الحاسّة التي نستعمل فيها الأنف؟', array['الشم', 'السمع', 'البصر', 'التذوق']),
  ('science:eh18ud', '*', 'science', 'ما الكوكب الذي يُلقّب بالكوكب الأحمر؟', array['المريخ', 'الزهرة', 'زحل', 'عطارد']),
  ('science:x1rvwf', '*', 'science', 'ما الكوكب المشهور بحلقاته الواضحة؟', array['زحل', 'المريخ', 'عطارد', 'الأرض']),
  ('science:xwoo9a', '*', 'science', 'ما أقرب كوكبٍ إلى الشمس؟', array['عطارد', 'الزهرة', 'الأرض', 'المريخ']),
  ('science:74ru0m', '*', 'science', 'عند كم درجةٍ مئوية يتجمّد الماء؟', array['0', '100', '10', '50']),
  ('science:rnjjpu', '*', 'science', 'عند كم درجةٍ مئوية يغلي الماء عند سطح البحر؟', array['100', '0', '50', '200']),
  ('science:6m4n9w', '*', 'science', 'ما أصلب مادةٍ طبيعية؟', array['الألماس', 'الحديد', 'الذهب', 'الخشب']),
  ('science:j42451', '*', 'science', 'ما الجهاز الذي نرى به الأشياء الصغيرة جداً؟', array['المجهر', 'التلسكوب', 'البوصلة', 'الميزان']),
  ('science:psjvch', '*', 'science', 'ما الجهاز الذي نرصد به النجوم البعيدة؟', array['التلسكوب', 'المجهر', 'مكبّر الصوت', 'ميزان الحرارة']),
  ('science:nw33p4', '*', 'science', 'كم عظمةً تقريباً في جسم الإنسان البالغ؟', array['206', '100', '300', '50']),
  ('science:h707h4', '*', 'science', 'ما أكبر عضوٍ في جسم الإنسان؟', array['الجلد', 'القلب', 'الكبد', 'الدماغ']),
  ('science:ijujlr', '*', 'science', 'أي هذه الأشياء ينجذب إلى المغناطيس؟', array['مسمار حديد', 'ملعقة خشب', 'ورقة', 'كأس زجاج']),
  ('science:3qrvyw', '*', 'science', 'ماذا تُسمّى حالة الماء حين يصير بخاراً؟', array['الحالة الغازية', 'الحالة الصلبة', 'الحالة السائلة', 'الحالة الجليدية']),
  ('science:pd4fct', '*', 'science', 'ما المصدر الرئيسي للضوء والحرارة على الأرض؟', array['الشمس', 'القمر', 'البرق', 'النار']),
  ('science:8opzli', '*', 'science', 'ماذا تُسمّى الحيوانات التي تأكل النباتات فقط؟', array['آكلات العشب', 'آكلات اللحوم', 'آكلات كل شيء', 'المفترسات']),
  ('science:agboop', '*', 'science', 'ما الجزء من النبات الذي يمتصّ الماء من التربة؟', array['الجذر', 'الورقة', 'الزهرة', 'الثمرة']),
  ('science:cc6fm7', '*', 'science', 'ما الجهاز الذي نكتب به الحروف في الحاسوب؟', array['لوحة المفاتيح', 'الشاشة', 'السماعة', 'الطابعة']),
  ('science:k2w4ah', '*', 'science', 'ما الجهاز الذي يُخرج الأوراق المطبوعة من الحاسوب؟', array['الطابعة', 'الفأرة', 'الشاشة', 'الميكروفون']),
  ('science:pq5433', '*', 'science', 'ما الجزء الذي يُعدّ «عقل» الحاسوب ويعالج البيانات؟', array['المعالج', 'الشاشة', 'الفأرة', 'السماعة']),
  ('science:t5g3vx', '*', 'science', 'ما الذي يحتاجه الهاتف الذكي ليعمل بلا سلك؟', array['البطارية', 'الورق', 'الماء', 'الرمل']),
  ('science:vcqeh2', '*', 'science', 'ما القوّة التي تجعل الأشياء تسقط نحو الأرض؟', array['الجاذبية', 'الرياح', 'الضوء', 'الصوت']),
  ('science:wvmx9t', '*', 'science', 'من العالِم الذي اشتهر بقانون الجاذبية؟', array['إسحاق نيوتن', 'ألبرت أينشتاين', 'توماس إديسون', 'ابن الهيثم']),
  ('science:xip72e', '*', 'science', 'من العالِم المسلم الذي اشتهر بدراسة الضوء والإبصار؟', array['ابن الهيثم', 'ابن بطوطة', 'الخوارزمي', 'ابن خلدون']),
  ('science:ddwna5', '*', 'science', 'أيهما أسرع: الضوء أم الصوت أم الطائرة أم السيارة؟', array['الضوء', 'الصوت', 'الطائرة', 'السيارة']),
  ('science:r9hcsv', '*', 'science', 'ما الذي يدور حول الأرض ويضيء ليلاً بنور الشمس؟', array['القمر', 'المريخ', 'الشمس', 'النجوم']),
  ('science:5fczif', '*', 'science', 'كم ساعةً تقريباً تحتاج الأرض لتدور حول نفسها دورةً كاملة؟', array['24', '12', '365', '30'])
on conflict do nothing;

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

-- ┌──────────────────────────────────────────────────────────────
-- │ التحقّق — صفٌّ واحد يظهر في المحرّر
-- └──────────────────────────────────────────────────────────────

notify pgrst, 'reload schema';

select
  (select count(*) from pg_tables where schemaname = 'public') as public_tables,
  (select count(*) from information_schema.role_table_grants
     where table_schema = 'public' and grantee = 'service_role' and privilege_type = 'INSERT')
    as service_role_writable_tables,
  (select count(*) from information_schema.role_table_grants
     where table_schema = 'public' and grantee in ('anon', 'authenticated')
       and privilege_type <> 'SELECT')
    as anon_write_grants_expected_0,
  (select string_agg(distinct table_name, ', ' order by table_name)
     from information_schema.role_table_grants
     where table_schema = 'public' and grantee = 'anon' and privilege_type = 'SELECT')
    as anon_readable_expected_app_kv_created_quizzes_lesson_configs;
