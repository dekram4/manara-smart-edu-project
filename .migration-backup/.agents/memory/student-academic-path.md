---
name: Student academic path
description: Cross-device persistence and restoration rules for the student's current academic selection.
---

The student's current academic path is stored on the shared student record (`grade`, `atram`, `subject`, `term`, and `unit`) and must be restored before using the first enrollment as a fallback.

**Why:** The first enrollment is only a safe default for a new student. Replacing an already saved path with it makes another device repeatedly ask the student to choose the term, subject, chapter, and unit.

**How to apply:** Hydrate shared student records before mounting dashboards, prefer the saved path when it belongs to the selected grade, and only open the selection panel when the saved path is incomplete.