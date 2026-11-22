import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:manara_student/src/l10n/student_strings.dart';
import 'package:manara_student/src/models/academic_context.dart';
import 'package:manara_student/src/models/student_content.dart';
import 'package:manara_student/src/screens/demo_duel_screen.dart';
import 'package:manara_student/src/screens/student_cinema_screen.dart';
import 'package:manara_student/src/screens/student_problem_solver_screen.dart';
import 'package:manara_student/src/services/demo_catalog.dart';
import 'package:manara_student/src/services/demo_content.dart';
import 'package:manara_student/src/services/demo_mode.dart';
import 'package:manara_student/src/services/demo_solver.dart';
import 'package:manara_student/src/services/duel_voice_recorder.dart';
import 'package:manara_student/src/services/student_auth_service.dart';
import 'package:manara_student/src/services/student_content_service.dart';
import 'package:manara_student/src/services/student_settings.dart';
import 'package:manara_student/src/services/student_study_service.dart';
import 'package:manara_student/src/widgets/arena_widgets.dart';

/// بطاقاتُ الزائر على الجهاز: السينما، والمذاكرة في كلّ مادة، وحلُّ المسائل
/// بسؤالين، والتحدّي مع «روبوت منارة» بثلاثة أسئلة.
const _dead = 'http://127.0.0.1:1';
const _kg = 'روضة منارة المعرفة';

