import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:manara_student/src/services/student_avatar_store.dart';

/// شخصيةُ الطالب تتبع ملفَّه لا الجهاز.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('من ملفّه، ومن لم يختر بعدُ فالشخصيةُ الأساسية — لا شخصيةُ من دخل قبله', () async {
    final other = StudentAvatars.all.last;
    await StudentAvatars.select(other);
    await StudentAvatars.adoptFromProfile(null);
    expect(StudentAvatars.selected.value, StudentAvatars.fallback);

    await StudentAvatars.adoptFromProfile({StudentAvatars.appearanceKey: other.id});
    expect(StudentAvatars.selected.value, other);
  });
}
