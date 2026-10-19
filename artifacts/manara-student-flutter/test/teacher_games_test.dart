import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:manara_student/src/models/student_content.dart';
import 'package:manara_student/src/services/student_auth_service.dart';
import 'package:manara_student/src/services/student_content_service.dart';

/// ألعابُ «الترفيه والألعاب» التي يُسندها المشرف إلى معلّم الطالب: تُجلب
/// بجلسة الطالب، وتُقرأ بمحلّل الفهرس نفسه، وأيُّ تعذّرٍ قائمةٌ فارغة.
class FakeAuth implements StudentAuthService {
  @override
  String? get apiSessionToken => 'token';
  @override
  Future<String?> ensureApiSession() async => 'token';
  @override
  void clearApiSession() {}
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  final service = StudentContentService(
    SupabaseClient('http://127.0.0.1:1', 'test-key'),
    baseUrl: 'https://manara.test',
    authService: FakeAuth(),
  );

  Future<List<HtmlGame>> fetchWith(MockClient client) =>
      http.runWithClient(service.fetchTeacherGames, () => client);

  test('تُجلب من مسار الطالب بجلسته، بصيغة الفهرس', () async {
    late http.Request seen;
    final games = await fetchWith(MockClient((request) async {
      seen = request;
      return http.Response(
        jsonEncode({
          'games': [
            {
              'id': 'teacher-game-1',
              'title': 'مغامرة الكسور',
              'subtitle': 'لعبة قصيرة',
              'url': 'https://games.example.com/fractions/',
              'orientation': 'any',
            },
            // رابطٌ غير آمن لا يصل إلى الرفّ.
            {'id': 'bad', 'title': 'x', 'url': 'javascript:alert(1)'},
          ],
        }),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    }));
    expect(seen.url.toString(), 'https://manara.test/api/student/entertainment');
    expect(seen.headers['Authorization'], 'Bearer token');
    expect(games, hasLength(1));
    expect(games.single.id, 'teacher-game-1');
    expect(games.single.title, 'مغامرة الكسور');
    expect(games.single.subtitle, 'لعبة قصيرة');
    expect(games.single.url, 'https://games.example.com/fractions/');
    expect(games.single.orientation, GameOrientation.any);
  });

  test('بطاقةٌ مغلقة أو خادمٌ أقدم: لا ألعاب، ولا خطأ', () async {
    for (final status in [403, 404, 502]) {
      final games = await fetchWith(MockClient((_) async => http.Response(
          jsonEncode({'error': 'x', 'code': 'card_locked'}), status)));
      expect(games, isEmpty, reason: '$status');
    }
  });
}
