---
name: Private video storage authentication
description: Private Supabase video storage requires a trusted Supabase Auth session or server-side bridge.
---

Private Supabase Storage must not be enabled from the custom role/password authentication alone. The anon client can only upload or create signed URLs safely when a trusted Supabase Auth session or server-side/Edge Function authorization layer establishes the user's identity and ownership.

**Why:** The app's custom SHA-256 login is not represented by `auth.uid()`, so Storage policies cannot reliably distinguish a teacher, admin, or student. Enabling the bucket with only the anon key would risk unauthorized uploads or reads.

**How to apply:** Keep the bucket private, scope object paths to the authenticated owner, issue short-lived signed URLs, and add a real auth bridge or trusted backend before enabling client-side video upload/playback.