import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:manara_student/src/l10n/student_strings.dart';
import 'package:manara_student/src/models/student_profile.dart';
import 'package:manara_student/src/screens/drawing_studio_screen.dart';
import 'package:manara_student/src/screens/student_chat_screen.dart';
import 'package:manara_student/src/services/coloring_canvas.dart';
import 'package:manara_student/src/services/coloring_cloud.dart';
import 'package:manara_student/src/services/drawing_studio.dart';
import 'package:manara_student/src/services/student_auth_service.dart';
import 'package:manara_student/src/services/student_settings.dart';

/// رسمةُ «استوديو الرسم» تُحفظ في «لوحاتي» نفسِها التي تحفظ فيها «لوحة الألوان»،
/// فتظهر في الدردشة عند «أرسل رسمة» وتُرسل منها.
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

const profile = StudentProfile(
  id: 'kid1',
  name: 'جوري',
  username: 'kid1',
  role: 'student',
  grade: 'الروضة',
  subject: 'الثقافة العامة',
);

final png = base64Decode('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==');

StudioController drawn(String id) => StudioController(id: id)
  ..begin(const Offset(10, 10), const StudioPen())
  ..move(const Offset(300, 300))
  ..end();

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    StudentSettings.resetForTest();
  });

  test('رسمةُ الاستوديو تُقرأ من «لوحاتي» بنوعها، وتُحفظ مرّةً واحدةً بمعرّفها', () async {
    final first = StudioArtwork(drawn('studio:1'));
    expect(await ColoringGallery.save(first, owner: 'kid1', replacingId: true), isTrue);
    // ‏حُفظت ثانيةً بعد تعديل: تحلّ محلّ الأولى لا بجانبها.
    expect(await ColoringGallery.save(StudioArtwork(drawn('studio:1')), owner: 'kid1', replacingId: true), isTrue);
    final gallery = await ColoringGallery.load(owner: 'kid1');
    expect(gallery, hasLength(1));
    expect(gallery.single, isA<StudioArtwork>());
    expect(gallery.single.artworkId, 'studio:1');
    expect(gallery.single.isEmpty, isFalse);
    // ‏ولا تختلط بطالبٍ آخر على الجهاز نفسه.
    expect(await ColoringGallery.load(owner: 'kid2'), isEmpty);

    expect(await ColoringGallery.removeId('studio:1', owner: 'kid1'), isTrue);
    expect(await ColoringGallery.load(owner: 'kid1'), isEmpty);
  });

  testWidgets('«احفظ في لوحاتي» في الاستوديو يضعها في «لوحاتي» بمعرّف الطالب', (tester) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      home: DrawingStudioScreen(
        account: const ColoringAccount(studentId: 'kid1'),
        initial: drawn('studio:42'),
      ),
    ));
    await tester.pump();
    for (var i = 0; i < 2; i++) {
      await tester.tap(find.byKey(const ValueKey('studio-save')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      await tester.tap(find.byKey(const ValueKey('studio-save-project')));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump();
    }
    final gallery = await ColoringGallery.load(owner: 'kid1');
    expect(gallery, hasLength(1), reason: 'الحفظُ الثاني يحلّ محلّ الأول');
    expect(gallery.single.artworkId, 'studio:42');
    // ‏والمشروعُ بطبقاته باقٍ للتعديل في الاستوديو.
    expect(await StudioProjects.load('kid1'), hasLength(1));
    await tester.pump(const Duration(seconds: 4));
  });

  testWidgets('الدردشة: رسمةُ الاستوديو في «أرسل رسمة»، لا «لا يوجد رسم محفوظ»، وتُرسل', (tester) async {
    await ColoringGallery.save(StudioArtwork(drawn('studio:7')), owner: 'kid1', replacingId: true);
    final requests = <http.Request>[];
    final client = MockClient((request) async {
      requests.add(request);
      final path = request.url.path;
      if (path.endsWith('/chat/messages')) {
        return http.Response(jsonEncode({'messages': [], 'ephemeral': true, 'visit': '2026-11-22T10:00:00.000Z'}), 200,
            headers: {'content-type': 'application/json; charset=utf-8'});
      }
      if (path.endsWith('/chat/peers')) {
        return http.Response(jsonEncode({'peers': [{'id': 'sara', 'name': 'سارة'}]}), 200,
            headers: {'content-type': 'application/json; charset=utf-8'});
      }
      if (path.endsWith('/chat/image') && request.method == 'POST') {
        return http.Response(jsonEncode({'message': {'id': 'chat_1_x', 'imageId': 'chatimage_1_x'}}), 201,
            headers: {'content-type': 'application/json; charset=utf-8'});
      }
      return http.Response('{}', 404);
    });
    tester.view.physicalSize = const Size(420, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    String? rendered;
    await tester.pumpWidget(MaterialApp(
      home: StudentChatScreen(
        profile: profile,
        apiBaseUrl: 'http://api.test',
        authService: FakeAuth(),
        httpClient: client,
        // ‏«لوحاتي» الحقيقية بمعرّف الطالب (بلا loadArtworks)، والصورةُ مزيّفةٌ للسرعة.
        renderArtwork: (artwork) async {
          rendered = artwork.artworkId;
          return png;
        },
      ),
    ));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    await tester.tap(find.byKey(const ValueKey('chat-send-art')));
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    await tester.tap(find.byKey(const ValueKey('chat-attach-art')));
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.text(tr('chat.art.none')), findsNothing);
    expect(find.byKey(const ValueKey('chat-art-0')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('chat-art-0')));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(rendered, 'studio:7');
    final sent = requests.where((r) => r.url.path.endsWith('/chat/image') && r.method == 'POST').single;
    expect(base64Decode((jsonDecode(sent.body) as Map)['image'] as String), isNotEmpty);
  });
}
