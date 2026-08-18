---
name: Quiz form events
description: Prevents manual quiz question actions from triggering parent-form navigation or resets.
---

Quiz creation UI must not contain nested HTML forms. Use explicit button handlers for AI generation and quiz saving, while keeping the standalone question editor form independent.

**Why:** Nested forms produce browser-dependent submit behavior; clicking the manual question action can submit the outer form and make the application appear to log the user out.

**How to apply:** When adding controls inside quiz creation, use `type="button"` with a direct handler unless the control intentionally submits its own standalone form.