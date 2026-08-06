---
name: Flutter game completion rewards
description: Rule for recording game completion and awarding gamification rewards in the Flutter app.
---

Game rewards and the `game_complete` interaction must be emitted exactly once, only after the player completes the full game round. Content-driven games should use lesson content when available and retain a deterministic local fallback.

**Why:** Partial progress, such as matching one memory pair, is not a completed game and can otherwise inflate XP, gems, achievements, and activity reports.

**How to apply:** Keep a local completion guard in multi-step game screens, check the full board or final question state, then call the centralized `AppState.completeGame` method once. Generate questions through the learning service, but never make the network or Gemini key a prerequisite for starting a round.