---
name: MANARA port layout
description: How the original smart-edu-project was structured and how it maps to the new monorepo layout under artifacts/manara/src/.
---

## Original structure (.migration-backup/smart-edu-project/)
- App.tsx, index.tsx, index.css — at project ROOT
- pages/ — at root; subfolders: admin, teacher, student, parent, shared
- utils/ — at root
- db/ — at root (sync.ts, remoteSupabase.ts, migratePasswords.ts)
- constants.ts, types.ts, supabaseClient.ts, permissions.ts — at root
- src/components/ — ONE LEVEL below root (not inside pages)
- public/ — static assets

## New structure (artifacts/manara/src/)
- App.tsx — moved to src/App.tsx (import './src/components/X' → './components/X')
- pages/ → src/pages/
- utils/ → src/utils/
- db/ → src/db/
- constants.ts, types.ts, supabaseClient.ts, permissions.ts → src/
- src/components/ (original) → src/components/ (same subfolder name, but now depth-1 under src/)

## Import depth corrections made
- src/components/*.tsx: `../../utils/` → `../utils/`, `../../types` → `../types`, `../../constants` → `../constants`
- src/components/effects/*.tsx: `../../../utils/` → `../../utils/`, etc.
- src/pages/X/*.tsx: `../../src/components/` → `../../components/`
- src/pages/student/components/*.tsx: `../../../src/components/` → `../../../components/`
- src/pages/RoleSelection.tsx: `../src/components/` → `../components/`

## CSS: Tailwind v3 → v4 conversion
- Replaced `@tailwind base/components/utilities` with `@import 'tailwindcss'`
- Added `@theme {}` block with custom brand colors (indigo/blue/purple overrides) and Tajawal font
- Original animations and CSS classes kept verbatim below the @theme block

## Boot behavior
- App shows Arabic boot loader for ~2.5s while attempting Supabase sync via /api/supabase/* bridge
- If API server is unavailable, app falls through to localStorage-only mode after timeout
- Screenshot tool reloads the page, always captures during boot window — this is expected

**Why:** The `remoteSupabase.ts` module probes `/api/supabase/health` and uses server-side Supabase bridge, not the VITE_ browser client. Supabase task (#3) needs to set up those API routes.
