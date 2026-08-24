---
name: Student chat authorization
description: Rules for the server-authorized student chat channel and its privacy boundary.
---

Student chat must never read `public_messages`, `private_messages`, or legacy chat records directly from Flutter or the web dashboard. Use only the server-authorized student chat channel, whose short-lived signed student session is validated against the current student record on every request.

**Why:** Filtering message rows in a client is not an access-control boundary; a student could change the requested identifier or call Supabase directly when permissive policies exist. The server must derive the grade and assigned teacher from the verified account, and must not trust client-provided scope fields.

**How to apply:** Keep message visibility limited to public messages in the student’s grade/teacher scope plus messages sent by or directly to that student. Validate the recipient is an eligible peer in the same scope before writing. Keep sessions in memory only on native clients; never use a client-provided student ID or localStorage identity as authorization.