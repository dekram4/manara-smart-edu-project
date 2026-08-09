---
name: Permission hierarchy
description: Rules for role permissions, numeric quotas, and parent-specific overrides.
---

The administrator owns the global policy for teachers and parents, including allow/deny switches and quotas. Teacher-specific parent overrides may only reduce the global parent permissions or quota; they must never expand them. A negative quota means unlimited.

**Why:** Permission controls are shared through localStorage and Supabase, so a lower-level account must not be able to grant itself or another account capabilities that the administrator disabled.

**How to apply:** Normalize legacy permission records before reading them, enforce quotas in the mutation handler as well as the UI, and compute effective parent permissions as the intersection of the global policy and the teacher's per-parent settings.