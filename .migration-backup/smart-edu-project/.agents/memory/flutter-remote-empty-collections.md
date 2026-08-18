---
name: Remote empty collections
description: Rule for hydrating Flutter collections from Supabase when the remote collection is empty.
---

When there are no pending local writes or deletes, an explicitly returned empty remote collection is authoritative and must replace the local cache.

**Why:** Treating empty responses as “no update” resurrects records that were deleted on another device and makes multi-device sync inconsistent.

**How to apply:** Skip remote hydration only while `manara_sync_pending` or queued deletes exist; otherwise clear and repopulate each collection from the remote list, including when it is empty.