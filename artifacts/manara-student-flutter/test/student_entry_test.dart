import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:manara_student/src/screens/login_screen.dart';
import 'package:manara_student/src/screens/student_entry.dart';
import 'package:manara_student/src/services/student_auth_service.dart';
import 'package:manara_student/src/services/student_avatar_store.dart';
import 'package:manara_student/src/services/student_settings.dart';

/// فتحُ التطبيق: شاشةُ الدخول من أوّل إطار، بلا افتتاحية.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late StudentAuthService authService;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    StudentSettings.resetForTest();
    authService = StudentAuthService(
      SupabaseClient('http://127.0.0.1:1', 'test-key'),
      apiBaseUrl: '',
    );
  });

  testWidgets('بلا جلسةٍ محفوظة: شاشةُ الدخول في الإطار الأوّل', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: StudentEntry(authService: authService, initializationError: null, apiBaseUrl: ''),
    ));
    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.byKey(const ValueKey('entry-restoring')), findsNothing);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('وبلا خدماتٍ مهيّأة أيضاً', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: StudentEntry(authService: null, initializationError: 'x', apiBaseUrl: ''),
    ));
    expect(find.byType(LoginScreen), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 5));
  });

  group('شخصيةُ الطالب', () {
    test('من ملفّه، ومن لم يختر بعدُ فالشخصيةُ الأساسية — لا شخصيةُ من دخل قبله', () async {
      final other = StudentAvatars.all.last;
      await StudentAvatars.select(other);
      await StudentAvatars.adoptFromProfile(null);
      expect(StudentAvatars.selected.value, StudentAvatars.fallback);

      await StudentAvatars.adoptFromProfile({StudentAvatars.appearanceKey: other.id});
      expect(StudentAvatars.selected.value, other);
    });
  });
}
