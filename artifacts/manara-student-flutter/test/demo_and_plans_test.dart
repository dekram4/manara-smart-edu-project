import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:manara_student/src/l10n/student_strings.dart';
import 'package:manara_student/src/models/student_profile.dart';
import 'package:manara_student/src/screens/demo_chat_screen.dart';
import 'package:manara_student/src/screens/plans_screen.dart';
import 'package:manara_student/src/screens/student_home_screen.dart';
import 'package:manara_student/src/services/demo_mode.dart';
import 'package:manara_student/src/services/duel_voice_recorder.dart';
import 'package:manara_student/src/services/student_auth_service.dart';
import 'package:manara_student/src/services/student_settings.dart';
import 'package:manara_student/src/services/subscription_plans.dart';
import 'package:manara_student/src/widgets/demo_lock.dart';

/// «وضع الزائر الاستكشافي» وفئاتُ الاشتراك و«احصل على حساب رسمي».
class FakeRecorder implements DuelVoiceRecorder {
  bool on = false;
  @override
  Future<bool> start() async => on = true;
  @override
  Future<VoiceNote> stop() async {
    on = false;
    return VoiceNote.ready(Uint8List.fromList(List.filled(800, 7)));
  }

  @override
  Future<void> cancel() async => on = false;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

StudentProfile demoProfile(String track) => StudentProfile.fromStudentRow({
      'id': 'demo-$track',
      'data': {
        'name': 'زائر منارة',
        'username': 'demo_$track',
        'role': 'student',
        'grade': track == 'kg' ? 'روضة منارة المعرفة' : 'الصف الرابع',
        'subscriptionPlan': 'demo',
        'demoTrack': track,
        'gamification': {'gems': 500, 'xp': 900, 'level': 7},
      },
    });

void main() {
  late StudentAuthService homeAuth;
  setUp(() {
    homeAuth = StudentAuthService(SupabaseClient('http://127.0.0.1:1', 'k'), apiBaseUrl: '');
    SharedPreferences.setMockInitialValues({});
    StudentSettings.resetForTest();
  });
  tearDown(DemoMode.exit);

  group('الباقات', () {
    test('الفردية بلا دردشةٍ ولا تحدٍّ ولا لقاءٍ ولا معلّمٍ افتراضي ولا حلّ مسائل', () {
      for (final card in ['chat', 'challenge', 'meeting', 'tutor', 'solver']) {
        expect(planAllowsCard('individual', card), isFalse, reason: card);
      }
      for (final card in ['lesson', 'cinema', 'games', 'quiz', 'study', 'personality']) {
        expect(planAllowsCard('individual', card), isTrue, reason: card);
      }
    });

    test('المجموعات: الفردية + الدردشة والتحدّي؛ والمؤسسيةُ وبلا باقةٍ: كلُّها', () {
      expect(planAllowsCard('family', 'chat'), isTrue);
      expect(planAllowsCard('family', 'challenge'), isTrue);
      expect(planAllowsCard('family', 'meeting'), isFalse);
      for (final plan in ['school_small', 'school_medium', 'school_large', null, 'demo']) {
        expect(planAllowsCard(plan, 'solver'), isTrue, reason: '$plan');
      }
      expect(subscriptionPlans.where((p) => p.group == PlanGroup.school), hasLength(3));
      expect(planFeatures.where((f) => !f.individual).length, greaterThan(planFeatures.where((f) => !f.family).length));
    });
  });

  group('قواعد الزائر', () {
    test('الملفُّ: باقةُ الزائر، وجواهرُه ومستواه أصفار', () {
      final p = demoProfile('kg');
      expect(p.isDemo, isTrue);
      expect(p.gamification.gems, 0);
      expect(p.gamification.xp, 0);
      DemoMode.enterFor(p);
      expect(DemoMode.track, DemoTrack.kg);
    });

    test('داخل البطاقات: سؤالان، ومقطعٌ واحد، و«المقلاع»، والفاتحة', () {
      DemoMode.enterFor(demoProfile('grade4'));
      expect(DemoMode.limit([1, 2, 3, 4], DemoMode.quizQuestions), [1, 2]);
      expect(DemoMode.allowsSegment(0), isTrue);
      expect(DemoMode.allowsSegment(1), isFalse);
      expect(DemoMode.allowsStudyGame('slingshot'), isTrue);
      expect(DemoMode.allowsStudyGame('train'), isFalse);
      expect(DemoMode.allowsSurah('سورة الفاتحة'), isTrue);
      expect(DemoMode.allowsSurah('سورة الإخلاص'), isFalse);
    });

    test('الروضة: كلُّ المواد؛ والحسابُ الحقيقيّ بلا قيود', () {
      DemoMode.enterFor(demoProfile('kg'));
      expect(DemoMode.allowsTracing(3), isTrue);
      expect(DemoMode.allowsTracing(4), isFalse);
      DemoMode.enterFor(const StudentProfile(id: 's', username: 'u', name: 'n', role: 'student'));
      expect(DemoMode.active, isFalse);
      expect(DemoMode.limit([1, 2, 3], 1), [1, 2, 3]);
      expect(DemoMode.allowsTracing(40), isTrue);
      expect(DemoMode.allowsSegment(9), isTrue);
    });

    testWidgets('عنصرٌ مقفل: باهتٌ بقفل، ولمستُه تقول لماذا', (tester) async {
      var tapped = false;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: DemoLocked(locked: true, child: ElevatedButton(onPressed: () => tapped = true, child: const Text('x'))),
        ),
      ));
      await tester.tap(find.byType(DemoLocked));
      await tester.pump();
      expect(tapped, isFalse);
      expect(find.byKey(const ValueKey('demo-locked')), findsOneWidget);
    });
  });

  testWidgets('الواجهة للزائر: زرٌّ ذهبيّ للحساب الرسمي، و«اللقاء المباشر» يشرح نفسه ولا يُفتح', (tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final profile = demoProfile('grade4');
    DemoMode.enterFor(profile);
    await tester.pumpWidget(MaterialApp(
      home: StudentHomeScreen(
        profile: profile,
        authService: homeAuth,
        apiBaseUrl: '',
      ),
    ));
    for (var i = 0; i < 60; i++) {
      await tester.pump(const Duration(milliseconds: 120));
    }
    expect(find.byKey(const ValueKey('demo-get-account')), findsOneWidget);
    final meeting = find.byKey(const ValueKey('portal-tile-portal.meeting'));
    await tester.ensureVisible(meeting);
    await tester.tap(meeting);
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 120));
    }
    expect(find.byKey(const ValueKey('demo-teaser-meeting')), findsOneWidget);
    expect(find.text(tr('demo.teaser.meeting')), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('الباقات: مقارنةٌ بالسعر «يُحدَّد لاحقاً»، ثم طلبٌ يصل الخادم وواتساب', (tester) async {
    tester.view.physicalSize = const Size(1200, 2600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    http.Request? sent;
    Uri? opened;
    await tester.pumpWidget(MaterialApp(
      home: PlansScreen(
        apiBaseUrl: 'http://api.test',
        httpClient: MockClient((request) async {
          sent = request;
          return http.Response('{"id":"join_1"}', 201);
        }),
        openUrl: (uri) async {
          opened = uri;
          return true;
        },
      ),
    ));
    await tester.pump();
    expect(find.byKey(const ValueKey('plan-card-individual')), findsOneWidget);
    expect(find.byKey(const ValueKey('plan-card-family')), findsOneWidget);
    expect(find.byKey(const ValueKey('plan-card-school')), findsOneWidget);
    expect(find.text(planPricePlaceholderAr), findsWidgets);

    await tester.tap(find.byKey(const ValueKey('plan-choose-school_medium')));
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.byKey(const ValueKey('plans-form')), findsOneWidget);
    await tester.enterText(find.byKey(const ValueKey('plans-name')), 'روضة النور');
    await tester.enterText(find.byKey(const ValueKey('plans-grade')), 'روضة');
    await tester.enterText(find.byKey(const ValueKey('plans-students')), '40');
    await tester.enterText(find.byKey(const ValueKey('plans-phone')), '0501234567');
    await tester.ensureVisible(find.byKey(const ValueKey('plans-submit')));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.byKey(const ValueKey('plans-submit')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    final body = jsonDecode(sent!.body) as Map<String, dynamic>;
    expect(sent!.url.path, '/api/join-requests');
    expect(body['plan'], 'school_medium');
    expect(body['students'], 40);
    expect(find.byKey(const ValueKey('plans-sent')), findsOneWidget);

    await tester.ensureVisible(find.byKey(const ValueKey('plans-whatsapp')));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.byKey(const ValueKey('plans-whatsapp')));
    await tester.pump();
    expect(opened!.host, 'wa.me');
    expect(Uri.decodeComponent(opened!.query), contains('روضة النور'));
  });

  testWidgets('باقة المجموعات تطلب ثلاثة طلابٍ على الأقل', (tester) async {
    tester.view.physicalSize = const Size(1200, 2600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    var posted = false;
    await tester.pumpWidget(MaterialApp(
      home: PlansScreen(
        apiBaseUrl: 'http://api.test',
        httpClient: MockClient((_) async {
          posted = true;
          return http.Response('{}', 201);
        }),
      ),
    ));
    await tester.tap(find.byKey(const ValueKey('plan-choose-family')));
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    await tester.enterText(find.byKey(const ValueKey('plans-name')), 'آل محمد');
    await tester.enterText(find.byKey(const ValueKey('plans-students')), '2');
    await tester.enterText(find.byKey(const ValueKey('plans-phone')), '0501234567');
    await tester.ensureVisible(find.byKey(const ValueKey('plans-submit')));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.byKey(const ValueKey('plans-submit')));
    await tester.pump();
    expect(posted, isFalse);
    expect(find.text(tr('plans.form.familyMin')), findsOneWidget);
  });

  testWidgets('دردشةُ الزائر: رسالتان كتابيتان وصوتيتان مع «منار»، والصورُ مغلقة', (tester) async {
    tester.view.physicalSize = const Size(500, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    DemoMode.enterFor(demoProfile('kg'));
    final played = <int>[];
    await tester.pumpWidget(MaterialApp(
      home: DemoChatScreen(recorder: FakeRecorder(), playBytes: (b) async => played.add(b.length)),
    ));
    final state = tester.state<DemoChatScreenState>(find.byType(DemoChatScreen));
    expect(state.messageCount, 1, reason: 'ترحيبُ منار');

    for (final text in ['مرحبا', 'كيف حالك', 'رسالة ثالثة']) {
      await tester.enterText(find.byKey(const ValueKey('demo-chat-input')), text);
      await tester.tap(find.byKey(const ValueKey('demo-chat-send')));
      await tester.pump(const Duration(seconds: 1));
    }
    expect(state.textsSent, 2);
    expect(find.text(tr('demo.chat.textLimit')), findsOneWidget);
    // ‏تُغلق رسالةُ الحدّ قبل الميكروفون.
    ScaffoldMessenger.of(tester.element(find.byType(DemoChatScreen))).hideCurrentSnackBar();
    await tester.pump(const Duration(seconds: 1));

    for (var i = 0; i < 3; i++) {
      await tester.tap(find.byKey(const ValueKey('demo-chat-voice')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('demo-chat-voice')));
      await tester.pump(const Duration(seconds: 1));
    }
    expect(state.voicesSent, 2);
    expect(state.messageCount, 1 + 4 + 4, reason: 'كلُّ رسالةٍ يردّ عليها منار');

    await tester.tap(find.byKey(const ValueKey('demo-chat-image')));
    await tester.pump();
    expect(find.byKey(const ValueKey('demo-chat-images-closed')), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));
  });
}
