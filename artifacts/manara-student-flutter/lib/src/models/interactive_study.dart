/// حزمةُ المذاكرة الذكية كما يقرؤها التطبيق.
///
/// ── لماذا تُقرأ بحرصٍ هنا أيضاً وقد تحقّق منها الخادم ──
/// الخادم يردّ ما لا يصلح، وهذا صحيح. لكنّ الحزمةَ قد تكون مخزَّنةً من
/// نسخةٍ أقدم من الخادم، أو يصل الردُّ منقوصاً على شبكةٍ ضعيفة. وشاشةٌ
/// تنهار على حقلٍ غائب أسوأ من شاشةٍ تقول «تعذّر التحضير».
///
/// فكلُّ قراءةٍ هنا تعود بـ`null` عند العطب، ولا ترفع خطأً.
library;

class StudyBranch {
  const StudyBranch({
    required this.title,
    required this.summary,
    this.icon = '',
  });

  final String title;
  final String summary;

  /// رمزٌ تعبيريٌّ يرسله النموذج، أو فارغٌ — فتُرسم نقطةٌ مكانه.
  final String icon;

  static StudyBranch? fromMap(Object? raw) {
    if (raw is! Map) return null;
    final title = _text(raw['title']);
    final summary = _text(raw['summary']);
    if (title.isEmpty || summary.isEmpty) return null;
    return StudyBranch(title: title, summary: summary, icon: _text(raw['icon']));
  }
}

class StudyMindMap {
  const StudyMindMap({required this.title, required this.branches});

  final String title;
  final List<StudyBranch> branches;

  static StudyMindMap? fromMap(Object? raw) {
    if (raw is! Map) return null;
    final branches = <StudyBranch>[];
    for (final entry in _list(raw['branches'])) {
      final branch = StudyBranch.fromMap(entry);
      if (branch != null) branches.add(branch);
    }
    final title = _text(raw['title']);
    if (title.isEmpty || branches.length < 2) return null;
    return StudyMindMap(title: title, branches: branches);
  }
}

/// نمطُ التحدي: يُغيّر شكلَ الموقف لا حسابه.
///
/// والمجهولُ يُردّ إلى [avatarPath]: حزمةٌ محفوزةٌ من نسخةٍ أقدم لا
/// تحمل نمطاً، وشاشةٌ لا ترسم شيئاً أسوأ من شاشةٍ ترسم بوّابتين.
enum StudyChallengeType {
  avatarPath,
  swipeFact,
  spotImposter;

  static StudyChallengeType fromName(Object? raw) {
    switch (raw is String ? raw.trim().toLowerCase() : '') {
      case 'swipe_fact':
        return StudyChallengeType.swipeFact;
      case 'spot_imposter':
        return StudyChallengeType.spotImposter;
      default:
        return StudyChallengeType.avatarPath;
    }
  }
}

class StudySituation {
  const StudySituation({
    required this.type,
    required this.prompt,
    required this.options,
    required this.answer,
    required this.because,
  });

  final StudyChallengeType type;

  /// الموقفُ كما يُحكى، أو نصُّ الحقيقة في نمط السحب.
  final String prompt;

  /// خياراتُ الموقف: بوّابتان، أو ثلاثُ فقاعات، أو فارغةٌ في السحب.
  final List<String> options;

  /// موضعُ الصحيح في [options].
  final int answer;
  final String because;

  bool isCorrect(int choice) => choice == answer;

  static StudySituation? fromMap(Object? raw) {
    if (raw is! Map) return null;
    final type = StudyChallengeType.fromName(raw['type']);
    final prompt = _text(raw['prompt']);
    final options = _list(raw['options'])
        .map(_text)
        .where((option) => option.isNotEmpty)
        .toList(growable: false);
    final answer = raw['answer'];
    if (prompt.isEmpty) return null;
    if (answer is! int || answer < 0) return null;

    // ── وعددُ الخيارات يتبع النمط ──
    // السحبُ لا خيارَ له والجوابُ صفرٌ أو واحد، والمسارُ بوّابتان،
    // والرادارُ ثلاث. وعددٌ لا يوافق نمطَه لا تعرف الشاشةُ كيف ترسمه،
    // فيُسقط الموقفُ ومعه مغامرتُه بدل أن يُعرض نصفُ مشهد.
    switch (type) {
      case StudyChallengeType.swipeFact:
        if (answer > 1) return null;
      case StudyChallengeType.avatarPath:
        if (options.length != 2 || answer >= options.length) return null;
      case StudyChallengeType.spotImposter:
        if (options.length != 3 || answer >= options.length) return null;
    }

    return StudySituation(
      type: type,
      prompt: prompt,
      options: options,
      answer: answer,
      because: _text(raw['because']),
    );
  }
}

class StudyScenario {
  const StudyScenario({
    required this.title,
    required this.situations,
    this.branch = '',
  });

  final String title;

  /// عنوانُ فرع الخريطة الذي يقيسه هذا التحدي، أو فارغٌ إن كان عامّاً.
  final String branch;

  final List<StudySituation> situations;

  static StudyScenario? fromMap(Object? raw) {
    if (raw is! Map) return null;
    final situations = <StudySituation>[];
    for (final entry in _list(raw['situations'])) {
      final situation = StudySituation.fromMap(entry);
      if (situation == null) return null;
      situations.add(situation);
    }
    final title = _text(raw['title']);
    if (title.isEmpty || situations.isEmpty) return null;
    return StudyScenario(
      title: title,
      branch: _text(raw['branch']),
      situations: situations,
    );
  }
}

class StudyPack {
  const StudyPack({required this.mindMap, required this.scenarios});

  final StudyMindMap mindMap;
  final List<StudyScenario> scenarios;

  /// مجموعُ المواقف في الحزمة كلِّها — وهو سقفُ ما يُكافأ عليه.
  int get totalSituations =>
      scenarios.fold(0, (total, scenario) => total + scenario.situations.length);

  /// تحدياتُ فرعٍ بعينه، أو الحزمةُ كلُّها إن لم يكن له تحدٍّ خاصّ.
  ///
  /// ── لماذا الارتداد إلى الكلّ ──
  /// الطفل يضغط الفرعَ فينتظر تحدياً. وحزمةٌ قديمةٌ لا تحمل أسماءَ الفروع،
  /// أو نموذجٌ سمّى فرعاً بغير ما في الخريطة — وكلاهما يعني قائمةً فارغة.
  /// وزرٌّ لا يفعل شيئاً أسوأ من تحدٍّ عامّ.
  List<StudyScenario> forBranch(String branch) {
    final title = branch.trim();
    if (title.isEmpty) return scenarios;
    final matching = scenarios
        .where((scenario) => scenario.branch.trim() == title)
        .toList(growable: false);
    return matching.isEmpty ? scenarios : matching;
  }

  static StudyPack? fromMap(Object? raw) {
    if (raw is! Map) return null;
    final mindMap = StudyMindMap.fromMap(raw['mindMap']);
    if (mindMap == null) return null;
    final scenarios = <StudyScenario>[];
    for (final entry in _list(raw['scenarios'])) {
      final scenario = StudyScenario.fromMap(entry);
      if (scenario != null) scenarios.add(scenario);
    }
    if (scenarios.isEmpty) return null;
    return StudyPack(mindMap: mindMap, scenarios: scenarios);
  }
}

String _text(Object? value) => value is String ? value.trim() : '';

List<Object?> _list(Object? value) => value is List ? value : const [];
