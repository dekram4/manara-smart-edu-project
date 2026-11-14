import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:manara_student/src/l10n/student_strings.dart';
import 'package:manara_student/src/models/student_profile.dart';
import 'package:manara_student/src/screens/student_chat_screen.dart';
import 'package:manara_student/src/services/coloring_canvas.dart';
import 'package:manara_student/src/services/coloring_drawings.dart';
import 'package:manara_student/src/services/student_auth_service.dart';

/// لوحاتُ «لوحاتي» في دردشة الصفّ: تُرسل إلى زميلٍ أو إلى المعلّم، وتُشاهد
/// مرّةً فتُبلَّغ — ثم تختفي كالرسائل الأخرى.
class FakeAuth implements StudentAuthService {
  @override
  String? get apiSessionToken => 'token';
  @override
  String? get apiSessionError => null;
  @override
  Future<String?> ensureApiSession() async => 'token';
  @override
  void expireApiSession() {}
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

const profile = StudentProfile(
  id: 'me',
  name: 'أنا',
  username: 'me',
  role: 'student',
  grade: 'الروضة',
  subject: 'الثقافة العامة',
);

// ‏صورةُ PNG حقيقيّة بنقطةٍ واحدة: يفكّها `Image.memory` كما يفكّ لوحةً.
final png = base64Decode('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==');

void main() {
  late List<Map<String, dynamic>> messages;
  late List<http.Request> requests;

  setUp(() {
    requests = [];
    messages = [
      {
        'id': 'chat_1_abcdefgh',
        'from': 'sara',
        'name': 'سارة',
        'to': 'me',
        'message': '',
        'kind': 'image',
        'imageId': 'chatimage_1_abcdefgh',
        'time': '2026-11-14T10:00:00Z',
      },
    ];
  });

  MockClient client() => MockClient((request) async {
        requests.add(request);
        final path = request.url.path;
        if (path.endsWith('/chat/messages')) {
          return http.Response(
              jsonEncode({'messages': messages, 'ephemeral': true, 'visit': '2026-11-14T10:05:00.000Z'}), 200,
              headers: {'content-type': 'application/json; charset=utf-8'});
        }
        if (path.endsWith('/chat/peers')) {
          return http.Response(
              jsonEncode({
                'peers': [
                  {'id': 'teacher:t1', 'name': 'معلّمي', 'teacher': true},
                  {'id': 'sara', 'name': 'سارة'},
                ],
              }),
              200,
              headers: {'content-type': 'application/json; charset=utf-8'});
        }
        if (path.endsWith('/chat/image') && request.method == 'POST') {
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          final message = {
            'id': 'chat_2_mineeeee',
            'from': 'me',
            'name': 'أنا',
            'to': body['to'],
            'message': '',
            'kind': 'image',
            'imageId': 'chatimage_2_mineeeee',
            'time': '2026-11-14T10:06:00Z',
          };
          messages = [...messages, message];
          return http.Response(jsonEncode({'message': message}), 201,
              headers: {'content-type': 'application/json; charset=utf-8'});
        }
        if (path.contains('/chat/image/')) {
          return http.Response.bytes(png, 200, headers: {'content-type': 'image/png'});
        }
        if (path.endsWith('/chat/seen')) return http.Response(jsonEncode({'seen': 1}), 200);
        return http.Response('{}', 404);
      });

  Future<void> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(420, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      home: StudentChatScreen(
        profile: profile,
        apiBaseUrl: 'http://api.test',
        authService: FakeAuth(),
        httpClient: client(),
        loadArtworks: () async => [
          ColoringController(handDrawnDrawings['cat']!())..fillAt(const Offset(150, 150), const Color(0xFFF97316)),
        ],
        renderArtwork: (_) async => png,
      ),
    ));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  List<String> seenIds() => [
        for (final r in requests)
          if (r.url.path.endsWith('/chat/seen')) ...(jsonDecode(r.body)['ids'] as List).cast<String>(),
      ];

  testWidgets('لوحةُ زميل: مغطّاةٌ ولا تُحسب مقروءةً حتى تُشاهد', (tester) async {
    await pump(tester);
    expect(find.byKey(const ValueKey('chat-image-tile')), findsOneWidget);
    expect(find.text(tr('chat.art.tapToView')), findsOneWidget);
    expect(seenIds(), isNot(contains('chat_1_abcdefgh')));

    await tester.tap(find.byKey(const ValueKey('chat-image-tile')));
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.byKey(const ValueKey('chat-image-viewer')), findsOneWidget);
    expect(requests.where((r) => r.url.path.endsWith('/chat/image/chatimage_1_abcdefgh')), hasLength(1));
    expect(seenIds(), contains('chat_1_abcdefgh'));

    await tester.tap(find.descendant(
        of: find.byKey(const ValueKey('chat-image-viewer')), matching: find.text(tr('chat.art.close'))));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text(tr('chat.art.viewed')), findsOneWidget);
  });

  testWidgets('يُرسل لوحةً من «لوحاتي» إلى المعلّم', (tester) async {
    await pump(tester);
    // ‏المعلّمُ في «أرسل إلى» باسمه.
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.text('👩‍🏫 ${tr('chat.teacher')}').last);
    await tester.pump(const Duration(milliseconds: 400));

    await tester.tap(find.byKey(const ValueKey('chat-send-art')));
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.byKey(const ValueKey('chat-art-0')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('chat-art-0')));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    final sent = requests.where((r) => r.url.path.endsWith('/chat/image') && r.method == 'POST').single;
    final body = jsonDecode(sent.body) as Map<String, dynamic>;
    expect(body['to'], 'teacher:t1');
    expect(base64Decode(body['image'] as String), png);
    expect(find.text(tr('chat.art.mine')), findsOneWidget);
  });
}
