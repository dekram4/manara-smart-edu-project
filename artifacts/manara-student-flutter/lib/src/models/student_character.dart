import 'package:flutter/material.dart';

/// One character a student can be represented by on the dashboard.
///
/// Adding a new character is a one-line change: append an entry to
/// [StudentCharacters.all]. Nothing else in the app enumerates characters,
/// so the dashboard, the personality screen and any future picker all pick
/// the addition up without a structural change.
@immutable
class StudentCharacter {
  const StudentCharacter({
    required this.id,
    required this.label,
    required this.emoji,
    required this.color,
  });

  /// Stable key. For the characters that come from the personality
  /// screen's shape picker this is the emoji itself, which is what that
  /// screen persists under `appearance['shape']`.
  final String id;
  final String label;
  final String emoji;
  final Color color;
}

/// The catalogue of characters, and the rules for resolving which one a
/// given student has picked.
class StudentCharacters {
  const StudentCharacters._();

  /// Shown when the student has not chosen anything yet.
  static const fallback = StudentCharacter(
    id: '🦸',
    label: 'البطل',
    emoji: '🦸',
    color: Color(0xFF38BDF8),
  );

  /// Extend this list to add characters.
  static const all = <StudentCharacter>[
    fallback,
    StudentCharacter(id: '🧑‍🚀', label: 'رائد الفضاء', emoji: '🧑‍🚀', color: Color(0xFF6366F1)),
    StudentCharacter(id: '🧙', label: 'الساحر', emoji: '🧙', color: Color(0xFF8B5CF6)),
    StudentCharacter(id: '🥷', label: 'النينجا', emoji: '🥷', color: Color(0xFF334155)),
    StudentCharacter(id: '🧑‍🔬', label: 'العالِم', emoji: '🧑‍🔬', color: Color(0xFF0EA5A5)),
    StudentCharacter(id: '🧑‍🎨', label: 'الفنان', emoji: '🧑‍🎨', color: Color(0xFFEC4899)),
    StudentCharacter(id: '🧑‍🚒', label: 'رجل الإطفاء', emoji: '🧑‍🚒', color: Color(0xFFEF4444)),
    StudentCharacter(id: '🧑‍✈️', label: 'الطيار', emoji: '🧑‍✈️', color: Color(0xFF0284C7)),
    StudentCharacter(id: '🦁', label: 'الأسد', emoji: '🦁', color: Color(0xFFF59E0B)),
    StudentCharacter(id: '🐼', label: 'الباندا', emoji: '🐼', color: Color(0xFF64748B)),
    StudentCharacter(id: '🦊', label: 'الثعلب', emoji: '🦊', color: Color(0xFFF97316)),
    StudentCharacter(id: '🌟', label: 'النجمة', emoji: '🌟', color: Color(0xFFFACC15)),
  ];

  static StudentCharacter byId(String? id) {
    if (id == null || id.trim().isEmpty) return fallback;
    final key = id.trim();
    for (final character in all) {
      if (character.id == key) return character;
    }
    return fallback;
  }

  /// The character the student picked on the personality screen, read from
  /// the same `appearance` map that screen writes. Falls back to the
  /// default character rather than showing nothing.
  static StudentCharacter fromAppearance(Map<String, dynamic>? appearance) {
    final character = byId(appearance?['shape']?.toString());
    final tint = _colorFromHex(appearance?['color']?.toString());
    if (tint == null) return character;
    // The student's chosen colour wins over the catalogue default.
    return StudentCharacter(
      id: character.id,
      label: character.label,
      emoji: character.emoji,
      color: tint,
    );
  }

  /// A Ready Player Me portrait, when the student built one. Takes
  /// precedence over the emoji character.
  static String? avatarImageUrl(Map<String, dynamic>? appearance) {
    final value =
        appearance?['readyPlayerMeAvatarImageUrl']?.toString().trim() ?? '';
    if (value.isEmpty) return null;
    final uri = Uri.tryParse(value);
    if (uri == null || !uri.hasScheme) return null;
    if (uri.scheme != 'https') return null;
    return value;
  }

  static Color? _colorFromHex(String? value) {
    var hex = value?.trim().replaceFirst('#', '') ?? '';
    if (hex.length == 6) hex = 'FF$hex';
    if (hex.length != 8) return null;
    final parsed = int.tryParse(hex, radix: 16);
    return parsed == null ? null : Color(parsed);
  }
}
