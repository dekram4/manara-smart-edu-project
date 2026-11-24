import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:manara_student/src/config/edition.dart';
import 'package:manara_student/src/l10n/student_strings.dart';
import 'package:manara_student/src/models/student_profile.dart';
import 'package:manara_student/src/screens/open_entry_screen.dart';
import 'package:manara_student/src/services/open_edition_service.dart';
import 'package:manara_student/src/services/saved_accounts.dart';
import 'package:manara_student/src/services/student_auth_service.dart';
import 'package:manara_student/src/services/student_settings.dart';

/// دخولٌ ينجح دائماً ويسجّل ما أُدخل به — بلا شبكة.
class _FakeAuth extends StudentAuthService {
  _FakeAuth() : super(SupabaseClient('http://127.0.0.1:1', 'test-key'), apiBaseUrl: '');

  final List<(String, String)> attempts = [];

  @override
  Future<StudentProfile> signIn({required String username, required String password}) async {
    attempts.add((username, password));
    return StudentProfile(id: 's-$username', name: 'سارة أحمد', username: username, role: 'student');
  }
}

/// خادمُ النسخة المفتوحة المزيّف: يسجّل ما طُلب منه.
class _Server {
  final List<Map<String, dynamic>> joins = [];
  int status = 201;
  Map<String, Object?> edition = {'edition': 'open', 'ready': true, 'teacherName': 'معلم الروضة داود سيد', 'grades': ['روضة منارة المعرفة']};

  MockClient get client => MockClient((request) async {
        if (request.method == 'GET' && request.url.path == '/api/edition') {
          return http.Response(jsonEncode(edition), 200, headers: {'content-type': 'application/json; charset=utf-8'});
        }
        if (request.method == 'POST' && request.url.path == '/api/open/student') {
          joins.add(jsonDecode(request.body) as Map<String, dynamic>);
          if (status != 201) {
            return http.Response(jsonEncode({'error': 'النسخة المفتوحة غير مُعدّة بعد'}), status, headers: {'content-type': 'application/json; charset=utf-8'});
          }
          return http.Response(jsonEncode({'studentId': '1', 'username': 'open_abc123', 'password': 'pw-xyz', 'grade': 'روضة منارة المعرفة'}), 201,
              headers: {'content-type': 'application/json; charset=utf-8'});
        }
        return http.Response('not found', 404);
      });
}

