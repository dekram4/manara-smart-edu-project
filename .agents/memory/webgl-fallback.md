---
name: WebGL fallback
description: Constraint for Three.js backgrounds in Replit previews and restricted browsers.
---

Three.js scenes used as decorative backgrounds need a non-WebGL fallback. Replit's preview browser can lack a usable WebGL context, and external GLTF hosts may be unreachable, so rendering or loading the scene unconditionally creates console errors and can leave the background blank.

**Why:** The preview environment reported that a WebGL context could not be created and could not fetch the sample Supabase-hosted GLTF even though the app itself was otherwise healthy.

**How to apply:** Detect WebGL availability before mounting the Three.js canvas, only load GLTF when an explicit reachable URL is supplied, and keep CSS gradients, animated educational symbols, or other lightweight effects as the fallback.