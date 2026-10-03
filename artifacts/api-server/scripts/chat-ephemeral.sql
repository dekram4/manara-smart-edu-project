-- ════════════════════════════════════════════════════════════════════
-- دردشةُ الصفّ: كنسٌ دوريٌّ احتياطي — اختياريّ.
--
-- ── لا يلزم لتعمل الميزة ──
-- الاختفاءُ بعد القراءة والحفظُ ٢٤ ساعة يعملان بنشر الخادم وحده: إيصالاتُ القراءة
-- والحفظ صفوفٌ في `interactions` (type = student_chat_receipt) بجانب الرسائل، والخادمُ
-- يحذف الرسالةَ ومقطعَها وإيصالاتِها حين يقرؤها كلُّ من أُرسلت إليه ولا يحفظها أحد، أو
-- حين يمضي عليها ٢٤ ساعةً بلا حفظٍ قائم.
--
-- وهذه الدالّةُ تكنس ما فات الخادمَ (صفٌّ لم يفتح أحدٌ دردشتَه بعد انتهاء عمر رسائله).
-- تُشغَّل مرّةً في محرّر SQL؛ وإن كان pg_cron مفعّلاً جُدولت كلَّ ربع ساعة.
-- ════════════════════════════════════════════════════════════════════

begin;

-- جدولُ الإيصالات القديم لم يعد يُستعمل.
drop table if exists public.student_chat_receipts;

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
  -- رسائلُ مضى عليها ٢٤ ساعةً ولا حفظَ قائماً لها.
  delete from public.interactions m
  where m.data->>'type' = 'student_chat'
    and m.updated_at < now() - interval '24 hours'
    and not exists (
      select 1 from public.interactions r
      where r.data->>'type' = 'student_chat_receipt'
        and r.data->>'messageId' = m.id
        and (r.data->>'savedUntil')::timestamptz > now()
    );
  get diagnostics v_messages = row_count;

  -- مقاطعُ لم تعد لها رسالة (والمقطعُ يُكتب قبل رسالته بلحظات: لا يُمسّ الحديث).
  delete from public.interactions v
  where v.data->>'type' = 'student_chat_voice'
    and v.updated_at < now() - interval '10 minutes'
    and not exists (
      select 1 from public.interactions m
      where m.data->>'type' = 'student_chat'
        and m.data->>'voiceId' = v.id
    );
  get diagnostics v_voices = row_count;

  -- إيصالاتٌ لم تعد لها رسالة.
  delete from public.interactions r
  where r.data->>'type' = 'student_chat_receipt'
    and not exists (
      select 1 from public.interactions m where m.id = r.data->>'messageId'
    );
  get diagnostics v_receipts = row_count;

  return jsonb_build_object('messages', v_messages, 'voices', v_voices, 'receipts', v_receipts);
end;
$$;

revoke all on function public.purge_student_chat() from public, anon, authenticated;
grant execute on function public.purge_student_chat() to service_role;

commit;

do $$
begin
  if exists (select 1 from pg_extension where extname = 'pg_cron') then
    perform cron.unschedule(jobid) from cron.job where jobname = 'purge-student-chat';
    perform cron.schedule('purge-student-chat', '*/15 * * * *', 'select public.purge_student_chat()');
  end if;
end $$;
