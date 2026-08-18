---
name: Deleted quiz tombstones
description: Durable deletion behavior for quizzes shared through localStorage and Supabase.
---

Shared quizzes must retain a synced deletion marker instead of being physically removed from the local collection.

**Why:** Another device can still hold the old quiz locally; the sync layer merges local records and may upload that stale record again if the deletion has no remote marker.

**How to apply:** Mark deleted quizzes inactive and hidden, persist the marker through the normal localStorage write-through path, and exclude marked records from admin, teacher, and student quiz lists.