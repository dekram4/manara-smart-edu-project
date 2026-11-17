import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:manara_student/src/models/academic_context.dart';
import 'package:manara_student/src/models/student_profile.dart';
import 'package:manara_student/src/services/demo_catalog.dart';
import 'package:manara_student/src/services/demo_content.dart';
import 'package:manara_student/src/services/demo_mode.dart';
import 'package:manara_student/src/services/student_auth_service.dart';
import 'package:manara_student/src/services/student_content_service.dart';
import 'package:manara_student/src/services/student_settings.dart';

/// الزائرُ يرى منهجَ الحساب الرسمي نفسَه: موادّه وفصولَه ووحداتِه ودروسَه.
const _deadServer = 'http://127.0.0.1:1';
const _kg = 'روضة منارة المعرفة';

Map<String, dynamic> _config(String owner, String grade, Map<String, Map<String, List<String>>> subjects) => {
      'grade': grade,
      'teacherId': owner,
      'subjects': [
        for (final s in subjects.entries)
          {
            'subject': s.key,
            'terms': [
              {
                'term': 'الفصل الأول',
                'units': s.value.keys.toList(),
                'lessons': s.value,
              },
            ],
          },
      ],
    };

Map<String, dynamic> _lesson(String id, String owner, String subject, String unit, String name) => {
      'id': id,
      'data': {
        'grade': _kg,
        'subject': subject,
        'term': 'الفصل الأول',
        'unit': unit,
        'lesson': name,
        'teacherId': owner,
        'lessonContent': 'شرح $name',
      },
    };

final _hierarchy = [
  // ‏قالبُ المشرف ومعلّمٌ آخر بمنهجٍ صغير: لا يُعرضان.
  _config('supervisor', _kg, {
    'قالب': {'و': ['د']},
  }),
  _config('teacher_small', _kg, {
    'مادة صغيرة': {'وحدة': ['درس']},
  }),
  _config('teacher_dawood', _kg, {
    'القرآن الكريم': {
      'جزء عم': ['سورة الفاتحة', 'سورة الناس', 'سورة الفلق'],
    },
    'القاعدة النورانية': {
      'القاعدة النورانية': ['الدرس الأول: الحروف المفردة', 'الدرس الثاني: الحروف المركبة'],
      'تعليم القراءة والقاعدة النورانية': ['الدرس الثالث: الحروف المقطعة'],
    },
    'الحروف العربية': {
      'الحروف': ['حرف الألف', 'حرف الباء'],
    },
  }),
  _config('teacher_g4', 'الصف الرابع الابتدائي', {
    'الرياضيات': {'الأعداد': ['القيمة المنزلية']},
  }),
];

final _rows = [
  _lesson('l1', 'teacher_dawood', 'القاعدة النورانية', 'القاعدة النورانية', 'الدرس الأول: الحروف المفردة'),
  _lesson('l2', 'teacher_dawood', 'القرآن الكريم', 'جزء عم', 'سورة الفاتحة'),
  _lesson('lx', 'teacher_small', 'مادة صغيرة', 'وحدة', 'درس'),
];

