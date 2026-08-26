---
name: Flutter Rive loading safety
description: Why routine student loading states should not depend on arbitrary Rive assets.
---

Use Flutter-native indicators for routine loading states. Only render a Rive loader when a screen explicitly opts into an asset known to work with the installed Rive runtime.

**Why:** A bundled Rive asset produced repeated range errors on Flutter Web and left the lesson screen visually stuck before its video list could appear.

**How to apply:** Keep essential navigation and data-loading states independent of Rive. Decorative screens may opt into trusted Rive assets, while reduced-motion mode should remain static.