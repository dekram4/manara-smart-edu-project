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

Internal role pages also need explicit shared wrappers for section headers, filter surfaces, card grids, table surfaces, and split detail layouts; adding only a `dashboard-page` root does not normalize legacy inline-style pages.

**Why:** Several menus kept their old bespoke grids and inline surfaces, so the first shell pass did not visibly fix their content layouts.

**How to apply:** Use `dashboard-section-header`, `dashboard-filter-surface`, `dashboard-card-grid`, `dashboard-table-surface`, and `dashboard-internal-layout` on each role-specific menu, including parent child/certificate views and shared chat.

The teacher account screenshot corresponds to the parent/student management page, so visual QA must inspect that route rather than only the admin student-management table.

**Why:** The two account-management screens have different data layouts and the earlier shell-only pass fixed the wrong surface for the reported screenshot.

**How to apply:** When a screenshot is supplied, map its sidebar role and page title to the exact role-specific component before choosing which internal layout to refactor.

Shared dashboard stat-card rules can override utility gradient classes because the shared stylesheet is loaded after utility classes.

**Why:** Account statistics rendered as white cards with nearly invisible light text when the shared surface background won the cascade.

**How to apply:** Give dashboard stat variants explicit component classes with explicit backgrounds and readable text instead of relying only on utility gradient/color classes.

For cross-role UI changes, update the dashboard shell and shared layout primitives first, then remove page-specific height/overflow constraints; individual screens should inherit the same responsive contract.

**Why:** Editing isolated pages repeatedly left the same spacing and clipping defects in other teacher, supervisor, and parent menus.

**How to apply:** Treat teacher, supervisor, and parent shells plus `index.css` as the first implementation surface for any global dashboard overhaul.

Screenshot-driven dashboard work must refactor the actual internal page surface, not only the role shell; shared control, form, table, and navigation primitives need to be visibly applied inside the selected menu.

**Why:** A shell-only pass left legacy inline-styled content-management forms and tables visually unchanged even though the surrounding dashboard had been normalized.

**How to apply:** Map the screenshot to its exact page component first, then create a page-specific shared interior pattern and let the other role pages inherit the common controls.

The teacher screenshot containing “نتائج اختبارات الطلاب” and “أولياء الأمور” maps to the reports screen, not the parent dashboard or account-management screen.

**Why:** The same Arabic labels appear in multiple role contexts, but the teacher sidebar and combined student/results/parent sections identify the reports component.

**How to apply:** Refactor the reports header, search, stats, student table, result cards, and parent cards together when this screenshot pattern is reported.