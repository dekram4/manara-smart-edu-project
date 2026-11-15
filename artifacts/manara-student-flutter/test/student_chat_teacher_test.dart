import 'dart:convert';
import 'dart:io' show gzip;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:manara_student/src/l10n/student_strings.dart';
import 'package:manara_student/src/models/student_profile.dart';
import 'package:manara_student/src/screens/student_chat_screen.dart';
import 'package:manara_student/src/services/student_auth_service.dart';

/// الدردشةُ مع المعلّم في قائمةٍ منفصلة، والملفّات، وقفلُ المعلّم للدردشة.
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
  grade: 'الرابع',
  subject: 'العلوم',
);

void main() {
  late List<Map<String, dynamic>> messages;
  late List<http.Request> requests;
  late bool locked;
  late bool oldServer;
  final doc = Uint8List.fromList(utf8.encode('واجب العلوم: اقرأ الدرس الثالث\n' * 60));

  setUp(() {
    requests = [];
    locked = false;
    oldServer = false;
    messages = [
      {
        'id': 'chat_1_teacherr',
        'from': 'teacher:t1',
        'fromTeacher': true,
        'name': 'المعلّم',
        'to': 'me',
        'message': 'أحسنت في الواجب',
        'kind': 'text',
        'time': '2026-11-15T10:00:00Z',
      },
      {
        'id': 'chat_2_saraaaaa',
        'from': 'sara',
        'name': 'سارة',
        'to': 'all',
        'message': 'مرحباً يا صف',
        'kind': 'text',
        'time': '2026-11-15T10:01:00Z',
      },
      {
        'id': 'chat_3_fileeeee',
        'from': 'teacher:t1',
        'name': 'المعلّم',
        'to': 'me',
        'message': '',
        'kind': 'file',
        'fileId': 'chatfile_3_fileeeee',
        'fileName': 'الواجب.txt',
        'fileSize': doc.length,
        'mime': 'text/plain',
        'time': '2026-11-15T10:02:00Z',
      },
    ];
  });

  http.Response json(Object body, [int status = 200]) => http.Response(jsonEncode(body), status,
      headers: {'content-type': 'application/json; charset=utf-8'});

  MockClient client() => MockClient((request) async {
        requests.add(request);
        final path = request.url.path;
        if (path.endsWith('/chat/messages') && request.method == 'GET') {
          return json({
            'messages': messages,
            'ephemeral': true,
            'visit': '2026-11-15T10:05:00.000Z',
            if (!oldServer) 'locked': locked,
          });
        }
        if (path.endsWith('/chat/peers')) {
          return json({
            'peers': [
              if (!oldServer) {'id': 'teacher:t1', 'name': 'معلّمي', 'teacher': true},
              {'id': 'sara', 'name': 'سارة'},
            ],
          });
        }
        if (locked && request.method == 'POST' && !path.endsWith('/chat/seen')) {
          return json({'error': 'المعلم قام بقفل الدردشة حالياً', 'code': 'chat_locked'}, 423);
        }
        if (path.endsWith('/chat/messages') && request.method == 'POST') {
          return json({'message': {'id': 'chat_9_newwwwww'}}, 201);
        }
        if (path.endsWith('/chat/file') && request.method == 'POST') {
          return json({'message': {'id': 'chat_8_fileeeee', 'fileId': 'chatfile_8_fileeeee'}}, 201);
        }
        if (path.contains('/chat/file/')) {
          return http.Response.bytes(doc, 200, headers: {'content-type': 'text/plain'});
        }
        if (path.contains('/chat/image/')) return json({'error': 'غير موجودة'}, 404);
        if (path.endsWith('/chat/seen')) return json({'seen': 1});
        return http.Response('{}', 404);
      });

  Future<void> settle(WidgetTester tester, [int n = 8]) async {
    for (var i = 0; i < n; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<List<(String, Uint8List)>> pump(WidgetTester tester, {PickedChatFile? pick}) async {
    final saved = <(String, Uint8List)>[];
    tester.view.physicalSize = const Size(420, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      home: StudentChatScreen(
        profile: profile,
        apiBaseUrl: 'http://api.test',
        authService: FakeAuth(),
        httpClient: client(),
        pickDeviceFile: () async => pick,
        saveFile: (name, bytes) async {
          saved.add((name, bytes));
          return true;
        },
      ),
    ));
    await settle(tester, 10);
    return saved;
  }

  testWidgets('«معلّمي» قائمةٌ منفصلة: محادثتُه وحدها، والأصدقاءُ وحدهم', (tester) async {
    await pump(tester);
    expect(find.text('مرحباً يا صف'), findsOneWidget);
    expect(find.text('أحسنت في الواجب'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('chat-tab-teacher')));
    await settle(tester, 4);
    expect(find.text('أحسنت في الواجب'), findsOneWidget);
    expect(find.text('مرحباً يا صف'), findsNothing);
    expect(find.byKey(const ValueKey('chat-file-tile')), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'شكراً أستاذ');
    await settle(tester, 2);
    await tester.tap(find.byIcon(Icons.send_rounded));
    await settle(tester);
    final sent = requests.where((r) => r.url.path.endsWith('/chat/messages') && r.method == 'POST').single;
    expect(jsonDecode(sent.body), {'message': 'شكراً أستاذ', 'to': 'teacher:t1'});
  });

  testWidgets('ملفٌّ من المعلّم: يُفتح بمعاينته ويُحفظ على الجهاز، ويُحسب مقروءاً', (tester) async {
    final saved = await pump(tester);
    await tester.tap(find.byKey(const ValueKey('chat-tab-teacher')));
    await settle(tester, 4);
    await tester.tap(find.byKey(const ValueKey('chat-file-tile')));
    await settle(tester);
    expect(find.byKey(const ValueKey('chat-file-viewer')), findsOneWidget);
    expect(find.byKey(const ValueKey('chat-file-preview')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('chat-file-save')));
    await settle(tester);
    expect(saved.single.$1, 'الواجب.txt');
    expect(saved.single.$2, doc);
    expect(find.text(tr('chat.file.saved')), findsOneWidget);
    final seen = [
      for (final r in requests)
        if (r.url.path.endsWith('/chat/seen')) ...(jsonDecode(r.body)['ids'] as List),
    ];
    expect(seen, contains('chat_3_fileeeee'));
  });

  testWidgets('مستندٌ يُرسل مضغوطاً gzip، ويفكّه الخادمُ كما كان', (tester) async {
    await pump(tester, pick: PickedChatFile('ملاحظات.txt', doc));
    await tester.tap(find.byKey(const ValueKey('chat-send-art')));
    await settle(tester, 6);
    await tester.tap(find.byKey(const ValueKey('chat-attach-file')));
    await settle(tester);
    final sent = requests.where((r) => r.url.path.endsWith('/chat/file') && r.method == 'POST').single;
    final body = jsonDecode(sent.body) as Map<String, dynamic>;
    expect(body['name'], 'ملاحظات.txt');
    expect(body['gzip'], isTrue);
    final payload = base64Decode(body['file'] as String);
    expect(payload.length, lessThan(doc.length));
    expect(gzip.decode(payload), doc);
    expect(body['to'], 'all');
  });

  testWidgets('ملفٌّ تنفيذيّ أو أكبرُ من السقف: لا يُرفع', (tester) async {
    await pump(tester, pick: PickedChatFile('لعبة.exe', Uint8List(100)));
    await tester.tap(find.byKey(const ValueKey('chat-send-art')));
    await settle(tester, 6);
    await tester.tap(find.byKey(const ValueKey('chat-attach-file')));
    await settle(tester);
    expect(find.text(tr('chat.file.unsupported')), findsOneWidget);
    expect(requests.where((r) => r.url.path.endsWith('/chat/file')), isEmpty);
    expect(packChatFile(Uint8List(100)).$2, isFalse, reason: 'الصغيرُ لا يُضغط');
  });

  testWidgets('قفل المعلّمُ الدردشة: سطرٌ ظاهر، ولا يُرسل شيء', (tester) async {
    locked = true;
    await pump(tester);
    expect(find.byKey(const ValueKey('chat-locked-banner')), findsOneWidget);
    expect(find.text('المعلم قام بقفل الدردشة حالياً'), findsWidgets);
    await tester.enterText(find.byType(TextField), 'مرحبا');
    await settle(tester, 2);
    await tester.tap(find.byIcon(Icons.send_rounded));
    await settle(tester);
    expect(requests.where((r) => r.method == 'POST' && !r.url.path.endsWith('/chat/seen')), isEmpty);
    await tester.tap(find.byKey(const ValueKey('chat-send-art')));
    await settle(tester, 6);
    expect(find.byKey(const ValueKey('chat-attach-file')), findsNothing);
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('قُفلت بعد فتح الشاشة: الخادمُ يردّ 423 فتُقال الجملةُ كما هي', (tester) async {
    await pump(tester);
    locked = true;
    await tester.enterText(find.byType(TextField), 'مرحبا');
    await settle(tester, 2);
    await tester.tap(find.byIcon(Icons.send_rounded));
    await settle(tester);
    expect(find.text('المعلم قام بقفل الدردشة حالياً'), findsWidgets);
    expect(find.byKey(const ValueKey('chat-locked-banner')), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('خادمٌ أقدمُ بلا محادثة المعلّم: يُقال ذلك، لا «لا معلّمَ لصفّك»', (tester) async {
    oldServer = true;
    messages.removeWhere((m) => m['from'] == 'teacher:t1');
    await pump(tester);
    await tester.tap(find.byKey(const ValueKey('chat-tab-teacher')));
    await settle(tester, 3);
    expect(find.text(tr('chat.teacher.serverOld')), findsOneWidget);
    expect(find.text(tr('chat.teacher.none')), findsNothing);
    await tester.pump(const Duration(seconds: 5));
  });
}
