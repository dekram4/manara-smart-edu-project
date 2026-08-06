---
name: Content hydration and scope
description: Shared content visibility depends on startup hydration and tolerant matching for legacy student records.
---

Teacher content can be present in Supabase while remaining invisible to a student if the dashboard reads localStorage before hydration completes or if an older student has blank term, atram, or unit fields that are treated as literal mismatches.

**Why:** Existing students may only have grade and subject populated, while teacher lessons contain the full academic path; new devices also start with an empty local content list.

**How to apply:** Complete Supabase hydration before mounting role dashboards, and treat blank student academic fields as unspecified during content matching while preserving teacher ownership filtering.