import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:manara_student/src/l10n/student_strings.dart';
import 'package:manara_student/src/models/student_profile.dart';
import 'package:manara_student/src/screens/login_screen.dart';
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
    return StudentProfile(
      id: 's-$username',
      name: 'سارة',
      username: username,
      role: 'student',
      appearance: const {'avatarId': 'girl1'},
    );
  }
}

/// الحساباتُ المحفوظة: مخزنُها، وسؤالُ الحفظ، والدخولُ بلمسة.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
    StudentSettings.resetForTest();
  });

  group('المخزن', () {
    test('يُحفظ الحسابُ وكلمةُ مروره، والقائمةُ لا تحمل كلمةَ المرور', () async {
      final saved = SavedAccounts();
      await saved.save(const SavedAccount(username: 'sara', displayName: 'سارة'), 'secret-1');
      final accounts = await saved.load();
      expect(accounts.single.username, 'sara');
      expect(accounts.single.displayName, 'سارة');
      expect(await saved.passwordFor('sara'), 'secret-1');

      const storage = FlutterSecureStorage();
      final list = await storage.read(key: 'manara.savedAccounts');
      expect(list, isNot(contains('secret-1')));
    });

    test('يُسأل مرّةً: لا لحسابٍ محفوظ، ولا لمن رفض', () async {
      final saved = SavedAccounts();
      expect(await saved.shouldOffer('omar'), isTrue);
      await saved.decline('Omar ');
      expect(await saved.shouldOffer('omar'), isFalse, reason: 'رفض فلا يُسأل ثانيةً');
      await saved.save(const SavedAccount(username: 'sara', displayName: 'سارة'), 'x');
      expect(await saved.shouldOffer('SARA'), isFalse);
    });

    test('التحديثُ لا يكرّر الحساب ويقدّمه، والإزالةُ تمحو كلمةَ مروره', () async {
      final saved = SavedAccounts();
      await saved.save(const SavedAccount(username: 'sara', displayName: 'سارة'), 'a');
      await saved.save(const SavedAccount(username: 'omar', displayName: 'عمر'), 'b');
      await saved.save(const SavedAccount(username: 'sara', displayName: 'سارة'), 'c');
      expect([for (final a in await saved.load()) a.username], ['sara', 'omar']);
      expect(await saved.passwordFor('sara'), 'c');

      await saved.remove('sara');
      expect([for (final a in await saved.load()) a.username], ['omar']);
      expect(await saved.passwordFor('sara'), isNull);
    });
  });

  group('شاشةُ الدخول', () {
    // ‏يُبنى خارج الوقت المزيّف للاختبار: عميلُ Supabase يبدأ مؤقّتَ تجديدٍ دوريّاً.
    late _FakeAuth auth;
    setUp(() => auth = _FakeAuth());

    Future<_FakeAuth> pump(
      WidgetTester tester,
      SavedAccounts saved, {
      List<String>? spoken,
      List<String>? asked,
    }) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final said = [...?spoken];
      await tester.pumpWidget(MaterialApp(
        home: LoginScreen(
          authService: auth,
          initializationError: null,
          apiBaseUrl: '',
          savedAccounts: saved,
          voicePrompt: () async => asked?.add('voice_login'),
          // ‏كمحرّك التعرّف: الكلماتُ تصل واحدةً واحدة، ثم النصُّ النهائيّ.
          voiceListen: ({required onResult, onPartial}) async {
            if (said.isEmpty) return false;
            final words = said.removeAt(0);
            scheduleMicrotask(() {
              final parts = words.split(' ');
              for (var n = 1; n <= parts.length; n++) {
                onPartial?.call(parts.take(n).join(' '));
              }
              onResult(words);
            });
            return true;
          },
        ),
      ));
      await tester.pump(const Duration(milliseconds: 300));
      return auth;
    }

    /// بعد الدخول تُفتح شاشةُ المسار بمؤقّتاتها: تُزال وتُستنفد.
    Future<void> settle(WidgetTester tester) async {
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 20));
    }

    Future<void> signInByHand(WidgetTester tester, String username, String password) async {
      await tester.enterText(find.descendant(of: find.byKey(const ValueKey('login-username')), matching: find.byType(TextFormField)), username);
      await tester.enterText(find.descendant(of: find.byKey(const ValueKey('login-password')), matching: find.byType(TextFormField)), password);
      await tester.tap(find.byType(FilledButton).first);
      await tester.pump(const Duration(milliseconds: 300));
    }

    testWidgets('أوّلُ دخولٍ ناجح يسأل: نعم تحفظه بكلمة مروره', (tester) async {
      final saved = SavedAccounts();
      await pump(tester, saved);
      await signInByHand(tester, 'sara', 'secret');
      expect(find.byKey(const ValueKey('login-save-dialog')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('login-save-yes')));
      await tester.pump(const Duration(milliseconds: 300));
      final accounts = await saved.load();
      expect(accounts.single.username, 'sara');
      expect(accounts.single.appearance, {'avatarId': 'girl1'});
      expect(await saved.passwordFor('sara'), 'secret');
      await settle(tester);
    });

    testWidgets('لا تحفظ: لا يُسأل ثانيةً', (tester) async {
      final saved = SavedAccounts();
      await pump(tester, saved);
      await signInByHand(tester, 'omar', 'pw');
      await tester.tap(find.byKey(const ValueKey('login-save-no')));
      await tester.pump(const Duration(milliseconds: 300));
      expect(await saved.load(), isEmpty);
      expect(await saved.shouldOffer('omar'), isFalse);
      await settle(tester);
    });

    testWidgets('حقلُ الاسم يعرض الحسابات المحفوظة، ولمسةٌ على صورة الطفل تُدخله', (tester) async {
      final saved = SavedAccounts();
      await saved.save(
        const SavedAccount(username: 'sara', displayName: 'سارة', appearance: {'avatarId': 'girl1'}),
        'secret',
      );
      final auth = await pump(tester, saved);
      await tester.tap(find.byKey(const ValueKey('login-username')));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byKey(const ValueKey('login-account-picker')), findsOneWidget);
      expect(find.text('سارة'), findsWidgets);

      await tester.tap(find.byKey(const ValueKey('login-account-sara')));
      await tester.pump(const Duration(milliseconds: 400));
      expect(auth.attempts, [('sara', 'secret')]);
      // ‏محفوظٌ من قبل: لا سؤالَ عن الحفظ.
      expect(find.byKey(const ValueKey('login-save-dialog')), findsNothing);
      await settle(tester);
    });

    testWidgets('«حساب آخر» يعيده إلى الكتابة، ولا تُفتح القائمةُ فوقه', (tester) async {
      final saved = SavedAccounts();
      await saved.save(const SavedAccount(username: 'sara', displayName: 'سارة'), 'secret');
      await pump(tester, saved);
      await tester.tap(find.byKey(const ValueKey('login-username')));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.tap(find.byKey(const ValueKey('login-other-account')));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byKey(const ValueKey('login-account-picker')), findsNothing);
      await tester.tap(find.byKey(const ValueKey('login-username')));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byKey(const ValueKey('login-account-picker')), findsNothing);
      await settle(tester);
    });
  
    testWidgets('الدخولُ بالصوت: يُسأل «إيش اسمك؟» فيقول اسمه ويُدخَل مباشرة', (tester) async {
      final saved = SavedAccounts();
      await saved.save(const SavedAccount(username: 'jory', displayName: 'جوري داود'), 'secret-j');
      await saved.save(const SavedAccount(username: 'sara', displayName: 'سارة'), 'secret-s');
      final asked = <String>[];
      final auth = await pump(tester, saved, spoken: ['أنا جوري داود'], asked: asked);
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      expect(asked, ['voice_login'], reason: 'السؤالُ المسموع قبل الاستماع');
      // ‏دخل لحظةَ اكتمل الاسمُ في الكلام الجزئيّ، والنصُّ النهائيُّ لم يُدخله ثانيةً.
      expect(auth.attempts, [('jory', 'secret-j')]);
      expect(find.byKey(const ValueKey('login-save-dialog')), findsNothing);
      await settle(tester);
    });

    testWidgets('اسمٌ لا يُعرف: لا دخول، ويُدعى ليقوله ثانيةً', (tester) async {
      final saved = SavedAccounts();
      await saved.save(const SavedAccount(username: 'sara', displayName: 'سارة'), 'secret');
      final auth = await pump(tester, saved, spoken: ['طائرة', 'سارة']);
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      expect(auth.attempts, isEmpty);
      expect(find.text(tr('voice.nameUnknown')), findsOneWidget);
      // ‏لمسةٌ على الميكروفون: محاولةٌ ثانية.
      await tester.tap(find.byKey(const ValueKey('voice-login')));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      expect(auth.attempts, [('sara', 'secret')]);
      await settle(tester);
    });

    testWidgets('بلا حسابٍ محفوظ: لا ميكروفون — لا اسمَ يُطابَق', (tester) async {
      await pump(tester, SavedAccounts(), spoken: ['سارة']);
      expect(find.byKey(const ValueKey('voice-login')), findsNothing);
      await settle(tester);
    });

    test('سؤالُ «إيش اسمك يا بطل؟» في الحزمة', () {
      expect(File('assets/audio/voice_login.mp3').existsSync(), isTrue);
    });
  
    testWidgets('الاسمُ الأوّل وحده لا يكفي: اسمان متشابهان لا يتداخلان', (tester) async {
      final saved = SavedAccounts();
      await saved.save(const SavedAccount(username: 'jory1', displayName: 'جوري داود'), 'a');
      await saved.save(const SavedAccount(username: 'jory2', displayName: 'جوري سالم'), 'b');
      final auth = await pump(tester, saved, spoken: ['جوري', 'جوري سالم']);
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      expect(auth.attempts, isEmpty, reason: 'جوري وحدها لا تُدخل أحداً');
      expect(find.text(tr('voice.nameUnknown')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('voice-login')));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      expect(auth.attempts, [('jory2', 'b')]);
      await settle(tester);
    });
  });
}
