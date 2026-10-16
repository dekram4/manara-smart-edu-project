import 'dart:convert';

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
      // ‏مسارُ البريد القديم (مصادقة Supabase): ملفُّه من `profiles` وحده.
      // ‏كان يُكمَّل من جدول `students` بالمفتاح العام، والجدولُ لم يعد
      // ‏مقروءاً به — سجلّاتُ الطلاب لا تُقرأ إلا عبر الخادم.
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
      // ‏التحقّقُ كلُّه في الخادم: يُرسل اسمُ المستخدم وكلمةُ المرور، فيعود
      // ‏رمزُ الجلسة وملفُّ الطالب بلا كلمة مرورٍ ولا هويةٍ ولا جوال وليّ أمر.
      //
      // ‏كان التطبيق يقرأ صفَّ الطالب من `students` بالمفتاح العام ويقارن
      // ‏بصمةَ كلمة المرور على الهاتف — فكان الجدولُ كلُّه مقروءاً لكل من
      // ‏يملك المفتاح المضمَّن في أيّ APK.
      final Map<String, dynamic> session;
      try {
        session = await _createApiSession(
          username: cleanUsername,
          password: password,
        );
      } on StudentAuthException {
        // ‏حسابٌ قديم بمصادقة Supabase بالبريد: ليس في جدول الطلاب، فيرفضه
        // ‏الخادم — فيُجرَّب مسارُه الخاص قبل أن يُقال إن البيانات خاطئة.
        if (cleanUsername.contains('@')) {
          return _signInWithSupabaseAuth(cleanUsername, password);
        }
        rethrow;
      }
      final row = _asMap(session['student']);
      if (row.isNotEmpty) {
        final profile = StudentProfile.fromStudentRow(row);
        if (!profile.isStudent) {
          clearApiSession();
          throw StudentAuthException(studentOnlyMessage);
        }
        _sessionUsername = cleanUsername;
        _sessionPassword = password;
        _sessionStudentId = profile.id;
        return profile;
      }
      clearApiSession();
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

  /// ينشئ جلسة الخادم ويعيد جسمَ ردّه (الرمز وملفّ الطالب).
  ///
  /// ردُّ ٤٠١ — اسمٌ أو كلمةُ مرورٍ خاطئة — يُرمى `auth.badCredentials`
  /// لا رسالةَ الخادم: الطفل يرى الجملةَ نفسها في كل رفضٍ لبياناته.
  Future<Map<String, dynamic>> _createApiSession({
    required String username,
    required String password,
    String? studentId,
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
            if (studentId != null && studentId.isNotEmpty) 'studentId': studentId,
            'password': password,
          }),
        )
        .timeout(const Duration(seconds: 12));
    final payload = response.body.isEmpty ? <String, dynamic>{} : jsonDecode(response.body);
    if (response.statusCode == 401) {
      throw StudentAuthException(tr('auth.badCredentials'));
    }
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
    return _asMap(payload);
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