import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:manara_student/src/widgets/student_avatar_view.dart';

/// The leaderboard draws every classmate with the same widget that draws
/// the child's own character. These cover the part that is new: reading
/// *someone else's* saved appearance instead of the device's selection.
void main() {
  Future<void> show(WidgetTester tester, Map<String, dynamic>? look) =>
      tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: StudentAvatarView(size: 48, appearance: look),
            ),
          ),
        ),
      );

  testWidgets('draws the emoji the classmate picked', (tester) async {
    await show(tester, {'shape': '🦊', 'color': '#F97316'});
    expect(find.text('🦊'), findsOneWidget);
  });

  testWidgets('two classmates who picked differently look different',
      (tester) async {
    await show(tester, {'shape': '🦁'});
    expect(find.text('🦁'), findsOneWidget);
    expect(find.text('🐼'), findsNothing);

    await show(tester, {'shape': '🐼'});
    expect(find.text('🐼'), findsOneWidget);
    expect(find.text('🦁'), findsNothing);
  });

  testWidgets('a classmate who picked nothing still gets a character',
      (tester) async {
    // خانةٌ فارغة في صفٍّ من الميداليات تبدو عطباً. الافتراضيّ أوضح.
    await show(tester, const <String, dynamic>{});
    expect(find.byType(Text), findsOneWidget);
  });

  testWidgets('a picked avatar image wins over the emoji', (tester) async {
    await show(tester, {'shape': '🦊', 'avatarId': 'a1'});
    expect(find.byType(Image), findsOneWidget);
    expect(find.text('🦊'), findsNothing);
  });

  testWidgets('a built portrait wins over everything', (tester) async {
    await show(tester, {
      'shape': '🦊',
      'avatarId': 'a1',
      'readyPlayerMeAvatarImageUrl': 'https://example.test/a.png',
    });
    final image = tester.widget<Image>(find.byType(Image));
    expect(image.image, isA<NetworkImage>());
  });

  testWidgets('an insecure portrait url is refused, not drawn',
      (tester) async {
    // الصورة تُحمَّل من عنوانٍ يصل من سجلّ طفلٍ آخر؛ غير https لا يُطلب.
    await show(tester, {
      'shape': '🦊',
      'readyPlayerMeAvatarImageUrl': 'http://example.test/a.png',
    });
    expect(find.text('🦊'), findsOneWidget);
  });

  testWidgets('with no appearance it still follows the device selection',
      (tester) async {
    await show(tester, null);
    expect(find.byType(Image), findsOneWidget);
  });
}
