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
          DuelChatMessage.fromPayload(
              {'id': 'a', 'kind': 'text', 'text': text}),
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
      expect(
          DuelChatMessage.fromPayload({'kind': 'text', 'text': 'هلا'}), isNull);
      expect(
        DuelChatMessage.fromPayload(
            {'id': '  ', 'kind': 'text', 'text': 'هلا'}),
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
          DuelChatMessage.fromPayload(
              {'id': 'a', 'kind': 'voice', 'audio': bad}),
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

  group('حالُ كتم الدردشة', () {
    test('بلا كتمٍ كلُّ شيءٍ مسموح', () {
      const state = DuelChatMuteState();
      expect(state.isChatMuted, isFalse);
      expect(state.canSend, isTrue);
      expect(state.showsIncoming, isTrue);
      expect(state.playsIncomingVoice, isTrue);
      expect(state.warnsRivalMuted, isFalse);
    });

    test('وكتمي يمنع الأربعةَ معاً', () {
      // ── وهذا هو ما يُنسى ──
      // الكتمُ يمنع أربعةَ أشياء: فقاعةً تُرسم، ومقطعاً يُشغَّل، ونصّاً يُرسل،
      // وصوتاً يُسجَّل. وشروطٌ مبثوثةٌ في شاشةٍ يُنسى واحدٌ منها — فيكتم
      // الطفلُ الدردشةَ ويظلّ يسمع صوتَ خصمه.
      const state = DuelChatMuteState(isChatMuted: true);
      expect(state.canSend, isFalse);
      expect(state.showsIncoming, isFalse);
      expect(state.playsIncomingVoice, isFalse);
    });

    test('وكتمُ الخصم لا يمنعني من شيء، ويُنبّهني', () {
      const state = DuelChatMuteState(isRivalMuted: true);
      expect(state.canSend, isTrue, reason: 'كتمُه ليس كتمي');
      expect(state.showsIncoming, isTrue);
      expect(state.warnsRivalMuted, isTrue);
    });

    test('ولا يُنبَّه الكاتمُ عن كتم خصمه', () {
      // هو يعرف أنه كاتم، وخبرُ حال الخصم في تلك اللحظة ضجيجٌ لا خبر.
      const both = DuelChatMuteState(isChatMuted: true, isRivalMuted: true);
      expect(both.warnsRivalMuted, isFalse);
    });

    test('والتبديلُ يحفظ الطرفَ الآخر', () {
      // بدّلتُ كتمي فبقي ما أعرفه عن الخصم: لو ضاع لظننتُ أنه يسمعني.
      const state = DuelChatMuteState(isRivalMuted: true);
      final muted = state.copyWith(isChatMuted: true);
      expect(muted.isChatMuted, isTrue);
      expect(muted.isRivalMuted, isTrue);
      final back = muted.copyWith(isChatMuted: false);
      expect(back, const DuelChatMuteState(isRivalMuted: true));
    });
  });

  group('حرسُ الإزعاج', () {
    test('الأولى تمرّ والثانيةُ تُمنع', () {
      var now = DateTime(2026, 10, 1, 9);
      final gate =
          DuelChatCooldown(gap: const Duration(seconds: 2), now: () => now);
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
      final gate =
          DuelChatCooldown(gap: const Duration(seconds: 2), now: () => now);
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
      final gate =
          DuelChatCooldown(gap: const Duration(seconds: 2), now: () => now);
      expect(gate.remaining, Duration.zero);
      gate.claim();
      now = now.add(const Duration(milliseconds: 500));
      expect(gate.remaining, const Duration(milliseconds: 1500));
      now = now.add(const Duration(seconds: 5));
      expect(gate.remaining, Duration.zero, reason: 'لا يصير سالباً');
    });
  });

  group('زرُّ الصوت والتفاعلات', () {
    testWidgets('الضغطُ المطوّل يبدأ التسجيل، والرفعُ يرسله، والإلغاءُ لا يرسل',
        (tester) async {
      final recording = ValueNotifier(false);
      final log = <String>[];
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Center(
            child: DuelVoiceButton(
              recording: recording,
              onHoldStart: () {
                log.add('start');
                recording.value = true;
              },
              onHoldEnd: ({required bool cancelled}) {
                log.add(cancelled ? 'cancel' : 'send');
                recording.value = false;
              },
            ),
          ),
        ),
      ));
      expect(find.text(tr('duel.voice.hold')), findsOneWidget);
      final gesture = await tester
          .startGesture(tester.getCenter(find.byType(DuelVoiceButton)));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text(tr('duel.voice.recording')), findsOneWidget);
      await gesture.up();
      await tester.pump(const Duration(milliseconds: 300));
      expect(log, ['start', 'send']);
      final second = await tester
          .startGesture(tester.getCenter(find.byType(DuelVoiceButton)));
      await tester.pump();
      await second.cancel();
      await tester.pump(const Duration(milliseconds: 300));
      expect(log, ['start', 'send', 'start', 'cancel']);
    });

    testWidgets('شريطُ التفاعلات: ستّةُ رموز، وكلُّ ضغطةٍ ترسل رمزَها',
        (tester) async {
      final sent = <String>[];
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: Center(child: DuelReactionBar(onReact: sent.add))),
      ));
      for (final emoji in duelReactions) {
        expect(find.text(emoji), findsOneWidget);
      }
      await tester.tap(find.text('🔥'));
      await tester.tap(find.text('👏'));
      await tester.pump(const Duration(milliseconds: 200));
      expect(sent, ['🔥', '👏']);
    });

    testWidgets('التفاعلُ يطير باسم صاحبه ثم يختفي', (tester) async {
      final controller = DuelReactionController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: DuelReactionLayer(controller: controller)),
      ));
      controller.pop('🏆', who: 'سارة');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('🏆'), findsOneWidget);
      expect(find.text('سارة'), findsOneWidget);
      await tester.pump(const Duration(seconds: 2));
      expect(find.text('🏆'), findsNothing);
      expect(controller.pops, isEmpty);
    });

    test('ضغطٌ متتابع لا يملأ الشاشة: اثنا عشر معاً على الأكثر', () {
      final controller = DuelReactionController();
      for (var i = 0; i < 30; i++) {
        controller.pop('👍');
      }
      expect(controller.pops.length, 12);
      controller.dispose();
    });
  });

  group('زرُّ الكتم', () {
    testWidgets('الكتمُ يقلب الأيقونةَ واللون', (tester) async {
      Future<void> pumpPair({required bool muted}) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Column(
                children: [
                  DuelMuteToggle(muted: muted, onPressed: () {}),
                ],
              ),
            ),
          ),
        );
        await tester.pump();
      }

      await pumpPair(muted: false);
      expect(find.byIcon(Icons.notifications_active_rounded), findsOneWidget);

      await pumpPair(muted: true);
      expect(find.byIcon(Icons.notifications_off_rounded), findsOneWidget);
    });

    testWidgets('وزرُّ الكتم يستجيب للّمس', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DuelMuteToggle(muted: false, onPressed: () => taps += 1),
          ),
        ),
      );
      await tester.tap(find.byType(DuelMuteToggle));
      await tester.pump();
      expect(taps, 1);
      // ومساحةُ لمسٍ يبلغها إصبعُ طفل.
      final size = tester.getSize(find.byType(DuelMuteToggle));
      expect(size.width, greaterThanOrEqualTo(40));
      expect(size.height, greaterThanOrEqualTo(40));
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
      expect(
          tester.getSize(find.byType(DuelSpeechBubble)).height, empty.height);
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
        'duel.chat.mute',
        'duel.chat.unmute',
        'duel.chat.mutedOn',
        'duel.chat.mutedOff',
        'duel.chat.mutedSelf',
        'duel.chat.mutedPanel',
        'duel.chat.rivalMuted',
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
