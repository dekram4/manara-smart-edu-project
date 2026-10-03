import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:manara_student/src/l10n/student_strings.dart';
import 'package:manara_student/src/models/duel_chat.dart';
import 'package:manara_student/src/models/duel_question.dart';
import 'package:manara_student/src/services/student_duel_service.dart';
import 'package:manara_student/src/services/student_settings.dart';
import 'package:manara_student/src/widgets/duel_versus.dart';

/// ترقيةُ المبارزة: أسئلةٌ من الخادم، ونقاطُ سرعة، وسجلُّ محادثةٍ يبقى.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    StudentSettings.resetForTest();
  });

  group('أسئلةُ المباراة تُقرأ من الخادم', () {
    Map<String, Object?> question({
      String id = 'general:abc',
      String category = 'general',
      String prompt = 'ما أكبر كوكب؟',
      List<String> options = const ['المشتري', 'الأرض', 'المريخ', 'عطارد'],
      int answerAt = 0,
    }) =>
        {
          'id': id,
          'category': category,
          'prompt': prompt,
          'options': options,
          'answerAt': answerAt,
        };

    test('سؤالٌ سليمٌ يُقرأ بكلّ حقوله', () {
      final read = DuelQuestion.fromJson(question());
      expect(read, isNotNull);
      expect(read!.id, 'general:abc');
      expect(read.category, 'general');
      expect(read.options, hasLength(4));
      expect(read.options[read.answerAt], 'المشتري');
    });

    test('وموضعُ جوابٍ خارج الخيارات يُردّ', () {
      // ── وهذا أخطرُ حقلٍ في الحزمة ──
      // سؤالٌ بموضعٍ خارج خياراته يُخرج سؤالاً **لا جوابَ صحيحَ له**: يجيب
      // الطفلُ بكلِّ خيارٍ فيُحسب خطأً، ولا خطأٌ يظهر في سجلّ.
      expect(DuelQuestion.fromJson(question(answerAt: 9)), isNull);
      expect(DuelQuestion.fromJson(question(answerAt: -1)), isNull);
      expect(DuelQuestion.fromJson(question(answerAt: 4)), isNull);
    });

    test('وسؤالٌ بخيارٍ واحدٍ ليس سؤالاً', () {
      expect(
        DuelQuestion.fromJson(question(options: ['وحيد'], answerAt: 0)),
        isNull,
      );
      expect(DuelQuestion.fromJson(question(options: const [])), isNull);
    });

    test('وحقلٌ ناقصٌ يُردّ ولا يرفع', () {
      for (final bad in <Object?>[
        null,
        'نصّ',
        <String, Object?>{},
        question(prompt: ''),
        question(id: ''),
        {...question(), 'answerAt': '0'},
      ]) {
        expect(() => DuelQuestion.fromJson(bad), returnsNormally);
        expect(DuelQuestion.fromJson(bad), isNull, reason: '$bad');
      }
    });

    test('وبابٌ لا يُعرف يُقرأ عامّاً لا يُسقط السؤال', () {
      // صفٌّ كُتب بنسخةٍ أحدثَ فيها بابٌ لم يُعرف بعد: السؤالُ صالحٌ، وإسقاطُه
      // يُفقد المباراةَ سؤالاً لأجل عنوانٍ يُعرض.
      final read = DuelQuestion.fromJson(question(category: 'astronomy'));
      expect(read, isNotNull);
      expect(read!.category, 'general');
    });

    test('ومفتاحُ البابِ يُبنى من اسمه', () {
      expect(
          DuelQuestion.fromJson(question())!.categoryKey, 'duel.cat.general');
    });

    test('والمباراةُ تحمل أسئلتَها وقواعدَها', () {
      final match = DuelMatch.fromJson({
        'id': 'duel_1',
        'rounds': 10,
        'questions': [question(), question(id: 'logic:x', category: 'logic')],
        'questionSeconds': 10,
        'pointsCorrect': 10,
        'pointsSpeedMax': 5,
        'maxScore': 150,
      });
      expect(match, isNotNull);
      expect(match!.questions, hasLength(2));
      expect(match.rounds, 10);
      expect(match.rules.questionSeconds, 10);
      expect(match.rules.maxScore, 150);
    });

    test('وسؤالٌ معطوبٌ في الحزمة يُسقَط ولا تُسقط المباراة', () {
      final match = DuelMatch.fromJson({
        'id': 'duel_1',
        'questions': [question(), question(answerAt: 99), 'ليس سؤالاً'],
      });
      expect(match!.questions, hasLength(1));
    });

    test('ومباراةٌ بلا أسئلةٍ تُقرأ، فلها مسلكٌ احتياطيّ', () {
      // ردُّ الصندوق لا يحمل أسئلة، وفتحُ المباراة يطلبها. فلو رُدّت المباراةُ
      // لغياب الأسئلة لما ظهرت في الردهة أصلاً.
      final match = DuelMatch.fromJson({'id': 'duel_1'});
      expect(match, isNotNull);
      expect(match!.questions, isEmpty);
    });
  });

  group('نقاطُ السرعة', () {
    const rules = DuelRules(
      questionSeconds: 10,
      pointsCorrect: 10,
      pointsSpeedMax: 5,
    );

    test('الصحيحُ في أوّل لحظةٍ ينال الأساسَ والسرعةَ كاملة', () {
      expect(
        rules.pointsFor(correct: true, left: const Duration(seconds: 10)),
        15,
      );
    });

    test('وفي منتصف الوقتِ نصفُ السرعة', () {
      expect(
          rules.pointsFor(correct: true, left: const Duration(seconds: 5)), 13);
    });

    test('وفي آخر لحظةٍ الأساسُ وحده', () {
      expect(rules.pointsFor(correct: true, left: Duration.zero), 10);
    });

    test('والخطأُ لا شيءَ له ولو كان أسرع', () {
      // ── وهذا شرطُ أن تبقى المباراةُ عن المعرفة ──
      // لو نال الخطأُ السريعُ شيئاً صار التخمينُ السريعُ استراتيجيّة.
      expect(
        rules.pointsFor(correct: false, left: const Duration(seconds: 10)),
        0,
      );
    });

    test('والمؤجَّلةُ بلا عدّادٍ تنال الأساسَ وحده', () {
      // لا عدّادَ فيها، فلا سرعةَ تُقاس: لاعبٌ وحده لا يسابق أحداً.
      expect(rules.pointsFor(correct: true, left: null), 10);
    });

    test('ووقتٌ أكثرُ من النافذة لا يزيد على السقف', () {
      // ساعةُ الجهاز قد تُقدّم، فيبدو المتبقّي أكثرَ من النافذة كلّها.
      expect(
        rules.pointsFor(correct: true, left: const Duration(minutes: 1)),
        15,
      );
    });

    test('وأقصى ما يمكن جمعُه يبقى داخل سقف الخادم', () {
      // ── ورفضُ الخادم يعني مباراةً كاملةً تُلعب ثم تُردّ نتيجتُها ──
      const match = DuelRules(maxScore: 150);
      final best = 10 * rules.pointsFor(correct: true, left: rules.window);
      expect(best, lessThanOrEqualTo(match.maxScore));
    });

    test('والقواعدُ تُقرأ من الخادم، وتُفترض عند سكوته', () {
      final fromServer = DuelRules.fromJson({
        'questionSeconds': 8,
        'pointsCorrect': 20,
        'pointsSpeedMax': 10,
        'maxScore': 300,
      });
      expect(fromServer.questionSeconds, 8);
      expect(fromServer.pointsCorrect, 20);
      // وقيمةٌ صفرٌ أو سالبةٌ أو ليست عدداً تُترك: نافذةٌ صفرٌ تُقسم عليها.
      final broken = DuelRules.fromJson({
        'questionSeconds': 0,
        'pointsCorrect': -5,
        'maxScore': 'كثير',
      });
      expect(broken.questionSeconds, 10);
      expect(broken.pointsCorrect, 10);
      expect(broken.maxScore, 150);
      expect(DuelRules.fromJson(null).questionSeconds, 10);
    });
  });

  group('سجلُّ المحادثة المحفوظ', () {
    test('رسالةٌ نصّيةٌ تُقرأ من السجلّ بمعرّفها ووقتها', () {
      final message = DuelChatMessage.fromStored({
        'id': 'row-1',
        'senderId': 'student_2',
        'kind': 'text',
        'text': 'أحسنت!',
        'createdAt': '2026-10-01T09:00:00.000Z',
      });
      expect(message, isNotNull);
      expect(message!.id, 'row-1');
      expect(message.text, 'أحسنت!');
      expect(message.at, isNotNull);
      expect(message.isVoice, isFalse);
    });

    test('ومقطعٌ صوتيٌّ يُقرأ بايتاتِه', () {
      final bytes = Uint8List.fromList(List.filled(2048, 5));
      final message = DuelChatMessage.fromStored({
        'id': 'row-2',
        'senderId': 'student_2',
        'kind': 'voice',
        'audio': base64Encode(bytes),
      });
      expect(message, isNotNull);
      expect(message!.isVoice, isTrue);
      expect(message.audio, bytes);
    });

    test('وما يُحفظ يُقرأ كما أُرسل', () {
      // ── وجسمٌ واحدٌ للنوعين ──
      // النوعُ مكتوبٌ في `kind`، فلا يحتاج القارئُ أن يعرف أيَّ عمودٍ يقرأ.
      final bytes = Uint8List.fromList(List.filled(900, 9));
      const text = DuelChatMessage(
        senderId: 'a',
        kind: DuelChatKind.text,
        text: 'ركّز!',
      );
      final voice = DuelChatMessage(
        senderId: 'a',
        kind: DuelChatKind.voice,
        audio: bytes,
      );
      expect(text.storedBody, 'ركّز!');
      expect(voice.storedBody, base64Encode(bytes));
      expect(
        DuelChatMessage.fromStored({
          'senderId': 'a',
          'kind': 'voice',
          'audio': voice.storedBody,
        })!
            .audio,
        bytes,
      );
    });

    test('وصفٌّ معطوبٌ في السجلّ يُترك ولا يرفع', () {
      for (final bad in <Object?>[
        null,
        'صفّ',
        <String, Object?>{},
        {'senderId': '', 'kind': 'text', 'text': 'هلا'},
        {'senderId': 'a', 'kind': 'text', 'text': '   '},
        {'senderId': 'a', 'kind': 'voice', 'audio': '!!!ليس ترميزاً!!!'},
        {'senderId': 'a', 'kind': 'voice', 'audio': ''},
      ]) {
        expect(() => DuelChatMessage.fromStored(bad), returnsNormally);
        expect(DuelChatMessage.fromStored(bad), isNull, reason: '$bad');
      }
    });

    test('ومقطعٌ أكبرُ من السقف يُترك', () {
      final huge = Uint8List(duelVoiceMaxBytes + 1);
      expect(
        DuelChatMessage.fromStored({
          'senderId': 'a',
          'kind': 'voice',
          'audio': base64Encode(huge),
        }),
        isNull,
      );
    });
  });

  group('شريطُ المقارنة والعدّاد', () {
    testWidgets('النقاطُ تُعرض للطرفين، والمتقدّمُ يُتوَّج', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: DuelVersusBar(
              myName: 'أنت',
              rivalName: 'سارة',
              myAppearance: null,
              rivalAppearance: null,
              myPoints: 42,
              rivalPoints: 15,
              live: true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('VS'), findsOneWidget);
      expect(find.text('أنت'), findsOneWidget);
      expect(find.text('سارة'), findsOneWidget);
      expect(find.text('42'), findsOneWidget);
      expect(find.text('15'), findsOneWidget);
      // تاجٌ واحدٌ للمتقدّم لا تاجان.
      expect(find.text('👑'), findsOneWidget);
    });

    testWidgets('وعند التعادلِ لا تاجَ لأحد', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: DuelVersusBar(
              myName: 'أنت',
              rivalName: 'سارة',
              myAppearance: null,
              rivalAppearance: null,
              myPoints: 20,
              rivalPoints: 20,
              live: false,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('👑'), findsNothing);
    });

    testWidgets('والعدّادُ يعرض ما بقي مُجبَراً لأعلى', (tester) async {
      // ── و`ceil` لا `round` ──
      // من بقي له ٢٠٠ مللي يرى «١» لا «٠»، والصفرُ المعروضُ وللسؤال بقيّةٌ
      // يُقرأ عطباً.
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: DuelCountdown(
              left: Duration(milliseconds: 200),
              window: Duration(seconds: 10),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.text('1'), findsOneWidget);
    });

    testWidgets('ونافذةٌ صفرٌ لا تُقسم عليها', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: DuelCountdown(left: Duration.zero, window: Duration.zero),
          ),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
    });
  });

  group('نصوصُ الترقية', () {
    test('لكل بابِ أسئلةٍ عنوانٌ في اللغتين', () async {
      for (final locale in [StudentSettings.arabic, StudentSettings.english]) {
        await StudentSettings.setLocale(locale);
        for (final category in [
          'general',
          'logic',
          'quick',
          'school',
          'lesson'
        ]) {
          final key = 'duel.cat.$category';
          expect(StudentStrings.has(key), isTrue, reason: key);
          expect(tr(key), isNot(key), reason: key);
        }
        for (final key in [
          'duel.waitRival',
          'duel.nextSoon',
          'duel.breakdown',
          'duel.chat.empty',
        ]) {
          expect(StudentStrings.has(key), isTrue, reason: key);
        }
      }
    });

    test('وتفصيلُ النقاط يحمل أرقامَه', () async {
      await StudentSettings.setLocale(StudentSettings.arabic);
      final line = trf('duel.breakdown', {
        'correct': '7',
        'total': '10',
        'points': '95',
      });
      expect(line, contains('7'));
      expect(line, contains('10'));
      expect(line, contains('95'));
      expect(line, isNot(contains('{')));
    });
  });
}
