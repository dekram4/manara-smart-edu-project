---
name: GameDistribution embeds
description: The difference between GameDistribution wrapper URLs and direct game iframe paths.
---

GameDistribution links in the common `html5.gamedistribution.com/<id>/?gd_sdk_referrer_url=...` format may render an “is not available here” wrapper with a Play link that opens outside the app. For an in-page iframe, use the direct game path in the form `https://html5.gamedistribution.com/rvvASMiM/<game-id>/index.html`.

**Why:** The wrapper page can intentionally refuse embedded playback even though the underlying game URL is available and embeddable.

**How to apply:** When a user supplies a GameDistribution iframe and asks for same-page playback, preserve the supplied game ID but resolve it to the direct `rvvASMiM/<id>/index.html` path for the iframe source. Do not add a restrictive `sandbox` to these frames: some Unity/HTML5 builds need browser APIs that make the provider fall back to its unavailable-page wrapper.