---
name: Teacher media authentication
description: Explains the server-backed teacher session needed for protected MP4 uploads.
---

Teacher MP4 uploads require a signed, HttpOnly teacher session; a browser-only teacher login cannot satisfy the API's authorization checks.

**Why:** The original upload route accepted an administrator session only, which returned 401 for every teacher. In this environment, the configured Supabase service-role key returned 401 during teacher verification, while the configured anonymous key could perform the narrowly scoped teacher lookup.

**How to apply:** Preserve server-side teacher credential verification and the short-lived media-session cookie when evolving upload authorization. Try the service key first, then the anonymous-key fallback; do not replace this with a client-supplied teacher ID or an unverified role header.