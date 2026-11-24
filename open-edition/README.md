# النسخة المفتوحة من منارة (`manara-open-app`)

نسخةٌ مستقلّة من المنصة يديرها حسابُ معلّمٍ واحد هو **«معلم الروضة داود سيد»**،
ويدخلها الطلابُ بأسمائهم وحدها، بلا اسم مستخدمٍ ولا كلمة مرور. بياناتُها كلُّها
في مشروع Supabase المستقلّ `manara-open-app`.

## البنية: كودٌ واحد ونشرٌ ثانٍ

| | النسخة الحالية | النسخة المفتوحة |
|---|---|---|
| القاعدة | المشروع القديم | `manara-open-app` (`yvvgvbwokclinsiabmzx`) |
| خدمة Railway | الحالية، **لا تُمسّ** | خدمةٌ **جديدة** من المستودع نفسه |
| المتغيّر `MANARA_EDITION` | غائب ← `standard` | `open` |
| الويب | شاشةُ الأدوار الثلاثة | بوابةُ المعلم الوحيد |
| تطبيق الطالب | `com.manara.student` | `com.manara.open` «منارة المفتوحة» |
| بناءُ APK | `build-student-apk.yml` | `build-open-apk.yml` (يدوي فقط) |
| الإصدار | `v1.1.x` (Latest) | `open-v1.1.x` (ليس Latest أبداً) |

والعزلُ يتحقّق من البيئة: الخادمُ لا يعرف إلا القاعدةَ التي في متغيّرات خدمته
(`SUPABASE_URL` و`SUPABASE_SERVICE_ROLE_KEY`). فخدمةُ النسخة المفتوحة لا تحمل إلا
مفاتيحَ `manara-open-app`، ولا يجتمع المفتاحان في أيّ مكان. وبلا `MANARA_EDITION`
لا تعمل أيُّ إضافة: الحارسُ يمرّر كلَّ طلب، و`/api/open/student` يردّ 404.

### ما أُضيف إلى الكود (لا يعمل إلا في الوضع المفتوح)

- **الخادم:** `artifacts/api-server/src/lib/edition.ts` و`src/routes/openEdition.ts`:
  - `GET /api/edition` يعيد الوضع، واسمَ المعلم، وصفوفه.
  - الحارس يغلق بوابة المشرف، وبوابة ولي الأمر، وحسابات العرض.
  - `POST /api/open/student` يُنشئ حساب الطالب في صفّ المعلم، بحدّ 5 حسابات في الدقيقة لكل عنوان.
- **الويب:** `artifacts/manara/src/edition.ts`، وفي `App.tsx` تحلّ لوحةُ المعلم الوحيد محلّ شاشة الأدوار.
- **التطبيق:**
  - `lib/src/config/edition.dart`، وقيمته `false` ثابتةً عند البناء في التطبيق الحالي.
  - `services/open_edition_service.dart` و`screens/open_entry_screen.dart`: بابُ الدخول بالاسم وحده، كتابةً أو بالصوت.
  - في Android يأتي `applicationId` واسمُ التطبيق من `MANARA_APP_ID` و`MANARA_APP_LABEL`. بلا هذين المتغيّرين يبقيان كما كانا.

## الإعداد (مرّةً واحدة)

### ١. قاعدة البيانات `manara-open-app`
1. افتح Supabase، ثم مشروع **manara-open-app**، ثم **SQL Editor**، ثم **New query**.
2. الصق `open-edition/sql/01-schema.sql` كاملاً وشغّله بـ **Run**. يُعاد تشغيله بلا ضرر.
3. يجب أن يظهر صفُّ التحقّق بهذه القيم:
   - `anon_write_grants_expected_0 = 0`
   - `anon_readable… = app_kv, created_quizzes, lesson_configs`

> يُعاد توليده من سكربتات الخادم بـ `node open-edition/scripts/build-schema-sql.mjs`.
>
> **جداولُ موجودةٌ من قبل:** أوّلُ جزءٍ فيه (`sql/parts/align-existing.sql`) يواءمها قبل أيّ شيء:
> - يحوّل الأنواع المختلفة، مثل `text` إلى `jsonb` و`int8` إلى `text`، بلا فقدٍ للبيانات.
> - يضيف الأعمدة الناقصة، ويضع المفتاح الأساسي على عموده الصحيح، مثل `app_kv.key`.
>
> وتُطبع كلُّ مواءمةٍ في المحرّر سطراً يبدأ بـ `manara:`.

### ٢. استنساخ المعلم
بعد ضبط `.env.open` في جذر المستودع (القالب `open-edition/.env.open.example`):

```bash
node open-edition/scripts/clone-teacher.mjs --dry     # ملخّصٌ فقط، بلا ملف وبلا كتابة
node open-edition/scripts/clone-teacher.mjs --apply   # يكتب في manara-open-app مباشرة
```

- **القاعدة القديمة:** طلباتُ قراءةٍ فقط (`GET`). عميلُها يرفض أيَّ طلبٍ آخر قبل أن يخرج.
- **مع التطابق:** إن تطابق `OLD_SUPABASE_URL` و`SUPABASE_URL` يتوقّف السكربت قبل أيّ شيء.
- **بلا `--apply`:** يُكتب `open-edition/out/seed-teacher.sql` (مستثنى من git) لتلصقه في SQL Editor بدلاً من الكتابة المباشرة.
- **ما يُنسخ** (كلُّه مما يملكه «داود سيد اكرام» وحده، بهويةٍ جديدة):
  - المعلم بمعرّف `teacher_open_kg_dawood` واسم «معلم الروضة داود سيد»، بنفس اسم الدخول وكلمة المرور.
  - الدروس بنصوصها وفيديوهاتها وبنوك تحدّيها وألعاب مذاكرتها، والاختبارات بأسئلتها.
  - الشجرة الأكاديمية وقوائمها، وفيديوهات الدروس، وصلاحيات البطاقات، وحزمة صلاحياته، والإعدادات العامّة.
  - السينما، وألعاب الترفيه، وأسئلة المبارزة الخاصة به مع البنك العام.
