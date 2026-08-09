---
name: Self-role package editing
description: Ownership rules for package creation and editing by non-admin roles.
---

Teachers and parents cannot create or edit packages for their own role from their dashboard. They may create and edit packages only for the account roles delegated to their scope: teachers manage parent/student packages, while parents manage student packages. Admin-owned packages and packages owned by another account are read-only.

**Why:** Package policy for a user's own role must remain under administrator control; delegated authoring is only for the accounts that the manager owns or supervises.

**How to apply:** Persist owner role, owner ID, and owner name on non-admin packages; allow only delegated target roles in create/edit validation; filter visible packages to admin-owned plus current-owner packages; validate ownership before edit/delete and cap all package values against the administrator policy.