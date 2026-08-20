# تطبيق منارة المعرفة للطالب

تطبيق Flutter مستقل للطلاب فقط، يستخدم هوية منصة منارة نفسها، ويرتبط بقاعدة
Supabase الحالية ومساعد API الاختياري.

## المتطلبات

- Flutter SDK مستقر حديث، ويُفضّل Flutter 3.24 أو أحدث.
- Dart المرفق مع Flutter.
- Android Studio مع Android SDK وAndroid Emulator، أو هاتف Android مع USB
  debugging.
- VS Code مع إضافتي **Flutter** و**Dart**، أو Android Studio مع إضافة Flutter.
- Java 17 عند بناء Android.

تحقق من البيئة قبل التشغيل:

```bash
flutter --version
dart --version
flutter doctor
```

## تهيئة المشروع وتشغيله محليًا

من جذر المشروع:

```bash
cd artifacts/manara-student-flutter
flutter create .
flutter clean
flutter pub get
```

الأمر `flutter create .` ينشئ مجلدات المنصة مثل `android/` و`ios/` مع إبقاء
ملفات `lib/` و`assets/` الحالية. إذا كانت مجلدات المنصة موجودة مسبقًا، لا حاجة
لتشغيله مرة أخرى.

شغّل التطبيق مع إعدادات Supabase:

```bash
flutter run \
  --dart-define=SUPABASE_URL=https://your-project.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=your-public-anon-key
```

ولتفعيل الإجابات الذكية الكاملة عبر خادم API:

```bash
flutter run \
  --dart-define=SUPABASE_URL=https://your-project.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=your-public-anon-key \
  --dart-define=API_BASE_URL=https://your-manara-api.example.com
```

`API_BASE_URL` اختياري لتفعيل إجابات المعلم الافتراضي عبر مسار
`/api/gemini/answer`. مقاطع MP4 الجديدة تُحفظ في Supabase Storage وتصل إلى
التطبيق عبر روابط عامة دائمة، لذلك لا تعتمد على `localhost` أو على خادم تطوير.

القيم تمرر وقت التشغيل فقط. لا تضع مفتاح `service_role` داخل التطبيق أو في ملفات
الأصول أو داخل `pubspec.yaml`.

## التشغيل من VS Code

1. افتح المجلد `artifacts/manara-student-flutter` في VS Code.
2. شغّل `Flutter: Run Flutter Doctor` من Command Palette وتأكد من ظهور جهاز.
3. اختر جهاز Android من شريط الحالة.
4. اضغط `F5` أو اختر **Run > Start Debugging**.
5. عند الحاجة إلى تمرير القيم، افتح الطرفية داخل VS Code واستخدم أمر `flutter run`
   السابق؛ أو أنشئ إعداد تشغيل محلي في `.vscode/launch.json` بالشكل التالي:

```json
{
  "version": "0.2.0",
  "configurations": [
    {
      "name": "Manara Student",
      "request": "launch",
      "type": "dart",
      "program": "lib/main.dart",
      "toolArgs": [
        "--dart-define=SUPABASE_URL=https://your-project.supabase.co",
        "--dart-define=SUPABASE_ANON_KEY=your-public-anon-key",
        "--dart-define=API_BASE_URL=https://your-manara-api.example.com"
      ]
    }
  ]
}
```

لا ترفع `launch.json` إذا كان يحتوي على قيم خاصة ببيئة غير مخصصة للمشاركة.

## التشغيل من Android Studio

1. اختر **Open** وافتح مجلد `artifacts/manara-student-flutter`.
2. بعد إنشاء ملفات Android عبر `flutter create .`، انتظر اكتمال مزامنة Gradle.
3. اختر Emulator أو جهازًا متصلًا من قائمة الأجهزة.
4. مرّر `--dart-define` من إعداد **Run/Debug Configuration** في حقل
   **Additional run args**.
5. اضغط زر التشغيل الأخضر.

## فحص المشروع قبل التصدير

```bash
flutter pub get
flutter analyze
dart format --output=none --set-exit-if-changed lib
flutter test
```

لا توجد اختبارات واجهة آلية مرفقة حاليًا، لذلك قد يعرض `flutter test` رسالة عدم
وجود ملفات اختبار. يبقى `flutter analyze` و`dart format` فحصي الجودة الأساسيين.

## بناء APK

### APK تجريبي Debug

```bash
flutter build apk --debug \
  --dart-define=SUPABASE_URL=https://your-project.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=your-public-anon-key \
  --dart-define=API_BASE_URL=https://your-manara-api.example.com
```

الملف الناتج عادة:

`build/app/outputs/flutter-apk/app-debug.apk`

### APK إصدار Release واحد

```bash
flutter build apk --release \
  --dart-define=SUPABASE_URL=https://your-project.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=your-public-anon-key \
  --dart-define=API_BASE_URL=https://your-manara-api.example.com
```

الملف الناتج عادة:

`build/app/outputs/flutter-apk/app-release.apk`

### APKs منفصلة حسب المعمارية

لتقليل حجم التنزيل:

```bash
flutter build apk --split-per-abi --release \
  --dart-define=SUPABASE_URL=https://your-project.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=your-public-anon-key \
  --dart-define=API_BASE_URL=https://your-manara-api.example.com
```

تظهر الملفات داخل:

`build/app/outputs/flutter-apk/`

قبل النشر العام يجب إعداد توقيع Android Release داخل مجلد `android/` عبر ملف
keystore آمن. لا تضع keystore أو كلمات المرور أو مفاتيح التوقيع في Git أو داخل
التطبيق.

## المحتوى التفاعلي

- بعد تسجيل الدخول يختار الطالب الصف والفصل والمادة والوحدة والدرس من سجلات
  `lesson_configs`. عند عدم توفر مسار مكتمل أو درس حقيقي، تظهر رسالة واضحة ولا
  تُنشأ خيارات افتراضية غير مرتبطة بالمحتوى.
- ينتقل سياق الاختيار إلى لوحة الطالب ويُستخدم لتضييق محتوى الدروس المعروض.
- بطاقات لوحة الطالب تدعم السحب باللمس أو الماوس، وأسهم لوحة المفاتيح اليمنى
  واليسرى عند استخدام التطبيق على سطح المكتب.
- تُقرأ سجلات `lesson_configs` من Supabase وتُطابق مع الصف والترم والمادة والوحدة
  ومعرّف المعلم عند توفره.
- فيديوهات `explanationVideos` و`explanationVideoUrl` تظهر في كاروسيل مع مشغل
  WebView داخلي، وزر إغلاق وتكبير.
- ألعاب HTML5 تبقى داخل `InAppWebView` ولا تفتح متصفحًا خارجيًا.
- تخصيص الشخصية يحفظ حقول الشعر والملابس والحذاء ولون البشرة داخل
  `students.data.appearance`.

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

## ملاحظة عن التحقق داخل Replit

بيئة Replit الحالية لا تحتوي Flutter SDK، لذلك لا يمكن تشغيل `flutter pub get` أو
`flutter analyze` أو بناء APK داخلها. تم تجهيز بنية المشروع وملفات Dart و
`pubspec.yaml` للاستخدام مباشرة بعد توفر Flutter SDK.