final _quizzes = [
  {
    'id': 'q1',
    'data': {
      'title': 'اختبار الحروف المفردة',
      'quizType': 'periodic',
      'isActive': true,
      'grade': _kg,
      'subject': 'القاعدة النورانية',
      'term': 'الفصل الأول',
      'unit': 'القاعدة النورانية',
      'lesson': 'الدرس الأول: الحروف المفردة',
      'lessonId': 'l1',
      'teacherId': 'teacher_dawood',
      'questions': [
        for (var i = 0; i < 4; i++)
          {'id': 'x$i', 'question': 'سؤال $i', 'options': ['أ', 'ب', 'ج'], 'correctAnswer': 'ب'},
      ],
    },
  },
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    StudentSettings.resetForTest();
  });
  tearDown(DemoMode.exit);

  test('يُختار مدخلُ الروضة الرسمي: أكبرُ شجرةٍ لمعلّم، لا قالبُ المشرف', () {
    final data = DemoCatalog.build(track: 'kg', hierarchy: _hierarchy, lessonRows: _rows, quizRows: _quizzes)!;
    expect(data.owner, 'teacher_dawood');
    expect(data.grade, _kg);
    expect(data.lessonRows.map((r) => r['id']), ['l1', 'l2']);
    final g4 = DemoCatalog.build(track: 'grade4', hierarchy: _hierarchy, lessonRows: _rows)!;
    expect(g4.owner, 'teacher_g4');
    expect(g4.grade, 'الصف الرابع الابتدائي');
    expect(DemoCatalog.build(track: 'kg', hierarchy: const []), isNull);
  });

  test('شجرةُ الزائر هي شجرةُ طالب الروضة الرسمي حرفاً بحرف — ومنها «القاعدة النورانية»', () async {
    final data = DemoCatalog.build(track: 'kg', hierarchy: _hierarchy, lessonRows: _rows, quizRows: _quizzes)!;
    DemoCatalog.current = data;
    final guest = DemoContent.profile('kg', grade: data.grade, teacherId: data.owner);
    DemoMode.enterFor(guest);
    DemoCatalog.current = data;
    final service = StudentContentService(SupabaseClient(_deadServer, 'k'), baseUrl: _deadServer);
    final selection = await service.fetchAcademicSelectionData(guest);

    const official = StudentProfile(id: 's1', username: 'u', name: 'n', role: 'student', grade: _kg, teacherId: 'teacher_dawood');
    final expected = StudentContentService.academicPaths(
      hierarchyValue: _hierarchy,
      hierarchyUnavailable: false,
      lessons: const [],
      profile: official,
    );
    String key(AcademicPath p) => '${p.grade}|${p.subject}|${p.term}|${p.unit}';
    expect(selection.paths.map(key), expected.map(key));
    expect(selection.subjectsFor(grade: _kg), ['القرآن الكريم', 'القاعدة النورانية', 'الحروف العربية']);
    expect(
      selection.unitsFor(grade: _kg, subject: 'القاعدة النورانية', term: 'الفصل الأول'),
      ['القاعدة النورانية', 'تعليم القراءة والقاعدة النورانية'],
    );
    final declared = declaredLessonsFromHierarchy(_hierarchy, official);
    expect(selection.declaredLessons.map((d) => d.name), declared.map((d) => d.name));
    expect(selection.declaredLessons, hasLength(8));
    expect(selection.lessons.map((l) => l.lessonName), contains('الدرس الأول: الحروف المفردة'));

    // ‏الدرسُ نفسه داخل البطاقة، واختبارُه الرسمي (تقصّه شاشةُ الاختبار إلى سؤالين).
    final context = AcademicContext(
        grade: _kg, subject: 'القاعدة النورانية', term: 'الفصل الأول', unit: 'القاعدة النورانية',
        selectedLesson: selection.lessons.firstWhere((l) => l.id == 'l1'));
    final lessons = await service.fetchLessons(guest, academicContext: context);
    expect(lessons.first.lessonText, 'شرح الدرس الأول: الحروف المفردة');
    final quizzes = await service.fetchAvailableQuizzes(guest, academicContext: context);
    expect(quizzes.single['title'], 'اختبار الحروف المفردة');
    expect(quizzes.single['questions'], hasLength(4));
    final game = DemoCatalog.studyGames('l1')!.games.single;
    expect(game.questions, hasLength(4));
  });

  test('دخولُ الزائر من النسخة المدمجة وحدها: صفُّ الحساب الرسمي ومعلّمُه، بلا طلبٍ للخادم', () async {
    final data = DemoCatalog.build(track: 'kg', hierarchy: _hierarchy, lessonRows: _rows, quizRows: _quizzes)!;
    final read = <String>[];
    DemoCatalog.readAsset = (path) async {
      read.add(path);
      return jsonEncode(data.toJson());
    };
    addTearDown(() => DemoCatalog.readAsset = rootBundle.loadString);
    final auth = StudentAuthService(SupabaseClient(_deadServer, 'k'), apiBaseUrl: _deadServer);
    final profile = await auth.signInDemo('kg');
    expect(read, ['assets/demo/catalog_kg.json']);
    expect(profile.grade, _kg);
    expect(profile.teacherId, 'teacher_dawood');
    expect(profile.isDemo, isTrue);

    // ‏والشجرةُ والدروسُ والاختبارات من النسخة: الخادمُ معطّلٌ ولا يُنتظر.
    DemoMode.enterFor(profile);
    final service = StudentContentService(auth.client, baseUrl: _deadServer, authService: auth);
    final selection = await service.fetchAcademicSelectionData(profile).timeout(const Duration(seconds: 2));
    expect(selection.subjectsFor(grade: _kg), contains('القاعدة النورانية'));
    auth.client.auth.stopAutoRefresh();
  });

  test('نسخةٌ مدمجةٌ فارغة (بناءٌ بلا أسرار): المنهجُ المدمج بديلاً، وفيه «القاعدة النورانية»', () async {
    final auth = StudentAuthService(SupabaseClient(_deadServer, 'k'), apiBaseUrl: _deadServer);
    final profile = await auth.signInDemo('kg');
    expect(DemoCatalog.current, isNull);
    expect(profile.grade, DemoContent.kgGrade);
    DemoMode.enterFor(profile);
    final service = StudentContentService(auth.client, baseUrl: _deadServer, authService: auth);
    final selection = await service.fetchAcademicSelectionData(profile);
    expect(selection.subjectsFor(grade: DemoContent.kgGrade).take(2), ['القرآن الكريم', 'القاعدة النورانية']);
    auth.client.auth.stopAutoRefresh();
  });

  test('أوّلُ دخولٍ بلا إنترنت: الصف الرابع من المنهج المدمج', () async {
    final auth = StudentAuthService(SupabaseClient(_deadServer, 'k'), apiBaseUrl: _deadServer);
    final profile = await auth.signInDemo('grade4');
    expect(DemoCatalog.current, isNull);
    expect(profile.grade, DemoContent.grade4);
    DemoMode.enterFor(profile);
    final service = StudentContentService(auth.client, baseUrl: _deadServer, authService: auth);
    final selection = await service.fetchAcademicSelectionData(profile);
    expect(selection.subjectsFor(grade: DemoContent.grade4), isNotEmpty);
    auth.client.auth.stopAutoRefresh();
  });
}
