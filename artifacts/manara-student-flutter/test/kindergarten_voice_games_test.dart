import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:manara_student/src/screens/home_layout.dart';
import 'package:manara_student/src/screens/kindergarten_voice_games.dart';
import 'package:manara_student/src/services/kindergarten_voice_quiz.dart';

/// ما «يقوله» الطفلُ في الاختبار: نصٌّ لكل سؤال، أو `null` إن تعذّر المايك.
typedef Say = String? Function(KgVoiceQuestion question);

void main() {
  late List<String> events;

  /// السؤالُ «يُقال» حتى يُكمَل هذا — لاختبار ضغط المايك أثناءه.
  Completer<void>? holdPrompt;

  Future<KgVoiceGameScreenState> boot(
    WidgetTester tester,
    KgVoiceGameKind kind,
    Say say, {
    bool micAllowed = true,
    Future<bool> Function({required ValueChanged<String> onResult, ValueChanged<String>? onPartial})? listen,
  }) async {
    events = [];
    holdPrompt = null;
    await tester.binding.setSurfaceSize(const Size(1000, 640));
    late KgVoiceGameScreenState state;
    await tester.pumpWidget(
      MaterialApp(
        home: KgVoiceGameScreen(
          key: UniqueKey(),
          kind: kind,
          random: math.Random(7),
          playToEnd: (clip) async {
            events.add('clip:${clip.split('/').last}');
            if (clip.contains('question_') || clip.contains('/general/')) events.add('prompt');
            if (holdPrompt != null && clip.contains('question_')) await holdPrompt!.future;
          },
          stopPrompt: () async => events.add('stop-prompt'),
          ensureMic: (_) async {
            events.add('ensure-mic');
            return micAllowed;
          },
          cheer: () async => events.add('cheer'),
          speak: (text) async => events.add('speak:$text'),
          stopListening: () async => events.add('stop-listening'),
          listen: listen ??
              ({required onResult, onPartial}) async {
                final heard = say(state.question!);
                if (heard == null) return false;
                events.add('heard:$heard');
                onPartial?.call(heard);
                Future<void>.microtask(() => onResult(heard));
                return true;
              },
        ),
      ),
    );
    state = tester.state<KgVoiceGameScreenState>(find.byType(KgVoiceGameScreen));
    await tester.pump();
    return state;
  }

  Future<void> start(WidgetTester tester) async {
    await tester.tap(find.byKey(const ValueKey('kg-voice-start')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  Future<void> answer(WidgetTester tester) async {
    await tester.tap(find.byKey(const ValueKey('kg-voice-mic')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
  }

  /// النجاحُ، ثم انزلاقُ السؤال التالي إلى مكانه.
  Future<void> afterCelebration(WidgetTester tester) async {
    await tester.pump(KgVoiceGameScreenState.celebrateFor + const Duration(milliseconds: 100));
    await tester.pump(KgVoiceGameScreenState.questionTransition + const Duration(milliseconds: 50));
  }

  testWidgets('بدءُ اللعبة: السؤالُ يُسمع أوّلاً، والمايكُ بعده', (tester) async {
    final state = await boot(tester, KgVoiceGameKind.colors, (q) => q.answer.label);
    expect(find.byKey(const ValueKey('kg-voice-intro')), findsOneWidget);
    await start(tester);
    expect(events.first, 'clip:question_color.mp3', reason: 'سؤالُ اللون المسجّل');
    expect(state.turn, KgTurn.ready);
    expect(find.byKey(const ValueKey('kg-visual-color')), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('إجابةٌ صحيحة: تشجيعٌ ونجمة، ثم السؤالُ التالي', (tester) async {
    final state = await boot(tester, KgVoiceGameKind.colors, (q) => 'اللون ${q.answer.label}');
    await start(tester);
    final first = state.question!;
    await answer(tester);
    expect(state.turn, KgTurn.correct);
    expect(events, contains('cheer'));
    expect(state.score, 1);
    await afterCelebration(tester);
    expect(state.question, isNot(same(first)), reason: 'مضى إلى التالي');
    expect(find.text('⭐ 1'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('إجابةٌ خاطئة: صوتُ الخطأ و«حاول مرة ثانية»، والسؤالُ باقٍ', (tester) async {
    final state = await boot(tester, KgVoiceGameKind.shapes, (q) => q.shape == KgShape.cube ? 'هرم' : 'مكعب');
    await start(tester);
    final first = state.question!;
    await answer(tester);
    expect(state.turn, KgTurn.wrong);
    expect(events.last, 'clip:wrong_answer.mp3');
    expect(find.text('حاول مرة ثانية يا بطل'), findsOneWidget);
    expect(state.question, same(first));
    expect(state.score, 0);
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('ثلاثُ محاولاتٍ خاطئة: يُقال الجوابُ ويمضي', (tester) async {
    final state = await boot(tester, KgVoiceGameKind.math, (q) => 'ما أعرف شيئاً');
    await start(tester);
    final first = state.question!;
    for (var i = 0; i < 3; i++) {
      await answer(tester);
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(state.turn, KgTurn.revealed);
    await tester.pump(const Duration(milliseconds: 50));
    expect(events.where((e) => e.startsWith('speak:الجواب')), hasLength(1));
    await afterCelebration(tester);
    expect(state.question, isNot(same(first)));
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('لم يُسمع شيء: «لم أسمعك» والمايكُ متاحٌ ثانية', (tester) async {
    final state = await boot(tester, KgVoiceGameKind.colors, (q) => '');
    await start(tester);
    await answer(tester);
    expect(state.turn, KgTurn.ready);
    expect(find.text('لم أسمعك، اضغط المايك وتكلّم'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('جهازٌ بلا مايك: الإجاباتُ أزرار', (tester) async {
    final state = await boot(tester, KgVoiceGameKind.colors, (q) => null);
    await start(tester);
    await answer(tester);
    expect(state.turn, KgTurn.listening, reason: 'يُحاوَل ثانيةً قبل «غير متاح»');
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('المايك غير متاح — اختر الجواب'), findsOneWidget);
    final right = state.question!.answer.id;
    expect(find.byKey(ValueKey('kg-choice-$right')), findsOneWidget);
    await tester.tap(find.byKey(ValueKey('kg-choice-$right')));
    await tester.pump();
    expect(state.turn, KgTurn.correct);
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('الجولةُ كاملة: عشرةُ أسئلة، ثم الحصيلة وزرُّ «العب مرة أخرى»', (tester) async {
    for (final kind in KgVoiceGameKind.values) {
      final state = await boot(tester, kind, (q) => q.story != null ? '${q.story!.result}' : q.answer.label);
      await start(tester);
      for (var i = 0; i < kgVoiceRoundLength; i++) {
        await answer(tester);
        expect(state.turn, KgTurn.correct, reason: '$kind سؤال ${i + 1}: ${state.question?.answer.label}');
        await afterCelebration(tester);
      }
      expect(find.byKey(const ValueKey('kg-voice-done')), findsOneWidget, reason: '$kind');
      expect(find.text('أجبت 10 من 10 إجابة صحيحة'), findsOneWidget);
      expect(events.where((e) => e == 'prompt'), hasLength(kgVoiceRoundLength), reason: '$kind: كلُّ سؤالٍ بمقطعه');
      await tester.tap(find.byKey(const ValueKey('kg-voice-again')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(state.question, isNotNull, reason: 'جولةٌ جديدة');
      await tester.pump(const Duration(seconds: 3));
    }
  });

  testWidgets('كلُّ شكلٍ وعلامةٍ ومسألةٍ يُرسم', (tester) async {
    final state = await boot(tester, KgVoiceGameKind.shapes, (q) => q.answer.label);
    await start(tester);
    final seen = <String>{};
    for (var i = 0; i < kgVoiceRoundLength; i++) {
      seen.add(state.question!.shape!.name);
      expect(find.byKey(ValueKey('kg-visual-${state.question!.shape!.name}')), findsOneWidget);
      await answer(tester);
      await afterCelebration(tester);
    }
    expect(seen, KgShape.values.map((s) => s.name).toSet());
    await tester.pump(const Duration(seconds: 3));

    final math =
        await boot(tester, KgVoiceGameKind.math, (q) => q.story != null ? '${q.story!.result}' : q.answer.label);
    await start(tester);
    var stories = 0;
    var signs = 0;
    for (var i = 0; i < kgVoiceRoundLength; i++) {
      final q = math.question!;
      if (q.story != null) {
        stories++;
        expect(find.byKey(const ValueKey('kg-visual-story')), findsOneWidget);
      } else {
        signs++;
        expect(find.byKey(ValueKey('kg-visual-sign-${q.sign!.name}')), findsOneWidget);
      }
      await answer(tester);
      await afterCelebration(tester);
    }
    expect((stories, signs), (8, 2));
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('المايكُ يستجيب والسؤالُ يُقال: يُسكته ثم يسمع', (tester) async {
    final state = await boot(tester, KgVoiceGameKind.colors, (q) => q.answer.label);
    holdPrompt = Completer<void>();
    await start(tester);
    expect(state.turn, KgTurn.prompting, reason: 'السؤالُ ما زال يُقال');
    await answer(tester);
    expect(events, containsAllInOrder(['clip:question_color.mp3', 'stop-prompt', 'ensure-mic']));
    expect(state.turn, KgTurn.correct, reason: 'سُمع الجوابُ وحُكم عليه');
    holdPrompt!.complete();
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('إذنُ الميكروفون مرفوض: الإجاباتُ أزرار، ولا يُسأل عن الإذن مع كل سؤال إن قُبل', (tester) async {
    final state = await boot(tester, KgVoiceGameKind.shapes, (q) => q.answer.label, micAllowed: false);
    await start(tester);
    await answer(tester);
    expect(find.text('لم يُسمح بالمايك — اختر الجواب، أو اضغط المايك لتسمح به'), findsOneWidget);
    expect(state.turn, KgTurn.ready);
    await tester.pump(const Duration(seconds: 3));

    final allowed = await boot(tester, KgVoiceGameKind.shapes, (q) => q.answer.label);
    await start(tester);
    for (var i = 0; i < 3; i++) {
      await answer(tester);
      await afterCelebration(tester);
    }
    expect(events.where((e) => e == 'ensure-mic'), hasLength(1), reason: 'الإذنُ مرّةً واحدة');
    expect(allowed.score, 3);
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('المسائلُ المصوّرة: المعادلةُ مقروءة، والعدُّ باللمس يُسمع، والقسمةُ توزيع', (tester) async {
    final state =
        await boot(tester, KgVoiceGameKind.math, (q) => q.story != null ? '${q.story!.result}' : q.answer.label);
    await start(tester);
    var sawDivide = false;
    var sawCount = false;
    for (var i = 0; i < kgVoiceRoundLength; i++) {
      final q = state.question!;
      final story = q.story;
      if (story != null) {
        expect(find.byKey(const ValueKey('kg-story-caption')), findsOneWidget);
        expect(events, contains('clip:how_much.mp3'));
        if (story.sign == KgSign.divide && !sawDivide) {
          sawDivide = true;
          events.clear();
          await tester.tap(find.byKey(const ValueKey('kg-pile-0')));
          await tester.pump();
          expect(find.byKey(const ValueKey('kg-pile-0')), findsNothing, reason: 'انتقل إلى الصندوق');
          expect(events, ['clip:n_1.mp3'], reason: 'في الصندوق الأوّل واحد');
        } else if (story.sign == KgSign.plus && !sawCount) {
          sawCount = true;
          events.clear();
          await tester.tap(find.byKey(const ValueKey('kg-thing-0')));
          await tester.pump();
          await tester.tap(find.byKey(const ValueKey('kg-thing-1')));
          await tester.pump();
          expect(events, ['clip:n_1.mp3', 'clip:n_2.mp3']);
          expect(find.text('2'), findsWidgets);
        }
      }
      events.clear();
      await answer(tester);
      await afterCelebration(tester);
    }
    expect(sawDivide && sawCount, isTrue);
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('الخياراتُ ظاهرةٌ مع المايك: يلمسها الطفلُ والمايكُ يسمع فيُغلق ويُحكم بلمسه', (tester) async {
    final state = await boot(tester, KgVoiceGameKind.colors, (q) => null);
    await start(tester);
    final q = state.question!;
    expect(find.byKey(ValueKey('kg-choice-${q.answer.id}')), findsOneWidget, reason: 'قبل أيّ ضغطٍ على المايك');
    expect(find.text('قل الجواب بصوتك، أو المس الصحيح 👇'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.byKey(ValueKey('kg-choice-${q.answer.id}')));
    await tester.pump();
    expect(state.turn, KgTurn.correct);
    await afterCelebration(tester);

    // ‏والمايكُ يسمع ولم يُسلّم بعد: لمسُ الخيار يُغلقه ويُحكم.
    final listening = Completer<void>();
    final general = await boot(
      tester,
      KgVoiceGameKind.general,
      (q) => null,
      listen: ({required onResult, onPartial}) async {
        events.add('listening');
        unawaited(listening.future.then((_) => onResult('كلامٌ متأخّر')));
        return true;
      },
    );
    await start(tester);
    await answer(tester);
    expect(general.turn, KgTurn.listening);
    final g = general.question!;
    expect(find.byKey(const ValueKey('kg-general-text')), findsOneWidget);
    await tester.tap(find.byKey(ValueKey('kg-choice-${g.distractors.first.id}')));
    await tester.pump();
    expect(events, contains('stop-listening'));
    expect(general.turn, KgTurn.wrong);
    listening.complete();
    await tester.pump();
    expect(general.turn, KgTurn.wrong, reason: 'ما يُسلّمه الإغلاقُ بعد اللمس يُهمَل');
    await tester.tap(find.byKey(ValueKey('kg-choice-${g.answer.id}')));
    await tester.pump();
    expect(general.turn, KgTurn.correct);
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('فشلٌ عابر يُعاد وحده، و«غير متاح» يُمحى حين يُفتح المايك', (tester) async {
    var calls = 0;
    var failNext = 1;
    final state = await boot(
      tester,
      KgVoiceGameKind.colors,
      (q) => q.answer.label,
      listen: ({required onResult, onPartial}) async {
        calls++;
        if (failNext > 0) {
          failNext--;
          return false;
        }
        final heard = tester.state<KgVoiceGameScreenState>(find.byType(KgVoiceGameScreen)).question!.answer.label;
        Future<void>.microtask(() => onResult(heard));
        return true;
      },
    );
    await start(tester);
    await answer(tester);
    await tester.pump(const Duration(milliseconds: 600));
    expect(calls, 2);
    expect(state.turn, KgTurn.correct, reason: 'المحاولةُ الثانيةُ سمعت');
    expect(find.text('المايك غير متاح — اختر الجواب'), findsNothing);
    await afterCelebration(tester);

    failNext = 2;
    await answer(tester);
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('المايك غير متاح — اختر الجواب'), findsOneWidget);
    await answer(tester);
    expect(find.text('المايك غير متاح — اختر الجواب'), findsNothing, reason: 'فُتح المايكُ فمُحي');
    expect(state.turn, KgTurn.correct);
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('محرّكٌ لا يُبلغ بنهاية الاستماع: يُغلق بعد نافذته ولا يعلق «أسمعك»', (tester) async {
    var stops = 0;
    final state = await boot(
      tester,
      KgVoiceGameKind.colors,
      (q) => null,
      listen: ({required onResult, onPartial}) async => true,
    );
    await start(tester);
    await answer(tester);
    expect(state.turn, KgTurn.listening);
    final before = events.where((e) => e == 'stop-listening').length;
    await tester.pump(KgVoiceGameScreenState.listenSafety + const Duration(seconds: 1));
    stops = events.where((e) => e == 'stop-listening').length - before;
    expect(stops, 1);
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('أسئلةُ الروضة: نصُّ السؤال ومقطعُه، ومشهدُه يتحرّك ويُلمس', (tester) async {
    final state = await boot(tester, KgVoiceGameKind.general, (q) => q.answer.label);
    await start(tester);
    final topics = <KgTopic>{};
    for (var i = 0; i < kgVoiceRoundLength; i++) {
      final g = state.question!.general!;
      topics.add(g.topic);
      expect(find.text(g.text), findsOneWidget);
      expect(events, contains('clip:${g.id}.mp3'));
      await tester.tap(find.byKey(const ValueKey('kg-general-emoji-0')));
      await tester.pump(const Duration(milliseconds: 100));
      await answer(tester);
      expect(state.turn, KgTurn.correct, reason: g.id);
      await afterCelebration(tester);
    }
    expect(topics, KgTopic.values.toSet());
    await tester.pump(const Duration(seconds: 3));
  });

  test('في الواجهة: بطاقةٌ واحدةٌ لألعاب الروضة بعد المذاكرة الذكية', () {
    expect(kgWorldModule, 13);
    expect(homeVisualOrder[4], kgWorldModule);
  });
}
