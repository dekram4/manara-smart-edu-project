import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:manara_student/src/l10n/student_strings.dart';
import 'package:manara_student/src/models/duel_chat.dart';
import 'package:manara_student/src/services/student_settings.dart';
import 'package:manara_student/src/widgets/duel_chat.dart';

/// دردشةُ المبارزة: ما يُقبل مما يصل، ومتى يُسمح بالإرسال.
///
/// ── لماذا يُختبر هذا بعينه ──
/// ما يصل من القناة **كتبه جهازٌ آخر**: نصٌّ قد يكون فارغاً أو ألفَ حرف،
/// وصوتٌ قد يكون ضخماً أو ليس ترميزاً أصلاً. وكلُّ واحدةٍ من هذه تمرّ بلا
/// خطأٍ يظهر — تُرسم فقاعةٌ خاوية، أو تغطّي الشاشة، أو تُرفع رميةٌ في مستمع
/// قناةٍ فتسقط المباراة.
///
/// والفاصلُ الزمنيُّ يُختبر بساعةٍ مزيّفة: حرسٌ على الإزعاج لا يُتحقَّق منه
/// بانتظار ثانيتين في اختبار.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    StudentSettings.resetForTest();
  });

  group('ما يُقرأ مما يصل', () {
    test('رسالةٌ نصّيةٌ سليمة تُقرأ', () {
      final message = DuelChatMessage.fromPayload({
        'id': 'student_1',
        'kind': 'text',
        'text': 'أحسنت!',
      });
      expect(message, isNotNull);
      expect(message!.senderId, 'student_1');
      expect(message.isVoice, isFalse);
      expect(message.text, 'أحسنت!');
    });

    test('ونصٌّ فارغٌ أو مسافاتٌ لا يُقرأ', () {
      // فقاعةٌ خاويةٌ تظهر فوق الشخصية ثلاثَ ثوانٍ بلا معنى.
      for (final text in ['', '   ', '\n\n', '\t ']) {
        expect(
          DuelChatMessage.fromPayload({'id': 'a', 'kind': 'text', 'text': text}),
          isNull,
          reason: 'نصّ: «$text»',
        );
      }
    });

    test('ونصٌّ طويلٌ يُقصّ ولا يُرفض', () {
      // ── والقصُّ لا الرفض ──
      // رسالةٌ طويلةٌ أرسلها زميلٌ بجهازٍ معدَّل: رفضُها يُسكت الدردشة،
      // وقبولُها كما هي يرسم فقاعةً تغطّي السؤالَ والخيارات.
      final long = 'ا' * (duelChatMaxChars * 3);
      final message = DuelChatMessage.fromPayload({
        'id': 'a',
        'kind': 'text',
        'text': long,
      });
      expect(message, isNotNull);
      expect(message!.text.length, duelChatMaxChars);
    });

    test('والأسطرُ تُجمع في سطر', () {
      final message = DuelChatMessage.fromPayload({
        'id': 'a',
        'kind': 'text',
        'text': 'أحسنت\n\n\nيا بطل',
      });
      expect(message!.text, 'أحسنت يا بطل');
    });

    test('ورسالةٌ بلا مُرسِلٍ لا تُقرأ', () {
      // بلا معرّفٍ لا يُعرف أيُّ فقاعةٍ تُعرض — ولا يُعرف أنها رسالتي عائدةً.
      expect(DuelChatMessage.fromPayload({'kind': 'text', 'text': 'هلا'}), isNull);
      expect(
        DuelChatMessage.fromPayload({'id': '  ', 'kind': 'text', 'text': 'هلا'}),
        isNull,
      );
      expect(DuelChatMessage.fromPayload('نصّ لا خريطة'), isNull);
      expect(DuelChatMessage.fromPayload(null), isNull);
    });

    test('ومقطعٌ صوتيٌّ سليم يُقرأ بايتاتِه', () {
      final bytes = Uint8List.fromList(List.filled(2048, 7));
      final message = DuelChatMessage.fromPayload({
        'id': 'a',
        'kind': 'voice',
        'audio': base64Encode(bytes),
      });
      expect(message, isNotNull);
      expect(message!.isVoice, isTrue);
      expect(message.audio, bytes);
    });

    test('ومقطعٌ أكبرُ من السقف يُترك', () {
      // قناةُ Realtime لها سقفُ حجم، ومقطعٌ ضخمٌ يُجهد المشغّل على جهاز طفل.
      final huge = Uint8List(duelVoiceMaxBytes + 1);
      expect(
        DuelChatMessage.fromPayload({
          'id': 'a',
          'kind': 'voice',
          'audio': base64Encode(huge),
        }),
        isNull,
      );
    });

    test('وترميزٌ معطوبٌ لا يرفع رمية', () {
      // ── وهذا موضعُ سقوطٍ محتمل ──
      // `base64Decode` ترفع على نصٍّ ليس ترميزاً، والرميةُ في مستمعِ قناةٍ
      // تُسقط المباراةَ كلَّها لا الرسالةَ وحدها.
      for (final bad in ['!!!ليس ترميزاً!!!', 'AAA', '']) {
        expect(
          () => DuelChatMessage.fromPayload({
            'id': 'a',
            'kind': 'voice',
            'audio': bad,
          }),
          returnsNormally,
          reason: bad,
        );
        expect(
          DuelChatMessage.fromPayload({'id': 'a', 'kind': 'voice', 'audio': bad}),
          isNull,
          reason: bad,
        );
      }
    });

    test('وما يُبثّ يُقرأ كما أُرسل', () {
      final bytes = Uint8List.fromList(List.filled(1024, 3));
      for (final original in [
        const DuelChatMessage(
          senderId: 'a',
          kind: DuelChatKind.text,
          text: '🔥',
        ),
        DuelChatMessage(
          senderId: 'b',
          kind: DuelChatKind.voice,
          audio: bytes,
        ),
      ]) {
        final back = DuelChatMessage.fromPayload(original.toPayload());
        expect(back, isNotNull);
        expect(back!.senderId, original.senderId);
        expect(back.kind, original.kind);
        expect(back.text, original.text);
        expect(back.audio, original.audio);
      }
    });
  });

  group('حرسُ الإزعاج', () {
    test('الأولى تمرّ والثانيةُ تُمنع', () {
      var now = DateTime(2026, 10, 1, 9);
      final gate = DuelChatCooldown(gap: const Duration(seconds: 2), now: () => now);
      expect(gate.claim(), isTrue);
      expect(gate.claim(), isFalse);
      now = now.add(const Duration(milliseconds: 1999));
      expect(gate.claim(), isFalse);
      now = now.add(const Duration(milliseconds: 2));
      expect(gate.claim(), isTrue);
    });

    test('والمحاولةُ المرفوضة لا تُمدّ المنع', () {
      // ── وهذا العطبُ يسهل أن يُكتب ──
      // لو سجّلت كلُّ محاولةٍ وقتَها لمدّ الطفلُ المنعَ على نفسه بلا نهاية:
      // يضغط كلَّ نصف ثانية فلا يُسمح له أبداً.
      var now = DateTime(2026, 10, 1, 9);
      final gate = DuelChatCooldown(gap: const Duration(seconds: 2), now: () => now);
      expect(gate.claim(), isTrue);
      for (var i = 0; i < 4; i += 1) {
        now = now.add(const Duration(milliseconds: 400));
        gate.claim();
      }
      // مضت ١٦٠٠ مللي من الأولى: لا يزال ممنوعاً.
      expect(gate.ready, isFalse);
      now = now.add(const Duration(milliseconds: 500));
      expect(gate.ready, isTrue, reason: 'المحاولاتُ المرفوضة مدّت المنع');
    });

    test('وما بقي يُقرأ ليُعرض للطفل', () {
      var now = DateTime(2026, 10, 1, 9);
      final gate = DuelChatCooldown(gap: const Duration(seconds: 2), now: () => now);
      expect(gate.remaining, Duration.zero);
      gate.claim();
      now = now.add(const Duration(milliseconds: 500));
      expect(gate.remaining, const Duration(milliseconds: 1500));
      now = now.add(const Duration(seconds: 5));
      expect(gate.remaining, Duration.zero, reason: 'لا يصير سالباً');
    });
  });

  group('نافذةُ الدردشة', () {
    late List<String> sent;
    late ValueNotifier<bool> recording;
    late ValueNotifier<Duration> cooldown;

    setUp(() {
      sent = [];
      recording = ValueNotifier(false);
      cooldown = ValueNotifier(Duration.zero);
    });

    tearDown(() {
      recording.dispose();
      cooldown.dispose();
    });

    Future<void> pump(WidgetTester tester, {bool holds = false}) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DuelChatSheet(
              onSendText: (text) {
                sent.add(text);
                return true;
              },
              onHoldStart: () => sent.add('hold:start'),
              onHoldEnd: ({required cancelled}) =>
                  sent.add('hold:end:$cancelled'),
              recording: recording,
              cooldownLeft: cooldown,
            ),
          ),
        ),
      );
      await tester.pump();
    }

    testWidgets('الإيموجي يُرسل بضغطةٍ واحدة', (tester) async {
      await pump(tester);
      await tester.tap(find.text('🔥'));
      await tester.pump();
      expect(sent, ['🔥']);
    });

    testWidgets('والعبارةُ السريعة تُرسل نصَّها لا مفتاحَها', (tester) async {
      // ── ومفتاحٌ يُرسل بدل نصّه يصل إلى الخصم «duel.chat.quick.focus» ──
      await StudentSettings.setLocale(StudentSettings.arabic);
      await pump(tester);
      await tester.tap(find.text('أحسنت!'));
      await tester.pump();
      expect(sent, ['أحسنت!']);
    });

    testWidgets('والمكتوبُ يُرسل ويُفرَّغ الحقل', (tester) async {
      await pump(tester);
      await tester.enterText(find.byType(TextField), '  ركّز يا بطل  ');
      await tester.tap(find.byIcon(Icons.send_rounded));
      await tester.pump();
      expect(sent, ['ركّز يا بطل'], reason: 'المسافاتُ تُقلَّم');
      expect(tester.widget<TextField>(find.byType(TextField)).controller?.text,
          isEmpty);
    });

    testWidgets('وحقلٌ فارغٌ لا يُرسل شيئاً', (tester) async {
      await pump(tester);
      await tester.tap(find.byIcon(Icons.send_rounded));
      await tester.pump();
      expect(sent, isEmpty);
    });

    testWidgets('والضغطُ المطوّل يبدأ التسجيل، والرفعُ يُرسله', (tester) async {
      await pump(tester);
      final mic = find.byIcon(Icons.mic_rounded);
      expect(mic, findsOneWidget);
      final gesture = await tester.startGesture(tester.getCenter(mic));
      await tester.pump();
      expect(sent, ['hold:start']);
      await gesture.up();
      await tester.pump();
      expect(sent, ['hold:start', 'hold:end:false']);
    });

    testWidgets('وحالُ التسجيل تُرى', (tester) async {
      await pump(tester);
      recording.value = true;
      await tester.pump();
      // أيقونةُ النقطة الحمراء تحلّ محلَّ الميكروفون: الطفلُ يعرف أنه يسجّل.
      expect(find.byIcon(Icons.fiber_manual_record_rounded), findsOneWidget);
      expect(find.byIcon(Icons.mic_rounded), findsNothing);
    });

    testWidgets('وما بقي من المنع يُعرض بالثواني', (tester) async {
      await StudentSettings.setLocale(StudentSettings.arabic);
      await pump(tester);
      expect(find.textContaining('انتظر'), findsNothing);
      cooldown.value = const Duration(milliseconds: 1400);
      await tester.pump();
      expect(find.textContaining('انتظر'), findsOneWidget);
      expect(find.textContaining('2'), findsOneWidget, reason: 'يُجبَر لأعلى');
    });
  });

  group('فقاعةُ الكلام', () {
    testWidgets('تُرسم نصّاً، وتحفظ مكانها وهي غائبة', (tester) async {
      Future<void> pumpBubble(DuelChatMessage? message) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: DuelSpeechBubble(
                message: message,
                appearance: null,
                mine: false,
                speaking: false,
              ),
            ),
          ),
        );
        await tester.pump();
      }

      await pumpBubble(null);
      // ── والمساحةُ محفوظة ──
      // لو انكمشت عند الغياب لتحرّكت الحلبةُ تحتها كلَّما وصلت رسالة، فينتقل
      // زرٌّ تحت إصبع الطفل لحظةَ ضغطه.
      final empty = tester.getSize(find.byType(DuelSpeechBubble));
      expect(empty.height, greaterThan(0));
      expect(find.text('أحسنت!'), findsNothing);

      await pumpBubble(
        const DuelChatMessage(
          senderId: 'a',
          kind: DuelChatKind.text,
          text: 'أحسنت!',
        ),
      );
      expect(find.text('أحسنت!'), findsOneWidget);
      expect(tester.getSize(find.byType(DuelSpeechBubble)).height, empty.height);
    });

    testWidgets('والصوتيةُ تُرسم سماعةً لا نصّاً', (tester) async {
      await StudentSettings.setLocale(StudentSettings.arabic);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DuelSpeechBubble(
              message: DuelChatMessage(
                senderId: 'a',
                kind: DuelChatKind.voice,
                audio: Uint8List(1024),
              ),
              appearance: null,
              mine: false,
              speaking: true,
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.byIcon(Icons.volume_up_rounded), findsOneWidget);
      expect(find.text(tr('duel.chat.voiceNote')), findsOneWidget);
    });
  });

  group('نصوصُ الدردشة', () {
    test('كلُّ مفتاحٍ مترجَمٌ في اللغتين', () async {
      final keys = [
        'duel.chat.open',
        'duel.chat.hint',
        'duel.chat.send',
        'duel.chat.hold',
        'duel.chat.recording',
        'duel.chat.voiceNote',
        'duel.chat.footer',
        'duel.chat.wait',
        'duel.chat.notSent',
        'duel.chat.noMic',
        'duel.chat.tooShort',
        'duel.chat.tooBig',
        ...duelQuickPhraseKeys,
      ];
      for (final locale in [StudentSettings.arabic, StudentSettings.english]) {
        await StudentSettings.setLocale(locale);
        for (final key in keys) {
          expect(StudentStrings.has(key), isTrue,
              reason: '$key في ${locale.languageCode}');
          expect(tr(key), isNot(key), reason: key);
        }
      }
    });

    test('وحدودُ التسجيل هي التي طُلبت', () {
      // خمسُ ثوانٍ كحدٍّ أقصى، ومدّةُ الفقاعة ثلاث.
      expect(duelVoiceMaxDuration, const Duration(seconds: 5));
      expect(duelBubbleLife, const Duration(seconds: 3));
    });

    test('وإذنُ المايكروفون معلَنٌ في بيان أندرويد', () {
      // ── وبلا إعلانٍ لا يُسأل الإذنُ أصلاً ──
      // `hasPermission` تعود بـ`false` دائماً على أندرويد إن لم يكن الإذنُ
      // في البيان، فلا يسجّل الزرُّ شيئاً أبداً ولا يظهر خطأٌ يقول لماذا.
      final manifest =
          File('android/app/src/main/AndroidManifest.xml').readAsStringSync();
      expect(manifest, contains('android.permission.RECORD_AUDIO'));
    });
  });
}
