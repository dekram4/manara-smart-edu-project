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
import 'package:manara_student/src/services/duel_voice_recorder.dart';
import 'package:manara_student/src/services/student_auth_service.dart';
import 'package:manara_student/src/services/student_content_service.dart';
import 'package:manara_student/src/services/student_settings.dart';
import 'package:manara_student/src/services/student_study_service.dart';

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
    await tester.pumpWidget(const SizedBox());
    auth.client.auth.stopAutoRefresh();
    await tester.pump(const Duration(seconds: 6));
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
    await tester.pump(const Duration(milliseconds: 300));
    expect(state.phase, DemoDuelPhase.playing);
    expect(state.roundLength, DemoMode.duelQuestions);

    // ‏رمزٌ يطير، وعبارةٌ يردّ عليها المنافس، ومقطعٌ صوتيّ يُسمع.
    await tester.tap(find.byKey(const ValueKey('demo-duel-emoji-🔥')));
    await tester.pump();
    expect(state.flyingCount, greaterThan(0));
    final before = state.messageCount;
    await tester.ensureVisible(find.byKey(ValueKey('demo-duel-phrase-${tr('demo.duel.phrase1')}')));
    await tester.tap(find.byKey(ValueKey('demo-duel-phrase-${tr('demo.duel.phrase1')}')));
    await tester.pump(const Duration(milliseconds: 950));
    expect(state.messageCount, before + 2);
    await tester.ensureVisible(find.byKey(const ValueKey('demo-duel-voice')));
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
      await tester.ensureVisible(option);
      await tester.tap(option);
      await tester.pump(const Duration(milliseconds: 1100));
      await tester.pump(const Duration(milliseconds: 1700));
    }
    expect(state.phase, DemoDuelPhase.done);
    expect(state.myScore, greaterThan(30));
    expect(find.byKey(const ValueKey('demo-duel-result')), findsOneWidget);
    expect(find.byKey(const ValueKey('demo-duel-locked')), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 2));
  });
}
