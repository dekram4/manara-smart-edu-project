---
name: Permission package propagation
description: How active teacher package identity reaches nested dashboard features.
---

Nested teacher screens must receive the active teacher's `permissionPackageId` explicitly when they evaluate permissions. Do not rely only on the local session fallback, because a dashboard component can otherwise evaluate a stale or unrelated account context.

**Why:** The package is assigned to the account, but content, video, and account-management screens are separate components. Their permission checks must remain consistent with the sidebar and with the logged-in teacher after package changes.

**How to apply:** When adding a teacher-facing feature, pass the current teacher/package identity from the dashboard into the feature component and call the role permission resolver with that identity. Preserve the fallback only for legacy standalone usage.