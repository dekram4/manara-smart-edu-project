# منصة منارة المعرفة التعليمية (MANARA SYSTEM)

## Overview
SmartEdu / منصة منارة المعرفة التعليمية is an Arabic, right-to-left (RTL) educational platform built with
React 19 + TypeScript + Vite. It supports four roles — admin (مشرف), teacher (معلم),
student (طالب), and parent (ولي أمر) — each with its own login screen and dashboard.

Authentication is custom and client-side. Data is kept in localStorage with a
write-through sync layer to Supabase. Passwords are hashed with SHA-256
(see `utils/password.ts` and `db/migratePasswords.ts`).

## Project Structure
- `App.tsx` — top-level routing via `mainView` state ('role' | 'admin' | 'teacher' | 'student' | 'parent').
- `pages/RoleSelection.tsx` — landing page where the user picks a role.
- `pages/<role>/<Role>Login.tsx` — login screens (rendered by each dashboard when unauthenticated).
- `pages/<role>/<Role>Dashboard.tsx` — per-role dashboards.
- `db/` — Supabase sync and password migration.
- `utils/password.ts` — SHA-256 hashing and password matching helpers.
- `public/` — static assets served at the site root (e.g. `/logo-badge.png`).

## Branding
- Brand: منصة منارة المعرفة التعليمية — MANARA SYSTEM.
- Logo asset: `public/logo-badge.png` (square emblem cropped from the supplied logo),
  used as the favicon, on the role-selection page, on all four login screens, and in
  each dashboard header/sidebar. Reference it by the URL path `/logo-badge.png`.

## Dev Notes
- Dev server runs via the `Start application` workflow (`npm run dev`) on port 5000.
- The app is RTL (`<html dir="rtl">`); a back button ("رجوع لاختيار الحساب") on each
  login returns to the role-selection page via the dashboard's `onLogout`.

## User preferences
- Communicate in Arabic.
- In the entertainment section, include only games whose embedded iframe links the user has provided; do not add built-in or suggested games.
