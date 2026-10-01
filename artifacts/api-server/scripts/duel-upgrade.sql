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
