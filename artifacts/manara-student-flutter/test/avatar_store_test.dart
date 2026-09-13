import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:manara_student/src/services/student_avatar_store.dart';
import 'package:manara_student/src/widgets/student_avatar_view.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    StudentAvatars.selected.value = StudentAvatars.fallback;
  });

  test('the catalogue holds the nine characters, each with its own asset', () {
    expect(StudentAvatars.all, hasLength(9));
    final assets = StudentAvatars.all.map((a) => a.asset).toSet();
    expect(assets, hasLength(9), reason: 'no two characters share an image');
    for (final avatar in StudentAvatars.all) {
      expect(avatar.asset, startsWith('assets/images/avatar_'));
    }
  });

  test('an unknown or empty id falls back rather than throwing', () {
    expect(StudentAvatars.byId(null).id, StudentAvatars.fallback.id);
    expect(StudentAvatars.byId('   ').id, StudentAvatars.fallback.id);
    expect(StudentAvatars.byId('nope').id, StudentAvatars.fallback.id);
  });

  test('a pick survives a restart', () async {
    final chosen = StudentAvatars.all[4];
    await StudentAvatars.select(chosen);
    expect(StudentAvatars.selected.value.id, chosen.id);

    // Simulate a relaunch: reset the in-memory value, then restore.
    StudentAvatars.selected.value = StudentAvatars.fallback;
    await StudentAvatars.restore();
    expect(StudentAvatars.selected.value.id, chosen.id);
  });

  testWidgets('every view of the avatar follows the pick without being told',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Row(
            children: [
              StudentAvatarView(size: 40),
              StudentAvatarView(size: 60),
            ],
          ),
        ),
      ),
    );

    Iterable<String> shownAssets() => tester
        .widgetList<Image>(find.byType(Image))
        .map((image) => (image.image as AssetImage).assetName);

    expect(shownAssets(), everyElement(StudentAvatars.fallback.asset));

    final chosen = StudentAvatars.all[6];
    await StudentAvatars.select(chosen);
    await tester.pump();

    // Both instances changed, though neither was passed the selection.
    expect(shownAssets(), everyElement(chosen.asset));
  });

  test('nothing but an explicit pick changes the character', () async {
    // The requirement is that the choice holds until the student taps a
    // different one. Restoring repeatedly, which is what every relaunch
    // and every navigation does, must not drift it.
    await StudentAvatars.select(StudentAvatars.all[5]);
    for (var i = 0; i < 3; i++) {
      await StudentAvatars.restore();
      expect(StudentAvatars.selected.value.id, StudentAvatars.all[5].id);
    }
  });

  test('a pick is on disk the instant it is made', () async {
    // The picker used to only stage a tap; it reached disk when the save
    // button was pressed. select() is what the tap calls now, so what
    // matters is that it writes through rather than deferring.
    await StudentAvatars.select(StudentAvatars.all[2]);

    final prefs = await SharedPreferences.getInstance();
    expect(
      prefs.getString('manara.student.avatarId'),
      StudentAvatars.all[2].id,
      reason: 'the pick did not reach storage',
    );
  });
}
