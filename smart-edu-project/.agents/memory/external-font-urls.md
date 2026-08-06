---
name: External font URLs
description: Reliability rule for remotely hosted font assets in the React preview.
---

Google Fonts CSS can continue to resolve while an older hard-coded `fonts.gstatic.com` asset URL returns 404. When keeping explicit `@font-face` declarations, use the current URLs from the Google Fonts stylesheet or rely on the stylesheet instead of duplicating stale paths.

**Why:** A stale font asset generated a browser 404 even though the Vite workflow, local assets, and React render were healthy.

**How to apply:** When preview logs show an unexplained 404, inspect external CSS/font URLs as well as local assets. Prefer `font-display: swap` and keep explicit font declarations synchronized with the provider's current stylesheet.