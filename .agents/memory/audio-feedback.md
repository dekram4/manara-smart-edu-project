---
name: Local audio feedback
description: Audio interaction decisions for the Manara learning experience.
---

The learning experience uses short original local audio assets for UI feedback instead of remote sound URLs. Each user action should trigger one intentional sound, with reward tiers choosing one clip rather than layering multiple clips.

**Why:** Remote or overlapping effects made the interface feel noisy and could make the same event sound twice.

**How to apply:** Keep new UI, navigation, quiz, and reward events inside the shared audio engine and gate each event to a single playback call. Keep the existing local student welcome recording as the only post-login welcome sound.