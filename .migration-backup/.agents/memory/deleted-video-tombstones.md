---
name: Deleted video tombstones
description: How shared teacher videos remain deleted across localStorage and Supabase hydration.
---

Shared videos live in `app_kv`, where a normal remote/local merge cannot distinguish an intentional deletion from an offline local omission. Keep deleted video IDs in a separate synced tombstone collection and filter both remote and local video arrays against it during hydration.

**Why:** Without a tombstone, an old remote video is merged back into the teacher's list when the app starts or another device hydrates.

**How to apply:** Write the tombstone before removing the video, sync the tombstone and video list through the normal localStorage boundary, and never clear tombstones during ordinary hydration.