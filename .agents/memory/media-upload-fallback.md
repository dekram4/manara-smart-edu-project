---
name: Media upload fallback
description: Behavior when durable Supabase video storage is unavailable during a teacher upload.
---

When Supabase Storage cannot be reached or authorized, accept the teacher's MP4 through the authenticated local-media route and return an explicit warning that the file is not durable.

**Why:** A bad or unavailable Storage credential must not block teachers from adding lesson material entirely, but silently treating local disk as permanent would cause unexpected data loss.

**How to apply:** Keep the local response marked as `storage: "local"` with a visible warning. Prefer repairing the Storage credential and migrating these files; do not remove the ownership checks or make an unavailable remote upload look permanent.