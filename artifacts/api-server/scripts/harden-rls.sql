-- ════════════════════════════════════════════════════════════════════════
--  تشديد سياسات RLS — منصة منارة
--  يُنفَّذ في Supabase SQL Editor
-- ════════════════════════════════════════════════════════════════════════
--
--  ما يعالجه:
--  كانت كل الجداول تحمل سياسة واحدة مفتوحة:
--      create policy "allow_all_<t>" on public.<t>
--        for all to anon, authenticated using (true) with check (true);
--  ومفتاح anon منشور في مستودع عام. أي شخص يملك المفتاح يقرأ ويكتب كل صف
--  في قاعدة البيانات — الطلاب، أولياء الأمور، الدرجات، الرسائل الخاصة.
--
-- ────────────────────────────────────────────────────────────────────────
--  ⚠️  اقرأ هذا قبل التنفيذ — السكريبت جزآن، والثاني له أثر على التطبيق
-- ────────────────────────────────────────────────────────────────────────
--
--  الجزء (أ): جداول لا يكتب فيها تطبيق الطالب مباشرةً إطلاقاً.
--             تشديدها **لا يكسر شيئاً**. نفّذه الآن بلا تردّد.
--
--  الجزء (ب): ثلاثة جداول يكتب فيها التطبيق مباشرةً بمفتاح anon:
--                students       ← الجواهر والخبرة والمستوى والسلسلة والشخصية
--                quiz_results   ← نتيجة كل اختبار يحلّه الطالب
--                interactions   ← تفاعلات الطالب
--
--             منع الكتابة عنها — وهو المطلوب أمنياً — **يوقف حفظ تقدّم
--             الطالب فوراً**: لن تُحفظ نتيجة اختبار، ولن تزيد جوهرة.
--
--             لذلك للجزء (ب) خياران، والافتراضي هو المنع الكامل كما طُلب.
--             إن لم تكن نقلت كتابات الطالب إلى خادم الـ API بعد، فعطّل
--             الخيار (ب-1) وفعّل (ب-2) مؤقتاً.
--
--  السبب الجذري الذي يبقى قائماً في الحالتين: مسار الدخول الأساسي للطالب
--  لا يستعمل مصادقة Supabase — يقرأ جدول `students` بدور anon — فلا يوجد
--  `auth.uid()` تُقصر به الصفوف على صاحبها. أي سماح بالكتابة لدور anon هو
--  سماح لأي حامل للمفتاح. الحل النهائي الوحيد هو توجيه كتابات الطالب عبر
--  خادم الـ API الذي يملك مفتاح الخدمة.
--
--  (يوجد مسار دخول ثانٍ بالبريد يستعمل `signInWithPassword` فتتوفّر فيه
--   جلسة حقيقية. جدول `profiles` وحده يستفيد منه، وسياستُه أدناه مقصورة
--   على صاحب الصف. أما بقية الجداول فيقرؤها الدوران معاً لأن المسار
--   الأساسي anon، ولا يمكن تقييدها بالصف قبل توحيد المصادقة.)
--
-- ════════════════════════════════════════════════════════════════════════

begin;

-- ────────────────────────────────────────────────────────────────────────
-- 0) إسقاط السياسات المفتوحة عن كل الجداول
-- ────────────────────────────────────────────────────────────────────────
do $$
declare t text;
begin
  foreach t in array array[
    'students','parents','teachers','lesson_configs','created_quizzes',
    'quiz_results','interactions','private_messages','public_messages',
    'certificates','app_kv','profiles'
  ]
  loop
    -- `profiles` قد لا يكون موجوداً في كل بيئة. بلا هذا الفحص يفشل
    -- `alter table` على جدول غائب فتسقط المعاملة كلها ولا يُنفَّذ شيء.
    if to_regclass(format('public.%I', t)) is null then
      raise notice 'تخطّي %: الجدول غير موجود.', t;
      continue;
    end if;
    execute format('alter table public.%I enable row level security;', t);
    execute format('drop policy if exists "allow_all_%s" on public.%I;', t, t);
    -- وإسقاط أي سياسة من تشغيل سابق لهذا السكريبت، ليكون قابلاً للإعادة.
    execute format('drop policy if exists "anon_read_%s"  on public.%I;', t, t);
    execute format('drop policy if exists "anon_write_%s" on public.%I;', t, t);
  end loop;
  drop policy if exists "auth_read_own_profile" on public.profiles;
end $$;

-- ملاحظة على `service_role`: يتجاوز RLS كلياً بحكم التصميم، فلا يحتاج
-- سياسات. إسقاط سياسات anon يترك القاعدة مفتوحة له وحده — وهو المقصود،
-- لأن خادم الـ API وحده يحمله.


