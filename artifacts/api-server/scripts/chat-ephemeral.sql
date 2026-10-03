-- ════════════════════════════════════════════════════════════════════
-- دردشةُ الصفّ: تنظيفٌ يدويٌّ لمرّةٍ واحدة للرسائل والمقاطع القديمة العالقة.
--
-- ── لا يلزم لتعمل الميزة ──
-- الخادمُ ينظّف وحده كلما فُتحت دردشةُ صفّ: يحذف الرسالةَ (ومقطعَها وإيصالاتِها) حين
-- يستهلكها كلُّ أطرافها، أو حين يراها المستلمون ويمضي عليها ٢٤ ساعة، أو إن كانت
-- أقدمَ من نظام الإيصالات بلا أثرٍ ومضى عليها ٢٤ ساعة، أو مضى عليها ٧ أيام —
-- ما لم تكن محفوظةً بـ 📌. انظر api-server/src/lib/chatLifecycle.ts.
--
-- وهذا لتنظيف كلِّ الصفوف الآن دفعةً واحدة: يحذف كلَّ رسالةٍ مضى عليها ٢٤ ساعة ولا
-- حفظَ قائماً لها، ثم المقاطعَ والإيصالاتِ التي لم تعد لها رسالة.
-- يُشغَّل يدوياً في محرّر SQL. لا يُجدوَل: رسالةٌ خاصّةٌ لم يرها مستلمُها تبقى أسبوعاً.
-- ════════════════════════════════════════════════════════════════════

begin;

-- جدولٌ قديمٌ لم يعد يُستعمل، وجدولةٌ قديمة إن وُجدت.
drop table if exists public.student_chat_receipts;
do $$
begin
  if exists (select 1 from pg_extension where extname = 'pg_cron') then
    perform cron.unschedule(jobid) from cron.job where jobname = 'purge-student-chat';
  end if;
end $$;
drop function if exists public.purge_student_chat();

-- رسائلُ مضى عليها ٢٤ ساعةً ولا حفظَ قائماً لها.
delete from public.interactions m
where m.data->>'type' = 'student_chat'
  and m.updated_at < now() - interval '24 hours'
  and not exists (
    select 1 from public.interactions r
    where r.data->>'type' = 'student_chat_receipt'
      and r.data->>'messageId' = m.id
      and nullif(r.data->>'savedUntil', '')::timestamptz > now()
  );

-- مقاطعُ لم تعد لها رسالة.
delete from public.interactions v
where v.data->>'type' = 'student_chat_voice'
  and v.updated_at < now() - interval '10 minutes'
  and not exists (
    select 1 from public.interactions m
    where m.data->>'type' = 'student_chat'
      and m.data->>'voiceId' = v.id
  );

-- إيصالاتٌ لم تعد لها رسالة.
delete from public.interactions r
where r.data->>'type' = 'student_chat_receipt'
  and not exists (select 1 from public.interactions m where m.id = r.data->>'messageId');

commit;

-- ما بقي بعد التنظيف:
select data->>'type' as type, count(*) from public.interactions
where data->>'type' in ('student_chat', 'student_chat_voice', 'student_chat_receipt')
group by 1;
