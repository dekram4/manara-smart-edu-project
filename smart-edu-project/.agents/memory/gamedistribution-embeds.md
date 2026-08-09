---
name: GameDistribution embeds
description: The difference between GameDistribution wrapper URLs and direct game iframe paths.
---

GameDistribution links in the common `html5.gamedistribution.com/<id>/?gd_sdk_referrer_url=...` format may render an “is not available here” wrapper with a Play link that opens outside the app. For an in-page iframe, use the direct game path in the form `https://html5.gamedistribution.com/rvvASMiM/<game-id>/index.html`.

**Why:** The wrapper page can intentionally refuse embedded playback even though the underlying game URL is available and embeddable.

**How to apply:** When a user supplies a GameDistribution iframe and asks for same-page playback, preserve the supplied game ID and resolve it to the direct `rvvASMiM/<id>/index.html` path. Use a targeted iframe sandbox that allows scripts, same-origin, forms, pointer/orientation lock, and modals, but never allows popups or top navigation; this blocks provider ad redirects while preserving the direct game runtime.