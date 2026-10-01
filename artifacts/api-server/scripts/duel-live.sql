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
