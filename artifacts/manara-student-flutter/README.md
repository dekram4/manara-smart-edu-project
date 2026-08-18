# تطبيق منارة المعرفة للطالب

تطبيق Flutter مستقل للطلاب فقط، يستخدم نفس هوية منصة منارة ويرتبط بقاعدة Supabase الحالية.

## التشغيل بعد توفر Flutter SDK

```bash
cd artifacts/manara-student-flutter
flutter create .
flutter pub get
flutter run \
  --dart-define=SUPABASE_URL=https://your-project.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=your-public-anon-key \
  --dart-define=API_BASE_URL=https://your-manara-api.example.com
```

القيم تمرر وقت التشغيل فقط. لا تضع مفتاح `service_role` داخل التطبيق أو في ملفات الأصول.

`API_BASE_URL` اختياري، ويُستخدم لتفعيل إجابات المعلم الافتراضي عبر مسار
`/api/gemini/answer`. إذا لم يتم تمريره، تعمل الدردشة بوضع تشجيعي محلي وتحفظ
المحادثة في جدول `interactions` عند توفر اتصال Supabase.

## المحتوى التفاعلي

- تُقرأ سجلات `lesson_configs` من Supabase وتُطابق مع الصف والترم والمادة والوحدة
  ومعرّف المعلم عند توفره.
- فيديوهات `explanationVideos` و`explanationVideoUrl` تظهر في كاروسيل مع مشغل
  WebView داخلي، وزر إغلاق وتكبير.
- ألعاب HTML5 تبقى داخل `InAppWebView` ولا تفتح متصفحًا خارجيًا.
- تخصيص الشخصية يحفظ حقول الشعر والملابس والحذاء ولون البشرة داخل
  `students.data.appearance`.

## مصدر بيانات تسجيل الدخول

يقرأ التطبيق سجلات الطلاب من جدول `students` الذي تستخدمه منصة الويب، حيث يكون السجل بالشكل:

```json
{ "id": "...", "data": { "username": "...", "password": "...", "role": "student" } }
```

تُقبل بصمة SHA-256 أو كلمة المرور النصية القديمة للتوافق مع بيانات منارة الحالية. كما يدعم التطبيق حسابات Supabase Auth البريدية عند إدخال بريد إلكتروني، بشرط أن يكون الدور في `profiles.role` مساويًا لـ `student`.

## ملاحظة عن التحقق

بيئة Replit الحالية لا تحتوي Flutter SDK، لذلك لا يمكن تشغيل `flutter pub get` أو `flutter analyze` داخلها. تم تجهيز بنية المشروع وملفات Dart و`pubspec.yaml` للاستخدام مباشرة بعد توفر Flutter SDK.