---
name: MANARA API routing
description: Durable decisions made porting MANARA's Express backend into artifacts/api-server — Express 5 quirks and artifact URL routing.
---

## Express 5 named wildcards
Express 5 (path-to-regexp 8) requires named wildcards. Use `*name` not bare `*`.
```
// WRONG (throws PathError at startup)
router.get('/game-embed/:gameId/*', ...)
// CORRECT
router.get('/game-embed/:gameId/*gameAssetPath', ...)
```
The named param may be delivered as a string or an array of segments; always normalize:
`Array.isArray(p) ? p.join('/') : p`

**Why:** path-to-regexp 8 is strict; unnamed wildcards are rejected at route registration, not at request time.

## Artifact URL routing: uploads must go through /api
The web artifact owns `/` with a catch-all SPA rewrite. Any URL NOT prefixed `/api` will be served as `index.html` by the web artifact.
Upload responses must return `/api/media/videos/<uuid>.mp4`, not `/uploads/videos/<uuid>.mp4`, so the browser fetches the file through the API artifact's static handler.

**Why:** `/uploads/videos/` is served by `express.static` in the api-server, but a bare `/uploads/...` URL is caught by the manara web artifact's catch-all rewrite first and returns the SPA.
