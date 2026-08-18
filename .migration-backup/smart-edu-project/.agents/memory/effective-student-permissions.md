---
name: Effective student permissions
description: How student package permissions are surfaced to parents and enforced in student actions.
---

A student's assigned permission package is the source for the effective student permissions shown in parent views. Parent-facing screens should resolve these permissions from the canonical student record, not only from an embedded child snapshot or the parent's own policy.

Sensitive student actions must enforce the effective permission in the mutation path as well as hiding or disabling the control. In particular, changing the selected grade must be rejected before the student record is persisted when `canChangeGrade` is false.

**Why:** Package assignment can be performed by a teacher while the parent is only a consumer of the child's current capabilities; UI-only checks allowed students to continue changing restricted fields.

**How to apply:** Pass the current student record to the shared permission resolver, synchronize embedded parent child snapshots after assignment, and validate the effective permission immediately before writing the student update.