import 'dart:convert';
import 'dart:io' show gzip;
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:manara_student/src/screens/kg_world_screen.dart';
import 'package:manara_student/src/screens/magic_coloring_screen.dart';
import 'package:manara_student/src/services/coloring_canvas.dart';
import 'package:manara_student/src/services/coloring_cloud.dart';
import 'package:manara_student/src/services/coloring_drawings.dart';
import 'package:manara_student/src/services/free_drawing.dart';
import 'package:manara_student/src/services/student_auth_service.dart';
import 'package:manara_student/src/services/student_settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// حفظُ اللوحة: على الجهاز باسم الطالب وحده، وفي السحابة، وفي استوديو الجهاز.
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

ColoringController painted() =>
    ColoringController(handDrawnDrawings['cat']!())..fillAt(const Offset(150, 150), const Color(0xFFF97316));

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    StudentSettings.resetForTest();
  });

  test('«لوحاتي» على الجهاز لكلّ طالبٍ وحده: سادن لا يرى لوحاتِ جوري', () async {
    await ColoringGallery.save(painted(), owner: 'sadin');
    await ColoringGallery.save(painted(), owner: 'sadin');
    await ColoringGallery.save(ColoringController(mandala(3)), owner: 'joury');
    expect(await ColoringGallery.load(owner: 'sadin'), hasLength(2));
    final joury = await ColoringGallery.load(owner: 'joury');
    expect(joury.map((a) => a.artworkId), ['mandala:3']);
    // ‏وحذفُ جوري لا يمسّ لوحاتِ سادن.
    expect(await ColoringGallery.delete(0, owner: 'joury'), isTrue);
    expect(await ColoringGallery.load(owner: 'joury'), isEmpty);
    expect(await ColoringGallery.load(owner: 'sadin'), hasLength(2));
    // ‏والمفتاحُ القديمُ المشترك لا يُقرأ لأحد.
    SharedPreferences.setMockInitialValues({
      'coloring.gallery.v1': [jsonEncode(painted().toJson())],
    });
    expect(await ColoringGallery.load(owner: 'sadin'), isEmpty);
  });

  group('السحابة', () {
    late List<http.Request> requests;
    late List<Map<String, dynamic>> stored;
    var deployed = true;

    MockClient server() => MockClient((request) async {
          requests.add(request);
          if (!deployed) {
            return http.Response(jsonEncode({'error': 'غير متوفرة', 'code': 'not_found'}), 404,
                headers: {'content-type': 'application/json; charset=utf-8'});
          }
          final path = request.url.path;
          if (path == '/api/student/artworks' && request.method == 'GET') {
            return http.Response(
                jsonEncode({
                  'artworks': [
                    for (final a in stored) {'id': a['id'], 'title': a['title'], 'time': '2026-11-14T10:00:00Z'},
                  ],
                }),
                200,
                headers: {'content-type': 'application/json; charset=utf-8'});
          }
          if (path == '/api/student/artworks' && request.method == 'POST') {
            final body = jsonDecode(request.body) as Map<String, dynamic>;
            final id = 'artwork_${stored.length + 1}_abcdefgh';
            stored.add({...body, 'id': id});
            return http.Response(jsonEncode({'artwork': {'id': id, 'title': body['title'], 'time': 'x'}}), 201,
                headers: {'content-type': 'application/json; charset=utf-8'});
          }
          if (path.endsWith('/doc')) {
            final id = path.split('/')[4];
            final item = stored.firstWhere((a) => a['id'] == id);
            return http.Response(jsonEncode({'id': id, 'doc': item['doc']}), 200,
                headers: {'content-type': 'application/json; charset=utf-8'});
          }
          if (request.method == 'DELETE') {
            stored.removeWhere((a) => path.endsWith(a['id'] as String));
            return http.Response(jsonEncode({'deleted': true}), 200);
          }
          return http.Response('{}', 404);
        });

    setUp(() {
      requests = [];
      stored = [];
      deployed = true;
    });

    ColoringCloud cloud() => ColoringCloud(baseUrl: 'http://api.test', authService: FakeAuth(), client: server());

    testWidgets('يُرفع: صورةٌ صغيرة وخطواتٌ مضغوطة، ثم تُفتح كما كانت وتُحذف', (tester) async {
      await tester.runAsync(() async {
        final c = cloud();
        final saved = await c.save(painted(), title: 'القطة اللطيفة');
        expect(saved.id, 'artwork_1_abcdefgh');
        final body = jsonDecode(requests.single.body) as Map<String, dynamic>;
        expect(body['title'], 'القطة اللطيفة');
        final image = base64Decode(body['image'] as String);
        expect(image.sublist(1, 4), 'PNG'.codeUnits);
        expect(image.length, lessThan(200 * 1024));
        final doc = jsonDecode(utf8.decode(gzip.decode(base64Decode(body['doc'] as String))));
        expect(doc['id'], 'cat');

        expect((await c.list()).single.title, 'القطة اللطيفة');
        final opened = await c.open(saved.id);
        expect(opened, isA<ColoringController>());
        expect(opened!.artworkId, 'cat');
        expect((opened as ColoringController).fills, isNotEmpty);

        // ‏والرسمُ الحرُّ يُفتح بخطواته.
        final free = FreeDrawingController()
          ..beginStroke(const Offset(10, 10), color: const Color(0xFF111827), width: 6)
          ..extendStroke(const Offset(90, 90))
          ..endStroke();
        final freeSaved = await c.save(free, title: 'رسمتي');
        final reopened = await c.open(freeSaved.id) as FreeDrawingController;
        await reopened.ready;
        expect(reopened.isEmpty, isFalse);

        await c.delete(saved.id);
        expect(stored.map((a) => a['id']), [freeSaved.id]);
        free.dispose();
        reopened.dispose();
      });
    });

    test('خادمٌ أقدمُ من التطبيق: «غير متاح بعد» لا خطأٌ مبهم', () async {
      deployed = false;
      await expectLater(
        cloud().list(),
        throwsA(isA<CloudException>().having((e) => e.problem, 'problem', CloudProblem.notDeployed)),
      );
    });

    testWidgets('من الشاشة: ثلاثةُ خيارات، والسحابةُ تحفظ، والاستوديو يتلقّى صورةً', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1100));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final photos = <Uint8List>[];
      final account = ColoringAccount(studentId: 'sadin', cloud: cloud());
      await tester.pumpWidget(MaterialApp(
        home: MagicColoringScreen(
          account: account,
          random: math.Random(4),
          playIntro: () {},
          cheer: () async {},
          saveToPhotos: (png) async {
            photos.add(png);
            return true;
          },
        ),
      ));
      Future<void> frames([int n = 6]) async {
        for (var i = 0; i < n; i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }
      }

      await frames();
      final state = tester.state<MagicColoringScreenState>(find.byType(MagicColoringScreen));
      expect(state.cloudItems, isEmpty);
      await tester.tap(find.byKey(const ValueKey('coloring-mode-ready')));
      await frames();
      await tester.tap(find.byKey(const ValueKey('coloring-pick-0')));
      await frames();
      await tester.tap(find.byKey(const ValueKey('coloring-board')));
      await frames(2);

      // ‏السحابة.
      await tester.tap(find.byKey(const ValueKey('coloring-save')));
      await frames();
      expect(find.byKey(const ValueKey('coloring-save-device')), findsOneWidget);
      expect(find.byKey(const ValueKey('coloring-save-cloud')), findsOneWidget);
      expect(find.byKey(const ValueKey('coloring-save-photos')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('coloring-save-cloud')));
      await tester.runAsync(() => Future<void>.delayed(const Duration(seconds: 2)));
      await frames();
      expect(stored, hasLength(1));
      expect(state.celebrating, isTrue);
      expect(find.text('⭐⭐⭐  حُفظت لوحتك في السحابة ☁️'), findsOneWidget);
      // ‏ولا شيءَ على الجهاز: اختار السحابة.
      expect(await ColoringGallery.load(owner: 'sadin'), isEmpty);

      // ‏الاستوديو.
      await tester.tap(find.byKey(const ValueKey('coloring-all')));
      await frames();
      await tester.tap(find.byKey(const ValueKey('coloring-pick-1')));
      await frames();
      await tester.tap(find.byKey(const ValueKey('coloring-board')));
      await frames(2);
      await tester.tap(find.byKey(const ValueKey('coloring-save')));
      await frames();
      await tester.tap(find.byKey(const ValueKey('coloring-save-photos')));
      await tester.runAsync(() => Future<void>.delayed(const Duration(seconds: 2)));
      await frames();
      expect(photos, hasLength(1));
      expect(photos.single.sublist(1, 4), 'PNG'.codeUnits);
      expect(state.celebrating, isTrue);
      await tester.pump(const Duration(seconds: 4));
    });
  });

  testWidgets('روضة: ألعابُ «عالم الحكايات والمغامرات» الخمسُ مربّعاتٌ متساوية', (tester) async {
    for (final size in const [Size(400, 900), Size(1280, 800)]) {
      await tester.binding.setSurfaceSize(size);
      await tester.pumpWidget(const MaterialApp(home: KgWorldScreen()));
      for (var i = 0; i < 30; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      final sizes = [
        for (final key in ['coloring', 'colors', 'shapes', 'math', 'general'])
          tester.getSize(find.byKey(ValueKey('kgworld-$key'))),
      ];
      for (final s in sizes) {
        expect(s.width, closeTo(sizes.first.width, 0.5), reason: '$size');
        expect(s.height, closeTo(sizes.first.height, 0.5), reason: '$size');
        expect(s.width, closeTo(s.height, 0.5), reason: 'مربّع');
      }
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 3));
    }
    await tester.binding.setSurfaceSize(null);
  });
}
