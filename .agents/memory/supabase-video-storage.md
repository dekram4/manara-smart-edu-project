---
name: Supabase video storage
description: Durable MP4 upload and playback requirements for Manara across web and Flutter.
---

New MP4 uploads must return public Supabase Storage URLs; local API media paths are only a legacy read/delete fallback.

**Why:** Localhost and workspace disk paths are unavailable to deployed or separately installed student apps, while Flutter can play the public URL directly without an API base URL.

**How to apply:** Keep the video bucket public and restricted to MP4 uploads, never put the service-role key in clients, and show a clear unavailable/permission message when a stored URL cannot be opened. Storage calls must use both `apikey` and `Authorization` headers plus Supabase's client-identification header so modern secret keys work consistently for upload, bucket setup, and deletion.