- **التكرار:** إعادةُ التشغيل تُحدِّث السجلات ولا تكرّرها.

### ٣. خدمة Railway الجديدة
1. في Railway أنشئ خدمةً جديدة (**New → GitHub Repo → هذا المستودع**). لا تفتح الخدمة الحالية ولا تعدّلها.
2. **Settings → Config-as-code path** = `open-edition/railway.json`. البناء نفسه: Dockerfile نفسه ونفس فحص الصحة.
3. **Variables** للخدمة الجديدة وحدها:
   ```
   MANARA_EDITION=open
   OPEN_TEACHER_ID=teacher_open_kg_dawood
   OPEN_TEACHER_USERNAME=<اسم دخول المعلم>      # اختياري: حارسٌ ثانٍ
   SUPABASE_URL=https://yvvgvbwokclinsiabmzx.supabase.co
   SUPABASE_ANON_KEY=<المفتاح العام للجديدة>
   SUPABASE_SERVICE_ROLE_KEY=<مفتاح الخدمة للجديدة>
   SESSION_SECRET=<قيمةٌ عشوائيةٌ جديدة، غيرُ قيمة الخدمة الحالية>
   ```
   ومفاتيحُ الذكاء الاصطناعي (`GEMINI_API_KEY`…) إن أردت ميزاته في النسخة المفتوحة.
   **لا تنسخ** `ADMIN_USERNAME`/`ADMIN_PASSWORD`، فبوابةُ المشرف مغلقة هنا.
4. **Networking → Generate Domain**، فيكون رابط بوابة المعلم: `https://<النطاق>/`.

### ٤. تطبيق الطالب المفتوح
1. في أسرار المستودع على GitHub أضف:
   - `OPEN_SUPABASE_URL`
   - `OPEN_SUPABASE_ANON_KEY`
   - `OPEN_API_BASE_URL`، وقيمته نطاقُ الخدمة الجديدة.
2. شغّل البناء من **Actions → Build Open Edition APK → Run workflow**. لا يظهر الزرّ إلا بعد أن يصل ملفّ سير العمل إلى `main`.
3. الناتج إصدار `open-v<النسخة>` فيه `manara-open.apk`.

## التحقّق

```bash
node open-edition/scripts/verify-open.mjs                          # القاعدتان
node open-edition/scripts/verify-open.mjs --api https://<النطاق>   # والخادمُ الجديد
```

يفحص السكربت:
- الدروس مقروءةٌ بالمفتاح العام، والكتابةُ به مرفوضة، وسجلاتُ الطلاب غيرُ مقروءة.
- في القاعدة الجديدة معلّمٌ واحد باسمه، وكلُّ الدروس والاختبارات والشجرة له.
- في القديمة: المعلمُ الأصلي باقٍ، ودروسُه كما هي، ولا أثر فيها للحساب الجديد.
- مع `--api`: الخادم في وضع `open` وجاهز، وبوابتا المشرف ووليّ الأمر تردّان 404.

ويدوياً:
1. **الويب:** افتح نطاق الخدمة الجديدة، فتظهر «النسخة المفتوحة — بوابة معلم الروضة داود سيد» وتحتها دخول المعلم. ادخل، وعدّل درساً أو أضف فيديو.
2. **التطبيق:** ثبّت `manara-open.apk`، واكتب اسماً أو قله بالميكروفون، ثم «ابدأ التعلّم». تظهر الروضة ومحتواها، والتعديل الذي أجريته على الويب يظهر فيها.
3. **النسخة القديمة:**
   - افتح `https://manara-aiedu.com` فتظهر شاشة الأدوار الثلاثة كما كانت.
   - يعيد `https://manara-aiedu.com/api/edition` القيمة `{"edition":"standard"}`.
   - التطبيق الحالي يدخل كما كان.

## التراجع (Rollback)

حسب المستوى، والأسرع أوّلاً:

1. **إيقاف النسخة المفتوحة فوراً:** في Railway افتح الخدمة الجديدة، ثم **Settings → Delete Service**، أو احذف `MANARA_EDITION` منها فتصير نسخةً عادية على قاعدة `manara-open-app`.
2. **إيقاف التطبيق المفتوح:** احذف إصدار `open-v…` من GitHub Releases، ثم احذف الأسرار `OPEN_*`.
3. **تفريغ القاعدة الجديدة:** شغّل في SQL Editor لمشروع **manara-open-app** وحده:
   ```sql
   truncate public.teachers, public.lesson_configs, public.created_quizzes, public.app_kv,
            public.students, public.cinema_videos, public.entertainment_games, public.duel_questions;
   ```
   أو احذف المشروع كلَّه من Supabase.
4. **إزالة الكود:** `git revert <commit>` لالتزام النسخة المفتوحة (أو `git revert -m 1 <merge>` إن دُمج).
   - **قبل الدمج:** لا شيء يلزم. فرعُ `feature/open-edition` لا ينشره Railway، ولا يبني منه سيرُ عمل APK الحالي.
   - **بعد الدمج:** الكود في الخدمة الحالية خاملٌ ما دام `MANARA_EDITION` غائباً.

لا تحتاج أيُّ خطوةٍ من هذه إلى لمس القاعدة القديمة أو الخدمة الحالية.
