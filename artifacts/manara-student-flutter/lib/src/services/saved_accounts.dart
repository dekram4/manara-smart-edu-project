import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// حسابٌ محفوظٌ على هذا الجهاز لدخولٍ بلمسة: اسمُ المستخدم وما يُعرض للطفل
/// (اسمُه وشخصيتُه). وكلمةُ المرور ليست هنا — في المخزن المشفّر وحدها.
@immutable
class SavedAccount {
  const SavedAccount({
    required this.username,
    required this.displayName,
    this.appearance,
  });

  final String username;
  final String displayName;

  /// شخصيتُه كما يحفظها ملفُّه — تُرسم بـ`StudentAvatarView(appearance:)`.
  final Map<String, dynamic>? appearance;

  Map<String, Object?> toJson() => {
        'username': username,
        'displayName': displayName,
        if (appearance != null) 'appearance': appearance,
      };

  static SavedAccount? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final username = raw['username'];
    if (username is! String || username.trim().isEmpty) return null;
    final display = raw['displayName'];
    final appearance = raw['appearance'];
    return SavedAccount(
      username: username,
      displayName: display is String && display.trim().isNotEmpty ? display : username,
      appearance: appearance is Map ? Map<String, dynamic>.from(appearance) : null,
    );
  }
}

/// الحساباتُ المحفوظة على التابلت لدخولٍ سريع.
///
/// ── أين تُحفظ ──
/// في `flutter_secure_storage`: على Android مخزنُ المفاتيح (Keystore) يشفّر ما
/// يُكتب، فكلمةُ المرور لا تُقرأ من ملفات التطبيق ولا من نسخةٍ احتياطية.
/// والقائمةُ (الأسماءُ والشخصيات) في المخزن نفسه، وكلمةُ مرور كلِّ حسابٍ في
/// مفتاحٍ وحدَه.
///
/// ── ومتى يُسأل الطالب ──
/// بعد أوّل دخولٍ ناجح لحسابٍ لم يُحفظ ولم يرفض حفظَه ([shouldOffer]). ومن
/// رفض لا يُسأل ثانيةً على هذا الجهاز.
class SavedAccounts {
  SavedAccounts({FlutterSecureStorage? storage}) : _storage = storage ?? _defaultStorage;

  static final SavedAccounts instance = SavedAccounts();

  static const _defaultStorage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  final FlutterSecureStorage _storage;

  static const _listKey = 'manara.savedAccounts';
  static const _declinedKey = 'manara.savedAccounts.declined';
  static String _passwordKey(String username) => 'manara.savedAccounts.pw.${_key(username)}';

  /// اسمُ المستخدم كما يُطابَق: بلا مسافاتٍ حوله وبلا فرق حروفٍ كبيرة.
  static String _key(String username) => username.trim().toLowerCase();

  Future<List<SavedAccount>> load() async {
    try {
      final raw = await _storage.read(key: _listKey);
      if (raw == null || raw.isEmpty) return const [];
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      return [
        for (final entry in decoded)
          if (SavedAccount.fromJson(entry) case final account?) account,
      ];
    } catch (error) {
      // مخزنٌ معطوب أو غيرُ متاح: لا حسابات محفوظة، والدخولُ العاديّ يبقى.
      debugPrint('[accounts] could not read saved accounts: $error');
      return const [];
    }
  }

  Future<String?> passwordFor(String username) async {
    try {
      return await _storage.read(key: _passwordKey(username));
    } catch (_) {
      return null;
    }
  }

  Future<bool> isSaved(String username) async =>
      (await load()).any((account) => _key(account.username) == _key(username));

  /// أوّلُ دخولٍ ناجحٍ لهذا الحساب على الجهاز: لم يُحفظ ولم يُرفض حفظُه.
  Future<bool> shouldOffer(String username) async {
    if (await isSaved(username)) return false;
    return !(await _declined()).contains(_key(username));
  }

  /// يحفظ الحسابَ أو يحدّثه (شخصيةٌ جديدة، كلمةُ مرورٍ تغيّرت) — الأحدثُ أوّلاً.
  Future<void> save(SavedAccount account, String password) async {
    final others = [
      for (final saved in await load())
        if (_key(saved.username) != _key(account.username)) saved,
    ];
    await _storage.write(key: _passwordKey(account.username), value: password);
    await _storage.write(
      key: _listKey,
      value: jsonEncode([account.toJson(), for (final saved in others) saved.toJson()]),
    );
  }

  Future<void> remove(String username) async {
    final kept = [
      for (final saved in await load())
        if (_key(saved.username) != _key(username)) saved.toJson(),
    ];
    await _storage.delete(key: _passwordKey(username));
    await _storage.write(key: _listKey, value: jsonEncode(kept));
  }

  /// رفض الحفظَ: لا يُسأل عن هذا الحساب ثانيةً على هذا الجهاز.
  Future<void> decline(String username) async {
    final declined = await _declined()..add(_key(username));
    await _storage.write(key: _declinedKey, value: jsonEncode(declined.toList()));
  }

  Future<Set<String>> _declined() async {
    try {
      final raw = await _storage.read(key: _declinedKey);
      if (raw == null) return <String>{};
      final decoded = jsonDecode(raw);
      return decoded is List ? {for (final v in decoded) if (v is String) v} : <String>{};
    } catch (_) {
      return <String>{};
    }
  }
}
