---
name: Dashboard menu layout
description: Durable layout rules for the Arabic teacher, admin, and parent web dashboards.
---

Dashboard sidebars must use non-shrinking menu items with explicit line-height and a dedicated scroll region. A generic `flex-1` wrapper or a page-level `h-screen` fix is not sufficient when Arabic labels wrap: flex children can compress their line box and make text appear overlapped.

**Why:** The same visual defect appeared across all three roles even though their page components were different; the shared failure mode was shrinking navigation items inside a fixed-height sidebar.

**How to apply:** Keep sidebar shells sticky on desktop and fixed on mobile, give the nav `min-height: 0` plus `overflow-y: auto`, and give each menu item `flex: 0 0 auto`, a minimum height, `line-height`, and normal word wrapping.