class _Recorder implements DuelVoiceRecorder {
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

DemoCatalogData _catalog({List<Map<String, dynamic>> videos = const []}) => DemoCatalog.build(
      track: 'kg',
      hierarchy: [
        {
          'grade': _kg,
          'teacherId': 'teacher_dawood',
          'subjects': [
            for (final s in ['القرآن الكريم', 'القاعدة النورانية', 'الحروف العربية', 'الأرقام الإنجليزية', 'الثقافة العامة'])
              {
                'subject': s,
                'terms': [
                  {
                    'term': 'الفصل الأول',
                    'units': ['الوحدة'],
                  },
                ],
              },
          ],
        },
      ],
      lessonRows: [
        for (final (i, s) in ['القرآن الكريم', 'القاعدة النورانية', 'الحروف العربية', 'الأرقام الإنجليزية', 'الثقافة العامة'].indexed)
          {
            'id': 'r$i',
            'data': {'grade': _kg, 'subject': s, 'term': 'الفصل الأول', 'unit': 'الوحدة', 'lesson': 'درس $s', 'teacherId': 'teacher_dawood'},
          },
      ],
      videos: videos,
    )!;

/// يضع [finder] في منتصف الشاشة قبل اللمس: لا تحت شريطٍ ولا على حافّتها.
Future<void> centre(WidgetTester tester, Finder finder) async {
  await Scrollable.ensureVisible(tester.element(finder), alignment: 0.5);
  await tester.pump();
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    StudentSettings.resetForTest();
  });
  tearDown(DemoMode.exit);

  test('المذاكرة في كلّ موادّ الروضة الرسمية — بلا اختبارٍ رسمي ولا شبكة: لعبةٌ بأسئلةٍ صحيحة', () async {
    final data = _catalog();
    final guest = DemoContent.profile('kg', grade: data.grade, teacherId: data.owner);
    DemoMode.enterFor(guest);
    DemoCatalog.current = data;
    final auth = StudentAuthService(SupabaseClient(_dead, 'k'), apiBaseUrl: _dead);
    final study = StudentStudyService(apiBaseUrl: _dead, authService: auth);
    for (final row in data.lessonRows) {
      final d = row['data'] as Map<String, dynamic>;
      final pack = await study.fetchGames(lessonId: '${row['id']}', subject: d['subject'], lessonName: d['lesson'], grade: _kg);
      final game = pack.games.single;
      expect(game.questions.length, greaterThanOrEqualTo(3), reason: d['subject']);
      expect(game.questions.every((q) => q.options.contains(q.answer)), isTrue, reason: d['subject']);
      final fresh = await study.fetchFreshGame(
          lessonId: '${row['id']}', type: game.type, exclude: const [], subject: d['subject'], lessonName: d['lesson'], grade: _kg);
      expect(fresh.questions, hasLength(game.questions.length));
    }
    // ‏درسٌ من شجرة المعلّم بلا سجلّ (معرّفٌ لا يُعرف) ولا اسمِ مادّة: لا يتعذّر أيضاً.
    expect((await study.fetchGames(lessonId: 'placeholder::x')).games.single.questions, isNotEmpty);
    auth.client.auth.stopAutoRefresh();
  });

  test('سينما الزائر: رفُّ الحساب الرسمي، أو المدمجُ إن خلا', () async {
    final data = _catalog(videos: [
      for (var i = 0; i < 5; i++)
        {'id': 'v$i', 'title': 'فيديو $i', 'url': 'https://example.com/v$i.mp4', 'grade': _kg, 'teacherId': 'teacher_dawood'},
      {'id': 'other', 'title': 'لغيره', 'url': 'https://example.com/o.mp4', 'grade': _kg, 'teacherId': 'someone'},
    ]);
    final guest = DemoContent.profile('kg', grade: data.grade, teacherId: data.owner);
    DemoMode.enterFor(guest);
    DemoCatalog.current = data;
    final service = StudentContentService(SupabaseClient(_dead, 'k'), baseUrl: _dead);
    final videos = await service.fetchCinemaVideos(guest);
    expect(videos.map((v) => v.title), ['فيديو 0', 'فيديو 1', 'فيديو 2', 'فيديو 3', 'فيديو 4']);
    DemoCatalog.current = _catalog();
    StudentContentService.clearLastResults();
    expect(await service.fetchCinemaVideos(guest), DemoContent.cinema);
  });

  testWidgets('شاشةُ السينما للزائر: القائمةُ كاملة، والأوّلُ وحده يعمل والباقي بقفلٍ ذهبيّ', (tester) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final guest = DemoContent.profile('kg');
    DemoMode.enterFor(guest);
    final auth = StudentAuthService(SupabaseClient(_dead, 'k'), apiBaseUrl: _dead);
    await tester.pumpWidget(MaterialApp(
      home: StudentCinemaScreen(profile: guest, authService: auth, apiBaseUrl: _dead),
    ));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.text('1 / ${DemoContent.cinema.length}'), findsOneWidget);
    expect(find.text(DemoContent.cinema.first.title), findsOneWidget);
    expect(find.byKey(const ValueKey('demo-cinema-locked-1')), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    auth.client.auth.stopAutoRefresh();
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('حلُّ المسائل للزائر: سؤالان من شرح الدرس، ثم قفلُ الحساب الرسمي', (tester) async {
    for (final channel in ['flutter_tts', 'plugin.csdcorp.com/speech_to_text']) {
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(MethodChannel(channel), (_) async => 1);
    }
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final guest = DemoContent.profile('kg');
    DemoMode.enterFor(guest);
    final auth = StudentAuthService(SupabaseClient(_dead, 'k'), apiBaseUrl: _dead);
    const lesson = LessonContent(
      id: 'l1',
      lessonId: 'l1',
      grade: _kg,
      subject: 'الثقافة العامة',
      term: 't',
      unit: 'u',
      lessonName: 'الألوان',
      createdAt: '',
      lessonText: 'الألوان الأساسية ثلاثة: الأحمر والأصفر والأزرق. نمزج الأحمر والأصفر فنحصل على البرتقالي.',
      videos: [],
      games: [],
    );
    await tester.pumpWidget(MaterialApp(
      home: StudentProblemSolverScreen(
        lessons: const [],
        apiBaseUrl: _dead,
        profile: guest,
        contentService: StudentContentService(auth.client, baseUrl: _dead, authService: auth),
        authService: auth,
        academicContext: const AcademicContext(grade: _kg, subject: 'الثقافة العامة', term: 't', unit: 'u', selectedLesson: lesson),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text(trf('demo.solver.left', {'n': 2, 'total': 2})), findsOneWidget);
    final state = tester.state(find.byType(StudentProblemSolverScreen)) as dynamic;
    Future<void> ask(String q) async {
      await tester.enterText(find.byType(TextField), q);
      await tester.ensureVisible(find.text(tr('solver.ask')).first);
      await tester.tap(find.text(tr('solver.ask')).first);
      await tester.pump(const Duration(milliseconds: 1000));
      await tester.pump(const Duration(milliseconds: 300));
    }

    await ask('ما ناتج مزج الأحمر والأصفر؟');
    expect(state.demoAsked, 1);
    expect(find.textContaining('البرتقالي'), findsWidgets);
    await ask('كم عدد الألوان الأساسية؟');
    expect(state.demoAsked, 2);
    expect(find.byKey(const ValueKey('demo-solver-locked')), findsOneWidget);
    await ask('سؤال ثالث');
    expect(state.demoAsked, 2, reason: 'الثالثُ مقفل');
    expect(tester.takeException(), isNull);

    // ‏العدّادُ على الجهاز بتاريخ اليوم: إغلاقُ البطاقة وفتحُها لا يُعيده.
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getInt('demo.solver.asked.${DemoSolverQuota.dayKey()}'), 2);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(MaterialApp(
      home: StudentProblemSolverScreen(
        lessons: const [],
        apiBaseUrl: _dead,
        profile: guest,
        contentService: StudentContentService(auth.client, baseUrl: _dead, authService: auth),
        authService: auth,
        academicContext: const AcademicContext(grade: _kg, subject: 'الثقافة العامة', term: 't', unit: 'u', selectedLesson: lesson),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byKey(const ValueKey('demo-solver-locked')), findsOneWidget, reason: 'رجع إلى البطاقة في اليوم نفسه');
    final reopened = tester.state(find.byType(StudentProblemSolverScreen)) as dynamic;
    // ‏بطاقةُ القفل بنصّها الإداريّ تطول: الحقلُ تحتها يُبلغ بالتمرير.
    await tester.scrollUntilVisible(find.byType(TextField), 200, scrollable: find.byType(Scrollable).first);
    await tester.enterText(find.byType(TextField), 'سؤال بعد الرجوع');
    await tester.ensureVisible(find.text(tr('solver.ask')).first);
    await tester.tap(find.text(tr('solver.ask')).first);
    await tester.pump(const Duration(milliseconds: 1300));
    expect(reopened.demoAsked, 2);
    expect(prefs.getInt('demo.solver.asked.${DemoSolverQuota.dayKey()}'), 2);
    await tester.pumpWidget(const SizedBox());
    auth.client.auth.stopAutoRefresh();
    await tester.pump(const Duration(seconds: 6));
  });

  test('عدّادُ الزائر اليوميّ: يومٌ جديدٌ يبدأ من صفر، والحسابُ الرسميّ لا يُعدّ ولا يُكتب له شيء', () async {
    DemoMode.enterFor(DemoContent.profile('grade4'));
    final today = DateTime(2026, 11, 17, 23, 50);
    expect(DemoSolverQuota.dayKey(today), '2026-11-17');
    expect(await DemoSolverQuota.record(now: today), 1);
    expect(await DemoSolverQuota.record(now: today), 2);
    expect(await DemoSolverQuota.used(now: today), 2);
    final tomorrow = DateTime(2026, 11, 18, 0, 5);
    expect(await DemoSolverQuota.used(now: tomorrow), 0);
    expect(await DemoSolverQuota.record(now: tomorrow), 1);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getKeys().where((k) => k.startsWith('demo.solver.asked.')), ['demo.solver.asked.2026-11-18'],
        reason: 'أيّامُ ما قبل اليوم تُمحى');

    // ‏الحسابُ الرسميّ: لا حدّ، ولا مفتاحَ يُكتب.
    DemoMode.exit();
    await prefs.clear();
    expect(await DemoSolverQuota.record(now: today), 0);
    expect(await DemoSolverQuota.used(now: today), 0);
    expect(prefs.getKeys(), isEmpty);
  });

  testWidgets('التحدّي: اتصالٌ بروبوت منارة، وثلاثةُ أسئلة، ورموزٌ وصوتٌ وعبارات', (tester) async {
    for (final channel in ['xyz.luan/audioplayers', 'xyz.luan/audioplayers.global']) {
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(MethodChannel(channel), (_) async => null);
    }
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    DemoMode.enterFor(DemoContent.profile('kg'));
    final questions = DemoContent.lessonQuestions(lessonId: 'x', subject: 'القاعدة النورانية', lessonName: 'الحروف المفردة', grade: _kg);
    expect(questions.length, greaterThanOrEqualTo(DemoMode.duelQuestions));
    final played = <int>[];
    await tester.pumpWidget(MaterialApp(
      home: DemoDuelScreen(
        questions: questions,
        lessonName: 'الحروف المفردة',
        recorder: _Recorder(),
        playBytes: (b) async => played.add(b.length),
        random: math.Random(3),
        botDelay: const Duration(seconds: 1),
        connectDelay: const Duration(milliseconds: 200),
      ),
    ));
    final state = tester.state<DemoDuelScreenState>(find.byType(DemoDuelScreen));
    expect(find.byKey(const ValueKey('demo-duel-connecting')), findsOneWidget);
    expect(find.byType(ArenaVersus), findsOneWidget, reason: 'مشهدُ المواجهة بالشخصيتين');
    await tester.pump(const Duration(milliseconds: 300));
    expect(state.phase, DemoDuelPhase.playing);
    expect(state.roundLength, DemoMode.duelQuestions);
    expect(find.byType(AnswerTile), findsWidgets);
    expect(find.byType(ArenaTimerRing), findsOneWidget);

    // ‏رمزٌ يطير، وعبارةٌ يردّ عليها المنافس، ومقطعٌ صوتيّ يُسمع.
    await centre(tester, find.byKey(const ValueKey('demo-duel-emoji-🔥')));
    await tester.tap(find.byKey(const ValueKey('demo-duel-emoji-🔥')));
    await tester.pump();
    expect(state.flyingCount, greaterThan(0));
    final before = state.messageCount;
    await centre(tester, find.byKey(ValueKey('demo-duel-phrase-${tr('demo.duel.phrase1')}')));
    await tester.tap(find.byKey(ValueKey('demo-duel-phrase-${tr('demo.duel.phrase1')}')));
    await tester.pump(const Duration(milliseconds: 950));
    expect(state.messageCount, before + 2);
    await centre(tester, find.byKey(const ValueKey('demo-duel-voice')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('demo-duel-voice')));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.byKey(const ValueKey('demo-duel-voice')));
    await tester.pump(const Duration(milliseconds: 100));
    expect(state.messageCount, before + 3);
    await tester.pump(const Duration(seconds: 1));

    // ‏الأسئلةُ الثلاثة: يُجاب الصحيحُ كلَّ مرّة.
    for (var i = 0; i < DemoMode.duelQuestions; i++) {
      await tester.pump(const Duration(milliseconds: 100));
      expect(state.questionIndex, i);
      final shown = questions.firstWhere((q) => find.text('${q['question']}').evaluate().isNotEmpty);
      final option = find.byKey(ValueKey('demo-duel-option-${shown['answer']}'));
      await centre(tester, option);
      await tester.tap(option);
      await tester.pump(const Duration(milliseconds: 1100));
      await tester.pump(const Duration(milliseconds: 1700));
    }
    expect(state.phase, DemoDuelPhase.done);
    expect(state.myScore, greaterThan(30));
    expect(find.byKey(const ValueKey('demo-duel-result')), findsOneWidget);
    expect(find.byKey(const ValueKey('demo-duel-locked')), findsOneWidget);
    // ‏أسئلةُ اليوم الثلاثة لُعبت: لا «تحدٍّ جديد» بثلاثةٍ أخرى.
    expect(state.leftToday, 0);
    expect(find.byKey(const ValueKey('demo-duel-again')), findsNothing);
    expect(find.text(tr('demo.duel.dailyDone')), findsOneWidget);
    // ‏وبالواجهة الجديدة: بلاطاتُ الخيارات والحلقةُ والمواجهةُ من قطع الحلبة نفسها.
    expect(tester.takeException(), isNull);

    // ‏خرج ورجع في اليوم نفسه: بطاقةُ الترويج مباشرةً، بلا سؤال.
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getInt('demo.duel.asked.${DemoDuelQuota.dayKey()}'), DemoMode.duelQuestions);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(MaterialApp(
      home: DemoDuelScreen(
        questions: questions,
        recorder: _Recorder(),
        random: math.Random(3),
        botDelay: const Duration(seconds: 1),
        connectDelay: const Duration(milliseconds: 200),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 300));
    final again = tester.state<DemoDuelScreenState>(find.byType(DemoDuelScreen));
    expect(again.roundLength, 0);
    expect(again.phase, DemoDuelPhase.done);
    expect(find.byKey(const ValueKey('demo-duel-locked')), findsOneWidget);
    expect(find.byType(AnswerTile), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 2));
  });

  test('عدّادُ التحدي اليوميّ: يومٌ جديدٌ يبدأ من صفر، ولا يُكتب شيءٌ لغير الزائر', () async {
    DemoMode.enterFor(DemoContent.profile('kg'));
    final today = DateTime(2026, 11, 17, 22);
    for (var i = 1; i <= 3; i++) {
      expect(await DemoDuelQuota.record(now: today), i);
    }
    expect(await DemoDuelQuota.used(now: today), 3);
    expect(await DemoDuelQuota.used(now: DateTime(2026, 11, 18, 8)), 0);
    DemoMode.exit();
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    expect(await DemoDuelQuota.record(now: today), 0);
    expect(prefs.getKeys(), isEmpty);
  });
}
