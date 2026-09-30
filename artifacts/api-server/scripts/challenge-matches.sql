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
