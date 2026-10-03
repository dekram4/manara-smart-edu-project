-- ════════════════════════════════════════════════════════════════════
-- التحدي الجماعي: لاعبٌ يدعو زميلاً أو أكثر، ويبدأ النزالُ بمن وافق.
--
-- يُشغَّل مرّةً واحدة في محرّر SQL في Supabase، قبل نشر الخادم الجديد.
--
-- ── القواعد (يحكم بها الخادم — roomStateOf في api-server/src/lib/duel.ts) ──
--   • مهلةُ الدعوة ٢٠ ثانية من إنشائها.
--   • ردّ الجميعُ قبلها: يبدأ النزالُ فوراً (بعد عدٍّ ٤ ثوانٍ) بمن وافق.
--   • انتهت المهلة: من لم يردّ يُستبعد، ويبدأ بمن وافق — إن وافق واحدٌ على الأقل.
--   • لم يوافق أحد: تُلغى المباراة.
--   • أوّلُ إجابةٍ صحيحةٍ تكسب السؤال (record_duel_answer — لم تتغيّر)،
--     وصاحبُ المركز الأول وحده ينال الجواهر الخمس، مرّةً لكل لعبةٍ في الدرس.
--
-- و`challenge_matches.guest_id` يبقى أوّلَ مدعوّ: للتوافق مع ما سبق.
-- ════════════════════════════════════════════════════════════════════

begin;

create table if not exists public.challenge_match_players (
  match_id text not null
    references public.challenge_matches (id) on delete cascade,
  student_id text not null,
  role text not null default 'guest',
  invited_at timestamptz not null default now(),
  -- متى ردّ المدعوّ، وبماذا. للداعي: يُكتب عند الإنشاء (accepted = true).
  responded_at timestamptz,
  accepted boolean,
  -- النتيجةُ والمركزُ بعد الحسم.
  score int,
  rank int,
  primary key (match_id, student_id),
  constraint challenge_match_players_role check (role in ('host', 'guest'))
);

create index if not exists challenge_match_players_student_idx
  on public.challenge_match_players (student_id);

alter table public.challenge_match_players enable row level security;
revoke all on table public.challenge_match_players from public, anon, authenticated;
grant all on table public.challenge_match_players to service_role;

comment on table public.challenge_match_players is
  'لاعبو مباراة التحدي: الداعي ومن دعاهم، وردُّ كلٍّ ومتى، ونتيجتُه ومركزُه. يكتبها الخادم وحده.';

commit;
