import 'package:flutter_test/flutter_test.dart';

import 'package:manara_student/src/models/student_gamification.dart';

/// The level formula, pinned at its boundaries.
///
/// It changed from `⌊xp/100⌋ + 1` to `⌊xp/100⌋`, so a new student now starts at
/// level 0 and reaches level 1 at exactly 100 XP. An off-by-one here is
/// invisible in normal play — every level simply reads one too high — which is
/// precisely why the boundaries are worth nailing down.
void main() {
  group('level is derived from xp, never trusted from storage', () {
    test('0–99 XP is level 0', () {
      for (final xp in [0, 1, 50, 99]) {
        expect(StudentGamification.fromMap({'xp': xp}).level, 0,
            reason: '$xp XP should be level 0');
      }
    });

    test('100 XP is exactly level 1', () {
      expect(StudentGamification.fromMap({'xp': 100}).level, 1);
      expect(StudentGamification.fromMap({'xp': 199}).level, 1);
    });

    test('200 XP is level 2, and it keeps stepping', () {
      expect(StudentGamification.fromMap({'xp': 200}).level, 2);
      expect(StudentGamification.fromMap({'xp': 999}).level, 9);
      expect(StudentGamification.fromMap({'xp': 1000}).level, 10);
    });

    test('a stale stored level is ignored in favour of the formula', () {
      // Older snapshots carry a level written under the previous formula.
      // Trusting it would show a student one level higher than they are.
      final stale = StudentGamification.fromMap({'xp': 100, 'level': 42});
      expect(stale.level, 1);
    });

    test('copyWith re-derives the level when xp changes', () {
      final base = StudentGamification.fromMap({'xp': 0});
      expect(base.level, 0);
      expect(base.copyWith(xp: 100).level, 1);
      expect(base.copyWith(xp: 250).level, 2);
    });

    test('a default snapshot starts at level 0', () {
      expect(const StudentGamification().level, 0);
    });
  });

  group('the gem→xp rule still holds', () {
    test('50 gems is 100 XP and therefore level 1', () {
      // This is the combination the dashboard sets by hand for a pilot
      // account, so it must fall out of the formula rather than fight it.
      const gems = 50;
      final xp = (gems ~/ 10) * 20;
      expect(xp, 100);
      expect(StudentGamification.fromMap({'xp': xp}).level, 1);
    });

    test('10 gems is 20 XP and therefore still level 0', () {
      final xp = (10 ~/ 10) * 20;
      expect(xp, 20);
      expect(StudentGamification.fromMap({'xp': xp}).level, 0);
    });
  });

  test('level progress is the remainder within the current level', () {
    expect(StudentGamification.fromMap({'xp': 0}).levelProgress, 0);
    expect(StudentGamification.fromMap({'xp': 140}).levelProgress, 40);
    expect(StudentGamification.fromMap({'xp': 140}).xpToNextLevel, 60);
  });
}
