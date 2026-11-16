/// محتوى «وضع الزائر» كلُّه على الجهاز: لا طلبَ واحداً إلى الخادم.
///
/// كان الزائرُ يدخل حسابَ عرضٍ على الخادم، فإن لم يُنشر خادمُ هذه النسخة
/// ظهرت له «هذه الخدمة غير متوفرة على الخادم». فصار الحسابُ والمسارُ
/// والدروسُ والاختبارات وألعابُ المذاكرة والسينما هنا، مكتوبةً في التطبيق:
/// يدخل الزائرُ فوراً، ولو بلا إنترنت.
///
/// المنهجُ كاملٌ مفتوحٌ كما في الحساب العادي: كلُّ الموادّ والفصولِ والوحداتِ
/// والدروس، ولكلّ درسٍ شرحٌ بمقاطع وأسئلةٌ ولعبة. والقيودُ بعد الدخول، داخل
/// البطاقات ([DemoMode]): مقطعٌ واحدٌ يعمل، وسؤالان، و«المقلاع» وحده…
library;

import '../models/academic_context.dart';
import '../models/student_content.dart';
import '../models/student_profile.dart';
import '../models/study_games.dart';
import 'demo_curriculum.dart';
import 'tracing_scope.dart';

abstract final class DemoContent {
  static const kgGrade = kindergartenGrade;
  static const grade4 = 'الصف الرابع';

  static const term1 = 'الفصل الدراسي الأول';
  static const term2 = 'الفصل الدراسي الثاني';
  static const unit1 = 'الوحدة الأولى';
  static const unit2 = 'الوحدة الثانية';

  /// الفيديو المدمج في التطبيق: يُشغَّل من الحزمة لا من الشبكة.
  static const videoAsset = 'asset:assets/video/welcome.mp4';

  static const _owner = 'supervisor';

  /// ملفُّ الزائر كما يُبنى من سجلّ طالب، بلا خادم.
  static StudentProfile profile(String track) {
    final kg = track != 'grade4';
    return StudentProfile.fromStudentRow({
      'id': 'demo-$track',
      'data': {
        'id': 'demo-$track',
        'username': kg ? 'demo_kg' : 'demo_grade4',
        'name': kg ? 'زائر الروضة' : 'زائر الصف الرابع',
        'role': 'student',
        'grade': kg ? kgGrade : grade4,
        'teacherId': _owner,
        'subscriptionPlan': 'demo',
        'demoTrack': kg ? 'kg' : 'grade4',
        'canAccessChat': true,
        'canAccessLiveMeeting': true,
      },
    });
  }
  // ── الموادّ والدروس: [demoKgCurriculum] و[demoGrade4Curriculum] ──

  static List<DemoSubject> _subjects(String grade) =>
      isKindergartenGrade(grade) ? demoKgCurriculum : demoGrade4Curriculum;

  /// موضعُ الدرس [l] من مادته: أربعةٌ في الوحدة الأولى من الفصل الأوّل، ثم
  /// ثلاثةٌ في الثانية، ثم ثلاثةٌ في الوحدة الأولى من الفصل الثاني.
  static (String term, String unit) _placeOf(int l) => l < 4
      ? (term1, unit1)
      : l < 7
          ? (term1, unit2)
          : (term2, unit1);

  static const _paths = [(term1, unit1), (term1, unit2), (term2, unit1)];

  /// خياراتُ السؤال مرتّبةً للعرض: الجوابُ مكتوبٌ أوّلاً، فيُدار موضعُه بين
  /// الأسئلة (سؤالُ صحٍّ وخطأٍ يبقى «صح» ثم «خطأ»).
  static List<String> _arranged(DemoQ q, int seed) {
    if (q.options.length <= 2) return q.options;
    final k = seed % q.options.length;
    return [...q.options.sublist(k), ...q.options.sublist(0, k)];
  }

