import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:manara_student/src/config/edition.dart';
import 'package:manara_student/src/l10n/student_strings.dart';
import 'package:manara_student/src/models/student_profile.dart';
import 'package:manara_student/src/screens/academic_selection_screen.dart';
import 'package:manara_student/src/screens/open_entry_screen.dart';
import 'package:manara_student/src/screens/student_home_screen.dart';
import 'package:manara_student/src/services/open_edition_service.dart';
import 'package:manara_student/src/services/saved_accounts.dart';
import 'package:manara_student/src/services/student_auth_service.dart';
import 'package:manara_student/src/services/student_settings.dart';

/// دخولٌ ينجح دائماً ويسجّل ما أُدخل به — بلا شبكة.
class _FakeAuth extends StudentAuthService {
  _FakeAuth() : super(SupabaseClient('http://127.0.0.1:1', 'test-key'), apiBaseUrl: '');

  final List<(String, String)> attempts = [];

  /// أسماءُ مستخدمين يرفضها الخادم (حسابٌ حُذف).
  final Set<String> reject = {};

  @override
  Future<StudentProfile> signIn({required String username, required String password}) async {
    attempts.add((username, password));
    if (reject.contains(username)) throw const StudentAuthException('حسابٌ غيرُ موجود');
    return StudentProfile(id: 's-$username', name: 'بطل الروضة', username: username, role: 'student');
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
    expect(openEditionActive, isFalse);
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

  group('بطاقاتُ النسخة المفتوحة', () {
    const hidden = ['solver', 'chat', 'tutor', 'meeting', 'challenge'];

    test('خمسُ بطاقاتٍ تُخفى في المفتوحة وحدها', () {
      for (final card in hidden) {
        expect(cardHiddenByEdition(card, openEdition: true), isTrue, reason: card);
        expect(cardHiddenByEdition(card, openEdition: false), isFalse, reason: card);
      }
      for (final card in ['lesson', 'cinema', 'games', 'personality', 'quiz', 'study', 'recite', 'write']) {
        expect(cardHiddenByEdition(card, openEdition: true), isFalse, reason: card);
      }
      // ‏والتطبيقُ الحالي (بلا MANARA_EDITION): لا شيء مخفيّ.
      expect(cardHiddenByEdition('solver'), isFalse);
    });

    // ‏خارج الاختبار: عميلُ Supabase يبدأ مؤقّتَ تجديدٍ دوريّاً حين يُنشأ.
    late StudentAuthService homeAuth;
    setUp(() => homeAuth = StudentAuthService(SupabaseClient('http://127.0.0.1:1', 'test-key'), apiBaseUrl: ''));

    Future<List<String>> rail(WidgetTester tester) async {
      tester.view.physicalSize = const Size(1280, 720);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(
        home: StudentHomeScreen(
          profile: const StudentProfile(id: 's1', name: 'طالب', username: 'student', role: 'student'),
          authService: homeAuth,
          apiBaseUrl: '',
        ),
      ));
      for (var i = 0; i < 60; i++) {
        await tester.pump(const Duration(milliseconds: 120));
      }
      final keys = [
        for (final e in find
            .byWidgetPredicate((w) => w.key is ValueKey<String> && (w.key! as ValueKey<String>).value.startsWith('portal-tile-'))
            .evaluate())
          (e.widget.key! as ValueKey<String>).value.replaceFirst('portal-tile-portal.', ''),
      ];
      await tester.pumpWidget(const SizedBox());
      return keys;
    }

    testWidgets('النسخةُ العادية: البطاقاتُ الخمس ظاهرةٌ كما كانت', (tester) async {
      final cards = await rail(tester);
      expect(cards, containsAll(hidden));
    });

    testWidgets('النسخةُ المفتوحة: تختفي الخمس وتبقى البقيّة', (tester) async {
      debugOverrideOpenEdition(true);
      addTearDown(() => debugOverrideOpenEdition(null));
      final cards = await rail(tester);
      for (final card in hidden) {
        expect(cards, isNot(contains(card)), reason: card);
      }
      expect(cards, containsAll(['lesson', 'cinema', 'games', 'personality', 'quiz', 'study']));
    });
  });

  group('باب النسخة المفتوحة', () {
    // ‏خارج الاختبار: عميلُ Supabase يبدأ مؤقّتَ تجديدٍ دوريّاً حين يُنشأ.
    late _FakeAuth auth;
    setUp(() => auth = _FakeAuth());

    Future<_Server> pump(WidgetTester tester, SavedAccounts saved, {bool autoContinue = false, _Server? server}) async {
      tester.view.physicalSize = const Size(800, 1280);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final fake = server ?? _Server();
      await tester.pumpWidget(MaterialApp(
        home: OpenEntryScreen(
          authService: auth,
          apiBaseUrl: 'https://open.example',
          autoContinue: autoContinue,
          savedAccounts: saved,
          service: OpenEditionService(apiBaseUrl: 'https://open.example', client: fake.client),
        ),
      ));
      await tester.pump(const Duration(milliseconds: 100));
      return fake;
    }

    Future<void> settle(WidgetTester tester) async {
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 20));
    }