-- ════════════════════════════════════════════════════════════════════════
--  الجزء (أ) — آمن التنفيذ الآن
-- ════════════════════════════════════════════════════════════════════════

-- ── teachers · parents ──────────────────────────────────────────────────
-- بيانات أشخاص بالغين وبيانات دخولهم. لا يقرؤها تطبيق الطالب ولا يكتبها.
-- لا سياسة anon إطلاقاً ⇒ لا قراءة ولا كتابة إلا عبر خادم الـ API.
-- (لا شيء يُكتب هنا: غياب السياسة هو المنع.)

-- ── private_messages ────────────────────────────────────────────────────
-- رسائل خاصة بين المعلم وولي الأمر. أخطر جدول على الخصوصية.
-- ممنوع على anon قراءةً وكتابةً.

-- ── certificates ────────────────────────────────────────────────────────
-- الشهادات تُصدَر من اللوحة لا من التطبيق. قراءة فقط ليعرضها التطبيق
-- للطالب، والإصدار عبر الخادم.
create policy "anon_read_certificates" on public.certificates
  for select to anon, authenticated using (true);

-- ── lesson_configs ──────────────────────────────────────────────────────
-- محتوى الدروس: نصوص وروابط فيديو ينشرها المعلم. التطبيق يقرؤها فقط.
create policy "anon_read_lesson_configs" on public.lesson_configs
  for select to anon, authenticated using (true);

-- ── created_quizzes ─────────────────────────────────────────────────────
-- الاختبارات المنشأة. التطبيق يقرؤها ليعرضها، ولا ينشئها.
--
-- تنبيه: الإجابات الصحيحة مخزّنة داخل `data`، فقراءتها تعني أن حاملَ
-- المفتاح يستطيع رؤيتها. علاجه الصحيح هو فصل الإجابات في عمود لا يُقرأ
-- من التطبيق وتصحيح الاختبار في الخادم — تغيير أوسع من هذا السكريبت.
create policy "anon_read_created_quizzes" on public.created_quizzes
  for select to anon, authenticated using (true);

-- ── public_messages ─────────────────────────────────────────────────────
-- لوحة الرسائل العامة. قراءة للجميع، والنشر من اللوحة عبر الخادم.
create policy "anon_read_public_messages" on public.public_messages
  for select to anon, authenticated using (true);

-- ── profiles ────────────────────────────────────────────────────────────
-- الجدول الوحيد هنا الذي يقبل تقييداً حقيقياً على مستوى الصف.
--
-- مسار الدخول الأساسي يقرأ جدول `students` بدور anon بلا مصادقة، لكن
-- `student_auth_service.dart` يسلك مساراً ثانياً عندما يحتوي اسم المستخدم
-- على «@»: `signInWithPassword` ثم قراءة `profiles`. في هذا المسار وحده
-- توجد جلسة حقيقية، فيتوفّر `auth.uid()`.
--
-- ولذلك لا نمنح anon شيئاً هنا، ونمنح المُصادَق صفَّه هو فقط — لا كل
-- الصفوف. هذا هو التقييد الذي تعذّر على بقية الجداول.
do $$
begin
  if to_regclass('public.profiles') is null then
    raise notice 'تخطّي profiles: الجدول غير موجود.';
  else
    -- التحويل إلى نص في الطرفين مقصود: `auth.uid()` من نوع uuid، وعمود
    -- `id` هنا قد يكون uuid أو text حسب كيفية إنشاء الجدول. المقارنة
    -- المباشرة تفشل بخطأ نوع إن اختلفا، وهذه تعمل في الحالتين.
    create policy "auth_read_own_profile" on public.profiles
      for select to authenticated using (auth.uid()::text = id::text);
  end if;
end $$;

-- ── app_kv ──────────────────────────────────────────────────────────────
-- خزانة مفاتيح/قيم مختلطة الحساسية:
--   الشجرة الأكاديمية (يحتاجها التطبيق) بجانب إعدادات المشرف والصلاحيات
--   والتقارير (لا يحتاجها ويجب ألا يراها).
-- لذلك القراءة مقيَّدة بقائمة مفاتيح صريحة لا مفتوحة على الجدول.
create policy "anon_read_app_kv" on public.app_kv
  for select to anon, authenticated
  using (
    key in (
      'smartEdu_grades',
      'smartEdu_subjects',
      'smartEdu_terms',
      'smartEdu_atrams',
      'smartEdu_units',
      'smartEdu_hierarchicalConfigs',
      'smartEdu_gradeConfigs',
      'smartEdu_videos',
      'smartEdu_deletedVideos',
      'smartEdu_deletedLessons',
      'smartEdu_deletedQuizzes',
      -- يقرؤه التطبيق فعلاً في student_content_service.dart لتحميل أسئلة
      -- الاختبار. كان مستثنى في أول صياغة لهذا السكريبت، فكان تنفيذه يُفرغ
      -- كل اختبار من أسئلته بصمت. وحَجْبه لا يحمي شيئاً ما دام
      -- `created_quizzes` مقروءاً وفيه الإجابات نفسها — العلاج الحقيقي
      -- تصحيحُ الاختبار في الخادم، لا إخفاء المفتاح.
      'smartEdu_quizQuestions'
    )
  );
