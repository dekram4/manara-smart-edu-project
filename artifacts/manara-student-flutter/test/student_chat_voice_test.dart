import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:manara_student/src/l10n/student_strings.dart';
import 'package:manara_student/src/models/student_profile.dart';
import 'package:manara_student/src/screens/student_chat_screen.dart';
import 'package:manara_student/src/services/duel_voice_recorder.dart';
import 'package:manara_student/src/services/student_auth_service.dart';
import 'package:manara_student/src/services/student_media_permissions.dart';
import 'package:manara_student/src/widgets/chat_voice.dart';

/// الرسائلُ الصوتية في دردشة الصفّ: الإذن، والتسجيلُ بالضغط المطوّل، والإلغاءُ
/// بالسحب، والإرسال، والتشغيل.
class FakeAuth implements StudentAuthService {
  @override
  String? get apiSessionToken => 'token';
  @override
  String? get apiSessionError => null;
  @override
  Future<String?> ensureApiSession() async => 'token';
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeRecorder implements DuelVoiceRecorder {
  final log = <String>[];
  bool allow = true;
  VoiceNote note = VoiceNote.ready(Uint8List.fromList(List.filled(2048, 7)));
  bool _on = false;

  @override
  VoidCallback? onAutoStop;
  @override
  bool get recording => _on;
  @override
  Future<bool> start() async {
    log.add('start');
    _on = allow;
    return allow;
  }

  @override
  Future<VoiceNote> stop() async {
    log.add('stop');
    _on = false;
    return note;
  }

  @override
  Future<void> cancel() async {
    if (_on) log.add('cancel');
    _on = false;
  }

  @override
  Future<void> dispose() async {}
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

const profile = StudentProfile(
  id: 'me',
  name: 'أنا',
  username: 'me',
  role: 'student',
  grade: 'الصف الرابع',
  subject: 'العلوم',
);

void main() {
  late List<Map<String, dynamic>> messages;
  late List<http.Request> requests;
  late FakeRecorder recorder;
  late MicAccess access;

  setUp(() {
    requests = [];
    recorder = FakeRecorder();
    access = MicAccess.granted;
    messages = [
      {
        'id': 'm1',
        'from': 'sara',
        'name': 'سارة',
        'to': 'all',
        'message': '',
        'kind': 'voice',
        'voiceId': 'chatvoice_1_abcdefgh',
        'durationMs': 4200,
        'time': '2026-10-01T10:00:00Z',
      },
      {
        'id': 'm2',
        'from': 'sara',
        'name': 'سارة',
        'to': 'all',
        'message': 'مرحبا',
        'kind': 'text',
        'time': '2026-10-01T10:01:00Z',
      },
    ];
  });

  MockClient client() => MockClient((request) async {
        requests.add(request);
        final path = request.url.path;
        if (path.endsWith('/chat/messages') && request.method == 'GET') {
          return http.Response(jsonEncode({'messages': messages}), 200,
              headers: {'content-type': 'application/json; charset=utf-8'});
        }
        if (path.endsWith('/chat/peers')) {
          return http.Response(jsonEncode({'peers': []}), 200);
        }
        if (path.endsWith('/chat/voice') && request.method == 'POST') {
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          final message = {
            'id': 'm3',
            'from': 'me',
            'name': 'أنا',
            'to': body['to'],
            'message': '',
            'kind': 'voice',
            'voiceId': 'chatvoice_2_mineeeee',
            'durationMs': body['durationMs'],
            'time': '2026-10-01T10:02:00Z',
          };
          messages = [...messages, message];
          return http.Response(jsonEncode({'message': message}), 201,
              headers: {'content-type': 'application/json; charset=utf-8'});
        }
        if (path.contains('/chat/voice/')) {
          return http.Response.bytes(List.filled(2048, 3), 200,
              headers: {'content-type': 'audio/mp4'});
        }
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
        recorder: recorder,
        micAccess: () async => access,
      ),
    ));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Finder mic() => find.byType(ChatVoiceMicButton);

  testWidgets('رسالةٌ صوتيةٌ من زميل: مشغّلٌ بمدّتها، والنصُّ بجانبها',
      (tester) async {
    await pump(tester);
    expect(find.byType(ChatVoiceNoteView), findsOneWidget);
    expect(find.text('0:04'), findsOneWidget);
    expect(find.text('مرحبا'), findsOneWidget);
  });

  testWidgets('حقلٌ فارغ: ميكروفون؛ وما إن يُكتب: زرُّ إرسال', (tester) async {
    await pump(tester);
    expect(mic(), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'سلام');
    await tester.pump();
    expect(mic(), findsNothing);
    expect(find.byIcon(Icons.send_rounded), findsOneWidget);
  });

  testWidgets('ضغطٌ مطوّل ثم إفلات: يُسجَّل ويُرسل بمدّته', (tester) async {
    await pump(tester);
    final gesture = await tester.startGesture(tester.getCenter(mic()));
    await tester.pump();
    await tester.pump();
    expect(find.byType(ChatRecordingStrip), findsOneWidget);
    expect(find.text(tr('chat.voice.slideCancel')), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
    expect(find.textContaining('0:03 /'), findsOneWidget);
    await gesture.up();
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(recorder.log, ['start', 'stop']);
    final post = requests.singleWhere((r) => r.method == 'POST');
    expect(post.url.path, '/api/student/chat/voice');
    final body = jsonDecode(post.body) as Map<String, dynamic>;
    expect(body['to'], 'all');
    expect(body['durationMs'], greaterThanOrEqualTo(3000));
    expect(base64Decode(body['audio'] as String).length, 2048);
    expect(find.byType(ChatRecordingStrip), findsNothing);
    // وتُحدَّث القائمةُ بعد الإرسال فتظهر رسالتي.
    expect(
      requests.where(
          (r) => r.method == 'GET' && r.url.path.endsWith('/chat/messages')),
      hasLength(2),
    );
  });

  testWidgets('السحبُ بعيداً ثم الإفلات: يُلغى ولا يُرسل شيء', (tester) async {
    await pump(tester);
    final gesture = await tester.startGesture(tester.getCenter(mic()));
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    await gesture.moveBy(const Offset(-150, 0));
    await tester.pump();
    expect(find.text(tr('chat.voice.releaseCancel')), findsOneWidget);
    await gesture.up();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(recorder.log, ['start', 'cancel']);
    expect(requests.where((r) => r.method == 'POST'), isEmpty);
    expect(find.text(tr('chat.voice.cancelled')), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('ضغطةٌ عابرة: «اضغط مطوّلاً» ولا يُرسل شيء', (tester) async {
    await pump(tester);
    final gesture = await tester.startGesture(tester.getCenter(mic()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    await gesture.up();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(recorder.log, ['start', 'cancel']);
    expect(requests.where((r) => r.method == 'POST'), isEmpty);
    expect(find.text(tr('chat.voice.tooShort')), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('رفضٌ نهائيٌّ للإذن: رسالةٌ وزرُّ الإعدادات، ولا تسجيل',
      (tester) async {
    access = MicAccess.blocked;
    await pump(tester);
    final gesture = await tester.startGesture(tester.getCenter(mic()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await gesture.up();
    await tester.pump();
    expect(recorder.log, isEmpty);
    expect(find.text(tr('chat.voice.blocked')), findsOneWidget);
    expect(find.text(tr('chat.voice.settings')), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('رفضٌ الآن: يقال لماذا، ولا تسجيل', (tester) async {
    access = MicAccess.denied;
    await pump(tester);
    final gesture = await tester.startGesture(tester.getCenter(mic()));
    await tester.pump();
    await gesture.up();
    await tester.pump();
    expect(recorder.log, isEmpty);
    expect(find.text(tr('chat.voice.denied')), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('جهازٌ بلا ميكروفون: يقال ذلك', (tester) async {
    recorder.allow = false;
    await pump(tester);
    final gesture = await tester.startGesture(tester.getCenter(mic()));
    await tester.pump();
    await gesture.up();
    await tester.pump();
    expect(find.byType(ChatRecordingStrip), findsNothing);
    expect(find.text(tr('chat.voice.noMic')), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('التشغيل: يُجلب المقطعُ مرّةً واحدة', (tester) async {
    await pump(tester);
    await tester.tap(find.byIcon(Icons.play_arrow_rounded));
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    final fetches =
        requests.where((r) => r.url.path.contains('/chat/voice/')).toList();
    expect(fetches, hasLength(1));
    expect(fetches.single.url.path,
        '/api/student/chat/voice/chatvoice_1_abcdefgh');
    expect(fetches.single.headers['Authorization'], 'Bearer token');
    await tester.pump(const Duration(seconds: 6));
  });
}
