import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:manara_student/src/services/student_auth_service.dart';
import 'package:manara_student/src/services/student_content_service.dart';

/// جلسةُ الخادم تنتهي والتطبيقُ مفتوح، فتُجدَّد ببيانات الدخول — لا تُمحى.
///
/// ── العطبُ الذي يمسكه ──
/// كان ردُّ ٤٠١ يُنادي `clearApiSession`، وهي تمحو اسمَ المستخدم وكلمةَ المرور
/// مع الرمز، ثم يُطلب التجديد فلا يجد ما يجدّد به. فبعد اثنتي عشرة ساعة —
/// عمرِ الرمز — يفشل كلُّ طلبٍ للخادم حتى يخرج الطالبُ ويدخل: تختفي ألعابُ
/// معلّمه بلا رسالة، والفهرسُ العامّ فارغٌ حين تُسند الألعابُ كلُّها لمعلّمين.
void main() {
  const base = 'https://manara.test';

  test('رمزٌ منتهٍ يُجدَّد، وتصل ألعابُ المعلم', () async {
    var sessions = 0;
    final seenTokens = <String?>[];
    final client = MockClient((request) async {
      if (request.url.path == '/api/auth/student/session') {
        sessions++;
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        // التجديدُ يُرسل البياناتِ نفسَها التي دخل بها الطالب.
        expect(body['username'], 'student1');
        expect(body['password'], 'secret');
        return http.Response(
          jsonEncode({
            'token': 'token-$sessions',
            'student': {
              'id': 'row-1',
              'data': {'username': 'student1', 'role': 'student'},
            },
          }),
          200,
        );
      }
      if (request.url.path == '/api/student/entertainment') {
        final token = request.headers['Authorization'];
        seenTokens.add(token);
        // الرمزُ الأوّل انتهى عمرُه على الخادم.
        if (token == 'Bearer token-1') {
          return http.Response(jsonEncode({'error': 'expired'}), 401);
        }
        return http.Response(
          jsonEncode({
            'games': [
              {
                'id': 'teacher-game-1',
                'title': 'سوات',
                'url': '/api/game-embed/6b40e38875b743a4957e2bb712864c33/index.html',
              },
            ],
          }),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }
      return http.Response('not found', 404);
    });

    await http.runWithClient(() async {
      final auth = StudentAuthService(
        SupabaseClient('http://127.0.0.1:1', 'test-key'),
        apiBaseUrl: base,
      );
      await auth.signIn(username: 'student1', password: 'secret');
      expect(auth.apiSessionToken, 'token-1');

      final content = StudentContentService(
        SupabaseClient('http://127.0.0.1:1', 'test-key'),
        baseUrl: base,
        authService: auth,
      );
      final games = await content.fetchTeacherGames();

      expect(seenTokens, ['Bearer token-1', 'Bearer token-2']);
      expect(sessions, 2);
      expect(games, hasLength(1));
      expect(
        games.single.url,
        '$base/api/game-embed/6b40e38875b743a4957e2bb712864c33/index.html',
      );
      // والطلبُ التالي بالرمز الجديد، بلا دخولٍ ثالث.
      expect(auth.apiSessionToken, 'token-2');
    }, () => client);
  });

  test('والخروجُ وحده يمحو بيانات الدخول', () async {
    final client = MockClient((request) async => http.Response(
          jsonEncode({
            'token': 'token-x',
            'student': {
              'id': 'row-1',
              'data': {'username': 'student1', 'role': 'student'},
            },
          }),
          200,
        ));
    await http.runWithClient(() async {
      final auth = StudentAuthService(
        SupabaseClient('http://127.0.0.1:1', 'test-key'),
        apiBaseUrl: base,
      );
      await auth.signIn(username: 'student1', password: 'secret');

      auth.expireApiSession();
      expect(auth.apiSessionToken, isNull);
      expect(await auth.ensureApiSession(), 'token-x');

      auth.clearApiSession();
      expect(await auth.ensureApiSession(), isNull);
    }, () => client);
  });
}