-- المستثناة عمداً: smartEdu_adminSettings · smartEdu_permissions ·
-- smartEdu_permissionPackages · smartEdu_reports


-- ════════════════════════════════════════════════════════════════════════
--  الجزء (ب) — يمسّ حفظ تقدّم الطالب
-- ════════════════════════════════════════════════════════════════════════

-- ── students ────────────────────────────────────────────────────────────
-- يقرؤه التطبيق ليعرض الجواهر والخبرة والمستوى.
--
-- تنبيه: الصف يحمل `password` داخل `data`. القراءة المفتوحة تكشف تجزئة
-- كلمة المرور. علاجه نقلها إلى عمود منفصل محجوب، وهو خارج نطاق هذا
-- السكريبت — لكن اعلمه.
create policy "anon_read_students" on public.students
  for select to anon, authenticated using (true);

-- ── quiz_results ────────────────────────────────────────────────────────
-- يقرؤه التطبيق ليعرض للطالب نتائجه السابقة.
create policy "anon_read_quiz_results" on public.quiz_results
  for select to anon, authenticated using (true);

-- ── interactions ────────────────────────────────────────────────────────
create policy "anon_read_interactions" on public.interactions
  for select to anon, authenticated using (true);


-- ┌────────────────────────────────────────────────────────────────────┐
-- │ (ب-1) المنع الكامل للكتابة — المطلوب أمنياً، وهو الفعّال الآن.      │
-- │                                                                     │
-- │ لا توجد سياسة كتابة لدور anon أعلاه، وهذا كافٍ: RLS يمنع كل ما لا   │
-- │ تسمح به سياسة صراحةً.                                               │
-- │                                                                     │
-- │ ⚠️ أثره: تطبيق الطالب سيتوقف عن حفظ نتائج الاختبارات والجواهر       │
-- │    والخبرة والشخصية حتى تُوجَّه هذه الكتابات عبر خادم الـ API.        │
-- └────────────────────────────────────────────────────────────────────┘

-- ┌────────────────────────────────────────────────────────────────────┐
-- │ (ب-2) بديل انتقالي — فعّله فقط إن لم تكن نقلت الكتابات بعد.          │
-- │                                                                     │
-- │ أزل التعليق عن الكتل الثلاث أدناه. يسمح بالتحديث والإضافة دون       │
-- │ الحذف، فيمنع محو السجلات ويُبقي التطبيق عاملاً.                      │
-- │                                                                     │
-- │ ⚠️ ليس حلاً: حاملُ المفتاح يبقى قادراً على تعديل درجات أي طالب.      │
-- │    مرحلة مؤقتة لا محطة نهائية.                                      │
-- └────────────────────────────────────────────────────────────────────┘
--
-- create policy "anon_write_students" on public.students
--   for update to anon, authenticated using (true) with check (true);
--
-- create policy "anon_write_quiz_results" on public.quiz_results
--   for insert to anon, authenticated with check (true);
--
-- create policy "anon_write_interactions" on public.interactions
--   for insert to anon, authenticated with check (true);


commit;


-- ════════════════════════════════════════════════════════════════════════
--  التحقّق بعد التنفيذ — شغّله وراجع الناتج
-- ════════════════════════════════════════════════════════════════════════
--
-- 1) لم تبقَ سياسة مفتوحة:
select tablename, policyname, cmd, roles
from pg_policies
where schemaname = 'public' and policyname like 'allow_all%';
-- المتوقّع: صفر صفوف.

-- 2) السياسات الفعلية الآن:
select tablename,
       policyname,
       cmd,
       array_to_string(roles, ',') as roles
from pg_policies
where schemaname = 'public'
order by tablename, cmd;
-- المتوقّع: سطور select لدور anon فقط، ولا سطر insert/update/delete
--           ما لم تكن فعّلت (ب-2).

-- 3) RLS مفعّل على كل جدول:
select relname as table_name, relrowsecurity as rls_enabled
from pg_class
where relnamespace = 'public'::regnamespace
  and relkind = 'r'
  and relname in (
    'students','parents','teachers','lesson_configs','created_quizzes',
    'quiz_results','interactions','private_messages','public_messages',
    'certificates','app_kv','profiles'
  )
order by relname;
-- المتوقّع: rls_enabled = true في كل سطر.
