import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:manara_student/src/l10n/student_strings.dart';
import 'package:manara_student/src/models/student_content.dart';
import 'package:manara_student/src/screens/student_tutor_screen.dart';
import 'package:manara_student/src/services/meeting_launcher.dart';
import 'package:manara_student/src/services/student_settings.dart';

/// «الاتصال بالاجتماع» يفتح الاجتماعَ فعلاً، ويقول للطفل حين لا يستطيع.
///
/// كان الزرُّ يعيد تحميلَ الإطار نفسه، أو يحاول تضمينَ Meet الذي يرفض أن
/// يُضمَّن — فيضغط الطفلُ ولا يحدث شيء.
void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    StudentSettings.resetForTest();
  });

  /// مُشغّلٌ يسجّل ما طُلب منه، ويجيب بما يُعطى لكل نمط.
  ({List<(Uri, LaunchMode)> calls, UrlOpener opener}) recorder(
    Map<LaunchMode, Object> answers,
  ) {
    final calls = <(Uri, LaunchMode)>[];
    Future<bool> opener(Uri uri, LaunchMode mode) async {
      calls.add((uri, mode));
      final answer = answers[mode] ?? false;
      if (answer is Exception) throw answer;
      return answer as bool;
    }

    return (calls: calls, opener: opener);
  }

  group('MeetingLauncher', () {
    test('يفتح في تطبيق الاجتماع أوّلاً', () async {
      final r = recorder({LaunchMode.externalApplication: true});
      final result = await MeetingLauncher(opener: r.opener)
          .open('https://meet.google.com/abc-defg-hij');
      expect(result, MeetingLaunchResult.opened);
      expect(r.calls, hasLength(1));
      expect(r.calls.single.$1.toString(), 'https://meet.google.com/abc-defg-hij');
      expect(r.calls.single.$2, LaunchMode.externalApplication);
    });

    test('ويرجع إلى النمط الافتراضيّ إن رُفض الخارجيّ', () async {
      final r = recorder({
        LaunchMode.externalApplication: false,
        LaunchMode.platformDefault: true,
      });
      final result = await MeetingLauncher(opener: r.opener)
          .open('https://zoom.us/j/123');
      expect(result, MeetingLaunchResult.opened);
      expect(r.calls.map((c) => c.$2), [
        LaunchMode.externalApplication,
        LaunchMode.platformDefault,
      ]);
    });

    test('واستثناءُ المنصّة لا يُسقط المحاولةَ التالية', () async {
      final r = recorder({
        LaunchMode.externalApplication:
            PlatformException(code: 'NO_ACTIVITY'),
        LaunchMode.platformDefault: true,
      });
      expect(
        await MeetingLauncher(opener: r.opener).open('https://zoom.us/j/1'),
        MeetingLaunchResult.opened,
      );
    });

    test('وإن رُفض النمطان: فشلٌ يُقال لا صمت', () async {
      final r = recorder({});
      expect(
        await MeetingLauncher(opener: r.opener).open('https://zoom.us/j/1'),
        MeetingLaunchResult.failed,
      );
      expect(r.calls, hasLength(2));
    });

    test('الرابطُ الفارغ أو غيرُ الآمن لا يُفتح أصلاً', () async {
      for (final raw in [
        null,
        '',
        '   ',
        'http://meet.google.com/abc',
        'javascript:alert(1)',
        'https://user:pass@meet.google.com/abc',
        'https://meet.google.com/a b',
      ]) {
        final r = recorder({LaunchMode.externalApplication: true});
        expect(
          await MeetingLauncher(opener: r.opener).open(raw),
          MeetingLaunchResult.invalidLink,
          reason: '$raw',
        );
        expect(r.calls, isEmpty, reason: '$raw');
      }
    });

    test('والرابطُ بلا مخطّطٍ يُكمَّل https كما يُعرض', () {
      expect(
        MeetingLauncher.meetingUri('meet.google.com/abc-defg-hij').toString(),
        'https://meet.google.com/abc-defg-hij',
      );
    });

    group('روابطُ التطبيقات من داخل الإطار', () {
      test('intent:// بصفحة بديلة: تُفتح الصفحة', () {
        final uri = Uri.parse(
          'intent://meet.google.com/abc-defg-hij#Intent;scheme=https;'
          'package=com.google.android.apps.meetings;'
          'S.browser_fallback_url=https%3A%2F%2Fmeet.google.com%2Fabc-defg-hij;end',
        );
        expect(
          MeetingLauncher.appLinkTarget(uri).toString(),
          'https://meet.google.com/abc-defg-hij',
        );
      });

      test('intent:// بلا صفحة بديلة: يُعاد بناؤه بمخطّطه', () {
        final uri = Uri.parse(
          'intent://zoom.us/join?confno=123#Intent;scheme=zoomus;package=us.zoom.videomeetings;end',
        );
        expect(
          MeetingLauncher.appLinkTarget(uri).toString(),
          'zoomus://zoom.us/join?confno=123',
        );
      });

      test('مخطّطُ تطبيقٍ مباشر يُمرَّر، والويبُ لا يُعدّ رابطَ تطبيق', () {
        expect(
          MeetingLauncher.appLinkTarget(Uri.parse('zoomus://zoom.us/join?confno=1'))
              .toString(),
          'zoomus://zoom.us/join?confno=1',
        );
        expect(MeetingLauncher.appLinkTarget(Uri.parse('https://zoom.us/j/1')), isNull);
      });

      test('intent:// معطوب: لا شيء', () {
        expect(MeetingLauncher.appLinkTarget(Uri.parse('intent://x')), isNull);
      });
    });
  });

  group('شاشةُ اللقاء', () {
    const meetUrl = 'https://meet.google.com/abc-defg-hij';

    Future<void> pumpMeeting(WidgetTester tester, UrlOpener opener) async {
      await tester.pumpWidget(
        MaterialApp(
          home: StudentTutorScreen(
            selection: const TutorExperienceSelection(
              type: TutorExperienceType.liveMeeting,
              status: TutorExperienceStatus.ready,
              url: meetUrl,
            ),
            apiBaseUrl: '',
            meetingLauncher: MeetingLauncher(opener: opener),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 600));
    }

    Finder joinButton() => find.widgetWithText(FilledButton, tr('tutor.joinMeeting'));

    testWidgets('بطاقةُ Meet تشرح ما سيحدث، لا مفتاحاً خاماً', (tester) async {
      await pumpMeeting(tester, recorder({}).opener);
      expect(find.text(tr('tutor.meetingJoinable')), findsOneWidget);
      expect(find.text('tutor.joinBody'), findsNothing,
          reason: 'كان المفتاحُ يُعرض كما هو: النصُّ لم يكن في الجدول');
      expect(find.text(tr('tutor.joinBody')), findsOneWidget);
    });

    testWidgets('الزرُّ يفتح الاجتماعَ خارج التطبيق', (tester) async {
      final r = recorder({LaunchMode.externalApplication: true});
      await pumpMeeting(tester, r.opener);
      await tester.tap(joinButton());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(r.calls, hasLength(1));
      expect(r.calls.single.$1.toString(), meetUrl);
      expect(r.calls.single.$2, LaunchMode.externalApplication);
      expect(find.byType(SnackBar), findsNothing);
    });

    testWidgets('وأثناء الفتح يقول «جارٍ» ولا يقبل ضغطةً ثانية', (tester) async {
      final gate = Completer<bool>();
      var calls = 0;
      Future<bool> slow(Uri uri, LaunchMode mode) {
        calls += 1;
        return gate.future;
      }

      await pumpMeeting(tester, slow);
      await tester.tap(joinButton());
      await tester.pump();
      expect(find.text(tr('tutor.opening')), findsOneWidget);
      final button = tester.widget<FilledButton>(
        find.ancestor(of: find.text(tr('tutor.opening')), matching: find.byType(FilledButton)),
      );
      expect(button.onPressed, isNull);
      await tester.tap(find.text(tr('tutor.opening')), warnIfMissed: false);
      await tester.pump();
      expect(calls, 1);

      gate.complete(true);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(joinButton(), findsOneWidget);
    });

    testWidgets('وإن لم يُفتح: تنبيهٌ واضح، وزرٌّ ينسخ الرابط', (tester) async {
      final r = recorder({});
      await pumpMeeting(tester, r.opener);
      await tester.tap(joinButton());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text(tr('tutor.meetingOpenFailed')), findsOneWidget);
      final copy = find.text(tr('tutor.copyLink'));
      expect(copy, findsOneWidget);

      String? copied;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            copied = (call.arguments as Map)['text'] as String?;
          }
          return null;
        },
      );
      addTearDown(() => tester.binding.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null));

      await tester.tap(copy);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(copied, meetUrl);
    });

    testWidgets('اللقاءُ بلا رابط: حالةٌ تشرح، لا زرٌّ ميّت', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: StudentTutorScreen(
            selection: TutorExperienceSelection(
              type: TutorExperienceType.liveMeeting,
              status: TutorExperienceStatus.unavailable,
            ),
            apiBaseUrl: '',
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.text(tr('tutor.noMeeting')), findsOneWidget);
      expect(joinButton(), findsNothing);
    });
  });
}
