import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../l10n/student_strings.dart';
import '../models/student_profile.dart';

/// Resolved on each read rather than held in a `const`, so the sentence
/// follows the language the student picked.
String get studentOnlyMessage => tr('auth.studentsOnly');

class StudentAuthException implements Exception {
  const StudentAuthException(this.message);

  final String message;

  @override
  String toString() => message;
}

class StudentAuthService {
  StudentAuthService(this.client, {required this.apiBaseUrl});

  final SupabaseClient client;
  final String apiBaseUrl;
  String? _apiSessionToken;
  String? _apiSessionError;
  String? _sessionUsername;
  String? _sessionPassword;
  String? _sessionStudentId;

  /// Never persist this token. It lives only for the signed-in app session.
  String? get apiSessionToken => _apiSessionToken;
  String? get apiSessionError => _apiSessionError;

  Future<StudentProfile?> restoreActiveStudentSession() async {
    final session = client.auth.currentSession;
    final user = session?.user ?? client.auth.currentUser;
    if (session == null || user == null || session.isExpired) return null;

    try {
      final profileRow = await client
          .from('profiles')
          .select('id,role,full_name,name,grade,student_id_number')
          .eq('id', user.id)
          .maybeSingle();
      var profile = StudentProfile.fromAuthProfile(
        id: user.id,
        profile: _asMap(profileRow),
        username: user.email ?? '',
      );
      // ‏جدول `profiles` مرآة للمصادقة: فيه الاسم والدور والصف، وليس فيه
      // ‏المواد المسندة ولا مسار الطالب. فاستعادة جلسة كانت تُرجِع حساباً
      // ‏ناقصاً — بلا قيد على المواد — فيرى الطالب عند فتح التطبيق من
      // ‏جديد ما لا يراه عند تسجيل دخوله. السجلّ نفسه هو المرجع.
      final row = await _findStudentById(user.id);
      if (row != null) {
        final full = StudentProfile.fromStudentRow(row);
        if (full.isStudent) profile = full;
      }
      if (!profile.isStudent) {
        await client.auth.signOut();
        return null;
      }
      return profile;
    } on AuthException {
      return null;
    } on PostgrestException {
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<StudentProfile> signIn({
    required String username,
    required String password,
  }) async {
    final cleanUsername = username.trim();
    if (cleanUsername.isEmpty || password.isEmpty) {
      throw StudentAuthException(tr('auth.fillBoth'));
    }

    try {
      final student = await _findStudent(cleanUsername);
      if (student != null) {
        final data = _asMap(student['data']);
        final storedPassword = data['password']?.toString();
        if (!_passwordsMatch(password, storedPassword)) {
          throw StudentAuthException(tr('auth.badCredentials'));
        }

        final profile = StudentProfile.fromStudentRow(student);
        if (!profile.isStudent) {
          throw StudentAuthException(studentOnlyMessage);
        }
        _sessionUsername = cleanUsername;
        _sessionPassword = password;
        _sessionStudentId = profile.id;
        await ensureApiSession();
        return profile;
      }

      if (cleanUsername.contains('@')) {
        return _signInWithSupabaseAuth(cleanUsername, password);
      }

      throw StudentAuthException(tr('auth.badCredentials'));
    } on StudentAuthException {
      rethrow;
    } on AuthException catch (error) {
      throw StudentAuthException(_authErrorMessage(error));
    } on PostgrestException catch (error) {
      throw StudentAuthException(
          trf('auth.dataUnreachable', {'error': error.message}));
    } catch (error) {
      throw StudentAuthException(trf('auth.signInError', {'error': error}));
    }
  }

  /// Re-establishes the short-lived API session after a temporary local-server
  /// or network interruption. Credentials stay in memory only for this app run.
  Future<String?> ensureApiSession() async {
    final existing = _apiSessionToken?.trim();
    if (existing != null && existing.isNotEmpty) return existing;
    final username = _sessionUsername;
    final password = _sessionPassword;
    final studentId = _sessionStudentId;
    if (username == null || password == null || studentId == null) return null;
    try {
      await _createApiSession(
        username: username,
        password: password,
        studentId: studentId,
      );
      _apiSessionError = null;
      return _apiSessionToken;
    } catch (error) {
      _apiSessionToken = null;
      _apiSessionError = error is StudentAuthException
          ? error.message
          : tr('auth.serviceUnreachable');
      return null;
    }
  }

  void clearApiSession() {
    _apiSessionToken = null;
    _apiSessionError = null;
    _sessionUsername = null;
    _sessionPassword = null;
    _sessionStudentId = null;
  }

  Future<void> _createApiSession({
    required String username,
    required String password,
    required String studentId,
  }) async {
    var base = apiBaseUrl.trim().replaceFirst(RegExp(r'/$'), '');
    // Flutter Web is served from the same proxied origin as the API. This
    // keeps local browser previews usable without requiring a build-time
    // API_BASE_URL, while native builds still provide their explicit URL.
    if (base.isEmpty) {
      final current = Uri.base;
      if (current.scheme == 'http' || current.scheme == 'https') {
        // `flutter run -d chrome` uses its own random port in the browser,
        // while the managed API workflow listens on 8080. In a hosted
        // preview, /api is proxied on the current origin instead.
        final isLocalBrowser = current.host == 'localhost' ||
            current.host == '127.0.0.1';
        base = isLocalBrowser ? 'http://localhost:8080' : current.origin;
      }
    }
    if (base.isEmpty) {
      throw StudentAuthException(tr('auth.serviceNotConfigured'));
    }
    final response = await http
        .post(
          Uri.parse('$base/api/auth/student/session'),
          headers: const {'Content-Type': 'application/json'},
          body: jsonEncode({
            'username': username,
            'studentId': studentId,
            'password': password,
          }),
        )
        .timeout(const Duration(seconds: 12));
    final payload = response.body.isEmpty ? <String, dynamic>{} : jsonDecode(response.body);
    if (response.statusCode < 200 || response.statusCode >= 300 || payload is! Map) {
      final message = payload is Map ? payload['error']?.toString() : null;
      throw StudentAuthException(
        message?.trim().isNotEmpty == true
            ? message!
            : tr('auth.sessionFailed'),
      );
    }
    final token = payload['token']?.toString().trim();
    if (token == null || token.isEmpty) {
      throw StudentAuthException(tr('auth.sessionFailed'));
    }
    _apiSessionToken = token;
  }

  /// سجلّ الطالب بمعرّفه، أو null إن لم يوجد أو تعذّرت القراءة.
  ///
  /// المعرّف قد يكون مفتاح الصفّ أو المعرّف المكتوب داخل `data`، فيُسأل
  /// عنهما معاً: الحسابات المنشأة من اللوحة تحمل الثاني.
  Future<Map<String, dynamic>?> _findStudentById(String id) async {
    if (id.isEmpty) return null;
    try {
      final byKey = await client
          .from('students')
          .select('id,data')
          .eq('id', id)
          .limit(1);
      if (byKey.isNotEmpty) return _asMap(byKey.first);

      final byData = await client
          .from('students')
          .select('id,data')
          .eq('data->>id', id)
          .limit(1);
      return byData.isEmpty ? null : _asMap(byData.first);
    } catch (_) {
      // تعذّرت القراءة: تبقى الجلسة على ما استُعيد من المصادقة.
      return null;
    }
  }

  Future<Map<String, dynamic>?> _findStudent(String username) async {
    final rows = await client
        .from('students')
        .select('id,data')
        .eq('data->>username', username)
        .limit(1);

    if (rows.isEmpty) return null;
    return _asMap(rows.first);
  }

  Future<StudentProfile> _signInWithSupabaseAuth(
    String email,
    String password,
  ) async {
    final response = await client.auth.signInWithPassword(
      email: email,
      password: password,
    );
    final user = response.user;
    if (user == null) {
      throw StudentAuthException(tr('auth.badCredentials'));
    }

    final profileRow = await client
        .from('profiles')
        .select('id,role,full_name,name,grade,student_id_number')
        .eq('id', user.id)
        .maybeSingle();
    final profile = StudentProfile.fromAuthProfile(
      id: user.id,
      profile: _asMap(profileRow),
      username: email,
    );

    if (!profile.isStudent) {
      await client.auth.signOut();
      throw StudentAuthException(studentOnlyMessage);
    }
    // This legacy email path has no server-verifiable student password row.
    // It can browse permitted Supabase content, but protected chat/AI remains
    // unavailable until an administrator provisions a student username.
    _apiSessionToken = null;
    clearApiSession();
    return profile;
  }

  bool _passwordsMatch(String input, String? stored) {
    if (stored == null || stored.isEmpty) return false;
    final normalized = stored.toLowerCase();
    final isSha256 = RegExp(r'^[a-f0-9]{64}$').hasMatch(normalized);
    if (isSha256) {
      final digest = sha256.convert(utf8.encode(input)).toString();
      return digest == normalized;
    }
    return input == stored;
  }

  String _authErrorMessage(AuthException error) {
    final message = error.message.toLowerCase();
    if (message.contains('invalid login credentials')) {
      return tr('auth.badCredentials');
    }
    if (message.contains('email not confirmed')) {
      return tr('auth.confirmEmail');
    }
    return trf('auth.supabaseFailed', {'error': error.message});
  }
}

Map<String, dynamic> _asMap(Object? value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) {
    return value.map((key, item) => MapEntry(key.toString(), item));
  }
  return <String, dynamic>{};
}