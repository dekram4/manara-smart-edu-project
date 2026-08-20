---
name: Local media storage path
description: Durable placement rules for API-served local MP4 files in the bundled API artifact.
---

Resolve local media storage from the bundled API `dist` directory into the workspace root, and retain a read fallback for the prior in-workspace legacy media directory.

**Why:** One extra parent traversal resolves outside the workspace. Files stored there can disappear when the environment or service restarts, leaving saved lesson records pointing at missing MP4 files.

**How to apply:** When changing the API build layout or media route, recalculate the resolved upload path from the compiled artifact location. Verify a media request still succeeds after an API restart and that byte-range `GET` and `HEAD` requests return `206`.