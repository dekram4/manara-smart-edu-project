---
name: Web global layout
description: Durable layout boundary between the React web dashboards and legacy/student UI styles.
---

The web app's global reset must only establish the document canvas (`html`, `body`, and `#root` at full viewport minimum height, full width, zero margin/padding, RTL). Dashboard scrolling and sizing belong to the shared dashboard shell, not the document root.

**Why:** Broad `overflow` and height rules added during the student/Flutter transition caused unrelated teacher, admin, and parent screens to compress or clip. Legacy/student styles must not redefine the document root.

**How to apply:** Keep dashboard layouts as a shared flex shell with a fixed-width sticky desktop sidebar and a flexible `min-width: 0` main area. Scope any student or mobile-app overflow rules to their component class; never add root-level `overflow: hidden` or fixed-height rules for a page-specific surface.