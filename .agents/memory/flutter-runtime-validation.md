---
name: Flutter runtime validation
description: GitHub Actions is the authoritative APK builder; Replit is limited to source checks that do not build an APK.
---

Do not attempt to build Flutter APKs locally in Replit. The project's configured GitHub Actions CI/CD is the authoritative APK builder and publishes successful packages as workflow artifacts.

**Why:** The user explicitly designated GitHub Actions for APK builds after Gradle repeatedly exhausted Replit's local storage quota.

**How to apply:** Make and validate source-level Flutter changes in Replit when compatible tooling is available, but rely on GitHub Actions for APK compilation and artifact delivery.