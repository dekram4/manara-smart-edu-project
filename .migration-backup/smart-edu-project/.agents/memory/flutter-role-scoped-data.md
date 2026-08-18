---
name: Flutter role-scoped data
description: Role-aware visibility and mutation rules for the native Flutter app.
---

The native app uses derived, role-scoped collections for teacher content and quizzes, student/guardian/teacher reports, certificates, private chat, and management screens. Administrators retain the full view; guardians and students only see linked student records; teachers use ownership, subject, or linked student enrollment as the current association until a dedicated assignment table exists. Supabase student content queries must apply the same student grade/subject scope before returning rows. Per-user progress and avatar state use role+user storage keys; logout/login increments a session epoch so stale async work cannot apply another account's state.

**Why:** The React platform has multiple account roles, so showing the shared local cache directly can expose another user's students, results, certificates, or messages.

**How to apply:** Add new role-sensitive screens through scoped getters in `AppState`, enforce destructive mutations in state methods as well as hiding controls in the UI, and filter remote student lessons/videos in the repository too. Keep the assignment model explicit when Supabase gains a dedicated teacher-student relationship.