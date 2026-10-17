-- مولَّدٌ بـ scripts/build-apply-sql.mjs — لا يُعدَّل باليد.
-- يُلصق كاملاً في محرّر SQL في Supabase ويُشغَّل مرّةً واحدة؛ ويُعاد تشغيله بأمان.
-- ‏قبل اللصق: محرّرٌ فارغ، ولا تحديدَ لجزءٍ من النصّ (المحرّر يشغّل المحدَّد وحده).

-- ┌──────────────────────────────────────────────────────────────
-- │ security-lockdown.sql
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
-- │ ai-qa-cache-vectors.sql
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
-- │ duel-knowledge-bank.sql
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
-- │ التحقّق
-- └──────────────────────────────────────────────────────────────

notify pgrst, 'reload schema';

select
  (select count(*) from public.duel_questions
     where category in ('culture', 'sports', 'geography', 'history', 'science'))
    as knowledge_questions_expected_146,
  (select count(*) from pg_proc p join pg_namespace n on n.oid = p.pronamespace
     where n.nspname = 'public' and p.proname = 'match_qa_cache'
       and pg_get_function_identity_arguments(p.oid) like 'query_embedding vector%')
    as match_qa_cache_expected_1,
  (select count(*) from information_schema.role_table_grants
     where table_schema = 'public' and grantee in ('anon', 'authenticated')
       and privilege_type <> 'SELECT')
    as anon_write_grants_expected_0,
  (select string_agg(distinct table_name, ', ' order by table_name)
     from information_schema.role_table_grants
     where table_schema = 'public' and grantee = 'anon' and privilege_type = 'SELECT')
    as anon_readable_expected_app_kv_created_quizzes_lesson_configs;
