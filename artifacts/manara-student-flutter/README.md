# تطبيق منارة المعرفة للطالب

تطبيق Flutter مستقل للطلاب فقط، يستخدم نفس هوية منصة منارة ويرتبط بقاعدة Supabase الحالية.

## التشغيل بعد توفر Flutter SDK

```bash
cd artifacts/manara-student-flutter
flutter create .
flutter pub get
flutter run \
  --dart-define=SUPABASE_URL=https://your-project.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=your-public-anon-key
```

القيمتان تمرران وقت التشغيل فقط. لا تضع مفتاح `service_role` داخل التطبيق أو في ملفات الأصول.

## مصدر بيانات تسجيل الدخول

يقرأ التطبيق سجلات الطلاب من جدول `students` الذي تستخدمه منصة الويب، حيث يكون السجل بالشكل:

```json
{ "id": "...", "data": { "username": "...", "password": "...", "role": "student" } }
```

تُقبل بصمة SHA-256 أو كلمة المرور النصية القديمة للتوافق مع بيانات منارة الحالية. كما يدعم التطبيق حسابات Supabase Auth البريدية عند إدخال بريد إلكتروني، بشرط أن يكون الدور في `profiles.role` مساويًا لـ `student`.

## ملاحظة عن التحقق

بيئة Replit الحالية لا تحتوي Flutter SDK، لذلك لا يمكن تشغيل `flutter pub get` أو `flutter analyze` داخلها. تم تجهيز بنية المشروع وملفات Dart و`pubspec.yaml` للاستخدام مباشرة بعد توفر Flutter SDK.