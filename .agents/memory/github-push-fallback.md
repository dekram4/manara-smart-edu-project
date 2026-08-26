---
name: GitHub push fallback
description: How to publish a verified local change when the workspace Git remote lacks credentials.
---

When the local Git remote rejects authentication but the GitHub connection is attached with repository write access, publish through the connection's Git REST endpoints instead of requesting credentials.

**Why:** Workspace shell credentials and the managed GitHub connection are independent. A failed shell `git push` does not mean the attached GitHub connection lacks permission.

**How to apply:** Verify the connected account can access the target repository, create the commit against the current remote branch through the GitHub REST API, then fetch and reset the local branch to the verified remote commit so history is aligned.