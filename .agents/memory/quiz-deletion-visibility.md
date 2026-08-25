---
name: Quiz deletion visibility
description: How deleted teacher assessments stay hidden on student devices after cross-device synchronization.
---

Student-facing assessment lists must exclude a quiz when either its record is marked deleted or its ID appears in the synchronized quiz-deletion tombstones. They must also require the quiz to be active.

**Why:** A student device can retain an old quiz record while another device has already deleted it. The tombstone is the cross-device source that prevents this stale copy from being displayed or uploaded again.

**How to apply:** Any new student quiz list or direct quiz-opening path must apply all three checks—tombstone ID, record deletion flag, and active state—and must not offer synthetic quiz cards when no published managed assessment exists.