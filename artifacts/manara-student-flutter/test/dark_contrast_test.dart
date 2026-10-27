import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:manara_student/src/theme/student_theme.dart';

/// الوضعُ الداكن: النصُّ والأيقونات مقروءةٌ على الأرضية والبطاقة (WCAG AA).
double _contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

void main() {
  Future<BuildContext> darkContext(WidgetTester tester) async {
    late BuildContext captured;
    await tester.pumpWidget(MaterialApp(
      theme: StudentTheme.dark(),
      home: Builder(builder: (context) {
        captured = context;
        return const SizedBox();
      }),
    ));
    return captured;
  }

  testWidgets('الحبرُ والحبرُ الثانويّ واضحان على الأرضية والبطاقة', (tester) async {
    final context = await darkContext(tester);
    for (final ground in [StudentSurface.ground(context), StudentSurface.card(context)]) {
      expect(_contrast(StudentSurface.ink(context), ground), greaterThan(12));
      expect(_contrast(StudentSurface.mutedInk(context), ground), greaterThan(9));
    }
  });

  testWidgets('ألوانُ العلامة الغامقة تسطع في الداكن', (tester) async {
    final context = await darkContext(tester);
    const brands = [
      Color(0xFF0B8693),
      Color(0xFF7C3AED),
      Color(0xFF16A34A),
      Color(0xFFDC2626),
      Color(0xFF0B9A67),
    ];
    for (final brand in brands) {
      expect(
        _contrast(StudentSurface.vivid(context, brand), StudentSurface.card(context)),
        greaterThan(4.5),
        reason: brand.toString(),
      );
    }
  });
}
