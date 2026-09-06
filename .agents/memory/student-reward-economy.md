---
name: Student reward economy
description: Product rules for lesson, quiz, cinema, XP, level, and entertainment-game progression.
---

Reward the lesson, not each video source: pressing the completion button for a lesson grants 5 gems once, whether its explanation uses YouTube or MP4. Periodic and final quizzes grant one gem per correct answer; the same quiz never grants a second reward, and the final quiz permits only one attempt.

Cinema viewing never grants rewards. Every 5 earned gems unlocks one additional cinema video.

XP comes from gem milestones: every completed group of 10 gems grants 20 XP. Levels begin at level 1 and advance every 100 XP. Level 1 opens one entertainment game, and each later level opens one additional game.

**Why:** The user confirmed these are the intended web-product economy rules after a prior implementation incorrectly rewarded individual videos and cinema viewing.

**How to apply:** Keep web and Flutter aligned with these rules. Use stable lesson and quiz IDs for one-time reward checks, and order entertainment games so required levels progress 1, 2, 3, and so on.