---
name: Student chat authorization
description: Why student chat stays disabled until server-enforced message isolation is available.
---

Student chat must not read `public_messages`, `private_messages`, or legacy chat records directly from Flutter until a server-authorized student session and restrictive row-level policies are in place.

**Why:** Filtering message rows in a mobile client is not an access-control boundary; a student could change the requested identifier or call Supabase directly when permissive policies exist.

**How to apply:** Keep the Flutter chat card in its clear privacy-preserving unavailable state. Enable it only alongside server-side identity validation, sender/recipient membership checks, and database policies that deny reads or writes outside the student’s permitted conversations.