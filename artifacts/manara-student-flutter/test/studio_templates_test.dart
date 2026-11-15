import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:manara_student/src/screens/drawing_studio_screen.dart';
import 'package:manara_student/src/services/drawing_studio.dart';
import 'package:manara_student/src/services/student_settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// «قوالب جاهزة» في استوديو الرسم، وحذفُ الرسومات من «لوحاتي».
void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    StudentSettings.resetForTest();
  });

  test('المكتبة: شخصياتٌ وحيواناتٌ وأشياء، وكلُّ قالبٍ له رسمته', () {
    for (final t in studioTemplates) {
      expect(studioTemplateDrawing(t.id), isNotNull, reason: t.id);
    }
    final ids = studioTemplates.map((t) => t.id).toSet();
    for (final wanted in ['girl', 'boy', 'cat', 'bunny', 'lion', 'dinosaur', 'butterfly', 'car', 'rocket', 'castle', 'bouquet']) {
      expect(ids, contains(wanted));
    }
    expect(studioTemplates.map((t) => t.section).toSet(), {'characters', 'animals', 'things'});
  });

  test('القالبُ يُفتح طبقتين: تلوينٌ نشط، وخطوطٌ مقفلة بمزج «ضرب»؛ والدلو لا يتسرّب', () {
    final c = StudioController.fromTemplate('lion')!;
    expect(c.layers, hasLength(2));
    expect(c.active, 0);
    expect(c.layers[1].locked, isTrue);
    expect(c.layers[1].blend, StudioBlend.multiply);
    expect(c.templateId, 'lion');

    // ‏الوجه (منطقةٌ أمام اللبدة) والخلفية.
    expect(c.fillAt(const Offset(500, 400), const Color(0xFFFACC15)), isTrue);
    expect(c.fillAt(const Offset(20, 20), const Color(0xFFBAE6FD)), isTrue);
    final fills = c.layers[0].ops;
    expect(fills.map((o) => o.kind), [StudioOpKind.fill, StudioOpKind.fill]);
    expect(fills.first.region, isNot(-1));
    expect(fills.last.region, -1);
    final face = studioVisibleRegion(studioTemplateDrawing('lion')!, fills.first.region);
    expect(face.contains(const Offset(150, 120)), isTrue);
    expect(face.contains(const Offset(150, 166)), isFalse, reason: 'الأنفُ والفمُ فوق الوجه لا يُصبغان');

    // ‏يُحفظ ويُستعاد، والقالبُ الأصليّ لا يتغيّر.
    final back = StudioController.fromJson(jsonDecode(jsonEncode(c.toJson())))!;
    expect(back.layers[0].ops, hasLength(2));
    expect(back.layers[1].ops.single.template, 'lion');
    final fresh = StudioController.fromTemplate('lion')!;
    expect(fresh.layers[0].ops, isEmpty);

    // ‏الطبقةُ المقفلة لا يُلوَّن عليها، ولوحةٌ بلا قالب لا دلوَ فيها.
    c.selectLayer(1);
    expect(c.fillAt(const Offset(500, 400), const Color(0xFF000000)), isFalse);
    expect(StudioController().fillAt(const Offset(10, 10), const Color(0xFF000000)), isFalse);
  });

  testWidgets('من الشاشة: «قوالب جاهزة» تفتح القالب، والدلو يلوّنه، ثم يُحفظ في «لوحاتي»', (tester) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const MaterialApp(home: DrawingStudioScreen()));
    await tester.pump();
    final state = tester.state<DrawingStudioScreenState>(find.byType(DrawingStudioScreen));

    await tester.tap(find.byKey(const ValueKey('studio-templates')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.byKey(const ValueKey('studio-templates-sheet')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('studio-template-girl')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(state.controller.templateId, 'girl');
    expect(state.tool, StudioTool.fill);

    final board = find.byKey(const ValueKey('studio-board'));
    final box = tester.getRect(board);
    // ‏الفستان: أسفلُ منتصف اللوحة.
    await tester.tapAt(Offset(box.center.dx, box.top + box.height * 0.88));
    await tester.pump();
    expect(state.controller.layers[0].ops.single.kind, StudioOpKind.fill);

    await tester.tap(find.byKey(const ValueKey('studio-save')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    await tester.tap(find.byKey(const ValueKey('studio-save-project')));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump();
    final saved = (await SharedPreferences.getInstance()).getStringList(StudioProjects.keyFor('guest'))!;
    expect(saved, hasLength(1));
    await tester.pump(const Duration(seconds: 4));
  });

  testWidgets('«لوحاتي»: سلّةٌ على كل رسمة، وتأكيدٌ قبل الحذف، والإلغاءُ يُبقيها', (tester) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final a = StudioController(id: 'studio:a')
      ..begin(const Offset(10, 10), const StudioPen())
      ..move(const Offset(80, 80))
      ..end();
    final b = StudioController(id: 'studio:b')
      ..begin(const Offset(10, 10), const StudioPen())
      ..move(const Offset(90, 30))
      ..end();
    await StudioProjects.save('guest', a);
    await StudioProjects.save('guest', b);

    await tester.pumpWidget(const MaterialApp(home: DrawingStudioScreen()));
    await tester.pump();
    Future<void> settle() async {
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
    }

    await tester.tap(find.byKey(const ValueKey('studio-projects')));
    await settle();
    expect(find.byKey(const ValueKey('studio-project-delete-0')), findsOneWidget);
    expect(find.byKey(const ValueKey('studio-project-delete-1')), findsOneWidget);

    // ‏إلغاء: تبقى.
    await tester.tap(find.byKey(const ValueKey('studio-project-delete-0')));
    await settle();
    expect(find.text('هل تريد حذف هذه الرسمة؟'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('studio-delete-cancel')));
    await settle();
    expect((await StudioProjects.load('guest')).length, 2);

    // ‏موافقة: تُحذف الأحدثُ (b) وحدها.
    await tester.tap(find.byKey(const ValueKey('studio-project-delete-0')));
    await settle();
    await tester.tap(find.byKey(const ValueKey('studio-delete-confirm')));
    await settle();
    final left = await StudioProjects.load('guest');
    expect(left.map((p) => p.id), ['studio:a']);
    expect(find.byKey(const ValueKey('studio-project-delete-1')), findsNothing);
    await tester.pump(const Duration(seconds: 4));
  });
}
