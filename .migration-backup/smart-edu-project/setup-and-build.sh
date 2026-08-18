#!/bin/bash
# 🚀 سكريبت بناء كامل لتطبيق MANARA (أندرويد + iOS)
set -e

echo "▶️ بدء إعداد البيئة لبناء MANARA..."

# 1. بناء الويب
echo "🔧 بناء الويب التطبيق..."
npm run build

# 2. مزامنة Capacitor
echo "🔄 مزامنة Capacitor مع الويب..."
npx cap sync

# 3. تثبيت Android SDK (إذا لم يكن مثبتاً)
if [ ! -d "sdk/platforms/android-34" ]; then
  echo "📥 تثبيت Android SDK..."
  export JAVA_HOME=/nix/store/k95pqfzyvrna93hc9a4cg5csl7l4fh0d-openjdk-21.0.7+6
  export ANDROID_HOME=/home/runner/workspace/sdk
  export PATH=$JAVA_HOME/bin:$ANDROID_HOME/cmdline-tools/latest/bin:$PATH

  mkdir -p $ANDROID_HOME/licenses
  echo "24333f8a63b6825ea9c5514f83c2829b004d1fee" > $ANDROID_HOME/licenses/android-sdk-license
  echo "d56f5187479451eabf01fb78af6dfcb131a6481e" >> $ANDROID_HOME/licenses/android-sdk-license

  sdkmanager "platforms;android-34" "build-tools;34.0.0" "platform-tools"
fi

# 4. بناء Android APK
echo "📱 بناء ملف APK الأندرويد..."
export JAVA_HOME=/nix/store/k95pqfzyvrna93hc9a4cg5csl7l4fh0d-openjdk-21.0.7+6
export ANDROID_HOME=/home/runner/workspace/sdk
cd android
./gradlew assembleDebug --no-daemon
cd ..
cp android/app/build/outputs/apk/debug/app-debug.apk MANARA-Android.apk

# 5. حالة iOS (iOS يحتاج macOS للبناء)
echo ""
echo "📱 iOS: تم إعداد المشروع في ios/App/"
echo "   لبناء IPA يجب فتح Xcode على macOS والضغط على Product > Archive"
echo "   أو شغل: cd ios/App && xcodebuild -workspace App.xcworkspace -scheme App -configuration Debug build"

echo ""
echo "✅ البناء الكامل انتهى!"
echo "   📱 Android APK: MANARA-Android.apk (يمكن تثبيته مباشرة على أي جهاز أندرويد)"
echo "   🔌 الويب: dist/ (ارفعه على أي استضافة)"
echo "   🍎 iOS: ios/App/ (يحتاج macOS للتجميع)"
