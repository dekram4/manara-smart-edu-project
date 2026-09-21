import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:manara_student/src/l10n/student_strings.dart';
import 'package:manara_student/src/widgets/unit_exam_gate.dart';

/// The gate in front of a unit exam.
///
/// A unit exam is spent on the first tap: the app shows the saved result
/// rather than reopening it. So the only answer that may open it is an
/// explicit yes — every other way out of this dialog has to mean no, or a
/// child loses their single attempt to a misplaced thumb.
void main() {
  /// Opens the gate and hands back the box the answer will land in.
  ///
  /// A box rather than a returned Future: the answer arrives when the
  /// dialog pops, which is after the test taps a button, so the value
  /// cannot be awaited before the tap that produces it.
  Future<List<bool?>> openGate(WidgetTester tester) async {
    final answer = <bool?>[null];
    await tester.pumpWidget(
      MaterialApp(
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async => answer[0] = await confirmUnitExam(context),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    return answer;
  }

  testWidgets('it asks before the exam opens', (tester) async {
    await openGate(tester);

    expect(find.text(tr('quiz.unitConfirmTitle')), findsOneWidget);
    // ‏السبب معروض مع السؤال: ما يميّز اختبار الوحدة أنه لا يعود.
    expect(find.text(tr('quiz.unitConfirmBody')), findsOneWidget);
    expect(find.text(tr('quiz.unitConfirmYes')), findsOneWidget);
    expect(find.text(tr('quiz.unitConfirmNo')), findsOneWidget);
  });

  testWidgets('«ready» is the only answer that opens it', (tester) async {
    final answer = await openGate(tester);
    await tester.tap(find.text(tr('quiz.unitConfirmYes')));
    await tester.pumpAndSettle();

    expect(answer[0], isTrue);
  });

  testWidgets('«I will review first» does not open it', (tester) async {
    final answer = await openGate(tester);
    await tester.tap(find.text(tr('quiz.unitConfirmNo')));
    await tester.pumpAndSettle();

    expect(answer[0], isFalse);
  });

  testWidgets('tapping outside does not open it either', (tester) async {
    final answer = await openGate(tester);
    // ‏الضغط خارج النافذة تردُّد لا موافقة، ولا يُصرف به الاختبار.
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();

    expect(answer[0], isFalse);
  });
}
