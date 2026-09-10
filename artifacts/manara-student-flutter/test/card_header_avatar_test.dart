import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:manara_student/src/services/student_avatar_store.dart';
import 'package:manara_student/src/widgets/student_avatar_view.dart';
import 'package:manara_student/src/widgets/student_experience.dart';

/// StudentScreenHero is the header of every opened card — cinema, the
/// lesson, the games, the quizzes, the solver, progress — so what it shows
/// on the side is what the student meets everywhere. It kept regressing to
/// a fixed illustration of two children; these tests pin it to the
/// student's own character.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    StudentAvatars.selected.value = StudentAvatars.fallback;
  });

  // The header's idle float repeats forever, which a widget test reports
  // as a leaked timer. Every piece of it honours disableAnimations, so the
  // tests run it the way a student with reduced motion sees it — the same
  // tree, just standing still.
  Widget hero({bool showCompanion = true}) => MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: Scaffold(
            body: StudentScreenHero(
              title: 'سينما منارة',
              subtitle: 'فيديوهات المعلم والمشرف',
              icon: Icons.movie_rounded,
              showCompanion: showCompanion,
            ),
          ),
        ),
      );

  Iterable<String> assetsIn(WidgetTester tester) => tester
      .widgetList<Image>(find.byType(Image))
      .map((image) => (image.image as AssetImage).assetName);

  testWidgets('the card header shows the student character, not the old '
      'fixed mascot', (tester) async {
    await tester.pumpWidget(hero());
    await tester.pump();

    expect(find.byType(StudentAvatarView), findsOneWidget);
    expect(
      assetsIn(tester),
      isNot(contains('assets/images/student_mascot.png')),
      reason: 'the two-children illustration must not come back',
    );
    expect(assetsIn(tester), contains(StudentAvatars.fallback.asset));
  });

  testWidgets('picking a character changes the header with no rebuild of '
      'the screen around it', (tester) async {
    await tester.pumpWidget(hero());
    await tester.pump();
    expect(assetsIn(tester), contains(StudentAvatars.fallback.asset));

    final chosen = StudentAvatars.all[5];
    await StudentAvatars.select(chosen);
    await tester.pump();

    expect(assetsIn(tester), contains(chosen.asset));
    expect(assetsIn(tester), isNot(contains(StudentAvatars.fallback.asset)));
  });

  testWidgets('a header that asked for no companion still shows none',
      (tester) async {
    await tester.pumpWidget(hero(showCompanion: false));
    await tester.pump();

    expect(find.byType(StudentAvatarView), findsNothing);
  });
}
