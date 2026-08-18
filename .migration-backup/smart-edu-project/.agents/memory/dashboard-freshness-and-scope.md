---
name: Dashboard freshness and scope
description: Freshness and visibility rules for role-specific dashboard summaries.
---

Dashboard summaries must derive from current persisted state on a short polling interval and clear their session-specific view when the active account disappears or changes. Admin metrics may aggregate globally, while teacher, student, and guardian metrics must use the same ownership or linked-student scope as their detail screens.

**Why:** Dashboard counts are a separate data surface; correct detail-screen filtering does not prevent stale totals, globally exposed quiz results, or misleading activity summaries.

**How to apply:** Keep dashboard refresh cleanup tied to authentication state, calculate active-student windows from real activity timestamps, and pass only linked child results into guardian summaries. Avoid treating array length as activity or using raw global result collections in role-specific dashboards.