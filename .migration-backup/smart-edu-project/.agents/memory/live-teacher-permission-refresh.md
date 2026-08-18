---
name: Live teacher permission refresh
description: Keep teacher dashboard visibility aligned with the persisted teacher package.
---

The teacher dashboard must refresh the current teacher record from persisted storage before evaluating sidebar visibility or opening protected screens. Academic settings and other feature visibility depend on the latest assigned package, not a stale login snapshot.

**Why:** Administrators can change a teacher's package while the teacher session is open. Without refreshing the account, the dashboard can hide a permission that was just granted or keep showing one that was removed.

**How to apply:** Resolve effective teacher permissions from the current account object, refresh that object periodically or after account/package mutations, and repeat the permission check inside the protected screen itself.