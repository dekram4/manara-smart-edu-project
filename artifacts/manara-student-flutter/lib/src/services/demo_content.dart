/// محتوى «وضع الزائر» كلُّه على الجهاز: لا طلبَ واحداً إلى الخادم.
///
/// كان الزائرُ يدخل حسابَ عرضٍ على الخادم، فإن لم يُنشر خادمُ هذه النسخة
/// ظهرت له «هذه الخدمة غير متوفرة على الخادم». فصار الحسابُ والمسارُ
/// والدروسُ والاختبارات وألعابُ المذاكرة والسينما هنا، مكتوبةً في التطبيق:
/// يدخل الزائرُ فوراً، ولو بلا إنترنت.
///
/// الدروسُ المفتوحة (الأوّل والثاني) لها شرحٌ وأسئلةٌ وألعاب؛ وما بعدها
/// يظهر بقفله ([DemoMode]) ليرى الزائرُ أن في الحساب الرسميّ أكثر.
library;

import '../models/academic_context.dart';
import '../models/student_content.dart';
import '../models/student_profile.dart';
import '../models/study_games.dart';
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

  // ── الموادّ والدروس ──

  static final List<_Subject> _kg = [
    _Subject('الحروف العربية', [
      _Lesson('حرف الألف', 'الألف أوّلُ حروف اللغة العربية. نكتبه خطّاً مستقيماً من الأعلى إلى الأسفل. نقول: أ أرنب، أ أسد. الأرنبُ يقفز، والأسدُ يزأر.', [
        _Q('بأيّ حرفٍ تبدأ كلمة «أرنب»؟', ['أ', 'ب', 'ت', 'ث'], 'أ'),
        _Q('كيف نكتب حرف الألف؟', ['خطّاً مستقيماً', 'دائرة', 'نقطتين', 'مربّعاً'], 'خطّاً مستقيماً'),
        _Q('أيُّ هذه الكلمات تبدأ بالألف؟', ['أسد', 'بطة', 'تفاحة', 'ثعلب'], 'أسد'),
        _Q('الألفُ أوّلُ الحروف العربية.', ['صح', 'خطأ'], 'صح'),
      ]),
      _Lesson('حرف الباء', 'الباءُ حرفٌ جميلٌ يشبه القارب، وتحته نقطةٌ واحدة. نقول: ب بطة، ب باب. البطةُ تسبح في الماء، والبابُ نفتحه ونغلقه.', [
        _Q('كم نقطةً تحت حرف الباء؟', ['نقطة واحدة', 'نقطتان', 'ثلاث نقاط', 'لا نقاط'], 'نقطة واحدة'),
        _Q('بأيّ حرفٍ تبدأ كلمة «بطة»؟', ['ب', 'أ', 'ت', 'ج'], 'ب'),
        _Q('أيُّ هذه الكلمات تبدأ بالباء؟', ['باب', 'أسد', 'تمر', 'جمل'], 'باب'),
        _Q('حرفُ الباء يشبه القارب.', ['صح', 'خطأ'], 'صح'),
      ]),
      _Lesson('حرف التاء', 'التاءُ فوقها نقطتان.', const []),
      _Lesson('حرف الثاء', 'الثاءُ فوقها ثلاثُ نقاط.', const []),
    ]),
    _Subject('الحروف الإنجليزية', [
      _Lesson('Letter A', 'A is the first letter of the English alphabet. A is for Apple and A is for Ant. The red apple is sweet, and the little ant works hard.', [
        _Q('A is for …', ['Apple', 'Ball', 'Cat', 'Dog'], 'Apple'),
        _Q('Which word starts with A?', ['Ant', 'Bee', 'Cow', 'Duck'], 'Ant'),
        _Q('A is the first letter.', ['True', 'False'], 'True'),
        _Q('What colour is the apple in the lesson?', ['Red', 'Blue', 'Green', 'Black'], 'Red'),
      ]),
      _Lesson('Letter B', 'B is for Ball and B is for Bee. I kick the ball. The bee says buzz buzz!', [
        _Q('B is for …', ['Ball', 'Apple', 'Fish', 'Egg'], 'Ball'),
        _Q('What does the bee say?', ['Buzz', 'Moo', 'Woof', 'Meow'], 'Buzz'),
        _Q('Which word starts with B?', ['Bee', 'Ant', 'Cat', 'Hat'], 'Bee'),
        _Q('Ball starts with the letter B.', ['True', 'False'], 'True'),
      ]),
      _Lesson('Letter C', 'C is for Cat.', const []),
      _Lesson('Letter D', 'D is for Dog.', const []),
    ]),
    _Subject('الأرقام العربية', [
      _Lesson('العدد واحد', 'العددُ واحد (١) يعني شيئاً واحداً: شمسٌ واحدة، وقمرٌ واحد، وأنفٌ واحد في وجهي.', [
        _Q('كم شمساً في السماء؟', ['١', '٢', '٣', '٤'], '١'),
        _Q('كم أنفاً في وجهك؟', ['واحد', 'اثنان', 'ثلاثة', 'أربعة'], 'واحد'),
        _Q('أيُّ هذه هو العدد واحد؟', ['١', '٥', '٧', '٩'], '١'),
        _Q('للإنسان قمرٌ واحد في السماء.', ['صح', 'خطأ'], 'صح'),
      ]),
      _Lesson('العدد اثنان', 'العددُ اثنان (٢) يعني شيئين: عينان أرى بهما، ويدان أكتب بهما، وأذنان أسمع بهما.', [
        _Q('كم عيناً لك؟', ['٢', '١', '٣', '٥'], '٢'),
        _Q('كم يداً لك؟', ['اثنتان', 'واحدة', 'ثلاث', 'أربع'], 'اثنتان'),
        _Q('أيُّ هذه هو العدد اثنان؟', ['٢', '٤', '٦', '٨'], '٢'),
        _Q('نسمع بأذنين اثنتين.', ['صح', 'خطأ'], 'صح'),
      ]),
      _Lesson('العدد ثلاثة', 'العددُ ثلاثة (٣).', const []),
      _Lesson('العدد أربعة', 'العددُ أربعة (٤).', const []),
    ]),
    _Subject('الأرقام الإنجليزية', [
      _Lesson('Number One', 'One (1) means a single thing: one sun, one moon and one nose on my face.', [
        _Q('How many suns are in the sky?', ['1', '2', '3', '4'], '1'),
        _Q('Which number is one?', ['1', '5', '7', '9'], '1'),
        _Q('I have one nose.', ['True', 'False'], 'True'),
        _Q('One comes before …', ['Two', 'Zero', 'Ten', 'Five'], 'Two'),
      ]),
      _Lesson('Number Two', 'Two (2) means a pair: two eyes, two hands and two ears.', [
        _Q('How many eyes do you have?', ['2', '1', '3', '6'], '2'),
        _Q('Which number is two?', ['2', '4', '6', '8'], '2'),
        _Q('I have two hands.', ['True', 'False'], 'True'),
        _Q('Two comes after …', ['One', 'Three', 'Five', 'Nine'], 'One'),
      ]),
      _Lesson('Number Three', 'Three (3).', const []),
      _Lesson('Number Four', 'Four (4).', const []),
    ]),
  ];

  static final List<_Subject> _grade4 = [
    _Subject('الرياضيات', [
      _Lesson('القيمة المنزلية', 'لكلّ رقمٍ في العدد قيمةٌ حسب منزلته: الآحاد، ثم العشرات، ثم المئات، ثم الآلاف. في العدد ٣٥٤٢ الرقمُ ٣ في منزلة الآلاف فقيمته ٣٠٠٠، والرقمُ ٥ في منزلة المئات فقيمته ٥٠٠، والرقمُ ٤ قيمته ٤٠، والرقمُ ٢ قيمته ٢. والصيغةُ التحليلية للعدد هي: ٣٠٠٠ + ٥٠٠ + ٤٠ + ٢.', [
        _Q('ما قيمةُ الرقم ٥ في العدد ٣٥٤٢؟', ['٥٠٠', '٥٠', '٥', '٥٠٠٠'], '٥٠٠'),
        _Q('ما منزلةُ الرقم ٣ في العدد ٣٥٤٢؟', ['الآلاف', 'المئات', 'العشرات', 'الآحاد'], 'الآلاف'),
        _Q('الصيغةُ التحليلية للعدد ٤٢٧ هي:', ['٤٠٠ + ٢٠ + ٧', '٤ + ٢ + ٧', '٤٠ + ٢٠ + ٧٠', '٤٠٠ + ٢٧٠'], '٤٠٠ + ٢٠ + ٧'),
        _Q('في العدد ٦٠٨١ قيمةُ الرقم صفر هي صفر.', ['صح', 'خطأ'], 'صح'),
      ]),
      _Lesson('مقارنة الأعداد وترتيبها', 'نقارن عددين بالبدء من المنزلة الكبرى: نقارن الآلاف أوّلاً، فإن تساوت قارنّا المئات، ثم العشرات، ثم الآحاد. نستعمل الرمز > (أكبر من) و< (أصغر من) و= (يساوي). مثال: ٤٢٥٠ > ٤٢٠٥ لأن عشرات العدد الأوّل أكبر.', [
        _Q('أيُّ رمزٍ يُكمل: ٤٢٥٠ … ٤٢٠٥؟', ['>', '<', '='], '>'),
        _Q('من أيّ منزلةٍ نبدأ المقارنة؟', ['الكبرى', 'الآحاد', 'العشرات', 'لا يهمّ'], 'الكبرى'),
        _Q('أيُّ الأعداد هو الأكبر؟', ['٧٨٩٠', '٧٨٠٩', '٧٠٩٨', '٧٩٨'], '٧٨٩٠'),
        _Q('٣٠٠٠ = ثلاثة آلاف.', ['صح', 'خطأ'], 'صح'),
      ]),
      _Lesson('تقريب الأعداد', 'نقرّب العدد إلى أقرب عشرة أو مئة.', const []),
      _Lesson('جمع الأعداد', 'نجمع الأعداد بدءاً من الآحاد.', const []),
    ]),
    _Subject('لغتي', [_Lesson('الأسماء والأفعال', 'درسٌ في لغتي.', const [])]),
    _Subject('العلوم', [_Lesson('النبات وأجزاؤه', 'درسٌ في العلوم.', const [])]),
    _Subject('English', [_Lesson('My Family', 'An English lesson.', const [])]),
  ];

  static List<_Subject> _subjects(String grade) => isKindergartenGrade(grade) ? _kg : _grade4;

  static String _gradeOf(StudentProfile profile) => profile.demoTrack == 'grade4' ? grade4 : kgGrade;

  static String _lessonId(String grade, int subject, int lesson) =>
      'demo-${isKindergartenGrade(grade) ? 'kg' : 'g4'}-$subject-$lesson';

  /// كلُّ دروس مسار الزائر: الفصلُ الأوّلُ والوحدةُ الأولى من كل مادة.
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
            term: term1,
            unit: unit1,
            lessonName: subjects[s].lessons[l].name,
            createdAt: '2026-01-0${l + 1}',
            ownerId: _owner,
            lessonText: subjects[s].lessons[l].text,
            videos: l < 2
                ? const [
                    LessonVideo(
                      id: 'demo-tour',
                      url: videoAsset,
                      sourceType: VideoSourceType.mp4,
                      title: 'جولة في منارة المعرفة',
                      description: 'فيديو تعريفيّ مدمج في التطبيق',
                    ),
                  ]
                : const [],
            games: const [],
          ),
    ];
  }

  /// شجرةُ المسار: الفصلان والوحدتان ظاهرةٌ كلُّها (الثانيةُ بقفلها).
  static AcademicSelectionData selection(StudentProfile profile) {
    final grade = _gradeOf(profile);
    final subjects = _subjects(grade);
    return AcademicSelectionData(
      paths: [
        for (final subject in subjects) ...[
          AcademicPath(grade: grade, subject: subject.name, term: term1, unit: unit1),
          AcademicPath(grade: grade, subject: subject.name, term: term1, unit: unit2),
          AcademicPath(grade: grade, subject: subject.name, term: term2, unit: unit1),
        ],
      ],
      lessons: lessons(profile),
    );
  }

  /// دروسُ ما اختاره الزائر — أو كلُّ دروسه إن لم يختر بعد.
  static List<LessonContent> lessonsFor(StudentProfile profile, AcademicContext? context) {
    // ‏المفتوحُ وحده (الدرسان الأوّلان): مبدّلُ الدروس داخل الشرح لا يصل المقفل.
    final all = lessons(profile).where(isOpen).toList();
    if (context == null) return all;
    final chosen = all.where((lesson) => lesson.id == context.lessonId).toList();
    final sameUnit = all
        .where((lesson) => lesson.subject == context.subject && lesson.id != context.lessonId)
        .toList();
    return [...chosen, ...sameUnit];
  }

  /// درسٌ مفتوحٌ للزائر: الأوّلُ أو الثاني في مادته.
  static bool isOpen(LessonContent lesson) => (int.tryParse(lesson.id.split('-').last) ?? 9) < 2;

  static _Lesson? _lessonById(String id) {
    for (final grade in const [kgGrade, grade4]) {
      final subjects = _subjects(grade);
      for (var s = 0; s < subjects.length; s++) {
        for (var l = 0; l < subjects[s].lessons.length; l++) {
          if (_lessonId(grade, s, l) == id) return subjects[s].lessons[l];
        }
      }
    }
    return null;
  }

  /// اختبارُ الدرس المختار في «مركز الاختبارات» (يقصّه [DemoMode] إلى سؤالين).
  static List<Map<String, dynamic>> quizzes(StudentProfile profile, AcademicContext? context) {
    final lessonId = context?.lessonId ?? '';
    final lesson = _lessonById(lessonId);
    if (lesson == null || lesson.questions.isEmpty) return const [];
    final questions = [
      for (var i = 0; i < lesson.questions.length; i++)
        {
          'id': '$lessonId-q$i',
          'question': lesson.questions[i].question,
          'options': lesson.questions[i].options,
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
    final lesson = _lessonById(lessonId);
    if (lesson == null || lesson.questions.isEmpty) return null;
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
                  'options': q.options,
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

  /// فيديو السينما: المدمجُ في التطبيق.
  static const cinema = [
    LessonVideo(
      id: 'demo-cinema',
      url: videoAsset,
      sourceType: VideoSourceType.mp4,
      title: 'مرحباً بك في منارة المعرفة',
      description: 'جولةٌ قصيرة في عالم منارة',
    ),
  ];
}

class _Subject {
  const _Subject(this.name, this.lessons);
  final String name;
  final List<_Lesson> lessons;
}

class _Lesson {
  const _Lesson(this.name, this.text, this.questions);
  final String name;
  final String text;
  final List<_Q> questions;
}

class _Q {
  const _Q(this.question, this.options, this.answer);
  final String question;
  final List<String> options;
  final String answer;
}
