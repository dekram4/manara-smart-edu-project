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
/// The idle float is deliberately gone: nine cards drifting on their own
/// timers read as restless, and that movement competed with the one that
/// matters. Everything that moves now is something the student caused —
/// which is what these check.
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

  /// Runs the clock in steps so pointer-driven work is processed.
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 60));
    }
  }

  double scaleOf(Matrix4 m) => m.getMaxScaleOnAxis();
  double yOf(Matrix4 m) => m.getTranslation().y;
  double tiltY(Matrix4 m) => m.entry(0, 2);
  double tiltX(Matrix4 m) => m.entry(1, 2);

  testWidgets('an untouched card holds perfectly still', (tester) async {
    await pumpHub(tester);

    // The old rail drifted on a repeating timer. Nothing moves now unless
    // a finger is on it — a card that wanders on its own is exactly the
    // restlessness this replaced.
    final first = cardMatrix(tester, 'portal.lesson');
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 400));
      final now = cardMatrix(tester, 'portal.lesson');
      expect(yOf(now), yOf(first));
      expect(scaleOf(now), scaleOf(first));
    }
  });

  testWidgets('a press compresses the card, more in height than width',
      (tester) async {
    await pumpHub(tester);
    final card = cardFinder('portal.lesson');

    final gesture = await tester.startGesture(tester.getCenter(card));
    await settle(tester);
    final matrix = cardMatrix(tester, 'portal.lesson');
    await gesture.cancel();

    // A uniform shrink reads as the card moving away. Taking more off the
    // height than the width is what reads as something soft giving under
    // a thumb.
    expect(
      matrix.getColumn(1).length,
      lessThan(matrix.getColumn(0).length),
      reason: 'the press scaled uniformly — no compression',
    );
  });

  testWidgets('the tilt follows the finger across the card', (tester) async {
    await pumpHub(tester);
    final card = cardFinder('portal.lesson');
    final box = tester.getRect(card);

    // Land in the middle, then drag to one edge and on to the other
    // without lifting. The tilt has to keep up the whole way — freezing
    // at the touch point is the canned-animation failure this guards.
    final gesture = await tester.startGesture(box.center);
    await settle(tester);
    final atCentre = tiltY(cardMatrix(tester, 'portal.lesson'));

    await gesture.moveTo(Offset(box.left + 6, box.center.dy));
    await settle(tester);
    final atLeft = tiltY(cardMatrix(tester, 'portal.lesson'));

    await gesture.moveTo(Offset(box.right - 6, box.center.dy));
    await settle(tester);
    final atRight = tiltY(cardMatrix(tester, 'portal.lesson'));

    await gesture.cancel();

    expect(atLeft, isNot(atCentre), reason: 'the drag did not move the tilt');
    expect(
      atLeft * atRight,
      lessThan(0),
      reason: 'opposite edges did not tilt the card opposite ways',
    );
  });

  testWidgets('dragging up and down tilts the other axis', (tester) async {
    await pumpHub(tester);
    final card = cardFinder('portal.lesson');
    final box = tester.getRect(card);

    final gesture = await tester.startGesture(box.center);
    await settle(tester);

    await gesture.moveTo(Offset(box.center.dx, box.top + 6));
    await settle(tester);
    final atTop = tiltX(cardMatrix(tester, 'portal.lesson'));

    await gesture.moveTo(Offset(box.center.dx, box.bottom - 6));
    await settle(tester);
    final atBottom = tiltX(cardMatrix(tester, 'portal.lesson'));

    await gesture.cancel();

    expect(atTop * atBottom, lessThan(0));
  });

  testWidgets('letting go springs back flat, fast', (tester) async {
    await pumpHub(tester);
    final card = cardFinder('portal.lesson');
    final box = tester.getRect(card);

    final gesture = await tester.startGesture(box.center);
    await gesture.moveTo(Offset(box.left + 6, box.center.dy));
    await settle(tester);
    expect(tiltY(cardMatrix(tester, 'portal.lesson')), isNot(0.0));

    await gesture.cancel();
    // "In a fraction of a second" is the requirement, so this window is
    // short on purpose: a card still visibly moving after 400ms is
    // sagging back, not springing.
    await tester.pump(const Duration(milliseconds: 400));
    final settled = cardMatrix(tester, 'portal.lesson');

    expect(tiltY(settled), moreOrLessEquals(0.0, epsilon: 0.005));
    await tester.pump(const Duration(milliseconds: 16));
    expect(
      (scaleOf(cardMatrix(tester, 'portal.lesson')) - scaleOf(settled)).abs(),
      lessThan(0.01),
      reason: 'the spring is still running — it never settles',
    );
  });

  testWidgets('the rail still scrolls under the drag tracking',
      (tester) async {
    // The tilt rides a raw Listener precisely so it never enters the
    // gesture arena. A pan recognizer here would contest the horizontal
    // list and either steal the scroll or never fire — and a rail that
    // stops scrolling is a far worse bug than a missing tilt.
    await pumpHub(tester);

    final rail = find.byType(ListView).first;
    final before = tester.getTopLeft(cardFinder('portal.lesson'));

    await tester.drag(rail, const Offset(-220, 0));
    await tester.pump(const Duration(milliseconds: 300));

    final after = tester.getTopLeft(cardFinder('portal.lesson'));
    expect(
      after.dx,
      lessThan(before.dx),
      reason: 'the rail did not scroll — the tilt stole the drag',
    );
  });

  testWidgets('reduced motion leaves the card entirely flat', (tester) async {
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

    final card = cardFinder('portal.lesson');
    final before = cardMatrix(tester, 'portal.lesson');

    final gesture = await tester.startGesture(tester.getCenter(card));
    await gesture.moveTo(tester.getRect(card).centerLeft);
    await settle(tester);

    final during = cardMatrix(tester, 'portal.lesson');
    expect(tiltY(during), 0.0);
    expect(scaleOf(during), scaleOf(before));

    await gesture.cancel();
  });
}
