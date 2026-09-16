import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:manara_student/src/widgets/academic_journey_map.dart';

/// The map is a view over the academic cascade, never a second copy of it.
/// These pin that down: the six levels are all present, a choice leaves by
/// the callback the screen passed in, and a level with nothing configured
/// cannot be opened at all.
void main() {
  List<JourneyStation> stations({
    required void Function(String level, String value) onPick,
    String? grade = 'الصف الرابع',
    List<String> unitOptions = const ['الوحدة الأولى'],
  }) =>
      [
        JourneyStation(
          label: 'الصف',
          icon: Icons.school_rounded,
          color: Colors.teal,
          value: grade,
          options: const ['الصف الرابع', 'الصف الخامس'],
          onSelected: (v) => onPick('الصف', v),
        ),
        JourneyStation(
          label: 'الترم',
          icon: Icons.calendar_month_rounded,
          color: Colors.orange,
          value: 'الترم الأول',
          options: const ['الترم الأول'],
          onSelected: (v) => onPick('الترم', v),
        ),
        JourneyStation(
          label: 'المادة',
          icon: Icons.menu_book_rounded,
          color: Colors.purple,
          value: 'الرياضيات',
          options: const ['الرياضيات'],
          onSelected: (v) => onPick('المادة', v),
        ),
        JourneyStation(
          label: 'الفصل',
          icon: Icons.bookmarks_rounded,
          color: Colors.red,
          value: 'الفصل الأول',
          options: const ['الفصل الأول'],
          onSelected: (v) => onPick('الفصل', v),
        ),
        JourneyStation(
          label: 'الوحدة',
          icon: Icons.category_rounded,
          color: Colors.green,
          value: unitOptions.isEmpty ? null : unitOptions.first,
          options: unitOptions,
          onSelected: (v) => onPick('الوحدة', v),
        ),
        JourneyStation(
          label: 'الدرس',
          icon: Icons.play_lesson_rounded,
          color: Colors.indigo,
          value: 'الدرس الأول',
          options: const ['الدرس الأول'],
          onSelected: (v) => onPick('الدرس', v),
        ),
      ];

  /// Fixed pumps, never `pumpAndSettle`: the waypoints pulse on a repeating
  /// controller, so the tree has no settled state to wait for and
  /// `pumpAndSettle` can only ever time out.
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 60));
    }
  }

  Future<void> pumpMap(
    WidgetTester tester, {
    required List<JourneyStation> given,
    int activeIndex = 0,
    Size size = const Size(768, 1024),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Directionality(
            textDirection: TextDirection.rtl,
            child: AcademicJourneyMap(
              stations: given,
              activeIndex: activeIndex,
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
  }

  testWidgets('all six levels appear as stations', (tester) async {
    await pumpMap(tester, given: stations(onPick: (_, __) {}));

    for (final label in ['الصف', 'الترم', 'المادة', 'الفصل', 'الوحدة', 'الدرس']) {
      expect(find.text(label), findsOneWidget, reason: '$label has no station');
    }
  });

  testWidgets('a station shows the answer already given', (tester) async {
    await pumpMap(tester, given: stations(onPick: (_, __) {}));
    expect(find.text('الصف الرابع'), findsOneWidget);
  });

  testWidgets('choosing on the map reports back through the station callback',
      (tester) async {
    final picks = <String>[];
    await pumpMap(
      tester,
      given: stations(onPick: (level, value) => picks.add('$level=$value')),
    );

    await tester.tap(find.text('الصف'));
    await settle(tester);

    // The sheet lists this level's options.
    expect(find.text('الصف الخامس'), findsOneWidget);

    await tester.tap(find.text('الصف الخامس'));
    await settle(tester);

    // The map decides nothing itself — it hands the choice straight back to
    // the cascade that owns it.
    expect(picks, ['الصف=الصف الخامس']);
  });

  testWidgets('a level with nothing configured cannot be opened',
      (tester) async {
    final picks = <String>[];
    await pumpMap(
      tester,
      given: stations(
        onPick: (level, value) => picks.add('$level=$value'),
        unitOptions: const [],
      ),
    );

    await tester.tap(find.text('الوحدة'));
    await settle(tester);

    expect(find.text('الوحدة الأولى'), findsNothing, reason: 'a sheet opened');
    expect(picks, isEmpty);
  });

  testWidgets('the trail lays out without overflow across screen shapes',
      (tester) async {
    for (final size in const [
      Size(360, 740),
      Size(768, 1024),
      Size(851, 393),
      Size(1024, 768),
    ]) {
      await pumpMap(tester, given: stations(onPick: (_, __) {}), size: size);
      expect(tester.takeException(), isNull, reason: 'overflowed at $size');
    }
  });
}
