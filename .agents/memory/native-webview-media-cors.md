---
name: Native WebView media CORS
description: CORS handling required for locally uploaded MP4 playback in desktop Flutter WebViews.
---

Allow an opaque `Origin: null` only for the public, read-only MP4 streaming endpoint.

**Why:** Desktop Flutter WebViews can load their internal media document with an opaque origin. Rejecting that request before the file route produces a server error even when the MP4 is valid and byte-range streaming is working.

**How to apply:** Keep normal origin checks for every authenticated or mutating API route. If the media endpoint or CORS middleware changes, preserve this narrowly scoped exception and verify a `Range` request with `Origin: null` returns a playable `206` response.