  static String _gradeOf(StudentProfile profile) => profile.demoTrack == 'grade4' ? grade4 : kgGrade;

  static String _lessonId(String grade, int subject, int lesson) =>
      'demo-${isKindergartenGrade(grade) ? 'kg' : 'g4'}-$subject-$lesson';

  /// كلُّ دروس مسار الزائر، في كلّ فصلٍ ووحدة.
  static List<LessonContent> lessons(StudentProfile profile) {
    final grade = _gradeOf(profile);
    final subjects = _subjects(grade);
    return [
      for (var s = 0; s < subjects.length; s++)
        for (var l = 0; l < subjects[s].lessons.length; l++)
          LessonContent(
            id: _lessonId(grade, s, l),
            lessonId: _lessonId(grade, s, l),
            grade: grade,
            subject: subjects[s].name,
            term: _placeOf(l).$1,
            unit: _placeOf(l).$2,
            lessonName: subjects[s].lessons[l].name,
            createdAt: '2026-01-${(l + 1).toString().padLeft(2, '0')}',
            ownerId: _owner,
            lessonText: subjects[s].lessons[l].text,
            // ‏مقاطعُ الشرح الأربعة ظاهرة، والأوّلُ وحده يعمل للزائر.
            videos: segments,
            games: const [],
          ),
    ];
  }

  /// مقاطعُ «شرح الدرس»: كلُّها من الفيديو المدمج، والأوّلُ وحده يعمل للزائر.
  static const segments = [
    LessonVideo(
      id: 'demo-segment-1',
      url: videoAsset,
      sourceType: VideoSourceType.mp4,
      title: 'المقطع الأول: تمهيد الدرس',
      description: 'مقطعٌ تعريفيّ يعمل في التجربة',
    ),
    LessonVideo(id: 'demo-segment-2', url: videoAsset, sourceType: VideoSourceType.mp4, title: 'المقطع الثاني: الشرح'),
    LessonVideo(id: 'demo-segment-3', url: videoAsset, sourceType: VideoSourceType.mp4, title: 'المقطع الثالث: أمثلة محلولة'),
    LessonVideo(id: 'demo-segment-4', url: videoAsset, sourceType: VideoSourceType.mp4, title: 'المقطع الرابع: تدريب وتقويم'),
  ];

  /// شجرةُ المسار كاملةً مفتوحة: الفصلان، ووحدتا الأوّل، ووحدةُ الثاني.
  static AcademicSelectionData selection(StudentProfile profile) {
    final grade = _gradeOf(profile);
    final subjects = _subjects(grade);
    return AcademicSelectionData(
      paths: [
        for (final subject in subjects)
          for (final (term, unit) in _paths) AcademicPath(grade: grade, subject: subject.name, term: term, unit: unit),
      ],
      lessons: lessons(profile),
    );
  }

  /// دروسُ ما اختاره الزائر: المختارُ أوّلاً ثم بقيّةُ وحدته — أو كلُّ دروسه إن لم يختر بعد.
  static List<LessonContent> lessonsFor(StudentProfile profile, AcademicContext? context) {
    final all = lessons(profile);
    if (context == null) return all;
    final chosen = all.where((lesson) => lesson.id == context.lessonId).toList();
    final sameUnit = all
        .where((lesson) =>
            lesson.subject == context.subject &&
            lesson.term == context.term &&
            lesson.unit == context.unit &&
            lesson.id != context.lessonId)
        .toList();
    return [...chosen, ...sameUnit];
  }

  /// الدرسُ وترتيبُه في مادته، من معرّفه.
  static ({DemoLesson lesson, int index})? _lessonById(String id) {
    for (final grade in const [kgGrade, grade4]) {
      final subjects = _subjects(grade);
      for (var s = 0; s < subjects.length; s++) {
        for (var l = 0; l < subjects[s].lessons.length; l++) {
          if (_lessonId(grade, s, l) == id) {
            return (lesson: subjects[s].lessons[l], index: l);
          }
        }
      }
    }
    return null;
  }

