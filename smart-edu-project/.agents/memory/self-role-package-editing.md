---
name: Self-role package editing
description: Ownership rules for package creation and editing by non-admin roles.
---

Teachers and parents can create and edit packages for their own role from their dashboard. They may also manage the package roles delegated to their scope, but admin-owned packages and packages owned by another account are read-only.

**Why:** The product needs delegated package authoring without allowing a teacher or parent to alter the administrator's global definitions or another account's private package.

**How to apply:** Persist owner role, owner ID, and owner name on non-admin packages; filter visible packages to admin-owned plus current-owner packages; validate ownership before edit/delete and cap all package values against the administrator policy.