void grantMic(WidgetTester tester) {
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
    const MethodChannel('flutter.baseflow.com/permissions/methods'),
    (call) async => call.method == 'requestPermissions' ? {7: 1} : 1,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
    StudentSettings.resetForTest();
  });

  test('التطبيقُ الحالي ليس النسخةَ المفتوحة: بلا MANARA_EDITION لا يتغيّر شيء', () {
    expect(manaraEdition, isEmpty);
    expect(isOpenEdition, isFalse);
  });

  group('خدمةُ النسخة المفتوحة', () {
    test('تقرأ ردَّ /api/edition، وما ليس open فليس جاهزاً', () {
      final info = OpenEditionInfo.fromJson({'edition': 'open', 'ready': true, 'teacherName': ' معلم ', 'grades': ['روضة', '', 3]});
      expect(info.ready, isTrue);
      expect(info.teacherName, 'معلم');
      expect(info.grades, ['روضة']);
      expect(OpenEditionInfo.fromJson({'edition': 'standard'}).ready, isFalse);
      expect(OpenEditionInfo.fromJson(null).ready, isFalse);
    });

    test('التسجيلُ يرسل الاسمَ والصفَّ والجنس، ويعيد الحساب', () async {
      final server = _Server();
      final service = OpenEditionService(apiBaseUrl: 'https://open.example/', client: server.client);
      final info = await service.info();
      expect(info.teacherName, 'معلم الروضة داود سيد');
      final credentials = await service.join(name: ' سارة ', grade: 'روضة منارة المعرفة', gender: 'female', fallbackError: 'x');
      expect(credentials.username, 'open_abc123');
      expect(credentials.password, 'pw-xyz');
      expect(server.joins.single, {'name': 'سارة', 'grade': 'روضة منارة المعرفة', 'gender': 'female'});
    });

    test('رسالةُ الخادم تصل كما هي، وانقطاعُه برسالةٍ عامّة', () async {
      final server = _Server()..status = 503;
      final service = OpenEditionService(apiBaseUrl: 'https://open.example', client: server.client);
      await expectLater(
        service.join(name: 'علي', fallbackError: 'عامّة'),
        throwsA(isA<OpenEditionException>().having((e) => e.message, 'message', 'النسخة المفتوحة غير مُعدّة بعد')),
      );
      final offline = OpenEditionService(apiBaseUrl: 'https://open.example', client: MockClient((_) async => throw Exception('offline')));
      await expectLater(
        offline.join(name: 'علي', fallbackError: 'عامّة'),
        throwsA(isA<OpenEditionException>().having((e) => e.message, 'message', 'عامّة')),
      );
      expect((await offline.info()).ready, isFalse);
    });
  });

  group('باب النسخة المفتوحة', () {
    // ‏خارج الاختبار: عميلُ Supabase يبدأ مؤقّتَ تجديدٍ دوريّاً حين يُنشأ.
    late _FakeAuth auth;
    setUp(() => auth = _FakeAuth());

    Future<(_FakeAuth, _Server)> pump(WidgetTester tester, SavedAccounts saved, {bool autoContinue = false}) async {
      grantMic(tester);
      tester.view.physicalSize = const Size(800, 1280);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final server = _Server();
      await tester.pumpWidget(MaterialApp(
        home: OpenEntryScreen(
          authService: auth,
          apiBaseUrl: 'https://open.example',
          autoContinue: autoContinue,
          savedAccounts: saved,
          service: OpenEditionService(apiBaseUrl: 'https://open.example', client: server.client),
          voiceListen: ({required onResult, onPartial}) async => false,
        ),
      ));
      await tester.pump(const Duration(milliseconds: 100));
      return (auth, server);
    }

    Future<void> settle(WidgetTester tester) async {
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 20));
    }

    testWidgets('طالبٌ جديد: اسمُه وحده، فيُنشأ حسابُه ويدخل ويُحفظ', (tester) async {
      final saved = SavedAccounts();
      final (auth, server) = await pump(tester, saved);
      expect(find.byKey(const ValueKey('open-entry')), findsOneWidget);
      expect(find.text(trf('open.withTeacher', {'name': 'معلم الروضة داود سيد'})), findsOneWidget);
      expect(find.byKey(const ValueKey('open-name-mic')), findsOneWidget, reason: 'الاسمُ بالصوت أيضاً');
      expect(find.byKey(const ValueKey('open-grade')), findsNothing, reason: 'صفٌّ واحد: لا سؤال');

      await tester.enterText(find.byKey(const ValueKey('open-name')), 'سارة أحمد');
      await tester.tap(find.text(tr('open.girl')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('open-start')));
      await tester.pump(const Duration(milliseconds: 300));

      expect(server.joins.single, {'name': 'سارة أحمد', 'grade': 'روضة منارة المعرفة', 'gender': 'female'});
      expect(auth.attempts, [('open_abc123', 'pw-xyz')]);
      final accounts = await saved.load();
      expect(accounts.single.username, 'open_abc123');
      expect(accounts.single.displayName, 'سارة أحمد');
      expect(await saved.passwordFor('open_abc123'), 'pw-xyz');
      await settle(tester);
    });

    testWidgets('بلا اسم: تنبيهٌ ولا تسجيل', (tester) async {
      final (auth, server) = await pump(tester, SavedAccounts());
      await tester.tap(find.byKey(const ValueKey('open-start')));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text(tr('open.nameRequired')), findsOneWidget);
      expect(server.joins, isEmpty);
      expect(auth.attempts, isEmpty);
      await settle(tester);
    });

    testWidgets('عند فتح التطبيق: حسابٌ محفوظٌ واحد يدخل وحده بلا كتابة', (tester) async {
      final saved = SavedAccounts();
      await saved.save(const SavedAccount(username: 'open_abc123', displayName: 'سارة'), 'pw-xyz');
      final (auth, server) = await pump(tester, saved, autoContinue: true);
      await tester.pump(const Duration(milliseconds: 300));
      expect(auth.attempts, [('open_abc123', 'pw-xyz')]);
      expect(server.joins, isEmpty, reason: 'لا حسابَ جديد');
      await settle(tester);
    });

    testWidgets('بعد الخروج: لا دخولَ تلقائي، بل «تابع باسمك» بلمسة', (tester) async {
      final saved = SavedAccounts();
      await saved.save(const SavedAccount(username: 'open_abc123', displayName: 'سارة'), 'pw-xyz');
      // ‏حسابٌ من التطبيق الحالي على الجهاز نفسه لا يظهر هنا.
      await saved.save(const SavedAccount(username: 'sara', displayName: 'سارة القديمة'), 'old');
      final (auth, _) = await pump(tester, saved);
      await tester.pump(const Duration(milliseconds: 300));
      expect(auth.attempts, isEmpty);
      expect(find.byKey(const ValueKey('open-continue-open_abc123')), findsOneWidget);
      expect(find.byKey(const ValueKey('open-continue-sara')), findsNothing);
      await tester.tap(find.byKey(const ValueKey('open-continue-open_abc123')));
      await tester.pump(const Duration(milliseconds: 300));
      expect(auth.attempts, [('open_abc123', 'pw-xyz')]);
      await settle(tester);
    });

    testWidgets('على الهاتف والتابلت: البطاقةُ تتّسع بلا فيضان', (tester) async {
      for (final size in const [Size(360, 740), Size(820, 1180), Size(1366, 1024)]) {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        await pump(tester, SavedAccounts());
        tester.view.physicalSize = size;
        await tester.pump();
        expect(tester.takeException(), isNull, reason: '$size');
        expect(tester.getSize(find.byKey(const ValueKey('open-entry'))).width, lessThanOrEqualTo(480));
        await settle(tester);
      }
    });
  });
}
