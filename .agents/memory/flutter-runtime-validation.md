---
name: Flutter runtime validation
description: Flutter source can be prepared in the mobile artifact, but this workspace currently has no Flutter or Dart SDK for local execution.
---

Flutter artifacts in this workspace require source-level validation until a Flutter/Dart toolchain and a mobile-capable workflow are available.

**Why:** The Replit runtime currently exposes Node/pnpm tooling only, so `flutter pub get`, `flutter analyze`, and device builds cannot run here.

**How to apply:** Keep Supabase values as `--dart-define` inputs, validate package/source structure locally, and run the real Flutter checks on a machine or workflow with Flutter installed.