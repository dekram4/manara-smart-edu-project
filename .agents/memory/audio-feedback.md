---
name: Local audio feedback
description: Audio interaction decisions for the Manara learning experience.
---

The learning experience uses short original local audio assets for UI feedback instead of remote sound URLs. Each user action should trigger one intentional sound, with reward tiers choosing one clip rather than layering multiple clips.

**Why:** Remote or overlapping effects made the interface feel noisy and could make the same event sound twice.

**How to apply:** Keep new UI, navigation, quiz, and reward events inside the shared audio engine and gate each event to a single playback call. Hover playback must be unlocked by a prior pointer/touch/keyboard gesture because browser autoplay policies can reject hover-only audio before the first user interaction. Keep the local Arabic student welcome as the only post-login welcome sound.