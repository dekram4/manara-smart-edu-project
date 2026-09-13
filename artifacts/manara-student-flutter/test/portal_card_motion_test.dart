import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:manara_student/src/models/student_profile.dart';
import 'package:manara_student/src/screens/student_home_screen.dart';
import 'package:manara_student/src/services/student_auth_service.dart';
import 'package:manara_student/src/services/student_settings.dart';

/// The portal rail's motion, pinned to what a finger actually does to it.
///
/// The card carries three separate motions — an idle float, a lift under
/// the pointer, and a spring on the push — and the interesting failures
/// are all about them interfering: a press that does nothing because the
/// hover already lifted the card, a float that freezes once a card has
/// been touched, a spring that never settles.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Points at nothing reachable on purpose: the hub's startup fetch is
  // wrapped in its own try/catch, so a refused connection is the quiet
  // path and the rail still builds. Built per test rather than once at
  // the top level, because SupabaseClient opens an HttpClient in its
  // constructor and that has to happen inside the test zone.
  late StudentAuthService authService;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    StudentSettings.resetForTest();
    authService = StudentAuthService(
      SupabaseClient('http://127.0.0.1:1', 'test-key'),
      apiBaseUrl: '',
    );
  });

  const profile = StudentProfile(
    id: 's1',
    name: 'طالب',
    username: 'student',
    role: 'student',
  );

  Future<void> pumpHub(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 720);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: StudentHomeScreen(
          profile: profile,
          authService: authService,
          apiBaseUrl: '',
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 400));
  }

  /// The transform the card's own AnimatedBuilder produces. Reading the
  /// matrix rather than a private field is what lets this assert on what
  /// is actually painted.
  Finder cardFinder(String titleKey) =>
      find.byKey(ValueKey('portal-tile-$titleKey'));

  Matrix4 cardMatrix(WidgetTester tester, String titleKey) {
    final transforms = find.descendant(
      of: cardFinder(titleKey),
      matching: find.byType(Transform),
    );
    return tester.widget<Transform>(transforms.first).transform;
  }

  /// Runs the clock until the press has actually registered.
  ///
  /// The rail is a horizontal ListView, so its drag recognizer contests
  /// the gesture arena and onTapDown only fires once the tap wins it.
  /// That resolution rides on a timer, so the clock has to be advanced in
  /// steps — one long pump jumps over it and reads an untouched card.
  Future<void> settlePress(WidgetTester tester) async {
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 60));
    }
  }

  double scaleOf(Matrix4 matrix) => matrix.getMaxScaleOnAxis();
  double yOf(Matrix4 matrix) => matrix.getTranslation().y;

  testWidgets('the cards float on their own, without being touched',
      (tester) async {
    await pumpHub(tester);

    // Sampled across a full drift period. A card that never moves, or one
    // that moves by a hair, is the "no sense of life" this was raised for.
    final heights = <double>[];
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 380));
      heights.add(yOf(cardMatrix(tester, 'portal.lesson')));
    }

    final travel = heights.reduce((a, b) => a > b ? a : b) -
        heights.reduce((a, b) => a < b ? a : b);
    expect(
      travel,
      greaterThan(4),
      reason: 'the idle float is too small to read as floating',
    );
  });

  testWidgets('neighbouring cards do not float in lockstep', (tester) async {
    await pumpHub(tester);
    await tester.pump(const Duration(milliseconds: 700));

    // Each card is given its own period precisely so nine of them never
    // pulse as one block.
    expect(yOf(cardMatrix(tester, 'portal.lesson')), isNot(yOf(cardMatrix(tester, 'portal.games'))));
  });

  testWidgets('the push is its own motion, faster than the lift',
      (tester) async {
    await pumpHub(tester);
    final card = cardFinder('portal.lesson');

    // Hold until both the lift and the push have settled, so the card is
    // sitting at "raised, and pushed in".
    final gesture = await tester.startGesture(tester.getCenter(card));
    await tester.pump(const Duration(milliseconds: 900));
    final held = scaleOf(cardMatrix(tester, 'portal.lesson'));

    // Cancel rather than lift, so the tap never fires and the hub is not
    // navigated away from underneath the assertions.
    await gesture.cancel();
    await tester.pump(const Duration(milliseconds: 70));
    final justReleased = scaleOf(cardMatrix(tester, 'portal.lesson'));

    // Both motions are now reversing, but the push is a stiff spring and
    // the lift is a half-second ease. If the two shared one controller
    // the scale could only fall from here; it rising is the proof that
    // the push released on its own, faster, timeline.
    expect(
      justReleased,
      greaterThan(held),
      reason: 'the push did not release independently of the lift',
    );
  });

  testWidgets('the push springs back and settles', (tester) async {
    await pumpHub(tester);
    final card = cardFinder('portal.lesson');

    final gesture = await tester.startGesture(tester.getCenter(card));
    await tester.pump(const Duration(milliseconds: 80));
    final pushed = scaleOf(cardMatrix(tester, 'portal.lesson'));

    await gesture.cancel();
    await tester.pump(const Duration(milliseconds: 40));
    expect(
      scaleOf(cardMatrix(tester, 'portal.lesson')),
      greaterThan(pushed),
      reason: 'the card did not start coming back',
    );

    // An unbounded controller driven by a spring runs until the
    // simulation reports it is done. One that never settles ticks
    // forever — a visible wobble and a battery drain both.
    await tester.pump(const Duration(seconds: 2));
    final settled = scaleOf(cardMatrix(tester, 'portal.lesson'));
    await tester.pump(const Duration(milliseconds: 16));
    expect(
      (scaleOf(cardMatrix(tester, 'portal.lesson')) - settled).abs(),
      lessThan(0.02),
    );
  });

  testWidgets('a press squashes the card rather than shrinking it',
      (tester) async {
    await pumpHub(tester);
    final card = cardFinder('portal.lesson');

    // The rail is a horizontal ListView, so its drag recognizer contests
    // the arena and onTapDown does not fire until the tap wins it — about
    // 300ms in. Measuring sooner reads an untouched card.
    final gesture = await tester.startGesture(tester.getCenter(card));
    await settlePress(tester);
    final matrix = cardMatrix(tester, 'portal.lesson');
    await gesture.cancel();

    // A uniform shrink reads as the card moving away. Taking more off the
    // height than the width is what reads as something soft giving under
    // a thumb, which is the whole point of the press.
    final scaleX = matrix.getColumn(0).length;
    final scaleY = matrix.getColumn(1).length;
    expect(
      scaleY,
      lessThan(scaleX),
      reason: 'the press scaled uniformly — no compression',
    );
  });

  testWidgets('the card tilts toward wherever the finger landed',
      (tester) async {
    await pumpHub(tester);
    final card = cardFinder('portal.lesson');
    final box = tester.getRect(card);

    Future<Matrix4> pressAt(Offset at) async {
      final gesture = await tester.startGesture(at);
      await settlePress(tester);
      final matrix = cardMatrix(tester, 'portal.lesson');
      await gesture.cancel();
      await tester.pump(const Duration(seconds: 1));
      return matrix;
    }

    // Pressing opposite edges has to tilt the card opposite ways. If the
    // tilt is canned, both presses produce the same matrix and the 3D is
    // an animation rather than an answer to where you touched.
    final left = await pressAt(Offset(box.left + 8, box.center.dy));
    final right = await pressAt(Offset(box.right - 8, box.center.dy));

    // Entry (0,2) of the matrix carries the Y rotation's sign.
    expect(
      left.entry(0, 2) * right.entry(0, 2),
      lessThan(0),
      reason: 'both edges tilted the same way — the tilt ignores the touch',
    );
  });

  testWidgets('reduced motion stops every one of the three motions',
      (tester) async {
    tester.view.physicalSize = const Size(1280, 720);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(disableAnimations: true),
        child: MaterialApp(
          home: StudentHomeScreen(
            profile: profile,
            authService: authService,
            apiBaseUrl: '',
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 400));

    final first = cardMatrix(tester, 'portal.lesson');
    await tester.pump(const Duration(milliseconds: 900));
    expect(yOf(cardMatrix(tester, 'portal.lesson')), yOf(first));
    expect(scaleOf(cardMatrix(tester, 'portal.lesson')), scaleOf(first));
  });
}
