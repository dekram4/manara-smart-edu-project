---
name: Deleted lesson tombstones
description: How shared lesson content remains deleted across localStorage and Supabase hydration.
---

Lesson configs are row-backed in Supabase, but local deletion can race with stale remote rows or another device. Store deleted lesson IDs in `smartEdu_deletedLessons` (synced through `app_kv`) before removing the local lesson. Hydration reads this set before lesson rows, filters stale remote/local lessons, deletes stale remote rows, and never clears the tombstones during ordinary hydration.

**Why:** A normal row delete alone can be followed by a merge that uploads or restores an old lesson.

**How to apply:** Add the lesson ID to `STORAGE_KEYS.DELETED_LESSONS` first, then remove the row; preserve the tombstone when creating the next hydration and delete any MP4 URLs belonging to the removed lesson.