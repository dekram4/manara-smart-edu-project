---
name: Progress sync boundary
description: The application keeps localStorage as its synchronous data boundary while Supabase persistence happens through intercepted writes.
---

Student-facing reward values may originate in scoped localStorage keys, but parent and teacher views must consume a shared snapshot on the student record. That snapshot needs to be written with the normal localStorage entity key so the existing write-through synchronization persists it to Supabase.

**Why:** The app's existing persistence layer intercepts entity writes rather than observing arbitrary gamification keys, so changing only the reward engine cannot make progress visible to other roles or durable remotely.

**How to apply:** When adding student progress fields, update the shared student snapshot after login and every reward/result mutation; keep readers tolerant of older students with no snapshot.