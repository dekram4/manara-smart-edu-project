---
name: Post-merge dependency setup
description: The legacy web app has its own lockfile and must be installed before its build runs after merges.
---

Post-merge setup must install dependencies for each app that owns a lockfile, not only the workspace root, before running that app's build.

**Why:** The root install can remove or omit packages owned by the nested web app, causing valid imports to fail during the post-merge build.

**How to apply:** Keep the post-merge script non-interactive and detect the package manager/lockfile for both the root and nested app; then build the nested web app.