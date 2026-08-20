---
name: Student content visibility
description: The intended visibility rule for teacher and supervisor managed lessons and videos in the Flutter student app.
---

The Flutter student app treats `lesson_configs` as a shared published catalogue: lesson explanation shows all published lesson records, and Manara Cinema shows safe videos extracted from all those records. Neither view is narrowed by the student's selected grade, term, subject, unit, lesson, or teacher assignment.

**Why:** Content managers may publish material outside a student's current academic selection, and the user explicitly expects all teacher/supervisor-managed content to appear.

**How to apply:** Preserve this broad visibility when changing the Flutter content service. Keep URL safety checks and the existing rule that raw lesson text is not displayed.