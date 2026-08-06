---
name: Supabase sync layer
description: How SmartEdu persists localStorage data to Supabase without rewriting components.
---

# Supabase persistence via sync layer

SmartEdu has ~13k lines of synchronous localStorage reads/writes across role dashboards. To make data persistent/shared without an async rewrite, persistence is a thin sync layer (`db/sync.ts`) wired in `App.tsx` on boot.

## Core decision
- **Hydrate on boot + write-through monkey-patch** instead of rewriting components: `hydrateFromSupabase()` loads tables into localStorage before first render; `installWriteThrough()` patches `window.localStorage.setItem` to mirror writes to Supabase. Components keep using localStorage synchronously and are never touched.
- **Why:** rewriting every read/write to async carries huge regression risk across the whole app; the interception layer achieves shared/persistent data with minimal blast radius.

## Data model decision — per-row JSONB, not relational columns
- Entity tables `(id text pk, data jsonb, updated_at)`; settings/lists/hierarchies in a single `app_kv (key, value jsonb)`.
- **Why:** robust to TS-interface drift, no column mapping to maintain; pragmatic for a fast, low-risk migration.

## Data-loss guards that MUST stay (regressions are silent + destructive)
- **Never overwrite local with empty remote.** On hydrate, if a Supabase table/key is empty but local has data, UPLOAD local (first-run migration) rather than writing `[]` over it.
- **On hydrate read error, do not touch local at all** — overwriting on a transient failure wipes user data.
- **Serialize sync per key** (promise-chain queue) so a slow older write can't land after a newer one and revert Supabase.

## Constraints / gotchas
- DDL must be run once by the user in the Supabase SQL Editor (`db/schema.sql`); only the anon key (VITE_SUPABASE_URL / VITE_SUPABASE_ANON_KEY) is available — no service-role/DB URL, so the agent cannot run migrations.
- `viewEnvVars` masks secret values (returns existence flags, not the string) — cannot read the anon key in code to self-test writes.
- RLS uses permissive allow-all for anon+authenticated. **Security caveat (disclosed, out of scope):** anyone with URL+anon key can read/write. Passwords are SHA-256 hashed (see password-hashing.md), no longer plaintext.
- Session-only keys are intentionally NOT synced: activeStudent, currentTeacher, activeParent, LAST_READ_MESSAGE_*.
- Literal storage keys (not all via STORAGE_KEYS): public chat uses `'CHAT_MESSAGES'`, certificates use `'smartEdu_certificates'`. Entity records key off `id`.
- **Known remaining gap (follow-up):** if writes fail for a whole offline session, next boot's hydrate overwrites the unsynced local changes — no persistent offline queue/reconciliation yet.
