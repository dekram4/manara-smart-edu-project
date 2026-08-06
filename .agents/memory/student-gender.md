---
name: Student gender compatibility
description: Backward-compatible gender storage and avatar selection for student records.
---

Student gender and custom appearance are optional so records created before these features continue to work. Student avatars should be derived through the shared appearance helper, preserving the gender emoji until the student chooses a custom appearance.

**Why:** Existing data is stored in localStorage and may not contain a gender field; making it required at the type level or assuming every record has it would break older accounts.

**How to apply:** New student creation/edit forms should collect and persist the value, student customization should save the optional appearance on the student record, parent embedded child records should stay synchronized, and views should use the shared helper rather than hardcoded student emojis.