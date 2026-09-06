---
name: Mobile role authentication
description: Cross-device authentication requirements for the administrator, teacher, and parent web roles.
---

Teacher and parent sign-in must fall back to server-side verification against shared account records when the browser has no matching local cache. Administrator sign-in remains server-verified. Forced password changes must update the shared account, not only browser storage.

**Why:** New Android and iPhone browsers have empty local storage. Client-only credential lookup made valid adult accounts appear incorrect and made password changes device-specific.

**How to apply:** Treat browser storage as a dashboard cache and session convenience, never as the only credential source. Preserve stable teacher, parent, and student IDs when hydrating a verified account so existing role links remain intact.