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
