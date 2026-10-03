-- ════════════════════════════════════════════════════════════════════
-- دردشةُ الصفّ: رسائلُ تختفي بعد قراءتها، وحفظٌ أقصاه ٢٤ ساعة.
--
-- يُشغَّل مرّةً واحدة في محرّر SQL في Supabase، قبل نشر الخادم أو بعده.
-- وقبل تشغيله تعمل الدردشةُ كما كانت (بلا اختفاءٍ ولا حفظ) — الخادمُ يكتشف غيابَ
-- الجدول ولا يتعطّل.
--
-- ── الفكرة ──
-- الرسائلُ والمقاطعُ كما هي في `interactions` (type = student_chat و
-- student_chat_voice). وهذا الجدولُ يقول لكل طالبٍ ولكل رسالة:
--   seen_at      — متى قرأها/سمعها (يُكتب حين يغادر شاشةَ الدردشة).
--   saved_until  — حفظها حتى متى؛ لا يتجاوز ٢٤ ساعةً من لحظة الحفظ.
--
-- والطالبُ لا يرى ما قرأه إلا إن حفظه. والرسالةُ تُحذف نهائياً (ومعها مقطعُها
-- وإيصالاتُها) حين يقرؤها كلُّ من أُرسلت إليه ولا يحفظها أحد، أو حين يمضي عليها
-- ٢٤ ساعةً ولا حفظَ قائماً لها. يحذف الخادمُ ذلك وهو يعمل، وهذه الدالّةُ تكنس ما فاته.
-- ════════════════════════════════════════════════════════════════════

begin;

create table if not exists public.student_chat_receipts (
  message_id text not null,
  student_id text not null,
  seen_at timestamptz,
  saved_until timestamptz,
  updated_at timestamptz not null default now(),
  primary key (message_id, student_id),
  -- الحفظُ لا يتجاوز ٢٤ ساعةً من آخر كتابة (والخادمُ يكتبه now() + 24h).
  constraint student_chat_receipts_saved_24h
    check (saved_until is null or saved_until <= updated_at + interval '24 hours 5 minutes')
);

create index if not exists student_chat_receipts_student_idx
  on public.student_chat_receipts (student_id);
create index if not exists student_chat_receipts_saved_idx
  on public.student_chat_receipts (saved_until)
  where saved_until is not null;

alter table public.student_chat_receipts enable row level security;
revoke all on table public.student_chat_receipts from public, anon, authenticated;
grant all on table public.student_chat_receipts to service_role;

comment on table public.student_chat_receipts is
  'إيصالاتُ دردشة الصفّ: من قرأ أيَّ رسالةٍ ومتى، ومن حفظها حتى متى (٢٤ ساعةً أقصى). يكتبها الخادم وحده.';

-- ── الكنس ──
-- يحذف: الرسائلَ التي مضى عليها ٢٤ ساعةً بلا حفظٍ قائم، والمقاطعَ التي لم تعد
-- لها رسالة، والإيصالاتِ التي لم تعد لها رسالة أو انتهى حفظُها بعد قراءتها.
create or replace function public.purge_student_chat()
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_messages int := 0;
  v_voices int := 0;
  v_receipts int := 0;
begin
  delete from public.interactions m
  where m.data->>'type' = 'student_chat'
    and m.updated_at < now() - interval '24 hours'
    and not exists (
      select 1 from public.student_chat_receipts r
      where r.message_id = m.id and r.saved_until > now()
    );
  get diagnostics v_messages = row_count;

  -- والمقطعُ يُكتب قبل رسالته بلحظات: لا يُحذف مقطعٌ عمرُه دقائق.
  delete from public.interactions v
  where v.data->>'type' = 'student_chat_voice'
    and v.updated_at < now() - interval '10 minutes'
    and not exists (
      select 1 from public.interactions m
      where m.data->>'type' = 'student_chat'
        and m.data->>'voiceId' = v.id
    );
  get diagnostics v_voices = row_count;

  delete from public.student_chat_receipts r
  where not exists (select 1 from public.interactions m where m.id = r.message_id);
  get diagnostics v_receipts = row_count;

  return jsonb_build_object('messages', v_messages, 'voices', v_voices, 'receipts', v_receipts);
end;
$$;

revoke all on function public.purge_student_chat() from public, anon, authenticated;
grant execute on function public.purge_student_chat() to service_role;

commit;

-- ── جدولةٌ كلَّ ربع ساعة، إن كان pg_cron مفعّلاً (Database → Extensions) ──
-- وبدونه يكفي ما يحذفه الخادم، ويُستدعى `purge_student_chat` منه أيضاً.
do $$
begin
  if exists (select 1 from pg_extension where extname = 'pg_cron') then
    perform cron.unschedule(jobid) from cron.job where jobname = 'purge-student-chat';
    perform cron.schedule('purge-student-chat', '*/15 * * * *', 'select public.purge_student_chat()');
  end if;
end $$;
