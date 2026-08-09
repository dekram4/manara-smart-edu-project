---
name: Admin package precedence
description: How admin-owned permission packages interact with legacy global permissions.
---

For an account assigned an admin-owned package, the package's explicitly stored permission values are the effective policy for that role. Older global permission values may fill fields missing from legacy packages but must not override an explicitly enabled package permission.

**Why:** The admin package editor can show a permission as enabled while a stale legacy global setting still blocks it, causing the account to receive a contradictory “no permission” result.

**How to apply:** Resolve the assigned package by normalized ID, apply admin-owned package fields explicitly, and reserve ceiling/intersection behavior for packages authored by non-admin managers.