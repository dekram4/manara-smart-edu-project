import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:manara_student/src/models/academic_context.dart';
import 'package:manara_student/src/models/student_content.dart';
import 'package:manara_student/src/models/student_profile.dart';
import 'package:manara_student/src/screens/academic_selection_screen.dart';
import 'package:manara_student/src/services/student_auth_service.dart';
import 'package:manara_student/src/services/student_path_memory.dart';
import 'package:manara_student/src/services/student_settings.dart';

/// آخرُ مسارٍ اختاره الطالب يعود معه: اختار العلومَ وخرج، فيعود إلى العلوم لا
/// إلى الإنجليزية التي في ملفّه.
const english = AcademicPath(
  grade: 'الصف الرابع',
  subject: 'اللغة الإنجليزية',
  term: 'الفصل الأول',
  unit: 'Unit 1',
);
const science = AcademicPath(
  grade: 'الصف الرابع',
  subject: 'العلوم',
  term: 'الفصل الثاني',
  unit: 'الوحدة الثالثة',
);

LessonContent lessonOn(AcademicPath path, String id, String name) => LessonContent(
      id: id,
      lessonId: id,
      grade: path.grade,
      subject: path.subject,
      term: path.term,
      unit: path.unit,
      lessonName: name,
      createdAt: '2026-01-01',
      videos: const [],
      games: const [],
    );

final data = AcademicSelectionData(
  paths: const [english, science],
  lessons: [
    lessonOn(english, 'en1', 'My family'),
    lessonOn(science, 'sc1', 'الخلية'),
    lessonOn(science, 'sc2', 'الجهاز الهضمي'),
  ],
);

AcademicContext contextOf(AcademicPath path, LessonContent lesson) => AcademicContext(
      grade: path.grade,
      subject: path.subject,
      term: path.term,
      unit: path.unit,
      selectedLesson: lesson,
    );

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    StudentSettings.resetForTest();
  });

  group('الحفظ والاستعادة', () {
    test('يُحفظ لكل طالبٍ مسارُه، ولا يُفتح لغيره', () async {
      await StudentPathMemory.save('s1', contextOf(science, data.lessons[2]));
      final mine = await StudentPathMemory.load('s1');
      expect(mine!.subject, 'العلوم');
      expect(mine.lessonId, 'sc2');
      expect(await StudentPathMemory.load('s2'), isNull, reason: 'إخوةٌ على جهازٍ واحد');
    });

    test('يُستعاد من شجرة اليوم بدرسه', () {
      final restored = StudentPathMemory.restore(
        data,
        StoredPath.of(contextOf(science, data.lessons[2])),
      );
      expect(restored!.subject, 'العلوم');
      expect(restored.lessonId, 'sc2');
    });

    test('تغيّر معرّفُ الدرس: يُعرف باسمه', () {
      const stored = StoredPath(
        grade: 'الصف الرابع',
        subject: 'العلوم',
        term: 'الفصل الثاني',
        unit: 'الوحدة الثالثة',
        lessonId: 'old-id',
        lessonName: 'الخلية',
      );
      expect(StudentPathMemory.restore(data, stored)!.lessonId, 'sc1');
    });

    test('حُذف الدرس أو الوحدة: لا يُفتح مسارٌ لم يعد قائماً', () {
      const gone = StoredPath(
        grade: 'الصف الرابع',
        subject: 'العلوم',
        term: 'الفصل الثاني',
        unit: 'الوحدة الثالثة',
        lessonId: 'deleted',
        lessonName: 'درسٌ محذوف',
      );
      expect(StudentPathMemory.restore(data, gone), isNull);
      const movedUnit = StoredPath(
        grade: 'الصف الرابع',
        subject: 'العلوم',
        term: 'الفصل الثاني',
        unit: 'وحدةٌ لم تعد',
        lessonId: 'sc1',
        lessonName: 'الخلية',
      );
      expect(StudentPathMemory.restore(data, movedUnit), isNull);
    });

    test('مادّةٌ قصرها المعلمُ عن الطالب بعد أن اختارها: لا تُفتح', () {
      final restored = StudentPathMemory.restore(
        data,
        StoredPath.of(contextOf(science, data.lessons[1])),
        allowsSubject: (subject) => subject != 'العلوم',
      );
      expect(restored, isNull);
    });

    test('محفوظٌ معطوب يُهمل', () async {
      SharedPreferences.setMockInitialValues({'student.path.s1': '{not json'});
      expect(await StudentPathMemory.load('s1'), isNull);
    });
  });

  group('شاشةُ اختيار المسار', () {
    late StudentAuthService authService;

    setUp(() {
      authService = StudentAuthService(
        SupabaseClient('http://127.0.0.1:1', 'test-key'),
        apiBaseUrl: '',
      );
    });

    // مادةُ ملفّه الإنجليزية — كما أسندها المعلم.
    const profile = StudentProfile(
      id: 's1',
      name: 'طالب',
      username: 'student',
      role: 'student',
      grade: 'الصف الرابع',
      subject: 'اللغة الإنجليزية',
    );

    Future<void> pump(WidgetTester tester) async {
      tester.view.physicalSize = const Size(1024, 1366);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          home: AcademicSelectionScreen(
            profile: profile,
            authService: authService,
            apiBaseUrl: '',
            initialData: data,
          ),
        ),
      );
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
    }

    testWidgets('بلا محفوظ: مادةُ الملفّ كما كانت', (tester) async {
      await pump(tester);
      expect(find.text('My family'), findsWidgets);
      expect(find.text('الجهاز الهضمي'), findsNothing);
    });

    testWidgets('اختار العلومَ وخرج: يعود إلى العلوم ودرسِه لا إلى الإنجليزية', (tester) async {
      await StudentPathMemory.save('s1', contextOf(science, data.lessons[2]));
      await pump(tester);
      expect(find.text('الجهاز الهضمي'), findsWidgets);
      expect(find.text('My family'), findsNothing);
    });
  });
}
