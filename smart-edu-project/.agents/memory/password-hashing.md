---
name: Password hashing (SHA-256)
description: How SmartEdu stores/compares passwords and why view-password UIs were removed
---

SmartEdu stores all account passwords as SHA-256 hashes (via `utils/password.ts`), NOT plaintext and NOT full Supabase Auth.

**Why:** User explicitly chose client-side hashing and DECLINED migrating to Supabase Auth. Auth stays custom (localStorage write-through to Supabase).

**How to apply:**
- Compare on login with `passwordsMatch(input, stored)` — it hash-compares and falls back to legacy plaintext so pre-migration records still log in.
- Store new passwords with `hashPassword(plain)`; at admin/teacher management save sites use `ensureHashed(...)` (idempotent — leaves a 64-hex hash untouched, hashes plaintext).
- On EDIT forms, blank the password field (never preload the stored hash); treat blank as "keep existing" via `ensureHashed(form.password || existing || DEFAULT_PASSWORD)`. Keep DEFAULT_PASSWORD visible only on CREATE.
- Never show stored passwords in the UI. Parent dashboard "view child password" was replaced with a masked display + "reset password" button.
- One-time migration `db/migratePasswords.ts` hashes existing plaintext for students/parents/teachers + adminSettings.adminPassword; runs in App.tsx after initSupabaseSync, before booting completes (relies on the patched setItem to sync to Supabase).
- Flutter must reject accounts with missing passwords; only the documented demo accounts use the shared `123456` default hash, while admin keeps its separate demo password.
