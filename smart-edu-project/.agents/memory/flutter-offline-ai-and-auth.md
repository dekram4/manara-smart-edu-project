---
name: Flutter offline AI and authentication
description: Flutter keeps learning features offline-first and verifies locally stored account passwords before accepting known usernames.
---

Flutter learning assistance is optional-network functionality: Gemini is used only when a build-time API key is supplied, while deterministic local question generation remains the offline fallback. Account password changes use SHA-256 hashes and existing legacy plaintext values are accepted only for migration compatibility.

**Why:** The native app must remain usable without Supabase, internet, or a configured AI key, while avoiding the old behavior of accepting any password for a known username.

**How to apply:** Keep AI and authentication behind services/state methods; never display or persist new passwords as plaintext, and preserve local fallback behavior when remote calls fail.