    testWidgets('زرٌّ واحد بلا كتابة: يُنشئ حساباً تلقائياً ويدخل ويحفظه', (tester) async {
      final saved = SavedAccounts();
      final server = await pump(tester, saved);
      expect(find.byKey(const ValueKey('open-entry')), findsOneWidget);
      expect(find.text(trf('open.withTeacher', {'name': 'معلم الروضة داود سيد'})), findsOneWidget);
      expect(find.byType(TextField), findsNothing, reason: 'لا اسمَ يُكتب');
      expect(find.text(tr('open.enter')), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('open-start')));
      await tester.pump(const Duration(milliseconds: 300));

      expect(OpenEntryScreen.autoName, 'بطل الروضة');
      expect(server.joins.single, {'name': 'بطل الروضة', 'grade': 'روضة منارة المعرفة'});
      expect(auth.attempts, [('open_abc123', 'pw-xyz')]);
      final accounts = await saved.load();
      expect(accounts.single.username, 'open_abc123');
      expect(await saved.passwordFor('open_abc123'), 'pw-xyz');
      await tester.pump(const Duration(seconds: 1));
      expect(find.byType(AcademicSelectionScreen), findsOneWidget, reason: 'مباشرةً إلى اختيار المسار والصف والمادة');
      await settle(tester);
    });

    testWidgets('حسابٌ محفوظ: الزرُّ يعود إليه ولا يُنشئ غيره', (tester) async {
      final saved = SavedAccounts();
      await saved.save(const SavedAccount(username: 'open_abc123', displayName: 'بطل الروضة'), 'pw-xyz');
      // ‏حسابٌ من التطبيق الحالي على الجهاز نفسه لا يُستعمل هنا.
      await saved.save(const SavedAccount(username: 'sara', displayName: 'سارة'), 'old');
      final server = await pump(tester, saved);
      await tester.pump(const Duration(milliseconds: 300));
      expect(auth.attempts, isEmpty, reason: 'لا دخولَ تلقائيَّ بعد خروج');
      await tester.tap(find.byKey(const ValueKey('open-start')));
      await tester.pump(const Duration(milliseconds: 300));
      expect(auth.attempts, [('open_abc123', 'pw-xyz')]);
      expect(server.joins, isEmpty);
      await settle(tester);
    });

    testWidgets('عند فتح التطبيق: الحسابُ المحفوظ يدخل وحده بلا لمسة', (tester) async {
      final saved = SavedAccounts();
      await saved.save(const SavedAccount(username: 'open_abc123', displayName: 'بطل الروضة'), 'pw-xyz');
      final server = await pump(tester, saved, autoContinue: true);
      await tester.pump(const Duration(milliseconds: 300));
      expect(auth.attempts, [('open_abc123', 'pw-xyz')]);
      expect(server.joins, isEmpty);
      await settle(tester);
    });

    testWidgets('حسابٌ محفوظ حُذف من الخادم: يُنسى ويُنشأ غيرُه', (tester) async {
      final saved = SavedAccounts();
      await saved.save(const SavedAccount(username: 'open_gone', displayName: 'بطل الروضة'), 'old-pw');
      auth.reject.add('open_gone');
      final server = await pump(tester, saved);
      await tester.tap(find.byKey(const ValueKey('open-start')));
      await tester.pump(const Duration(milliseconds: 300));
      expect(server.joins, hasLength(1));
      expect(auth.attempts.last, ('open_abc123', 'pw-xyz'));
      expect((await saved.load()).map((a) => a.username), ['open_abc123']);
      await settle(tester);
    });

    testWidgets('الخادمُ غيرُ متاح: رسالةٌ ويبقى الزرّ', (tester) async {
      await pump(tester, SavedAccounts(), server: _Server()..status = 503);
      await tester.tap(find.byKey(const ValueKey('open-start')));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byKey(const ValueKey('open-error')), findsOneWidget);
      expect(find.byKey(const ValueKey('open-start')), findsOneWidget);
      await settle(tester);
    });

    testWidgets('على الهاتف والتابلت: البطاقةُ تتّسع بلا فيضان', (tester) async {
      for (final size in const [Size(360, 640), Size(820, 1180), Size(1366, 1024)]) {
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
