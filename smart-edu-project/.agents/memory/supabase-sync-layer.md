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
- The web app uses a server-side Supabase bridge (`server/supabase-bridge.js`) with `SUPABASE_URL` and `SUPABASE_ANON_KEY` stored as Replit Secrets; keys never reach the browser.
- DDL must be run once by the user in the Supabase SQL Editor (`db/schema.sql`); REST access cannot create these tables.
- The Replit Supabase connector may show as added but expose no usable credentials; direct server-side Secrets are the reliable runtime path.
- RLS uses permissive allow-all for anon+authenticated. **Security caveat (disclosed, out of scope):** anyone with URL+anon key can read/write. Passwords are SHA-256 hashed (see password-hashing.md), no longer plaintext.
- Session-only keys are intentionally NOT synced: activeStudent, currentTeacher, activeParent, LAST_READ_MESSAGE_*.
- Literal storage keys (not all via STORAGE_KEYS): public chat uses `'CHAT_MESSAGES'`, certificates use `'smartEdu_certificates'`. Entity records key off `id`.
- **Known remaining gap (follow-up):** if writes fail for a whole offline session, next boot's hydrate overwrites the unsynced local changes — no persistent offline queue/reconciliation yet.
