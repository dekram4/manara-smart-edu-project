---
name: Gemini student-answer resilience
description: Model ordering and timeout policy for the student problem solver.
---

For student problem-solving requests, prefer Gemini's flash-lite model before the general flash model, try only a short ordered fallback list, and cap each model request.

**Why:** The general flash model can spend tens of seconds returning a temporary high-demand response while flash-lite is available shortly afterward. Allowing an unbounded walk through every discovered model also causes browser requests to be abandoned before an answer returns.

**How to apply:** Keep the lightweight model first, retain a small fallback list for temporary provider failures, and make client retries only for transient HTTP failures. Do not remove the server-side lesson-scope verification while tuning provider reliability.