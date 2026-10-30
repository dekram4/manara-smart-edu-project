import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:manara_student/src/l10n/student_strings.dart';
import 'package:manara_student/src/widgets/quiz_games.dart';

/// ألعابُ الأسئلة الأربع: الاختيارُ الأوّل هو الإجابة، ويُبلَغ بعد أن يرى
/// الطفلُ نتيجته؛ ولمسةٌ ثانية لا تُحسب.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const options = ['أسد', 'قطة', 'فيل', 'زرافة'];
  bool isCorrect(String option) => option == 'زرافة';

  setUp(() => SharedPreferences.setMockInitialValues({}));

  void muteAudio(WidgetTester tester) {
    for (final channel in ['xyz.luan/audioplayers', 'xyz.luan/audioplayers.global']) {
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(MethodChannel(channel), (_) async => null);
    }
  }

  /// يُرسم ويُنتظر حتى يدخل القطارُ المحطة وتطفو البالونات.
  Future<void> pump(WidgetTester tester, Widget game, {Size size = const Size(1024, 720)}) async {
    muteAudio(tester);
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: game)));
    for (var i = 0; i < 16; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 22; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> finish(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 3));
  }

  Widget game(QuizGameStyle style, List<String> answers, {String? answered}) => switch (style) {
        QuizGameStyle.balloons => BalloonQuizQuestion(
            prompt: 'رقبتُه طويلة؟', options: options, isCorrect: isCorrect, onAnswered: answers.add, answered: answered),
        _ => quizGameFor(style, prompt: 'رقبتُه طويلة؟', options: options, isCorrect: isCorrect, onAnswered: answers.add),
      };

  const keys = {
    QuizGameStyle.balloons: 'balloon',
    QuizGameStyle.fishing: 'fish',
    QuizGameStyle.train: 'wagon',
    QuizGameStyle.slingshot: 'target',
  };

  for (final MapEntry(key: style, value: key) in keys.entries) {
    group(style.name, () {
      testWidgets('الصحيحةُ تُرى ثم تُبلَغ، ولمسةٌ ثانية لا تُحسب', (tester) async {
        final answers = <String>[];
        await pump(tester, game(style, answers));
        await tester.tap(find.byKey(ValueKey('$key-3')));
        await tester.pump(const Duration(milliseconds: 300));
        expect(answers, isEmpty, reason: 'يرى النتيجةَ أوّلاً');
        await tester.tap(find.byKey(ValueKey('$key-0')), warnIfMissed: false);
        await settle(tester);
        expect(answers, ['زرافة']);
        expect(tester.takeException(), isNull);
        await finish(tester);
      });

      testWidgets('الخاطئةُ تُبلَغ كما هي — تُحسب خطأً', (tester) async {
        final answers = <String>[];
        await pump(tester, game(style, answers));
        await tester.tap(find.byKey(ValueKey('$key-1')));
        await settle(tester);
        expect(answers, ['قطة']);
        await finish(tester);
      });

      testWidgets('الإجاباتُ كلُّها ظاهرةٌ بخطٍّ كبير، بلا تجاوزٍ على هاتفٍ رأسيّ', (tester) async {
        await pump(tester, game(style, []), size: const Size(360, 640));
        expect(tester.takeException(), isNull);
        for (final option in options) {
          expect(find.text(option), findsOneWidget);
        }
        final prompt = tester.widget<Text>(find.byKey(const ValueKey('quiz-prompt')));
        expect(prompt.style!.fontSize, greaterThanOrEqualTo(24));
        await finish(tester);
      });
    });
  }

  testWidgets('البالونات: سؤالٌ أُجيب من قبل لا يُجاب ثانيةً', (tester) async {
    final answers = <String>[];
    await pump(tester, game(QuizGameStyle.balloons, answers, answered: 'فيل'));
    await tester.tap(find.byKey(const ValueKey('balloon-3')), warnIfMissed: false);
    await settle(tester);
    expect(answers, isEmpty);
    await finish(tester);
  });

  testWidgets('الصيد: الصحيحةُ تُرفع من الماء — «اصطدتها!»', (tester) async {
    final answers = <String>[];
    await pump(tester, game(QuizGameStyle.fishing, answers));
    await tester.tap(find.byKey(const ValueKey('fish-3')));
    await settle(tester);
    expect(find.text(tr('quiz.game.caught')), findsOneWidget);
    await finish(tester);
  });

  testWidgets('المقلاع: سحبُ الخيط يُري المسار، وإفلاتُه يرمي الحصاة', (tester) async {
    final answers = <String>[];
    await pump(tester, game(QuizGameStyle.slingshot, answers));
    final pouch = tester.getCenter(find.byKey(const ValueKey('sling-pouch')));
    final gesture = await tester.startGesture(pouch);
    for (var i = 1; i <= 8; i++) {
      await gesture.moveTo(pouch + Offset(-10.0 * i, 9.0 * i));
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(find.text(tr('quiz.game.pull')), findsNothing, reason: 'الإرشادُ يختفي والخيطُ مشدود');
    await gesture.up();
    await settle(tester);
    // ‏أصاب هدفاً فأُبلغ، أو أخطأها كلَّها فيُدعى ليصوّب ثانيةً.
    expect(answers.length == 1 || find.text(tr('quiz.game.missed')).evaluate().isNotEmpty, isTrue);
    expect(tester.takeException(), isNull);
    await finish(tester);
  });

  testWidgets('الأغلفةُ الأربع تُرسم بلا خطأ', (tester) async {
    muteAudio(tester);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Row(children: [
          for (final style in QuizGameStyle.values)
            Expanded(child: SizedBox(height: 128, child: QuizGameCoverArt(style: style))),
        ]),
      ),
    ));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}
