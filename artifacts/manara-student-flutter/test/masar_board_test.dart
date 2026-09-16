import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:manara_student/src/widgets/masar_path_board.dart';

/// The board prints the six levels into the squares already drawn on the
/// artwork. It owns no academic state: every choice leaves through the
/// callback the screen handed in, which is what keeps the cascade the one
/// place the tree is resolved.
void main() {
  List<MasarStage> stages({
    required void Function(String level, String value) onPick,
    List<String> unitOptions = const ['الوحدة الأولى'],
  }) =>
      [
        MasarStage(
          label: 'الصف',
          icon: Icons.school_rounded,
          color: Colors.teal,
          value: 'الصف الرابع',
          options: const ['الصف الرابع', 'الصف الخامس'],
          onSelected: (v) => onPick('الصف', v),
        ),
        MasarStage(
          label: 'الترم',
          icon: Icons.calendar_month_rounded,
          color: Colors.orange,
          value: 'الترم الأول',
          options: const ['الترم الأول'],
          onSelected: (v) => onPick('الترم', v),
        ),
        MasarStage(
          label: 'المادة',
          icon: Icons.menu_book_rounded,
          color: Colors.purple,
          value: 'الرياضيات',
          options: const ['الرياضيات'],
          onSelected: (v) => onPick('المادة', v),
        ),
        MasarStage(
          label: 'الفصل',
          icon: Icons.bookmarks_rounded,
          color: Colors.red,
          value: 'الفصل الأول',
          options: const ['الفصل الأول'],
          onSelected: (v) => onPick('الفصل', v),
        ),
        MasarStage(
          label: 'الوحدة',
          icon: Icons.category_rounded,
          color: Colors.green,
          value: unitOptions.isEmpty ? null : unitOptions.first,
          options: unitOptions,
          onSelected: (v) => onPick('الوحدة', v),
        ),
        MasarStage(
          label: 'الدرس',
          icon: Icons.play_lesson_rounded,
          color: Colors.indigo,
          value: 'الدرس الأول',
          options: const ['الدرس الأول'],
          onSelected: (v) => onPick('الدرس', v),
        ),
      ];

  /// Fixed pumps, never `pumpAndSettle`: the active square glows on a
  /// repeating controller, so there is no settled state to wait for.
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 60));
    }
  }

  Future<void> pumpBoard(
    WidgetTester tester, {
    required List<MasarStage> given,
    int activeIndex = 0,
    Size size = const Size(1024, 768),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Directionality(
            textDirection: TextDirection.rtl,
            child: MasarPathBoard(stages: given, activeIndex: activeIndex),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
  }

  testWidgets('all six levels are printed on the board', (tester) async {
    await pumpBoard(tester, given: stages(onPick: (_, __) {}));

    for (final label in ['الصف', 'الترم', 'المادة', 'الفصل', 'الوحدة', 'الدرس']) {
      expect(find.text(label), findsOneWidget, reason: '$label has no square');
    }
  });

  testWidgets('a square shows the answer already given', (tester) async {
    await pumpBoard(tester, given: stages(onPick: (_, __) {}));
    expect(find.text('الصف الرابع'), findsOneWidget);
  });

  testWidgets('the six squares sit where the artwork draws them',
      (tester) async {
    await pumpBoard(tester, given: stages(onPick: (_, __) {}));

    Rect rectOf(String label) => tester.getRect(find.text(label));

    // Two rows of three. The top row shares a baseline, the bottom row sits
    // below it, and the columns run right to left in Arabic reading order —
    // which is the order the path is walked.
    final top = ['الصف', 'الترم', 'المادة'].map(rectOf).toList();
    final bottom = ['الفصل', 'الوحدة', 'الدرس'].map(rectOf).toList();

    for (final r in top) {
      expect((r.center.dy - top.first.center.dy).abs(), lessThan(2),
          reason: 'the top row is not level');
    }
    for (final r in bottom) {
      expect((r.center.dy - bottom.first.center.dy).abs(), lessThan(2),
          reason: 'the bottom row is not level');
    }
    expect(bottom.first.center.dy, greaterThan(top.first.center.dy + 40),
        reason: 'the two rows are not separated');

    // Each column steps to the left of the one before it.
    expect(top[1].center.dx, greaterThan(top[0].center.dx));
    expect(top[2].center.dx, greaterThan(top[1].center.dx));
  });

  testWidgets('tapping a square opens that level and reports the choice back',
      (tester) async {
    final picks = <String>[];
    await pumpBoard(
      tester,
      given: stages(onPick: (level, value) => picks.add('$level=$value')),
    );

    await tester.tap(find.text('الصف'));
    await settle(tester);
    expect(find.text('الصف الخامس'), findsOneWidget, reason: 'no sheet opened');

    await tester.tap(find.text('الصف الخامس'));
    await settle(tester);

    expect(picks, ['الصف=الصف الخامس']);
  });

  testWidgets('a level with nothing configured cannot be opened',
      (tester) async {
    final picks = <String>[];
    await pumpBoard(
      tester,
      given: stages(
        onPick: (level, value) => picks.add('$level=$value'),
        unitOptions: const [],
      ),
    );

    await tester.tap(find.text('الوحدة'));
    await settle(tester);

    expect(find.text('الوحدة الأولى'), findsNothing, reason: 'a sheet opened');
    expect(picks, isEmpty);
  });

  testWidgets('the board lays out without overflow across screen shapes',
      (tester) async {
    for (final size in const [
      Size(360, 740),
      Size(768, 1024),
      Size(851, 393),
      Size(1024, 768),
      Size(1280, 720),
    ]) {
      await pumpBoard(tester, given: stages(onPick: (_, __) {}), size: size);
      expect(tester.takeException(), isNull, reason: 'overflowed at $size');
    }
  });
}
