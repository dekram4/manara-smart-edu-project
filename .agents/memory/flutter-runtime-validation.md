---
name: Flutter runtime validation
description: Flutter Android checks can run from a temporary SDK, but Gradle may exceed this workspace's user-storage quota.
---

Flutter artifacts can use a temporary official Flutter SDK and Android SDK for local analysis and Android builds, but the user-storage quota may be exhausted by Gradle's dependency cache before an APK is produced.

**Why:** Gradle needs several gigabytes of Android and plugin artifacts in addition to Flutter, Pub, and the web project's existing generated dependencies. The filesystem can report free disk space while a per-user quota rejects new cache files.

**How to apply:** Keep Supabase values as `--dart-define` inputs. Before attempting an APK build, provision reusable Android build storage or explicitly free only generated dependency caches with the user's informed approval; do not delete application code, media, or uploaded data.