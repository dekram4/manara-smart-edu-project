# تشغيل نسخة Flutter الأصلية

هذه الحزمة مستقلة عن نسخة React الموجودة في جذر المشروع.

## التشغيل

```bash
cd flutter_app
flutter pub get
flutter analyze
flutter test
flutter run
```

## لماذا لا تظهر في معاينة Replit الحالية؟

الـworkflow الحالي في جذر المشروع مضبوط على `npm run dev`، وهذا يشغّل تطبيق React القديم على المنفذ 5000. Flutter تطبيق أصلي ولا يعمل داخل معاينة الويب نفسها كـWebView.

لتشغيل Android استخدم جهاز Android أو محاكي Android مع Flutter SDK. لتشغيل iPhone/iPad يلزم macOS وXcode.

## Supabase

```bash
flutter run \
  --dart-define=SUPABASE_URL=https://your-project.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=your-anon-key
```