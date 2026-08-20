---
name: Student content visibility
description: The intended visibility rule for teacher and supervisor managed lessons and videos in the Flutter student app.
---

The Flutter student app limits lesson explanation and Manara Cinema to the student's selected academic path (grade, atram, subject, term, and unit). Lesson explanation shows every lesson in that path and every safe explanation clip attached to the selected lesson. Cinema shows every safe video published in `smartEdu_videos` for that path.

**Why:** Students must see all content their teacher or a supervisor added for their academic path, but must not see content published for other paths.

**How to apply:** Keep the full five-part academic path filter and teacher/supervisor ownership rule. Do not reduce the lesson view to only one clip or the cinema view to a single video. Keep URL safety checks and the existing rule that raw lesson text is not displayed.