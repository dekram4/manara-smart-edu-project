---
name: WebGL fallback
description: Constraint for Three.js backgrounds in Replit previews and restricted browsers.
---

Three.js scenes used as decorative backgrounds need a non-WebGL fallback. Replit's preview browser can lack a usable WebGL context, so rendering the scene unconditionally creates console errors and can leave the background blank.

**Why:** The preview environment reported that a WebGL context could not be created even though the app itself was otherwise healthy.

**How to apply:** Detect WebGL availability before mounting the Three.js canvas and keep CSS gradients, animated orbs, or other lightweight effects as the fallback.