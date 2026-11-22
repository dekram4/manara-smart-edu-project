import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:manara_student/src/l10n/student_strings.dart';
import 'package:manara_student/src/services/student_auth_service.dart';
import 'package:manara_student/src/services/student_chat_inbox.dart';
import 'package:manara_student/src/widgets/chat_arrival_banner.dart';

/// تنبيهُ الرسائل والطالبُ خارج الدردشة: كم ينتظره، وما الذي وصل الآن.
class FakeAuth implements StudentAuthService {
  @override
  Future<String?> ensureApiSession() async => 'token';
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Map<String, dynamic> message(String id, String from, String name, {String kind = 'text', String text = ''}) => {
      'id': id,
      'from': from,
      'name': name,
      'to': 'me',
      'message': text,
      'kind': kind,
      'time': '2026-11-22T10:00:00Z',
    };

void main() {
  late List<Map<String, dynamic>> messages;
  late List<http.Request> requests;

  setUp(() {
    requests = [];
    messages = [
      message('chat_1', 'sara', 'سارة', text: 'مرحبا'),
      message('chat_2', 'me', 'أنا', text: 'رسالتي'),
    ];
  });

  StudentChatInbox inbox() => StudentChatInbox(
        apiBaseUrl: 'http://api.test',
        authService: FakeAuth(),
        myId: 'me',
        // ‏لا نبضَ دوريّ في الاختبار: الفحصُ يُستدعى بيده.
        every: const Duration(hours: 1),
        client: MockClient((request) async {
          requests.add(request);
          return http.Response(jsonEncode({'messages': messages, 'ephemeral': true}), 200,
              headers: {'content-type': 'application/json; charset=utf-8'});
        }),
      );

  test('أوّلُ فحص: ما ينتظره مجتمعاً، ثم الجديدُ وحده باسم مرسله', () async {
    final watcher = inbox();
    final arrivals = <ChatArrival>[];
    final sub = watcher.arrivals.listen(arrivals.add);
    await watcher.check();
    await Future<void>.delayed(Duration.zero);
    expect(watcher.unread.value, 1, reason: 'رسالتي لا تُعدّ');
    expect(arrivals.single.count, 1);
    expect(arrivals.single.name, 'سارة');
    // ‏لا إيصالَ قراءة: التنبيهُ لا يستهلك الرسالة.
    expect(requests.every((r) => r.method == 'GET' && r.url.path.endsWith('/chat/messages')), isTrue);

    await watcher.check();
    await Future<void>.delayed(Duration.zero);
    expect(arrivals, hasLength(1), reason: 'لا جديد: لا تنبيه');

    messages.add(message('chat_3', 'teacher:t1', 'المعلّم', kind: 'image'));
    await watcher.check();
    await Future<void>.delayed(Duration.zero);
    expect(arrivals, hasLength(2));
    expect(arrivals.last.fromTeacher, isTrue);
    expect(arrivals.last.kind, 'image');
    expect(watcher.unread.value, 2);
    expect(ChatArrivalBanner.bodyOf(arrivals.last), tr('chat.arrival.image'));
    await sub.cancel();
    watcher.dispose();
  });

  test('الدردشةُ مفتوحة: لا فحص؛ وبعد إغلاقها لا تنبيهَ لما رآه هناك', () async {
    final watcher = inbox();
    final arrivals = <ChatArrival>[];
    final sub = watcher.arrivals.listen(arrivals.add);
    await watcher.check();
    watcher.pause();
    messages.add(message('chat_4', 'omar', 'عمر', text: 'هيا نلعب'));
    await watcher.check();
    expect(requests, hasLength(1), reason: 'متوقّف: لا يسأل الخادم');

    watcher.resume(quietly: true);
    await Future<void>.delayed(const Duration(milliseconds: 20));
    await Future<void>.delayed(Duration.zero);
    expect(arrivals, hasLength(1), reason: 'رآها في الدردشة');
    expect(watcher.unread.value, 2);

    messages.add(message('chat_5', 'omar', 'عمر', text: 'أين أنت؟'));
    await watcher.check();
    await Future<void>.delayed(Duration.zero);
    expect(arrivals.last.text, 'أين أنت؟');
    await sub.cancel();
    watcher.dispose();
  });

  testWidgets('التنبيهُ: الاسمُ والنصّ، و«افتح» يفتح الدردشة، و«×» يغلقه', (tester) async {
    var opened = 0;
    var closed = 0;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Stack(children: [
          ChatArrivalBanner(
            arrival: const ChatArrival(
              id: 'chat_1',
              name: 'سارة',
              kind: 'text',
              text: 'هل حللتِ الواجب؟',
              fromTeacher: false,
            ),
            onOpen: () => opened++,
            onClose: () => closed++,
          ),
        ]),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text(trf('chat.arrival.title', {'name': 'سارة'})), findsOneWidget);
    expect(find.text('هل حللتِ الواجب؟'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('chat-arrival-open')));
    await tester.tap(find.byKey(const ValueKey('chat-arrival-close')));
    expect(opened, 1);
    expect(closed, 1);
  });

  test('عدّةُ رسائل تنتظر عند الفتح: تنبيهٌ واحدٌ بعددها', () {
    const many = ChatArrival(id: 'x', name: 'سارة', kind: 'text', text: '', fromTeacher: false, count: 3);
    expect(ChatArrivalBanner.titleOf(many), trf('chat.arrival.many', {'n': '3'}));
  });
}
