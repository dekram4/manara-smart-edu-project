---
name: Flutter build environment
description: The workspace currently has no Flutter or Dart SDK and no available Flutter module.
---

Flutter source can be authored and reviewed in `flutter_app/`, but Android/iOS builds cannot be validated in this workspace until Flutter/Dart tooling is provided. A macOS/Xcode environment is still required for iOS and iPadOS archives.

**Why:** Package/module checks found no Flutter module, and the SDK binaries were unavailable.

**How to apply:** Do not claim APK/IPA output from this environment. Keep the Flutter rewrite isolated until the SDK is available, then run `flutter pub get`, `flutter analyze`, and platform builds. For compatibility with the user's local Flutter toolchain, prefer traditional `switch` statements and ordinary classes/maps over switch expressions and records in shared Flutter code.