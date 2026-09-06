---
name: Flutter video fullscreen contract
description: Interaction and orientation rules shared by lesson and cinema video players.
---

Fullscreen playback must retain an app-owned exit control above the video surface for both YouTube and direct video. Exiting must restore portrait orientation and preserve the current direct-video position and play/pause state in the embedded player.

**Why:** Provider controls can hide or leave the device in landscape, trapping students or making the lesson card appear frozen after returning.

**How to apply:** Keep fullscreen behavior in the shared student video player rather than screen-specific wrappers. Treat MP4 completion as visible UI state and offer an explicit replay action that seeks to zero before playing.