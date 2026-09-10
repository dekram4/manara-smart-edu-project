import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// One of the nine characters a student can pick as their picture.
@immutable
class StudentAvatar {
  const StudentAvatar({required this.id, required this.label, required this.asset});

  final String id;
  final String label;
  final String asset;
}

/// The catalogue, and the student's current pick.
///
/// The pick is a single app-wide value rather than a parameter threaded
/// through every screen: the top bar, the dashboard, the chat and the
/// profile card all render whatever this holds, so choosing a character
/// updates them together. It is a [ValueNotifier], so a widget that
/// listens rebuilds the moment the choice changes — no restart, no
/// reload, no passing the selection down a tree.
class StudentAvatars {
  const StudentAvatars._();

  static const _prefsKey = 'manara.student.avatarId';

  /// Adding a character is one entry here. Nothing else enumerates them.
  static const all = <StudentAvatar>[
    StudentAvatar(id: 'a1', label: 'المستكشف', asset: 'assets/images/avatar_1.png'),
    StudentAvatar(id: 'a2', label: 'العالِمة', asset: 'assets/images/avatar_2.png'),
    StudentAvatar(id: 'a3', label: 'القارئ', asset: 'assets/images/avatar_3.png'),
    StudentAvatar(id: 'a4', label: 'المخترع', asset: 'assets/images/avatar_4.png'),
    StudentAvatar(id: 'a5', label: 'المبدعة', asset: 'assets/images/avatar_5.png'),
    StudentAvatar(id: 'a6', label: 'البطل', asset: 'assets/images/avatar_6.png'),
    StudentAvatar(id: 'a7', label: 'النجمة', asset: 'assets/images/avatar_7.png'),
    StudentAvatar(id: 'a8', label: 'المغامر', asset: 'assets/images/avatar_8.png'),
    StudentAvatar(id: 'a9', label: 'الفنانة', asset: 'assets/images/avatar_9.png'),
  ];

  static StudentAvatar get fallback => all.first;

  /// The current pick. Widgets listen to this directly.
  static final ValueNotifier<StudentAvatar> selected =
      ValueNotifier<StudentAvatar>(fallback);

  static StudentAvatar byId(String? id) {
    if (id == null || id.trim().isEmpty) return fallback;
    final key = id.trim();
    for (final avatar in all) {
      if (avatar.id == key) return avatar;
    }
    return fallback;
  }

  /// Reads the stored pick. Called once at startup; a storage failure
  /// simply leaves the default in place rather than blocking the app.
  static Future<void> restore() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      selected.value = byId(prefs.getString(_prefsKey));
    } catch (_) {
      selected.value = fallback;
    }
  }

  /// Applies a pick immediately and persists it in the background — the
  /// UI must not wait on disk to show the character the student just
  /// tapped.
  static Future<void> select(StudentAvatar avatar) async {
    selected.value = avatar;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsKey, avatar.id);
    } catch (_) {
      // The choice still applies for this session if storage is
      // unavailable; it just will not survive a restart.
    }
  }
}
