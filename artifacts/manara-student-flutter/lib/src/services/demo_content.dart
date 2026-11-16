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
import 'tracing_scope.dart';

abstract final class DemoContent {
  static const kgGrade = kindergartenGrade;
  static const grade4 = 'الصف الرابع';

  static const term1 = 'الفصل الدراسي الأول';
  static const term2 = 'الفصل الدراسي الثاني';
  static const unit1 = 'الوحدة الأولى';
  static const unit2 = 'الوحدة الثانية';
  static const unit3 = 'الوحدة الثالثة';

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
    // ‏درسُ «حفظ وشرح السور القصيرة» يفتح بطاقةَ «أبطال التسميع» — الفاتحةُ وحدها للزائر.
    _Subject('القرآن الكريم', [
      _Lesson('حفظ وشرح السور القصيرة', 'نحفظ اليوم سورةَ الفاتحة، أمَّ الكتاب. نقرؤها في كل صلاة، وآياتُها سبع. نبدأ بالاستعاذة ثم البسملة: بسم الله الرحمن الرحيم. الحمدُ لله ربّ العالمين: نشكر الله على نِعَمه.', [
        _Q('كم آيةً في سورة الفاتحة؟', ['سبع', 'خمس', 'ثلاث', 'عشر'], 'سبع'),
        _Q('ماذا نقول قبل القراءة؟', ['أعوذ بالله من الشيطان الرجيم', 'صباح الخير', 'شكراً', 'مع السلامة'], 'أعوذ بالله من الشيطان الرجيم'),
        _Q('نقرأ الفاتحة في كل صلاة.', ['صح', 'خطأ'], 'صح'),
        _Q('«الحمد لله» معناها:', ['نشكر الله', 'نلعب', 'ننام', 'نأكل'], 'نشكر الله'),
      ]),
      _Lesson('آداب تلاوة القرآن', 'نتوضّأ قبل أن نمسك المصحف، ونجلس بهدوء، ونقرأ بصوتٍ جميلٍ واضح، ونستمع إذا قُرئ القرآن.', [
        _Q('ماذا نفعل قبل أن نمسك المصحف؟', ['نتوضّأ', 'نلعب', 'نركض', 'نأكل'], 'نتوضّأ'),
        _Q('كيف نجلس عند التلاوة؟', ['بهدوء', 'ونحن نقفز', 'ونحن نصرخ', 'ونحن نلعب'], 'بهدوء'),
        _Q('نستمع إذا قُرئ القرآن.', ['صح', 'خطأ'], 'صح'),
        _Q('نقرأ القرآن بصوتٍ …', ['جميلٍ واضح', 'عالٍ جداً', 'غاضب', 'سريعٍ جداً'], 'جميلٍ واضح'),
      ]),
      _Lesson('سورة الإخلاص', 'قل هو الله أحد.', const []),
      _Lesson('سورة الكوثر', 'إنا أعطيناك الكوثر.', const []),
    ]),
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
    // ‏«الثقافة العامة» تفتح «عالم الحكايات» — لعبةُ الألوان وحدها للزائر.
    _Subject('الثقافة العامة', [
      _Lesson('الألوان من حولنا', 'السماءُ زرقاء، والعشبُ أخضر، والشمسُ صفراء، والتفاحةُ حمراء. الألوانُ تجعل الدنيا جميلة!', [
        _Q('ما لونُ السماء؟', ['أزرق', 'أحمر', 'أسود', 'بنّي'], 'أزرق'),
        _Q('ما لونُ العشب؟', ['أخضر', 'أصفر', 'برتقالي', 'أبيض'], 'أخضر'),
        _Q('الشمسُ صفراء.', ['صح', 'خطأ'], 'صح'),
        _Q('ما لونُ التفاحة في الدرس؟', ['أحمر', 'أزرق', 'بنفسجي', 'رمادي'], 'أحمر'),
      ]),
      _Lesson('الحيوانات وأصواتها', 'القطةُ تقول مياو، والبقرةُ تقول موو، والكلبُ ينبح، والأسدُ يزأر في الغابة.', [
        _Q('ماذا تقول القطة؟', ['مياو', 'موو', 'زئير', 'صياح'], 'مياو'),
        _Q('أين يعيش الأسد؟', ['في الغابة', 'في البحر', 'في البيت', 'في السماء'], 'في الغابة'),
        _Q('البقرةُ تقول موو.', ['صح', 'خطأ'], 'صح'),
        _Q('من الذي ينبح؟', ['الكلب', 'السمكة', 'العصفور', 'الأرنب'], 'الكلب'),
      ]),
      _Lesson('فصول السنة', 'للسنة أربعةُ فصول.', const []),
      _Lesson('أفراد أسرتي', 'أبي وأمي وإخوتي.', const []),
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
    _Subject('لغتي', [_Lesson('الأسماء والأفعال', 'درسٌ في لغتي.', const []), _Lesson('الجملة الاسمية', 'درسٌ في لغتي.', const [])]),
    _Subject('العلوم', [_Lesson('النبات وأجزاؤه', 'درسٌ في العلوم.', const []), _Lesson('دورة حياة النبات', 'درسٌ في العلوم.', const [])]),
    _Subject('اللغة الإنجليزية', [_Lesson('My Family', 'An English lesson.', const []), _Lesson('My School', 'An English lesson.', const [])]),
    _Subject('الدراسات الإسلامية', [_Lesson('أركان الإسلام', 'درسٌ في الدراسات الإسلامية.', const []), _Lesson('الوضوء', 'درسٌ في الدراسات الإسلامية.', const [])]),
    _Subject('الدراسات الاجتماعية', [_Lesson('وطني المملكة', 'درسٌ في الدراسات الاجتماعية.', const []), _Lesson('خريطة بلادي', 'درسٌ في الدراسات الاجتماعية.', const [])]),
    _Subject('المهارات الرقمية', [_Lesson('أجزاء الحاسب', 'درسٌ في المهارات الرقمية.', const []), _Lesson('الرسم بالحاسب', 'درسٌ في المهارات الرقمية.', const [])]),
    _Subject('التربية الفنية', [_Lesson('الألوان الأساسية', 'درسٌ في التربية الفنية.', const []), _Lesson('التشكيل بالصلصال', 'درسٌ في التربية الفنية.', const [])]),
  ];

  /// بقيّةُ دروس كلّ مادة بعد المكتوبة أعلاه، بالترتيب: تتوزّع على الوحدات ([_placeOf]).
  static const _more = <String, List<String>>{
    'القرآن الكريم': ['سورة الفلق', 'سورة الناس', 'سورة العصر', 'سورة النصر', 'سورة الفيل', 'سورة قريش'],
    'الحروف العربية': ['حرف الجيم', 'حرف الحاء', 'حرف الخاء', 'حرف الدال', 'حرف الذال', 'حرف الراء'],
    'الحروف الإنجليزية': ['Letter E', 'Letter F', 'Letter G', 'Letter H', 'Letter I', 'Letter J'],
    'الأرقام العربية': ['العدد خمسة', 'العدد ستة', 'العدد سبعة', 'العدد ثمانية', 'العدد تسعة', 'العدد عشرة'],
    'الأرقام الإنجليزية': ['Number Five', 'Number Six', 'Number Seven', 'Number Eight', 'Number Nine', 'Number Ten'],
    'الثقافة العامة': ['الفواكه والخضروات', 'وسائل المواصلات', 'المهن من حولنا', 'جسمي وحواسي', 'النظافة الشخصية', 'السلامة في الطريق'],
    'الرياضيات': ['طرح الأعداد', 'تقدير ناتج الجمع والطرح', 'الجمع والطرح ذهنياً', 'الضرب في عدد من رقم واحد', 'القسمة على عدد من رقم واحد', 'الكسور الاعتيادية'],
    'لغتي': ['الجملة الفعلية', 'همزة الوصل والقطع', 'الضمائر', 'أسماء الإشارة', 'كتابة فقرة', 'الاسم الموصول', 'التاء المربوطة والمفتوحة', 'كتابة قصة قصيرة'],
    'العلوم': ['تصنيف الحيوانات', 'السلاسل الغذائية', 'الماء في الطبيعة', 'حالات المادة', 'الطقس', 'الضوء والظل', 'الصوت', 'المغناطيس'],
    'اللغة الإنجليزية': ['My Body', 'Colours and Shapes', 'Food I Like', 'Animals', 'My House', 'Days of the Week', 'Weather', 'Sports'],
    'الدراسات الإسلامية': ['الصلاة', 'آداب الطعام', 'سورة الضحى', 'بر الوالدين', 'الصدق', 'الصيام', 'صلة الرحم', 'آداب المسجد'],
    'الدراسات الاجتماعية': ['رموز وطني', 'مناطق المملكة', 'التضاريس', 'المناخ', 'الموارد الطبيعية', 'المواطنة', 'الحقوق والواجبات', 'يوم التأسيس'],
    'المهارات الرقمية': ['لوحة المفاتيح', 'الفأرة', 'حفظ الملفات', 'المجلدات', 'الإنترنت الآمن', 'البرمجة بالرسوم', 'تصميم بطاقة', 'العرض التقديمي'],
    'التربية الفنية': ['الرسم بالخطوط', 'الألوان الثانوية', 'الطباعة بالأوراق', 'الزخرفة الإسلامية', 'الكولاج', 'النسيج الورقي', 'الخزف', 'المجسمات'],
  };

  static List<_Subject> _complete(List<_Subject> subjects) => [
        for (final s in subjects)
          _Subject(s.name, [
            ...s.lessons,
            for (final name in _more[s.name] ?? const <String>[]) _Lesson(name, '', const []),
          ]),
      ];

  static final _kgAll = _complete(_kg);
  static final _grade4All = _complete(_grade4);

  static List<_Subject> _subjects(String grade) => isKindergartenGrade(grade) ? _kgAll : _grade4All;

  /// موضعُ الدرس [l] من مادته: أربعةٌ في الوحدة الأولى من الفصل الأوّل، ثم
  /// ثلاثةٌ في الثانية، ثم ثلاثةٌ في الوحدة الأولى من الفصل الثاني.
  static (String term, String unit) _placeOf(int l) => l < 4
      ? (term1, unit1)
      : l < 7
          ? (term1, unit2)
          : (term2, unit1);

  static const _paths = [(term1, unit1), (term1, unit2), (term2, unit1)];

  /// شرحُ الدرس: المكتوبُ له، أو تمهيدٌ باسمه ومادّته.
  static String _textOf(String subject, _Lesson lesson) => lesson.text.isNotEmpty
      ? lesson.text
      : 'نتعلّم في هذا الدرس «${lesson.name}» من مادة $subject. نشاهد المقطع، ثم نجيب عن الأسئلة، ونلعب لعبةَ الدرس لنتأكّد أننا فهمنا.';

  /// أسئلةُ الدرس: المكتوبةُ له، وإلا أربعةٌ من موضعه في المنهج — ليعمل
  /// الاختبارُ واللعبةُ في كلّ درسٍ يختاره الزائر.
  static List<_Q> _questionsOf(List<_Subject> subjects, int s, int l) {
    final lesson = subjects[s].lessons[l];
    if (lesson.questions.isNotEmpty) return lesson.questions;
    final subject = subjects[s].name;
    final siblings = subjects[s].lessons.map((x) => x.name).where((n) => n != lesson.name).toList();
    final others = subjects.map((x) => x.name).where((n) => n != subject).toList();
    final (term, unit) = _placeOf(l);
    List<String> pick(String answer, List<String> pool) =>
        [answer, for (var i = 0; i < 3 && i < pool.length; i++) pool[(l + i * 2) % pool.length]];
    List<String> rotate(List<String> options) {
      final k = l % options.length;
      return [...options.sublist(k), ...options.sublist(0, k)];
    }

    return [
      _Q('ما اسمُ الدرس الذي تذاكره الآن؟', rotate(pick(lesson.name, siblings)), lesson.name),
      _Q('درسُ «${lesson.name}» من مادة:', rotate(pick(subject, others)), subject),
      _Q('درسُ «${lesson.name}» في $term1.', const ['صح', 'خطأ'], term == term1 ? 'صح' : 'خطأ'),
      _Q('في أيّ وحدةٍ درسُ «${lesson.name}»؟', rotate([unit, if (unit != unit1) unit1, if (unit != unit2) unit2, unit3]), unit),
    ];
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
            lessonText: _textOf(subjects[s].name, subjects[s].lessons[l]),
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

  /// الدرسُ وأسئلتُه من معرّفه.
  static ({_Lesson lesson, List<_Q> questions})? _lessonById(String id) {
    for (final grade in const [kgGrade, grade4]) {
      final subjects = _subjects(grade);
      for (var s = 0; s < subjects.length; s++) {
        for (var l = 0; l < subjects[s].lessons.length; l++) {
          if (_lessonId(grade, s, l) == id) {
            return (lesson: subjects[s].lessons[l], questions: _questionsOf(subjects, s, l));
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
      for (var i = 0; i < found.questions.length; i++)
        {
          'id': '$lessonId-q$i',
          'question': found.questions[i].question,
          'options': found.questions[i].options,
          'correctAnswer': found.questions[i].answer,
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
              for (final q in found.questions)
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
