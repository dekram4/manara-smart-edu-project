import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:manara_student/src/models/study_games.dart';
import 'package:manara_student/src/services/tracing_scope.dart';
import 'package:manara_student/src/widgets/study_games.dart';
import 'package:manara_student/src/widgets/tracing_shelf_card.dart';

/// «تتبّع واكتب» لروضة منارة المعرفة في موادّها الأربع وحدها.
void main() {
  group('القاعدة', () {
    test('الروضةُ والمادّةُ الأربع معاً', () {
      for (final subject in const [
        'الحروف العربية',
        'الحروف الإنجليزية',
        'الارقام العربية',
        'الارقام الانجليزية',
        'الأرقام الإنجليزية',
      ]) {
        expect(tracingAllowedFor(grade: 'روضة منارة المعرفة', subject: subject), isTrue, reason: subject);
      }
      expect(tracingAllowedFor(grade: 'روضه مناره المعرفه', subject: 'الحروف العربيه'), isTrue);
    });

    test('صفٌّ آخر بالمادّة نفسها: لا', () {
      expect(tracingAllowedFor(grade: 'الصف الأول', subject: 'الحروف العربية'), isFalse);
      expect(tracingAllowedFor(grade: null, subject: 'الأرقام العربية'), isFalse);
    });

    test('الروضةُ بمادّةٍ أخرى: لا', () {
      expect(tracingAllowedFor(grade: 'روضة منارة المعرفة', subject: 'العلوم'), isFalse);
      expect(tracingAllowedFor(grade: 'روضة منارة المعرفة', subject: 'اللغة العربية'), isFalse);
      expect(tracingAllowedFor(grade: 'روضة منارة المعرفة', subject: null), isFalse);
    });
  });

  group('الرفّ', () {
    StudyGame tracing() => StudyGame.fromMap({
          'id': 'tracing',
          'game_type': 'tracing',
          'title': 'تتبّع واكتب!',
          'instructions': 'المس حرفاً',
          'items': {
            'tracing': [
              {'text': 'ب', 'kind': 'letter', 'lang': 'ar'},
            ],
          },
          'gems_reward': 6,
          'points_reward': 30,
        })!;
    StudyGame matching() => StudyGame.fromMap({
          'id': 'matching',
          'game_type': 'matching',
          'title': 'صِل',
          'instructions': 'صل',
          'items': {
            'drag_items': ['أ', 'ب'],
            'drop_targets': ['١', '٢'],
            'correct_pairs': [
              {'item': 'أ', 'target': '١'},
              {'item': 'ب', 'target': '٢'},
            ],
          },
          'gems_reward': 5,
          'points_reward': 20,
        })!;

    Future<void> pumpTab(WidgetTester tester, {required bool allowTracing}) async {
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: child!,
          ),
          home: Scaffold(
            body: StudyGamesTab(
              load: () async => StudyGamesPack(lessonId: 'L1', games: [matching(), tracing()]),
              onWin: (_) async => null,
              allowTracing: allowTracing,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('خارج الروضة: لا بطاقةَ تتبّع ولو أرسلها الخادم، وتبقى بقيّةُ الألعاب', (tester) async {
      await pumpTab(tester, allowTracing: false);
      expect(find.byType(TracingShelfCard), findsNothing);
      expect(find.text('صِل'), findsOneWidget);
    });

    testWidgets('في الروضة: تظهر', (tester) async {
      await pumpTab(tester, allowTracing: true);
      expect(find.byType(TracingShelfCard), findsOneWidget);
    });
  });
}
