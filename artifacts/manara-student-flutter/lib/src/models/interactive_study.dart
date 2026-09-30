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
  const StudyBranch({required this.title, required this.summary});

  final String title;
  final String summary;

  static StudyBranch? fromMap(Object? raw) {
    if (raw is! Map) return null;
    final title = _text(raw['title']);
    final summary = _text(raw['summary']);
    if (title.isEmpty || summary.isEmpty) return null;
    return StudyBranch(title: title, summary: summary);
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

class StudySituation {
  const StudySituation({
    required this.prompt,
    required this.options,
    required this.answer,
    required this.because,
  });

  final String prompt;
  final List<String> options;

  /// موضعُ الصحيح في [options].
  final int answer;
  final String because;

  bool isCorrect(int choice) => choice == answer;

  static StudySituation? fromMap(Object? raw) {
    if (raw is! Map) return null;
    final prompt = _text(raw['prompt']);
    final options = _list(raw['options'])
        .map(_text)
        .where((option) => option.isNotEmpty)
        .toList(growable: false);
    final answer = raw['answer'];
    if (prompt.isEmpty || options.length < 2) return null;
    // والموضعُ داخل القائمة شرط: خارجَها يعني موقفاً لا جوابَ له، فيُسقط
    // كلَّ الحزمة بدل أن يُعرض على الطفل سؤالٌ لا يُصاب.
    if (answer is! int || answer < 0 || answer >= options.length) return null;
    return StudySituation(
      prompt: prompt,
      options: options,
      answer: answer,
      because: _text(raw['because']),
    );
  }
}

class StudyScenario {
  const StudyScenario({required this.title, required this.situations});

  final String title;
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
    return StudyScenario(title: title, situations: situations);
  }
}

class StudyPack {
  const StudyPack({required this.mindMap, required this.scenarios});

  final StudyMindMap mindMap;
  final List<StudyScenario> scenarios;

  /// مجموعُ المواقف في الحزمة كلِّها — وهو سقفُ ما يُكافأ عليه.
  int get totalSituations =>
      scenarios.fold(0, (total, scenario) => total + scenario.situations.length);

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
