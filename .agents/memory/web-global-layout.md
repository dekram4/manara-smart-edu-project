---
name: Web global layout
description: Durable layout boundary between the React web dashboards and legacy/student UI styles.
---

The web app's global reset must only establish the document canvas (`html`, `body`, and `#root` at full viewport minimum height, full width, zero margin/padding, RTL). Dashboard scrolling and sizing belong to the shared dashboard shell, not the document root.

**Why:** Broad `overflow` and height rules added during the student/Flutter transition caused unrelated teacher, admin, and parent screens to compress or clip. Legacy/student styles must not redefine the document root.

**How to apply:** Keep dashboard layouts as a shared flex shell with a fixed-width sticky desktop sidebar and a flexible `min-width: 0` main area. Scope any student or mobile-app overflow rules to their component class; never add root-level `overflow: hidden` or fixed-height rules for a page-specific surface.

Cross-role dashboard pages should use the shared surface primitives for banners, stats, actions, and data regions so card sizing and overflow behavior stay consistent across teacher, admin, and parent views.

**Why:** Per-page Tailwind combinations had diverging minimum heights and grid breakpoints, which made the same kind of card wrap or clip differently between roles.

**How to apply:** Prefer `dashboard-page-banner`, `dashboard-stats-grid`, `dashboard-stat-card`, `dashboard-actions-grid`, and `dashboard-surface` for new dashboard sections; keep fixed heights out of content cards and allow horizontal scrolling only at the data-region boundary.

The same responsive contract applies to role selection, all three login screens, and every dashboard sidebar: use shared shell classes, keep Arabic labels from shrinking, and make mobile navigation an overlay with an explicit close layer.

**Why:** Navigation and authentication were the remaining places where each role had separate spacing, overflow, and mobile behavior, so fixing dashboard content alone left the experience inconsistent.

**How to apply:** Keep sidebars fixed/sticky on desktop and fixed to the right on smaller screens; use an independently scrolling nav and responsive login card. Reuse the shared chat responsive classes when opening support chat from any role.