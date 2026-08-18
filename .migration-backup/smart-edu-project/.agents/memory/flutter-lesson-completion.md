---
name: Lesson completion progress
description: Cross-device and offline behavior for lesson completion rewards in Flutter.
---

Completing a lesson must be idempotent by lesson ID: repeated presses or revisits do not grant XP, gems, or duplicate completion interactions. Completed lesson IDs are stored locally and included in the student's remote progress record.

**Why:** A completion button can be pressed repeatedly, and students may use multiple devices; without an ID-based guard, rewards and progress diverge.

**How to apply:** Check and add the lesson ID before awarding rewards, persist the set with local progress, merge remote IDs after student sign-in, and keep local progress authoritative while offline work is pending.