  /// اختبارُ الدرس المختار في «مركز الاختبارات» (يقصّه [DemoMode] إلى سؤالين).
  static List<Map<String, dynamic>> quizzes(StudentProfile profile, AcademicContext? context) {
    final lessonId = context?.lessonId ?? '';
    final found = _lessonById(lessonId);
    if (found == null) return const [];
    final lesson = found.lesson;
    final questions = [
      for (var i = 0; i < lesson.questions.length; i++)
        {
          'id': '$lessonId-q$i',
          'question': lesson.questions[i].question,
          'options': _arranged(lesson.questions[i], found.index + i),
          'correctAnswer': lesson.questions[i].answer,
          'quizType': 'periodic',
          'quizId': 'demo-quiz-$lessonId',
        },
    ];
    return [
      {
        'id': 'demo-quiz-$lessonId',
        'title': 'اختبار «${lesson.name}»',
        'quizType': 'periodic',
        'questions': questions,
        'questionCount': questions.length,
        'questionsPerAttempt': questions.length,
        'isActive': true,
        'grade': context?.grade ?? '',
        'subject': context?.subject ?? '',
        'term': context?.term ?? '',
        'unit': context?.unit ?? '',
        'lesson': lesson.name,
        'lessonId': lessonId,
        'createdBy': _owner,
      },
    ];
  }

  /// لعبةُ السباق في «المذاكرة»: أسئلةُ الدرس نفسُها، لـ«المقلاع».
  static StudyGamesPack? studyGames(String lessonId) {
    final found = _lessonById(lessonId);
    if (found == null) return null;
    final lesson = found.lesson;
    return StudyGamesPack.fromMap({
      'lessonId': lessonId,
      'games': [
        {
          'id': 'demo-race',
          'game_type': StudyGameType.endlessQuiz.wire,
          'title': lesson.name,
          'instructions': 'أصب الإجابة الصحيحة!',
          'items': {
            'questions': [
              for (final q in lesson.questions)
                {
                  'kind': q.options.length == 2 ? 'true_false' : 'mcq',
                  'question': q.question,
                  'options': _arranged(q, found.index + lesson.questions.indexOf(q)),
                  'answer': q.answer,
                },
            ],
          },
          'gems_reward': 0,
          'points_reward': 0,
        },
      ],
    });
  }

  /// رفُّ السينما كاملاً: الأوّلُ (المدمجُ في التطبيق) يعمل، والباقي بقفله.
  static const cinema = [
    LessonVideo(
      id: 'demo-cinema',
      url: videoAsset,
      sourceType: VideoSourceType.mp4,
      title: 'مرحباً بك في منارة المعرفة',
      description: 'جولةٌ قصيرة في عالم منارة',
    ),
    LessonVideo(id: 'demo-cinema-2', url: videoAsset, sourceType: VideoSourceType.mp4, title: 'مغامرة الحروف'),
    LessonVideo(id: 'demo-cinema-3', url: videoAsset, sourceType: VideoSourceType.mp4, title: 'رحلة إلى الفضاء'),
    LessonVideo(id: 'demo-cinema-4', url: videoAsset, sourceType: VideoSourceType.mp4, title: 'عالم الحيوانات'),
    LessonVideo(id: 'demo-cinema-5', url: videoAsset, sourceType: VideoSourceType.mp4, title: 'تجارب علمية ممتعة'),
    LessonVideo(id: 'demo-cinema-6', url: videoAsset, sourceType: VideoSourceType.mp4, title: 'أناشيد الأرقام'),
    LessonVideo(id: 'demo-cinema-7', url: videoAsset, sourceType: VideoSourceType.mp4, title: 'قصص الأنبياء للأطفال'),
    LessonVideo(id: 'demo-cinema-8', url: videoAsset, sourceType: VideoSourceType.mp4, title: 'حكاية قبل النوم'),
  ];
}
