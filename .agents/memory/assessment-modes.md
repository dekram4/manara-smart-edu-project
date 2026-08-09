---
name: Assessment modes
description: Durable rules for the platform's two assessment modes and backward compatibility.
---

The platform has exactly two assessment modes: periodic assessments may be retaken, while teacher assessments allow one result per student and quiz.

**Why:** Older content used unit/term/final categories, but the product requirement now defines behavior rather than academic period labels. Treating legacy values as periodic preserves existing content without retaining a third behavior model.

**How to apply:** Use a stable created-quiz ID for reward deduplication and teacher-attempt checks. Store teacher results in the shared quiz-results collection and the student snapshot so student, teacher, and parent views remain consistent across sessions.