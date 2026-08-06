---
name: React ownership and rewards
description: Ownership fallback and per-student gamification rules for the React platform.
---

When a record has both `teacherId` and `createdBy`, `teacherId` is the current owner and `createdBy` is the legacy fallback. An explicitly empty `teacherId` remains an intentional unassigned scope; it must not fall back to another teacher or broad content.

Gamification storage and completion markers must be scoped to the active student's stable identity. Lesson and video rewards are idempotent by activity ID, so polling, revisiting, or switching modules cannot duplicate rewards or leak progress between accounts.

**Why:** The platform supports legacy records and multiple student accounts in one browser. Direct `createdBy` comparisons caused old parent-created students and newer teacher-owned records to diverge, while global reward keys could transfer XP, gems, or completion state across accounts.

**How to apply:** Route ownership reads through the shared scope helper, preserve the student's teacher assignment when a guardian creates a child, and require an activity ID before granting a lesson/video reward. Keep account/session cleanup separate from the per-student reward namespace.