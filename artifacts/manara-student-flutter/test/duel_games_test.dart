import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:manara_student/src/l10n/student_strings.dart';
import 'package:manara_student/src/screens/home_layout.dart';
import 'package:manara_student/src/services/student_duel_service.dart';
import 'package:manara_student/src/services/student_settings.dart';
import 'package:manara_student/src/widgets/duel_arenas.dart';

/// الألعابُ الأربع: تُرسم، وتستجيب للّمس، وتقرأ النتيجةَ نفسها.
///
/// ── لماذا الأربعُ في اختبارٍ واحد ──
/// هي مباراةٌ واحدة بأربعة أشكال: البذرةُ والنتيجةُ وحسمُ الفائز في محرّكٍ
/// واحد. فالذي يُخشى على الأشكال هو أن يُفتح شكلٌ فلا يستجيب — لعبةٌ تُختار
/// من القائمة ثم يضغط الطفلُ فلا يحدث شيء. وهو عطبٌ لا يرفع خطأً ولا يمسكه
/// تحليل، ويحتاج ضغطةَ إصبعٍ على كلِّ واحدةٍ منها.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    StudentSettings.resetForTest();
  });

  const options = ['جليد', 'بخار', 'سائل', 'غاز'];

  Future<void> pumpChoices(
    WidgetTester tester, {
    required DuelGame game,
    required void Function(int) onPick,
    int? picked,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: DuelChoices(
              game: game,
              options: options,
              answerAt: 0,
              picked: picked,
              onPick: onPick,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  group('خياراتُ كل لعبة تستجيب للّمس', () {
    for (final game in DuelGame.values) {
      testWidgets('${game.id}: الضغطةُ تصل بالموضع الصحيح', (tester) async {
        final taps = <int>[];
        await pumpChoices(tester, game: game, onPick: taps.add);

        // كلُّ الخيارات معروضة: شكلٌ يُخفي خياراً يجعل الجوابَ غيرَ قابلٍ
        // للاختيار أصلاً.
        for (final option in options) {
          expect(find.text(option), findsOneWidget, reason: '$game / $option');
        }

        await tester.tap(find.text(options[2]));
        await tester.pump();
        expect(taps, [2], reason: 'لمسةٌ لم تبلغ المحرّك في ${game.id}');
      });

      testWidgets('${game.id}: ولا تُقبل ضغطةٌ ثانية بعد الجواب', (tester) async {
        // ── وقفلُها بعد الاختيار ──
        // المحرّكُ يردّ الثانية على كل حال، لكن زرّاً يستجيب لضغطةٍ لا أثرَ
        // لها يجعل الطفل يظنّ أنه بدّل جوابه.
        final taps = <int>[];
        await pumpChoices(tester, game: game, onPick: taps.add, picked: 1);
        await tester.tap(find.text(options[2]));
        await tester.pump();
        expect(taps, isEmpty);
      });
    }
  });

  group('حلبةُ كل لعبة تُرسم وتقرأ النتيجتين', () {
    for (final game in DuelGame.values) {
      testWidgets('${game.id}: نتيجتي ونتيجته ظاهرتان', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: DuelArena(
                  game: game,
                  mine: 3,
                  theirs: 1,
                  total: 5,
                  live: true,
                  myAppearance: null,
                  theirAppearance: null,
                  opponentName: 'سارة',
                ),
              ),
            ),
          ),
        );
        await tester.pump();

        expect(tester.takeException(), isNull);
        // الرقمان في كل حلبة: الشكلُ يتغيّر والحسابُ لا.
        expect(find.text('3/5'), findsOneWidget, reason: game.id);
        expect(find.text('1/5'), findsOneWidget, reason: game.id);
        expect(find.text('سارة'), findsOneWidget, reason: game.id);
        // ولها أبعاد: حلبةٌ في صفرٍ في صفر لا تُرى ولا يُكتشف ذلك في تحليل.
        final size = tester.getSize(find.byType(DuelArena));
        expect(size.height, greaterThan(40), reason: game.id);
      });

      testWidgets('${game.id}: وشوطٌ صفرٌ لا يقسم على صفر', (tester) async {
        // الحلباتُ تحسب نسبةً من عدد الأشواط. وبنكٌ لم يُقرأ بعد يجعله صفراً،
        // والقسمةُ عليه تُخرج `NaN` فتُسقط التخطيط.
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: DuelArena(
                  game: game,
                  mine: 0,
                  theirs: 0,
                  total: 0,
                  live: false,
                  myAppearance: null,
                  theirAppearance: null,
                  opponentName: '',
                ),
              ),
            ),
          ),
        );
        await tester.pump();
        expect(tester.takeException(), isNull, reason: game.id);
      });
    }
  });

  group('نصوصُ الألعاب الأربع', () {
    test('لكل لعبةٍ اسمٌ وشرحٌ وسطرُ اختيار، في اللغتين', () async {
      for (final locale in [StudentSettings.arabic, StudentSettings.english]) {
        await StudentSettings.setLocale(locale);
        for (final game in DuelGame.values) {
          for (final key in [
            'duel.game.${game.id}',
            'duel.how.${game.id}',
            'duel.pick.${game.id}',
          ]) {
            expect(StudentStrings.has(key), isTrue,
                reason: '$key مفقود في ${locale.languageCode}');
            expect(tr(key), isNot(key), reason: key);
          }
        }
      }
    });

    test('ورسالةُ الانتظار تحمل النتيجةَ واسمَ الزميل', () async {
      // ── والرقمُ هو ما يطمئنه ──
      // «في انتظار الخصم» وحدها تُقرأ تعليقاً لا حفظاً. فالنتيجةُ المسجَّلة
      // في الجملة نفسها.
      for (final locale in [StudentSettings.arabic, StudentSettings.english]) {
        await StudentSettings.setLocale(locale);
        final line = trf('duel.waitingScored', {'score': '4', 'name': 'سارة'});
        expect(line, contains('4'), reason: locale.languageCode);
        expect(line, contains('سارة'), reason: locale.languageCode);
        expect(line, isNot(contains('{')), reason: 'بديلٌ لم يُستبدل');
      }
    });

    test('ولا تبقى نصوصُ القفل القديمة', () {
      // شارةُ «قريباً» ورسالتُها كانتا للألعاب الثلاث المقفلة. وبقاؤهما يعني
      // أنّ موضعاً ما لا يزال يقفل لعبةً.
      for (final retired in ['duel.ready', 'duel.soon', 'duel.soon.badge']) {
        expect(StudentStrings.has(retired), isFalse, reason: retired);
      }
    });
  });

  group('رفُّ الواجهة بعد الدمج', () {
    test('بطاقةٌ واحدةٌ للتحدي لا اثنتان', () {
      // أُضيفت للحلبة بطاقةٌ ثانية في الموضع ١١، فصار في الرفّ موضعان
      // يقولان «تحدّ» ولا يفرّق بينهما طفلٌ بالاسم.
      expect(homeModuleCount, 11);
      expect(homeVisualOrder, hasLength(11));
      expect(homeVisualOrder.toSet(), hasLength(11));
      expect(homeVisualOrder, isNot(contains(11)));
    });

    test('واسمُ البطاقة صار «تحدَّ زملاءك» ومفتاحُها كما كان', () async {
      // ── والمفتاحُ هو ما يحمل الصوتَ والخلفية ──
      // `portal.challenge` هو ما تُقرأ به `challenge_ar.mp3` وصورةُ البطاقة.
      // فتغييرُه إلى `portal.duel` كان سيُفقدها صوتَها بلا خطأٍ يظهر.
      await StudentSettings.setLocale(StudentSettings.arabic);
      expect(tr('portal.challenge'), 'تحدَّ زملاءك');
      expect(StudentStrings.has('portal.challenge.voice'), isTrue);
      // ولا تبقى مفاتيحُ البطاقة المحذوفة.
      expect(StudentStrings.has('portal.duel'), isFalse);
    });
  });
}
