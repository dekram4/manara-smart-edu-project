/// ألعابُ «بطاقة المذاكرة» التفاعلية كما يولّدها الخادم من نصّ الدرس.
///
/// الصيغةُ من `/api/ai/study-games` (انظر `lib/studyGames.ts` في الخادم):
///   { id, game_type, title, instructions,
///     items: { drag_items, drop_targets, correct_pairs, questions? },
///     gems_reward, points_reward }
///
/// والمكافأةُ هنا للعرض وحده: الخادمُ يصرفها من سجلّ الدرس لا ممّا يرسله
/// التطبيق.
enum StudyGameType {
  dragDrop('drag_drop'),
  matching('matching'),
  endlessQuiz('endless_quiz');

  const StudyGameType(this.wire);

  final String wire;

  static StudyGameType? parse(Object? value) {
    for (final type in values) {
      if (type.wire == value) return type;
    }
    return null;
  }
}

class StudyGamePair {
  const StudyGamePair({required this.item, required this.target});

  final String item;
  final String target;
}

/// أشكالُ أسئلة السباق: تتبدّل فلا يملّ الطفل.
enum StudyQuestionKind {
  mcq,
  trueFalse,
  fillBlank;

  static StudyQuestionKind parse(Object? value) => switch (value) {
        'true_false' => trueFalse,
        'fill_blank' => fillBlank,
        _ => mcq,
      };
}

class StudyQuickQuestion {
  const StudyQuickQuestion({
    this.kind = StudyQuestionKind.mcq,
    required this.question,
    required this.options,
    required this.answer,
  });

  final StudyQuestionKind kind;
  final String question;
  final List<String> options;
  final String answer;
}

class StudyGame {
  const StudyGame({
    required this.id,
    required this.type,
    required this.title,
    required this.instructions,
    required this.dragItems,
    required this.dropTargets,
    required this.pairs,
    required this.questions,
    required this.gemsReward,
    required this.pointsReward,
  });

  final String id;
  final StudyGameType type;
  final String title;
  final String instructions;
  final List<String> dragItems;
  final List<String> dropTargets;
  final List<StudyGamePair> pairs;
  final List<StudyQuickQuestion> questions;
  final int gemsReward;
  final int pointsReward;

  /// السلّةُ أو المعنى الصحيح لهذه البطاقة.
  String? targetOf(String item) {
    for (final pair in pairs) {
      if (pair.item == item) return pair.target;
    }
    return null;
  }

  /// لعبةٌ لا تُلعب (عناصرُ ناقصة) تُرجع `null` فلا تظهر للطفل.
  static StudyGame? fromMap(Object? raw) {
    if (raw is! Map) return null;
    final type = StudyGameType.parse(raw['game_type']);
    if (type == null) return null;
    final items = raw['items'] is Map ? raw['items'] as Map : const {};
    final pairs = <StudyGamePair>[
      for (final entry in _list(items['correct_pairs']))
        if (entry is Map &&
            _text(entry['item']).isNotEmpty &&
            _text(entry['target']).isNotEmpty)
          StudyGamePair(
            item: _text(entry['item']),
            target: _text(entry['target']),
          ),
    ];
    final questions = <StudyQuickQuestion>[
      for (final entry in _list(items['questions']))
        if (entry is Map)
          StudyQuickQuestion(
            kind: StudyQuestionKind.parse(entry['kind']),
            question: _text(entry['question']),
            options: [
              for (final option in _list(entry['options']))
                if (_text(option).isNotEmpty) _text(option),
            ],
            answer: _text(entry['answer']),
          ),
    ].where((q) => q.question.isNotEmpty && q.options.contains(q.answer)).toList();

    final game = StudyGame(
      id: _text(raw['id']).isEmpty ? type.wire : _text(raw['id']),
      type: type,
      title: _text(raw['title']),
      instructions: _text(raw['instructions']),
      dragItems: [
        for (final item in _list(items['drag_items']))
          if (_text(item).isNotEmpty) _text(item),
      ],
      dropTargets: [
        for (final item in _list(items['drop_targets']))
          if (_text(item).isNotEmpty) _text(item),
      ],
      pairs: pairs,
      questions: questions,
      gemsReward: _int(raw['gems_reward']),
      pointsReward: _int(raw['points_reward']),
    );
    final playable = switch (type) {
      StudyGameType.endlessQuiz => questions.isNotEmpty,
      _ => pairs.isNotEmpty && game.dropTargets.isNotEmpty,
    };
    return playable ? game : null;
  }
}

class StudyGamesPack {
  const StudyGamesPack({required this.lessonId, required this.games});

  final String lessonId;
  final List<StudyGame> games;

  static StudyGamesPack? fromMap(Object? raw) {
    if (raw is! Map) return null;
    final games = [
      for (final entry in _list(raw['games']))
        if (StudyGame.fromMap(entry) case final game?) game,
    ];
    if (games.isEmpty) return null;
    return StudyGamesPack(lessonId: _text(raw['lessonId']), games: games);
  }
}

List<Object?> _list(Object? value) => value is List ? value : const [];
String _text(Object? value) => value is String ? value.trim() : '';
int _int(Object? value) =>
    value is num ? value.round() : int.tryParse('${value ?? ''}') ?? 0;
