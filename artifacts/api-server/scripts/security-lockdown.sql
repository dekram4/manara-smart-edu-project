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
