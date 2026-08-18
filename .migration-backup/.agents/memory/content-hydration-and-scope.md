---
name: Content hydration and scope
description: Shared content visibility depends on startup hydration and tolerant matching for legacy student records.
---

Teacher content can be present in Supabase while remaining invisible to a student if the dashboard reads localStorage before hydration completes or if an older student has blank term, atram, or unit fields that are treated as literal mismatches.

**Why:** Existing students may only have grade and subject populated, while teacher lessons contain the full academic path; new devices also start with an empty local content list.

**How to apply:** Complete Supabase hydration before mounting role dashboards, and treat blank student academic fields as unspecified during content matching while preserving teacher ownership filtering.

Lesson records can legitimately have media links while `lessonContent` is blank; lesson rewards and the student's practice quiz must not be gated only by text content. Use the matched lesson record as the availability signal and provide a safe practice-question fallback.

**Why:** Imported/older lesson records may contain video configuration without written lesson text, which previously made the completion reward and trial questions disappear even though the lesson was available.

**How to apply:** Keep the reward action visible whenever a lesson is matched, and generate clearly labeled local practice questions when no shared question bank or lesson text is available.