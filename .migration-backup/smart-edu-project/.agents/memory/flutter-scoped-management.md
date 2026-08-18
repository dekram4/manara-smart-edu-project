---
name: Scoped management screens
description: Role-scoping rule for Flutter management and records screens.
---

Management and records screens must consume the same role-scoped getters as dashboards and reports. A hidden navigation entry is not sufficient protection because a teacher can still reach a manager route through another content action.

**Why:** The shared local cache contains all accounts and content; an unscoped management list can expose or mutate records outside the teacher's assignment.

**How to apply:** Use `studentsForCurrentTeacher`, `lessonsForCurrentRole`, `videosForCurrentRole`, and `quizzesForCurrentRole` in manager screens, while keeping mutation guards in `AppState`.