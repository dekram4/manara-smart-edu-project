---
name: Interactive tutor iframe permissions
description: Browser permissions required by third-party virtual tutor embeds in Flutter Web.
---

Interactive tutor URLs displayed in Flutter Web must delegate camera and microphone access through the iframe's `allow` policy. Keep that delegation limited to the virtual tutor surface rather than applying it to all lesson video embeds.

**Why:** Third-party tutor providers can load successfully but then fail their `getUserMedia` request with a “microphone blocked” message and remain in their own loading state when the iframe has no explicit feature delegation.

**How to apply:** When adding a new interactive tutor, preserve the opt-in permission flag on its shared embedded-content player. Video explanations and ordinary external links should remain permission-free by default.