---
name: Foreground sync refresh
description: Safe multi-device refresh behavior for the Flutter app using the legacy Supabase JSONB schema.
---

Refresh remote collections when the app resumes, but only after checking the local pending-sync and queued-delete markers. If local work is pending, retry it instead of hydrating remote data.

**Why:** The legacy shared-table schema does not scope a broad delete operation to the current user or role, so sync must not delete every remote row absent from one device's local cache.

**How to apply:** Keep foreground refresh read-oriented; allow upserts through the existing sync path, defer authoritative remote deletion until the schema supports ownership-scoped mutations, and preserve local cache during failures.