---
name: Theming / brand palette
description: How the app's colors map to the MANARA logo and how to retheme consistently.
---

# Brand theming (MANARA SYSTEM)

The app has NO central color token file in components — colors are hardcoded
Tailwind classes spread across ~22 page files. To retheme globally without
editing every file, the brand palette is injected by **overriding default
Tailwind color scales** in `tailwind.config.js` (`theme.extend.colors`):

- `indigo` = primary brand (teal/cyan/navy ramp). It was the app's dominant
  primary color, so overriding it reskins most surfaces (buttons, headers,
  sidebars, focus rings, gradients) automatically.
- `purple` = secondary (deep ocean navy). Makes `indigo->purple` gradients read
  as teal->navy.
- `blue` = tertiary accent, overridden to a harmonized cyan-blue ramp (~120
  usages) so it tunes with the teal brand instead of vivid default blue.
  Safe because blue carries no warning/danger semantics here.
- Interactive `*-600` shades were darkened so white-on-600 meets WCAG AA
  (~4.5:1); the obvious teal #0b8693 failed at 4.33:1.
- `brand` / `accent` aliases added for new work.

**Why:** user wanted a full theme matching the logo (deep navy + teal/cyan +
emerald). Central palette override = one place to change, no risk of missing files.

**How to apply / gotchas:**
- Keep override scales monotonic (50 lightest → 950 darkest) or gradients invert.
- `blue`, `green`, `orange`, `red`, `amber`, `slate` are left as Tailwind defaults
  on purpose (orange/red/amber carry warning/danger semantics in many files).
- Role-selection cards (`pages/RoleSelection.tsx`) are colored explicitly:
  student=cyan, teacher=teal, parent=emerald, admin=purple(→navy).
- Changing `tailwind.config.js` may need a workflow restart for the JIT rebuild.
- Some print/report HTML (e.g. ParentDashboard report) uses inline hex colors
  (#1e40af etc.) that are NOT covered by the Tailwind override.
