---
name: Explicit teacher assignment for student video scope
description: How student-teacher assignment interacts with legacy subject-based video visibility.
---

When a student has an explicit teacher assignment, video visibility must require the video's owner to match that teacher. Subject-based matching is only a legacy fallback for students without an assignment.

**Why:** Multiple teachers can teach the same subject, so using subject alone can expose another teacher's private video records.

**How to apply:** Preserve `teacherId` through local persistence, remote sync, hydration, account editing, and role-scoped getters. Treat an explicitly cleared assignment as intentional, not as permission to fall back to subject matching.