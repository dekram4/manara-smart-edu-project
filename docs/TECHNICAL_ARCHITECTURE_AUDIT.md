# منارة المعرفة — التقرير التقني المعماري والتدقيقي الشامل

> **Full Technical Architecture & Audit Report**
> النسخة: 2.0 · التاريخ: 17 أكتوبر 2026 · الفرع: `main` · تطبيق الطالب: v1.1.0
> مصدر كل رقمٍ هنا: الكود في المستودع، وفحصٌ حيّ لبيئة الإنتاج (Railway) وقاعدة البيانات (Supabase) وGitHub بتاريخ التقرير.
> لا يحتوي هذا الملف على أيّ مفتاحٍ أو كلمة مرور أو بيانات شخصية.

---

## المحتويات

0. [الملخّص التنفيذي](#0-الملخّص-التنفيذي)
1. [لغات البرمجة وأطر العمل](#1-لغات-البرمجة-وأطر-العمل)
2. [هيكلية المستودع](#2-هيكلية-المستودع)
3. [المعمارية وتدفّق البيانات](#3-المعمارية-وتدفّق-البيانات)
4. [تطبيق الطالب (Android)](#4-تطبيق-الطالب-android)
5. [لوحات الويب](#5-لوحات-الويب)
6. [خادم الـ API](#6-خادم-الـ-api)
7. [النقاط البرمجية (Endpoints)](#7-النقاط-البرمجية-endpoints)
8. [قاعدة البيانات](#8-قاعدة-البيانات)
9. [الذكاء الاصطناعي](#9-الذكاء-الاصطناعي)
10. [الأمان والتشفير](#10-الأمان-والتشفير)
11. [البنية التحتية والنشر (CI/CD)](#11-البنية-التحتية-والنشر-cicd)
12. [الاختبار والجودة](#12-الاختبار-والجودة)
13. [نتائج التدقيق الحيّ](#13-نتائج-التدقيق-الحيّ)
14. [سجلّ المعالجة](#14-سجلّ-المعالجة)
15. [التشغيل والصيانة](#15-التشغيل-والصيانة)

---

## 0. الملخّص التنفيذي

منارة المعرفة منصّةٌ تعليمية للمرحلة الابتدائية بأربعة أدوار (مشرف، معلم، وليّ أمر، طالب). تتكوّن من:

| المكوّن | التقنية | الحالة |
|---|---|---|
| تطبيق الطالب | Flutter / Dart — Android (وWindows) | v1.1.0 · موقَّع بمفتاح الإصدار · `com.manara.student` |
| لوحات المشرف والمعلم ووليّ الأمر | React 19 + TypeScript | تعمل على `manara-aiedu.com` |
| خادم API | Node.js 20 + Express 5 + TypeScript | يعمل على Railway · صفر أخطاء |
| قاعدة البيانات | Supabase (PostgreSQL + pgvector + Storage) | محكمة: المفتاح العام لا يقرأ بيانات أشخاص ولا يكتب |
| الذكاء الاصطناعي | Google Gemini | حل المسائل، والتحدي، والمذاكرة، وتوليد الاختبارات |

**نتيجة التدقيق:** لا ثغرة مفتوحة ولا مهمّة معلّقة. كل النقاط التي رصدها التقرير السابق عولجت وتحقّق منها حيّاً (القسم 13 والقسم 14).

| المؤشّر | القيمة |
|---|---|
| جداول يقرؤها المفتاح العام | 3 من 22 (محتوى تعليمي فقط) |
| جداول يكتب فيها المفتاح العام | 0 |
| كلمات مرور بصيغة scrypt | 6 / 6 |
| اختبارات تطبيق الطالب | 691 / 691 |
| اختبارات الخادم | 291 / 291 |
| الخادم الحيّ | `/api/healthz` ← 200 في ~0.36 ث |

---

## 1. لغات البرمجة وأطر العمل

### 1.1 اللغات

| المكوّن | المسار | اللغة | الحجم التقريبي |
|---|---|---|---|
| تطبيق الطالب | `artifacts/manara-student-flutter` | **Dart** (Flutter) | ~47,000 سطر · 182 ملفاً |
| لوحات الويب | `artifacts/manara` | **TypeScript + TSX** (React) | ~34,000 سطر |
| خادم API | `artifacts/api-server` | **TypeScript** (Node.js) | ~16,000 سطر |
| نماذج تصميم داخلية | `artifacts/mockup-sandbox` | TypeScript + TSX | ~6,300 سطر (غير منشورة) |
| مخطّطات قاعدة البيانات | `artifacts/api-server/scripts/*.sql` | SQL (PostgreSQL / PL/pgSQL) | 19 ملفاً |
| غلاف أندرويد | `android/app/src/main/kotlin/com/manara/student/MainActivity.kt` | Kotlin | ملفٌّ واحد (نقطة دخول Flutter) |

> **لا Java ولا PHP ولا Laravel** في المشروع.

### 1.2 أطر العمل والمكتبات

**تطبيق الطالب**

| الحزمة | الإصدار | الدور |
|---|---|---|
| Flutter SDK / Dart | 3.44.8 / ≥3.5 | الواجهة والمنطق (Material 3) |
| `supabase_flutter` | ^2.8.0 | قراءة المحتوى التعليمي، وقنوات البثّ الحيّ للمبارزة |
| `http` | ^1.2.2 | الاتصال بخادم الـ API |
| `flutter_animate` · `confetti` | ^4.5.2 · ^0.8.0 | الحركة وتأثيرات «لمسة» |
| `flutter_tts` · `speech_to_text` · `record` | ^4.2.0 · ^7.0.0 · ^5.1.2 | النطق والإملاء والرسائل الصوتية |
| `media_kit` · `video_player` · `youtube_player_iframe` | ^1.2.6 · 2.10.0 · ^6.0.2 | الفيديو والسينما |
| `flutter_inappwebview` | ^6.1.5 | الألعاب التعليمية المضمّنة |
| `image_picker` · `permission_handler` | ^1.1.2 · ^11.3.1 | تصوير المسائل والأذونات |
| `audioplayers` · `shared_preferences` · `google_fonts` · `url_launcher` | — | المؤثرات، والإعدادات المحلّية، والخطوط، والروابط |

**لوحات الويب**

| الحزمة | الإصدار |
|---|---|
| React · React DOM | 19.1.0 |
| Vite · Tailwind CSS | 7.3 · 4.1 |
| Radix UI (27 حزمة) · lucide-react | — · 0.545 |
| framer-motion · three.js / @react-three/fiber · tsparticles | 12.42 · 0.185 / 9.7 |
| TanStack Query · wouter · react-hook-form · zod · recharts | 5.9 · 3.3 · 7.5 · 3.25 · 2.15 |
| @supabase/supabase-js | ^2.112 |

**خادم API**

| الحزمة | الإصدار | الدور |
|---|---|---|
| Node.js | 20 (Debian bookworm-slim) | بيئة التشغيل |
| Express | 5.2 | المسارات |
| express-rate-limit | 8.7 | تحديد المعدّل |
| pino · pino-http | 9.14 · 10.5 | السجلات المنظّمة |
| cookie-parser · cors | 1.4 · 2.8 | الجلسات والأصول المسموحة |
| esbuild | 0.27.3 | حزم الخادم في `dist/index.mjs` |
| `node:crypto` | مدمج | scrypt وHMAC-SHA256 وSHA-256 |

**المستودع:** pnpm workspaces (10.34.5) · TypeScript 5.9. لا ORM: الخادم يتعامل مع Supabase عبر PostgREST مباشرة.

---

## 2. هيكلية المستودع

```
manara-smart-edu-project/
├── artifacts/
│   ├── api-server/            خادم API (Express + TypeScript)
│   │   ├── src/
│   │   │   ├── app.ts         الإعداد: CORS، حدود الأجسام، تقديم الويب
│   │   │   ├── routes/        15 ملفَّ مسارات (القسم 7)
│   │   │   ├── middleware/    adminAuth، studentAuth، rateLimiter
│   │   │   └── lib/           المنطق النقيّ: passwords، studentAccess، solverPolicy،
│   │   │                      embeddings، knowledgeBank، duelQuestions، appSettings…
│   │   │       └── __tests__/ 23 ملفَّ اختبار (node --test)
│   │   ├── scripts/           مخطّطات SQL وسكربتات الصيانة (القسم 15)
│   │   └── build.mjs          بناء esbuild
│   ├── manara/                لوحات الويب (React)
│   │   └── src/pages/{admin,teacher,parent,shared}/ + RoleSelection.tsx
│   ├── manara-student-flutter/ تطبيق الطالب (Flutter)
│   │   ├── lib/src/{screens,services,widgets,models,l10n,theme,config}/
│   │   ├── android/           إعداد Gradle والتوقيع
│   │   └── test/              73 ملفَّ اختبار
│   └── mockup-sandbox/        نماذج تصميم داخلية (لا تُنشر)
├── lib/                       حزم مشتركة (db، api-spec، api-zod، api-client-react)
├── docs/                      هذا التقرير
├── .github/workflows/         بناء APK وبناء Windows
├── Dockerfile · railway.json  النشر على Railway
└── vercel.json                إيقاف نشر Vercel التلقائي
```

---

## 3. المعمارية وتدفّق البيانات

### 3.1 الصورة العامة

```
┌────────────────────┐   Bearer HMAC token    ┌──────────────────────────────┐
│ تطبيق الطالب        │ ─────────────────────▶ │  Railway: خدمة manara-platform │
│ Flutter (Android)  │                        │  Express API  +  واجهة الويب  │
└─────────┬──────────┘                        └──────┬──────────────┬────────┘
          │ المفتاح العام: قراءة محتوى               │ service role  │ HTTPS
          │ تعليمي فقط + قنوات بثّ المبارزة           ▼               ▼
          │                                  ┌──────────────┐  ┌──────────────┐
          └────────────────────────────────▶ │  Supabase    │  │ Google Gemini│
                                             │ PostgreSQL   │  │ توليد + متّجهات│
┌────────────────────┐  كعكات موقَّعة        │ pgvector     │  └──────────────┘
│ لوحات الويب (React) │ ──────────▶ API ───▶ │ Storage      │
└────────────────────┘                       └──────────────┘
```

**المبدأ الحاكم:** كلُّ قراءةٍ لبيانات الأشخاص وكلُّ كتابةٍ في قاعدة البيانات تمرّ بالخادم (مفتاح الخدمة). العملاء لا يحملون إلا المفتاح العام، وهو مقصورٌ على قراءة المحتوى التعليمي.

### 3.2 تسجيل دخول الطالب

1. التطبيق يرسل `{username, password}` إلى `POST /api/auth/student/session`.
2. الخادم يجد الطالب (`students`، بمفتاح الخدمة) ويتحقّق بـ scrypt (القسم 10.1). إن كانت البصمة بصيغةٍ قديمة رُقّيت في الخلفية.
3. يعيد رمزاً موقَّعاً (HMAC-SHA256، 12 ساعة) وملفّ الطالب **بلا** `password` و`nationalId` و`parentPhoneNumber`.
4. كلُّ طلبٍ لاحق يحمل `Authorization: Bearer <token>`، ويُجدَّد الرمز تلقائياً مرّةً عند انتهائه.

### 3.3 حل المسائل

1. `POST /api/gemini/answer` (طالب) — نصٌّ أو صورة (≤6 MB) أو صوتٌ مُفرَّغ.
2. الصورة تُقرأ أوّلاً إلى نصّ (نداء Gemini قصير بحرارة 0)؛ وتعذّرُ القراءة يجعل المفتاح بصمةَ الصورة (SHA-256).
3. **سلّم الذاكرة** (الأرخص أوّلاً): مطابقةٌ حرفية ← تشابهٌ لفظيّ ← تشابهٌ دلاليّ (متّجهات، عتبة 0.95) مع اشتراط تطابق الأرقام والوحدات.
4. إصابةٌ في الذاكرة: لا تُخصم من الحصّة. إخفاق: الحصّة (10 مجاناً يومياً، ثم 5 جواهر بموافقة الطالب) ← Gemini ← الإجابة.
5. الحفظ الدائم في الخلفية (`persistAnswer`): متّجه 768 بُعداً، ثلاث محاولات، والأعمدة المقروءة؛ ولا يُحفظ رفضٌ أبداً.

### 3.4 المبارزة (تحدَّ زملاءكَ)

1. الدعوة والقبول والانضمام عبر `/api/duel/*`.
2. حزمة الأسئلة تُبنى مرّةً في القاعدة (`claim_duel_pack`) وتُكتب في المباراة، فيقرأ كلُّ اللاعبين الحزمةَ نفسها.
3. التوزيع: 4 من مجال الدرس، و4 معرفة عامة (بابٌ مختلفٌ لكل سؤال)، و2 ذكاءٌ وسرعة، على النمط `DKBDKDKBDK`؛ وما لُعب في آخر 10 مباريات لأيّ لاعبٍ يتأخّر.
4. الإجابات والأسبقية يحسمها الخادم (`/api/duel/:id/answer`)، والبثّ الحيّ عبر قنوات Supabase Realtime (broadcast).

### 3.5 مزامنة لوحات الويب

اللوحات تعمل على `localStorage` وتعكس كل كتابةٍ إلى الخادم عبر `/api/supabase/:table/upsert`، وتُحمَّل منه عند الإقلاع. الجسر:
- يقصر الصفوف على صلاحية الدور (المعلم يرى سجلّاته، ووليّ الأمر أبناءه).
- **لا يرسل كلمات المرور** إلى المتصفّح (`withoutPasswords`).
- **لا يخزّن إلا scrypt** (`passwordToStore`): لا تنزيل لصيغة، ولا قيمةَ ضعيفة.

---

## 4. تطبيق الطالب (Android)

### 4.1 الهوية والبناء

| البند | القيمة |
|---|---|
| المعرّف (applicationId / namespace) | `com.manara.student` |
| الإصدار | `1.1.0+2` |
| الحدّ الأدنى | Android 7.0 (minSdk 24) |
| المعماريات | arm64-v8a · armeabi-v7a (≈110 MB) |
| التوقيع | مفتاح إصدار RSA 4096، PKCS12، صالح 30 سنة — `CN=Manara Al-Maarifa, O=Manara Smart Edu, C=SA` |
| الإعداد وقت البناء | `--dart-define`: `SUPABASE_URL`، `SUPABASE_ANON_KEY`، `API_BASE_URL` (من أسرار GitHub) |
| العنوان الافتراضي للخادم | `https://manara-aiedu.com` |

### 4.2 الشاشات (16)

الدخول (مشهد حيّ) · البداية · اختيار المسار الأكاديمي · الرئيسية · شرح الدرس والألعاب · المذاكرة الذكية · الاختبارات · السينما · تحدَّ زملاءكَ · المباراة الحيّة · حل المسائل · المعلّم الافتراضي · المحادثة · الشخصية · التقدّم · الإطار العام.

### 4.3 الخدمات (17)

`student_auth_service` (الدخول عبر الخادم) · `student_content_service` (المحتوى، والملف، والنتائج، والمكافآت) · `student_duel_service` و`duel_live_controller` (المبارزة) · `student_challenge_service` · `student_study_service` · `student_voice_service` (النطق والإملاء) · `student_leaderboard_service` · `audio_service` و`student_sound_service` · `duel_voice_recorder` · `meeting_links` · `student_avatar_store` · `student_media_permissions` · `student_path_memory` · `student_settings` · `study_rotation`.

### 4.4 ما يصل إليه التطبيق مباشرة

| الوصول | الطريق |
|---|---|
| ملف الطالب، والنتائج، ومحادثات المعلّم، وأسماء المعلّم | الخادم: `/student/me`، `/student/quiz-results`، `/student/tutor-history` |
| المكافآت والسلاسل والمظهر | الخادم: `/student/progress/*` |
| الدروس، واختبارات المعلّم، ومفاتيح المحتوى | Supabase بالمفتاح العام (قراءة فقط) |
| حزمة المبارزة | `claim_duel_pack` (الدالة الوحيدة المتاحة للمفتاح العام) |
| فيديو الدروس | Supabase Storage (حاوية عامة) |

### 4.5 الإصدار والتوزيع

- **البناء:** GitHub Actions يبني APK موقَّعاً، ويتحقّق بـ `apksigner` من أن التوقيع ليس مفتاح التطوير، وبـ `aapt2` من أن المعرّف `com.manara.student`، ويرفض البناء إن غابت أسرار التوقيع.
- **النشر:** GitHub Release `v1.1.0` — الملف `manara-student.apk`.
- **رابط التنزيل الدائم:** `https://github.com/dekram4/manara-smart-edu-project/releases/latest/download/manara-student.apk` — يتبع آخر إصدار، وهو ما يفتحه زرّ «تحميل تطبيق الطالب» (ويُغيَّر من لوحة المشرف).

### 4.6 تجربة الاستخدام

حركات «لمسة» (مشهد دخول حيّ، وخلفيات حيّة في الرئيسية والبطاقات)، والعربية والإنجليزية، والوضع الليلي، والاتجاهان الرأسي والأفقي، واحترام «تقليل الحركة»، والنطق العربي `ar-SA` بلا تشكيل وبسرعة 0.52.

---

## 5. لوحات الويب

| الدور | الصفحات |
|---|---|
| مشترك | اختيار الأدوار (مع زرّ تحميل تطبيق الطالب) |
| المشرف | لوحة القيادة، المعلمون، الطلاب، الإعدادات الأكاديمية، المحتوى، الاختبارات، حزم الصلاحيات، صلاحيات البطاقات، التقارير، إشعارات الفيديو، إعدادات النظام (ومنها رابط APK) |
| المعلم | لوحة القيادة، المحتوى، الفيديو، الإعدادات الأكاديمية، الطلاب وأولياء الأمور، الشهادات، التقارير، حسابي، مراجعة أسئلة التحدي، المحادثة الخاصة |
| وليّ الأمر | لوحة الأبناء، إعداد الحساب |

البناء: Vite إلى `artifacts/manara/dist/public`، ويقدّمه خادم Express نفسه على `manara-aiedu.com`.

---

## 6. خادم الـ API

### 6.1 التشغيل

- نقطة الدخول: `node --enable-source-maps artifacts/api-server/dist/index.mjs`.
- يقدّم الواجهة المبنية والـ API تحت `/api` من العملية نفسها.
- السجلات: pino منظّمة (JSON)، تُقرأ في Railway Logs.

### 6.2 متغيّرات البيئة (بالأسماء فقط)

| المتغيّر | الغرض |
|---|---|
| `SUPABASE_URL` · `SUPABASE_SERVICE_ROLE_KEY` · `SUPABASE_ANON_KEY` | الاتصال بقاعدة البيانات |
| `SUPABASE_VIDEO_BUCKET` | حاوية الفيديو (افتراضياً `lesson-videos`) |
| `GEMINI_API_KEY` · `GEMINI_MODEL` | الذكاء الاصطناعي (النموذج يُكتشف آلياً إن لم يُحدَّد) |
| `SESSION_SECRET` | توقيع الجلسات والرموز (HMAC) |
| `ADMIN_USERNAME` · `ADMIN_PASSWORD` | حساب المشرف |
| `DID_CLIENT_KEY` · `DID_AGENT_ID` | المعلّم الافتراضي (D-ID) |
| `ALLOWED_ORIGIN_DOMAINS` | نطاقاتٌ إضافية لـ CORS (اختياري؛ نطاق الخادم موثوقٌ دائماً) |
| `NODE_ENV` · `LOG_LEVEL` | البيئة ومستوى السجل |

### 6.3 الحدود

| البند | القيمة |
|---|---|
| جسم JSON الافتراضي | 100 KB (افتراضيّ Express) |
| `/api/gemini/answer` | 10 MB (الصورة ≤6 MB بعد الترميز) |
| `/api/student/chat/voice` | 320 KB |
| رفع الفيديو | 500 MB، MP4 وحده |
| حصّة حل المسائل | 10 أسئلة مجانية يومياً، ثم 5 جواهر للسؤال بموافقة الطالب |

### 6.4 تحديد المعدّل (لكل عميل، في الدقيقة)

| المسار | الحد |
|---|---|
| حل المسائل `/gemini/answer` | 20 |
| جولات التحدي `/gemini/challenge` | 12 |
| محادثة الطلاب | 30 |
| تقدّم الطالب | 60 |
| ملف الطالب ونتائجه | 120 |
| صلاحيات البطاقات: قراءة / كتابة | 120 / 60 |
| السينما: قراءة / كتابة | 120 / 30 |
| الوسائط: عام / رفع / حذف / تنزيل / ترحيل | 200 / 20 / 30 / 100 / 20 |
| إعداد رابط APK (كتابة) | 20 |

مفتاح التحديد مستخرجٌ من مصدرٍ لا يزوّره العميل (`forwardedClientKey`)، ولا يُفعَّل `trust proxy`.

---

## 7. النقاط البرمجية (Endpoints)

**73 نقطة في 15 مجموعة.** الأعمدة: الطريقة · المسار · من يصل · ملاحظات.
مفتاح الصلاحية: **عام** = بلا جلسة · **طالب** = رمز Bearer · **معلم/مشرف** = كعكة موقَّعة · **قارئ** = أيُّ جلسة لوحة (مشرف/معلم/وليّ أمر) بنطاق دوره.

### الصحّة (1)
| الطريقة | المسار | الوصول |
|---|---|---|
| GET | `/api/healthz` | عام |

### المصادقة (11)
| الطريقة | المسار | الوصول | ملاحظات |
|---|---|---|---|
| POST | `/api/auth/admin` | عام | يُصدر كعكة المشرف (14 يوماً) |
| GET | `/api/auth/admin/session` | عام | حالة الجلسة |
| POST | `/api/auth/student/session` | عام | scrypt ← رمز 12 ساعة + ملفٌّ آمن |
| POST | `/api/auth/teacher/session` | عام | جلسة الوسائط للمعلم |
| POST | `/api/auth/teacher/login` | عام | كعكة المعلم (12 ساعة) |
| POST | `/api/auth/parent/login` | عام | كعكة وليّ الأمر (12 ساعة) |
| POST | `/api/auth/teacher/change-password` | عام + كلمة المرور الحالية | يكتب scrypt |
| POST | `/api/auth/parent/change-password` | عام + كلمة المرور الحالية | يكتب scrypt |
| POST | `/api/auth/{admin,parent,teacher}/logout` | — | يمحو الكعكة |

### ملف الطالب (3)
| الطريقة | المسار | الوصول |
|---|---|---|
| GET | `/api/student/me` | طالب |
| GET | `/api/student/quiz-results` | طالب |
| GET | `/api/student/tutor-history` | طالب |

### تقدّم الطالب (6) — كلُّها طالب
`POST /api/student/progress/reward` · `GET /leaderboard` · `POST /streak` · `POST /appearance` · `POST /quiz-result` · `POST /interaction`
(الخادم يحسب الجواهر والخبرة والإنجازات؛ والعميل يصف ما جرى فقط.)

### الذكاء الاصطناعي (5)
| الطريقة | المسار | الوصول |
|---|---|---|
| GET | `/api/gemini/quota` | طالب |
| POST | `/api/gemini/answer` | طالب |
| POST | `/api/gemini/challenge` | طالب |
| POST | `/api/ai/interactive-study` | طالب |
| POST | `/api/gemini/generate-quiz` | معلم/مشرف |

### المبارزة (12) — كلُّها طالب
`POST /api/duel/invite` · `POST /:id/respond` · `POST /:id/join` · `POST /:id/answer` · `POST /:id/finish` · `POST /:id/score` · `POST /:id/cancel` · `GET /inbox` · `GET /standings` · `GET /:id` · `GET /:id/messages` · `POST /:id/messages`

### بنك أسئلة المبارزة (4)
| الطريقة | المسار | الوصول |
|---|---|---|
| GET | `/api/duel-questions` | معلم/مشرف |
| POST | `/api/duel-questions/:id/active` | معلم/مشرف |
| GET / POST | `/api/duel-questions/generate-all` | مشرف |

### محادثة الطلاب (7) — كلُّها طالب
`GET /api/student/chat/peers` · `GET /messages` · `POST /messages` · `POST /seen` · `POST /save` · `POST /voice` · `GET /voice/:id`

### السينما (4)
| الطريقة | المسار | الوصول |
|---|---|---|
| GET | `/api/cinema/videos` | معلم/مشرف (داخل المعالج) |
| POST / DELETE | `/api/cinema/videos[/:id]` | معلم/مشرف — المعلم على فيديوهاته وحدها |
| GET | `/api/student/cinema` | طالب |

### صلاحيات البطاقات (4)
| الطريقة | المسار | الوصول |
|---|---|---|
| GET / PUT | `/api/card-permissions` | معلم/مشرف — المعلم على صفّه وطلابه |
| DELETE | `/api/card-permissions/:id` | معلم/مشرف |
| GET | `/api/student/card-permissions` | طالب |

### الوسائط (4)
| الطريقة | المسار | الوصول |
|---|---|---|
| GET | `/api/media/videos/:fileName` | عام (توافقٌ مع روابط قديمة) |
| POST | `/api/media/upload` | معلم/مشرف — إلى Supabase Storage |
| POST | `/api/media/delete` | معلم/مشرف — المالك وحده |
| POST | `/api/media/migrate-legacy` | مشرف |

### جسر المزامنة (7)
| الطريقة | المسار | الوصول |
|---|---|---|
| GET | `/api/supabase/health` · `/api/supabase/context` | عام / قارئ |
| GET | `/api/supabase/app_kv` | قارئ (وليّ الأمر: مفاتيح بعينها) |
| POST | `/api/supabase/app_kv/upsert` | معلم/مشرف (بحسب المفتاح) |
| GET | `/api/supabase/:table` | قارئ — بنطاق الدور، **بلا كلمات مرور** |
| POST | `/api/supabase/:table/upsert` · `/delete` | معلم/مشرف — بنطاق الدور، **scrypt وحده** |

### إعدادات المنصّة (2)
| الطريقة | المسار | الوصول |
|---|---|---|
| GET | `/api/app-settings/student-apk` | عام |
| PUT | `/api/app-settings/student-apk` | مشرف — `https://` وحده |

### الألعاب والمعلّم الافتراضي (3)
`GET /api/game-catalog` (عام) · `GET /api/game-embed/:gameId/*` (عام) · `GET /api/did-agent/config` (عام: مفتاح عميل D-ID العامّ ومعرّف الوكيل)

**تحقّقٌ حيّ:** بلا جلسة، ترفض كلُّ المسارات المحميّة المختبرة الطلبَ بـ 401 (`/student/me`، `/student/quiz-results`، `/student/tutor-history`، `/supabase/students`، `/gemini/quota`، كتابة رابط APK، ودخول الطالب بيانات خاطئة).

---

## 8. قاعدة البيانات

**Supabase PostgreSQL** عبر PostgREST · الإضافات: `pgvector` · التخزين: حاوية `lesson-videos` (عامة).
النمط الغالب: `id text` + `data jsonb` + `updated_at`. RLS مفعّل على كل الجداول.

### 8.1 الجداول

| الجدول | الصفوف | الأعمدة الرئيسية | المحتوى | المفتاح العام |
|---|---:|---|---|---|
| `students` | 4 | id, data, updated_at | حسابات الطلاب ومساراتهم وتلعيبهم | ✗ |
| `teachers` | 1 | id, data, updated_at | حسابات المعلمين | ✗ |
| `parents` | 1 | id, data, updated_at | حسابات أولياء الأمور | ✗ |
| `lesson_configs` | 55 | id, data, updated_at | الدروس ونصوصها وبنوك التحدي والمذاكرة | قراءة |
| `created_quizzes` | 77 | id, data, updated_at | اختبارات المعلمين | قراءة |
| `quiz_results` | 41 | id, data, updated_at | نتائج الاختبارات | ✗ |
| `interactions` | 205 | id, data, updated_at | التفاعلات ومحادثات المعلّم الافتراضي | ✗ |
| `app_kv` | 14 | key, value, updated_at | إعدادات المنصّة (مفتاح/قيمة) | قراءة 5 مفاتيح |
| `ai_qa_cache` | 31 | id, data, embedding vector(768), question_hash, question_text, answer_json, domain | ذاكرة حل المسائل الدائمة (27 بمتّجه) | ✗ |
| `solved_questions_cache` (عرض) | 31 | id, question_hash, question_text, answer_json, domain, created_at, updated_at | عرضٌ مقروء للذاكرة | ✗ |
| `duel_questions` | 1,067 | id, subject_key, unit, grade_band, category, prompt, choices text[], source, active… | بنك المبارزة: 870 مجال · 146 معرفة عامة · 51 عامة/ذكاء/سرعة/مدرسية | ✗ |
| `challenge_matches` | 37 | id, lesson_id, game, host_id, guest_id, status, scores, questions jsonb, expires_at… | المباريات وحزمها | ✗ |
| `match_answers` | 233 | match_id, question_index, student_id, correct, won, answered_at | إجابات المباريات | ✗ |
| `challenge_match_players` · `match_messages` | 0 | — | التحدي الجماعي والرسائل (تُكتب بديلتها في `interactions`) | ✗ |
| `public_messages` · `private_messages` · `chat_read_receipts` | 5 · 0 · 0 | — | المحادثات | ✗ |
| `certificates` | 1 | id, data | الشهادات | ✗ |
| `cinema_videos` · `student_card_permissions` | 0 | — | جداول مُعدّة؛ والبديل الفعّال في `app_kv` | ✗ |
| `duel_questions_bank` | 20 | — | بنكٌ قديم غير مستخدم | ✗ |

### 8.2 مفاتيح `app_kv` (14)

`smartEdu_adminSettings` · `smartEdu_cardPermissions`¹ · `smartEdu_contentEpoch` · `smartEdu_deletedLessons` · `smartEdu_deletedQuizzes`¹ · `smartEdu_deletedStudents` · `smartEdu_deletedVideos`¹ · `smartEdu_grades` · `smartEdu_hierarchicalConfigs`¹ · `smartEdu_permissionPackages` · `smartEdu_permissions` · `smartEdu_studentApkUrl` · `smartEdu_videoNotifications` · `smartEdu_videos`¹

¹ المفاتيح الخمسة المقروءة بالمفتاح العام (المحتوى وحده؛ وتُضاف `smartEdu_quizQuestions` إن وُجد).

### 8.3 الدوالّ (RPC)

| الدالة | الغرض | من ينفّذها |
|---|---|---|
| `claim_duel_pack(text)` | بناء حزمة المباراة مرّةً تحت قفل الصفّ | المفتاح العام + الخادم |
| `match_qa_cache(vector, text, double)` | أقرب سؤالٍ محفوظ معنىً (عتبة 0.95) | الخادم وحده |
| `record_duel_answer` · `cleanup_expired_ephemeral_chat` | المبارزة الحيّة والمحادثة المؤقتة | الخادم وحده |
| `duel_subject_key` · `duel_grade_band` | تطبيع المادة والمرحلة | الخادم وحده |

### 8.4 نموذج الصلاحيات في القاعدة

| الدور | الصلاحية |
|---|---|
| `service_role` (الخادم وحده) | كاملة على كل الجداول |
| `anon` / `authenticated` (العملاء) | `SELECT` على `lesson_configs` و`created_quizzes` و`app_kv` (بسياسة مفاتيح) — ولا شيء غيره |
| الحذف من `ai_qa_cache` | مرفوضٌ لكل الأدوار (ذاكرة دائمة) |

---

## 9. الذكاء الاصطناعي

| الاستخدام | النموذج | ملاحظات |
|---|---|---|
| حل المسائل، وجولات التحدي، والمذاكرة الذكية، وتوليد الاختبارات، وقراءة الصور | Gemini (يُكتشف آلياً؛ حالياً `gemini-flash-lite-latest`) | لهجة سعودية بسيطة، وخطواتٌ موجزة |
| المطابقة بالمعنى | `gemini-embedding-001` بـ 768 بُعداً | `SEMANTIC_SIMILARITY`، عتبة 0.95 بعد قياسٍ حيّ (المختلف يبلغ 0.94) |

**نطاق حل المسائل:** يجيب عن كل ما يتصل بمهارات المادة وموضوع الدرس — ولو لم يرد بنصّه — ويعتذر بلطف عمّا لا علاقة له بالتعليم وحده. والرفضُ القديم المحفوظ يُعامَل إخفاقاً ويُستبدل.

**الذاكرة الدائمة (`ai_qa_cache`):** كلُّ إجابةٍ جديدة تُحفظ بمتّجهها وأعمدتها المقروءة، وتُخدَم لكل طالبٍ يسأل السؤال نفسه أو ما يعادله معنىً بلا كلفةٍ ولا خصم. وإن غابت دالة المطابقة في القاعدة قاس الخادم التشابه بنفسه.

**النطق:** محرّك الجهاز (`flutter_tts`)، `ar-SA` بصوتٍ سعوديٍّ إن وُجد، مع حذف التشكيل كاملاً قبل النطق.

---

## 10. الأمان والتشفير

### 10.1 كلمات المرور

| البند | القيمة |
|---|---|
| الخوارزمية | **scrypt** (`node:crypto.scryptSync`) |
| المعاملات | N = 2¹⁵ (32768) · r = 8 · p = 1 · طول الناتج 32 بايت · ذاكرةٌ قصوى 64 MB |
| الملح | 16 بايتاً عشوائياً لكل حساب (`crypto.randomBytes`) |
| الصيغة المخزّنة | `scrypt1$<salt base64url>$<hash base64url>` |
| المدخل | `scrypt( sha256hex(كلمة المرور) )` — يتيح ترقية البصمات القديمة في مكانها بلا كلمات المرور |
| المقارنة | ثابتة الزمن (`timingSafeEqual`) |
| الصيغ القديمة | تُقبل للتحقّق (SHA-256، نصٌّ صريح) وتُرقّى فوراً عند أوّل دخولٍ ناجح |
| الحالة الحيّة | **6 / 6 حسابات بـ scrypt** (طلاب 4، معلم 1، وليّ أمر 1)؛ صفرُ بصمةٍ ضعيفة |
| المشرف | بياناتٌ في متغيّرات البيئة، لا في القاعدة |

**أين يحدث التحقّق:** على الخادم وحده. لا التطبيق ولا المتصفّح يستلم بصمةً من الخادم؛ وجسرُ المزامنة يحفظ البصمة المخزّنة إن وصلته نسخةٌ قديمة، ويلفّ أيَّ كلمة مرورٍ جديدة بـ scrypt.

### 10.2 الجلسات والرموز

| الدور | الآلية | المدّة | الخصائص |
|---|---|---|---|
| المشرف | كعكة `manara_admin_session` موقَّعة HMAC | 14 يوماً | HttpOnly · SameSite=Lax · Secure |
| المعلم | كعكة `manara_teacher_session` موقَّعة HMAC | 12 ساعة | HttpOnly · SameSite=Lax · Secure |
| وليّ الأمر | كعكة `manara_parent_session` موقَّعة HMAC | 12 ساعة | HttpOnly · SameSite=Lax · Secure |
| الطالب | رمز Bearer: `base64url(payload).HMAC-SHA256` | 12 ساعة | مقارنةٌ ثابتة الزمن · لا يُحفظ على الجهاز |

المفتاح: `SESSION_SECRET` في متغيّرات الخادم.

### 10.3 التفويض

- كلُّ مسارٍ يتحقّق من الجلسة ثم من **النطاق**: المعلم على صفّه وطلابه وفيديوهاته، ووليّ الأمر على أبنائه، والطالب على مساره وبياناته.
- الطالب لا يرسل هويته: الخادم يأخذها من الرمز (نتيجة الاختبار تُكتب باسم صاحب الرمز وحده).
- المكافآت والجواهر يحسبها الخادم، وسجلّ الأنشطة يمنع تكرار المكافأة.

### 10.4 قاعدة البيانات

- المفتاح العام (المضمَّن في التطبيق، فهو علنيّ) **لا يقرأ** أيّ جدولٍ فيه بيانات أشخاص، و**لا يكتب** في أيّ جدول.
- الخادم وحده يحمل مفتاح الخدمة.
- RLS مفعّل على كل الجداول، والسياسات القائمة للقراءة العامة ثلاث فقط (القسم 8.4).

### 10.5 النقل والأصول

- HTTPS على `manara-aiedu.com` و`manara-edu.up.railway.app`.
- CORS: نطاق الخادم نفسه، و`ALLOWED_ORIGIN_DOMAINS` إن ضُبط؛ والرفض بإغفال ترويسات CORS لا بخطأ خادم.
- `x-powered-by` معطّل.

### 10.6 المدخلات والمحتوى

- رابط APK: `https://` وحده، بلا بيانات اعتماد مضمّنة، ≤2048 حرفاً.
- الصور: JPEG/PNG/WebP وحدها، ≤6 MB؛ والفيديو MP4 وحده.
- حدود الأجسام وتحديد المعدّل (القسمان 6.3 و6.4).

### 10.7 الأسرار

| السرّ | مكانه |
|---|---|
| مفاتيح Supabase وGemini وD-ID و`SESSION_SECRET` وبيانات المشرف | متغيّرات Railway |
| `SUPABASE_URL` · `SUPABASE_ANON_KEY` · `API_BASE_URL` (للتطبيق) | أسرار GitHub (تُحقن وقت البناء) |
| مفتاح توقيع التطبيق | أسرار GitHub (`ANDROID_KEYSTORE_*`) + نسخةٌ لدى المالك |

لا سرّ في المستودع؛ و`key.properties` و`*.jks` مستثناة من git.

### 10.8 التخزين الدائم

الفيديو في Supabase Storage. في الإنتاج لا يُكتب أيُّ ملفٍّ على قرص الحاوية (يُمحى مع كل نشر): إن تعذّر التخزين الدائم رُفض الرفع صراحةً.

---

## 11. البنية التحتية والنشر (CI/CD)

### 11.1 Railway

| البند | القيمة |
|---|---|
| الخدمة | `manara-platform` (بيئة `production`) |
| المنطقة | `sfo` (غرب الولايات المتحدة) |
| النطاقات | `manara-aiedu.com` (مخصّص) · `manara-edu.up.railway.app` |
| البناء | Dockerfile: `node:20-bookworm-slim` ← `pnpm install --frozen-lockfile` ← بناء الويب ثم الخادم |
| التشغيل | `node --enable-source-maps artifacts/api-server/dist/index.mjs` |
| الفحص الصحّي | `/api/healthz` بمهلة 120 ث قبل اعتماد النشر |
| إعادة التشغيل | عند الفشل، حتى 5 مرّات |
| المصدر | مربوطٌ بالمستودع؛ كلُّ دفعٍ إلى `main` يُنشر تلقائياً |

### 11.2 GitHub Actions

| سير العمل | المشغّل | الخطوات |
|---|---|---|
| Build Student APK | دفعٌ إلى `main` + يدوي | Java 17 · Flutter 3.44.8 · استعادة مفتاح التوقيع (يفشل إن غاب) · `flutter build apk --release` · التحقّق من التوقيع والمعرّف · رفع الأثر |
| Build Student Windows | دفعٌ إلى `main` + يدوي | `flutter build windows --release` |

### 11.3 الإصدار

GitHub Releases: `v1.0.0` (أوّل إصدار) · `v1.1.0` (الإصدار الأمني، **الأحدث**) — مع بصمة SHA-256 في ملاحظات كل إصدار.

### 11.4 سير العمل

- التطوير على `feature/lamsa-ui-landscape`، والدمج إلى `main` دمجاً صريحاً (`--no-ff`) بعد نجاح الاختبارات.
- النسخ الاحتياطية: الوسمان `backup/main-2026-10-14` و`backup/lamsa-ui-2026-10-14`.
- Vercel: النشر التلقائي من المستودع موقوف (`vercel.json` بـ `git.deploymentEnabled: false`).

---

## 12. الاختبار والجودة

| المجموعة | العدد | الأداة | يغطي |
|---|---:|---|---|
| تطبيق الطالب | 691 اختباراً في 73 ملفاً | `flutter test` + `flutter analyze` | الواجهات في الاتجاهين، والحركة وتقليلها، والمبارزة، والنطق، والصلاحيات، والمحتوى |
| الخادم | 291 اختباراً في 23 ملفاً | `node --test` على البناء | كلمات المرور وscrypt، وعدم تسريب البيانات، والإغلاق، والذاكرة والمتّجهات، والحصّة، والمبارزة والبنوك، والأصول الموثوقة، وإعدادات APK |
| لوحات الويب | — | `tsc --noEmit` + `vite build` | سلامة الأنواع والبناء |
| مخطّطات SQL | — | تشغيلٌ على PostgreSQL 18 محليّ بنسخةٍ مطابقة للمخطّط | الإغلاق، والبنك، والتشغيل المتكرّر |

---

## 13. نتائج التدقيق الحيّ

بتاريخ 17 أكتوبر 2026، على `main@2f97b81`:

| الفحص | النتيجة |
|---|---|
| `https://manara-aiedu.com/` | 200 |
| `/api/healthz` · `/api/supabase/health` | 200 (0.36 ث) · 200 |
| سجلّ الخادم منذ آخر نشر | صفرُ أخطاء |
| المسارات المحميّة بلا جلسة | 401 جميعاً |
| المفتاح العام — قراءة | 3 جداول (محتوى تعليمي) · 19 مرفوضة |
| المفتاح العام — كتابة (تعديل/إدراج/حذف) | مرفوضة على الجداول الـ21 |
| `match_qa_cache` | الخادم 200 · المفتاح العام 401 |
| كلمات المرور | scrypt 6/6 |
| أسئلة المعرفة العامة | 146 (ثقافة 30 · رياضة 28 · جغرافيا 30 · تاريخ 28 · علوم 30) |
| APK v1.1.0 | `com.manara.student` · توقيع الإصدار · SHA-256 `942d7c12dcd949e376d6f97cd55dc03227cceca78ea45887646609da84ad0589` |
| رابط التنزيل العام | 200 · `application/vnd.android.package-archive` · البصمة مطابقة |

---

## 14. سجلّ المعالجة

| # | النقطة (التقرير السابق) | المعالجة | الحالة |
|---|---|---|---|
| 1 | المفتاح العام يقرأ سجلّات الطلاب كاملة | الدخول والملف والنتائج عبر الخادم؛ وسحب الصلاحيات | ✅ مغلق |
| 2 | المفتاح العام يكتب في جداول الحسابات وغيرها | سحب كل صلاحيات الكتابة | ✅ مغلق |
| 3 | كلمات المرور SHA-256 بلا ملح | scrypt بملحٍ لكل حساب + ترقية فورية | ✅ مُرقّى |
| 4 | التحقّق من كلمة المرور على الهاتف والمتصفّح | التحقّق على الخادم وحده؛ لا بصمات للعملاء | ✅ مُصحَّح |
| 5 | `match_qa_cache` معطوبة | حذفٌ وإنشاءٌ بالتوقيع الصحيح | ✅ تعمل |
| 6 | بنك المعرفة العامة غير مطبَّق | القيد والدالة و146 سؤالاً | ✅ مفعّل |
| 7 | الوسائط وقرص الحاوية المؤقّت | لا كتابة محليّة في الإنتاج | ✅ دائم |
| 8 | APK بمفتاح التطوير ومعرّف `com.example` | مفتاح إصدار + `com.manara.student` + تحقّقٌ في البناء | ✅ جاهز |
| 9 | نشرٌ موازٍ على Vercel | `vercel.json` | ✅ موقوف |
| 10 | بقايا Replit | إزالة الحزم والإعدادات، وتسمية الخدمة `manara-platform` | ✅ نظيف |

---

## 15. التشغيل والصيانة

### 15.1 سكربتات قاعدة البيانات المرجعية (`artifacts/api-server/scripts`)

| الملف | الغرض |
|---|---|
| `apply-supabase-schema.sql` | ما طُبّق فعلاً في 17 أكتوبر 2026: الإغلاق، و`match_qa_cache`، وقيد الأبواب، و`claim_duel_pack` |
| `seed-knowledge-questions.mjs` | إدراج أسئلة المعرفة العامة الـ146 (بمفتاح الخدمة) |
| `apply-supabase.sql` | النسخة الكاملة المولّدة (الأجزاء الثلاثة + الأسئلة + صفّ تحقّق) |
| `security-lockdown.sql` | إغلاق المفتاح العام (جزءٌ من السابق) |
| `ai-qa-cache.sql` · `ai-qa-cache-vectors.sql` · `solved-questions-cache.sql` | الذاكرة الدائمة ومتّجهاتها وعرضها |
| `duel-question-bank.sql` · `duel-knowledge-bank.sql` | بنك المبارزة الأوّل وأبواب المعرفة العامة |
| `upgrade-password-hashes.mjs` | ترقية كلمات المرور القديمة إلى scrypt (يتحقّق قبل الكتابة) |
| `backfill-cache-embeddings.mjs` · `backfill-cache-columns.mjs` | إكمال المتّجهات والأعمدة المقروءة للذاكرة |

تُشغَّل سكربتات `.mjs` بمتغيّرات الخادم: `railway run node ./scripts/<name>.mjs`.

### 15.2 ممارسات

- **مفتاح توقيع التطبيق** محفوظٌ لدى المالك في `Documents\Manara-Signing` وفي أسرار GitHub؛ تُحفظ منه نسخةٌ خارج الجهاز، فبه تُوقَّع كلُّ تحديثات التطبيق.
- **إصدار جديد للتطبيق:** رفع `version` في `pubspec.yaml`، ثم الدفع إلى `main`، ثم نشر GitHub Release بالملف `manara-student.apk` — والرابط الدائم يتبعه تلقائياً.
- **تغييرات قاعدة البيانات** تُكتب سكربتاتٍ في المستودع أوّلاً، ليبقى مرجعَها الوحيد.
- **الطلاب على v1.0.0** يحذفونها ويثبّتون v1.1.0؛ المعرّف الجديد يجعلها تطبيقاً جديداً، والدخول بالبيانات نفسها.

---

*أُعدّ من الكود في `main` ومن فحصٍ حيّ لـ Railway وSupabase وGitHub بتاريخ 17 أكتوبر 2026.*
