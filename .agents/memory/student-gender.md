---
name: Student gender compatibility
description: Backward-compatible gender storage and avatar selection for student records.
---

Student gender is an optional `male`/`female` value so records created before the feature continue to work. Student-specific avatars should be derived through the shared appearance helper, with male as the legacy fallback.

**Why:** Existing data is stored in localStorage and may not contain a gender field; making it required at the type level or assuming every record has it would break older accounts.

**How to apply:** New student creation/edit forms should collect and persist the value, parent embedded child records should stay synchronized, and views should use the shared helper rather than hardcoded student emojis.