import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:manara_student/src/widgets/quiz_games.dart';

/// ألعابُ الاختبار: الاختيارُ الأوّل هو الإجابة، ويُبلَغ بعد أن يرى الطفلُ نتيجته.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const options = ['أسد', 'قطة', 'فيل', 'زرافة'];
  bool isCorrect(String option) => option == 'زرافة';

  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<void> pump(WidgetTester tester, Widget game) async {
    for (final channel in ['xyz.luan/audioplayers', 'xyz.luan/audioplayers.global']) {
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(MethodChannel(channel), (_) async => null);
    }
    tester.view.physicalSize = const Size(1024, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: game)));
    await tester.pump(const Duration(milliseconds: 300));
  }

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  group('البالونات', () {
    testWidgets('الصحيحةُ تنفجر ثم تُبلَغ، ولمسةٌ ثانية لا تُحسب', (tester) async {
      final answers = <String>[];
      await pump(
        tester,
        BalloonQuizQuestion(prompt: 'رقبتُه طويلة؟', options: options, isCorrect: isCorrect, onAnswered: answers.add),
      );
      await tester.tap(find.byKey(const ValueKey('balloon-3')));
      await tester.pump(const Duration(milliseconds: 200));
      expect(answers, isEmpty, reason: 'يرى الانفجارَ أوّلاً');
      await tester.tap(find.byKey(const ValueKey('balloon-0')), warnIfMissed: false);
      await settle(tester);
      expect(answers, ['زرافة']);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 3));
    });

    testWidgets('الخاطئةُ تُبلَغ كما هي — تُحسب خطأً كما في القائمة', (tester) async {
      final answers = <String>[];
      await pump(
        tester,
        BalloonQuizQuestion(prompt: 'رقبتُه طويلة؟', options: options, isCorrect: isCorrect, onAnswered: answers.add),
      );
      await tester.tap(find.byKey(const ValueKey('balloon-1')));
      await settle(tester);
      expect(answers, ['قطة']);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 3));
    });

    testWidgets('سؤالٌ أُجيب من قبل لا يُجاب ثانيةً', (tester) async {
      final answers = <String>[];
      await pump(
        tester,
        BalloonQuizQuestion(
          prompt: 'رقبتُه طويلة؟',
          options: options,
          isCorrect: isCorrect,
          onAnswered: answers.add,
          answered: 'فيل',
        ),
      );
      await tester.tap(find.byKey(const ValueKey('balloon-3')), warnIfMissed: false);
      await settle(tester);
      expect(answers, isEmpty);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 3));
    });
  });

  group('الصيد', () {
    testWidgets('تُلمس السمكةُ فتنزل الصنّارة، ثم تُبلَغ الإجابة', (tester) async {
      final answers = <String>[];
      await pump(
        tester,
        FishingQuizQuestion(prompt: 'رقبتُه طويلة؟', options: options, isCorrect: isCorrect, onAnswered: answers.add),
      );
      await tester.tap(find.byKey(const ValueKey('fish-3')));
      await tester.pump(const Duration(milliseconds: 300));
      expect(answers, isEmpty);
      await settle(tester);
      expect(answers, ['زرافة']);
      expect(find.text('اصطدتها! 🎉'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 3));
    });

    testWidgets('السمكةُ الخاطئة تفلت، وتُبلَغ خطأً', (tester) async {
      final answers = <String>[];
      await pump(
        tester,
        FishingQuizQuestion(prompt: 'رقبتُه طويلة؟', options: options, isCorrect: isCorrect, onAnswered: answers.add),
      );
      await tester.tap(find.byKey(const ValueKey('fish-0')));
      await settle(tester);
      expect(answers, ['أسد']);
      expect(find.text('اصطدتها! 🎉'), findsNothing);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 3));
    });
  });
}
