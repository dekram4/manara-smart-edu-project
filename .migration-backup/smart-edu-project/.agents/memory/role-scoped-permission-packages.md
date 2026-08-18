---
name: Role-scoped permission packages
description: Permission package assignment boundaries for teacher and parent dashboards.
---

Permission package assignment is role-scoped: a teacher can assign existing parent and student packages to accounts owned by that teacher, while a parent can assign existing student packages only to their own children. Neither role can create a package that exceeds the administrator policy ceiling.

**Why:** The administrator owns package definitions and the global policy ceiling. Delegated assignment needs to remain useful without allowing one teacher or parent to affect unrelated accounts or grant forbidden capabilities.

**How to apply:** Keep assignment screens filtered by ownership before rendering targets, validate the selected package role before saving, and write both canonical student records and embedded parent child snapshots when a student package changes.