import 'dart:convert';

import 'package:http/http.dart' as http;

/// ما يقوله خادمُ النسخة المفتوحة عن نفسه (`GET /api/edition`).
class OpenEditionInfo {
  const OpenEditionInfo({required this.ready, this.teacherName, this.grades = const []});

  final bool ready;
  final String? teacherName;
  final List<String> grades;

  static OpenEditionInfo fromJson(Object? raw) {
    if (raw is! Map || raw['edition'] != 'open') {
      return const OpenEditionInfo(ready: false);
    }
    final name = raw['teacherName'];
    final grades = raw['grades'];
    return OpenEditionInfo(
      ready: raw['ready'] == true,
      teacherName: name is String && name.trim().isNotEmpty ? name.trim() : null,
      grades: grades is List ? [for (final g in grades) if (g is String && g.trim().isNotEmpty) g.trim()] : const [],
    );
  }
}

/// حسابٌ أنشأه الخادمُ للطالب: يدخل به التطبيقُ مرّةً ثم يحفظه.
class OpenCredentials {
  const OpenCredentials({required this.username, required this.password});

  final String username;
  final String password;
}

class OpenEditionException implements Exception {
  const OpenEditionException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// الكلامُ مع خادم النسخة المفتوحة: سؤالُه عن نفسه، وتسجيلُ الطالب باسمه.
class OpenEditionService {
  OpenEditionService({required this.apiBaseUrl, http.Client? client}) : _client = client ?? http.Client();

  final String apiBaseUrl;
  final http.Client _client;

  /// عنوانُ الخادم؛ وفي الويب بلا عنوانٍ مضبوط فأصلُ الموقع.
  String get _base {
    final base = apiBaseUrl.trim().replaceFirst(RegExp(r'/+$'), '');
    if (base.isNotEmpty) return base;
    final current = Uri.base;
    return current.scheme == 'http' || current.scheme == 'https' ? current.origin : '';
  }

  Future<OpenEditionInfo> info() async {
    final base = _base;
    if (base.isEmpty) return const OpenEditionInfo(ready: false);
    try {
      final response = await _client.get(Uri.parse('$base/api/edition')).timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) return const OpenEditionInfo(ready: false);
      return OpenEditionInfo.fromJson(jsonDecode(response.body));
    } catch (_) {
      return const OpenEditionInfo(ready: false);
    }
  }

  /// يُنشئ حسابَ الطالب في صفّ المعلم الوحيد. [message] لرسالةٍ عامّةٍ تُعرض
  /// حين لا يقول الخادمُ سبباً.
  Future<OpenCredentials> join({
    required String name,
    String? grade,
    String? gender,
    required String fallbackError,
  }) async {
    final base = _base;
    if (base.isEmpty) throw OpenEditionException(fallbackError);
    http.Response response;
    try {
      response = await _client
          .post(
            Uri.parse('$base/api/open/student'),
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode({
              'name': name.trim(),
              if (grade != null && grade.isNotEmpty) 'grade': grade,
              if (gender != null) 'gender': gender,
            }),
          )
          .timeout(const Duration(seconds: 15));
    } catch (_) {
      throw OpenEditionException(fallbackError);
    }
    Object? payload;
    try {
      payload = response.body.isEmpty ? null : jsonDecode(response.body);
    } catch (_) {
      payload = null;
    }
    if (response.statusCode < 200 || response.statusCode >= 300 || payload is! Map) {
      final error = payload is Map ? payload['error'] : null;
      throw OpenEditionException(error is String && error.trim().isNotEmpty ? error.trim() : fallbackError);
    }
    final username = payload['username'];
    final password = payload['password'];
    if (username is! String || username.isEmpty || password is! String || password.isEmpty) {
      throw OpenEditionException(fallbackError);
    }
    return OpenCredentials(username: username, password: password);
  }
}
