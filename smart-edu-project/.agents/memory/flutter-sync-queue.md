---
name: Flutter sync queue
description: Offline-first ordering and retry behavior for the native Supabase sync layer.
---

Local collections are authoritative while a full sync is marked pending or deletes are queued. On startup, the app must not hydrate remote collections over those local changes; it retries the full upload and deferred deletes first.

**Why:** Hydrating stale remote data before retrying local changes can silently overwrite offline edits, while failed deletes can reappear after the next sync.

**How to apply:** Keep local persistence synchronous from the user's perspective, mark remote work pending, retry after connectivity is available, and clear the pending state only after the complete collection/key-value sync succeeds.