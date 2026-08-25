import 'academic_context.dart';
import 'student_profile.dart';

enum StudentQuizType { periodic, teacher }

/// Shared assessment rules for the Flutter student experience.
///
/// Records in Supabase originate from both the current quiz manager and the
/// legacy question bank, so the rules deliberately operate on JSON maps. This
/// keeps old content usable without weakening the student ownership boundary.
class StudentAssessmentRules {
  const StudentAssessmentRules._();

  static StudentQuizType quizType(Object? value) {
    final normalized = _normalize(value);
    return normalized == 'teacher' ||
            normalized.contains('teacher') ||
            normalized.contains('معلم')
        ? StudentQuizType.teacher
        : StudentQuizType.periodic;
  }

  static bool isTeacherQuiz(Map<String, dynamic> quiz) =>
      quizType(quiz['quizType']) == StudentQuizType.teacher;

  static String quizTypeValue(Object? value) =>
      quizType(value) == StudentQuizType.teacher ? 'teacher' : 'periodic';

  static String quizTypeLabel(Map<String, dynamic> quiz) {
    if (isTeacherQuiz(quiz)) return 'اختبار المعلم';

    final number = int.tryParse(_text(quiz['periodicNumber']));
    const ordinals = [
      'الأول',
      'الثاني',
      'الثالث',
      'الرابع',
      'الخامس',
      'السادس',
      'السابع',
      'الثامن',
      'التاسع',
      'العاشر',
    ];
    if (number == null || number < 1) return 'الاختبار الدوري';
    return 'الاختبار الدوري ${number <= ordinals.length ? ordinals[number - 1] : number}';
  }

  static String ownerId(Map<String, dynamic> record) => _normalize(
        record['teacher_id'] ?? record['teacherId'] ?? record['createdBy'],
      );

  static bool matchesAcademicScope(
    Map<String, dynamic> record,
    StudentProfile profile, {
    AcademicContext? academicContext,
  }) {
    final selected = <String, String?>{
      'grade': academicContext?.grade ?? profile.grade,
      'atram': academicContext?.atram ?? profile.atram,
      'subject': academicContext?.subject ?? profile.subject,
      'term': academicContext?.term ?? profile.term,
      'unit': academicContext?.unit ?? profile.unit,
    };
    return selected.entries.every((entry) {
      final expected = _normalize(entry.value);
      final actual = _normalize(record[entry.key]);
      return expected.isEmpty || actual.isEmpty || actual == expected;
    });
  }

  /// Prefers the assigned teacher's records for each quiz type. Only when the
  /// teacher has no scoped record of that type do supervisor/admin records act
  /// as the public fallback. Another teacher's material is never a fallback.
  static List<Map<String, dynamic>> selectAvailableQuizzes({
    required Iterable<Map<String, dynamic>> createdQuizzes,
    required Iterable<Map<String, dynamic>> legacyQuestions,
    required StudentProfile profile,
    AcademicContext? academicContext,
    Iterable<String> deletedQuizIds = const [],
  }) {
    final deletedIds = deletedQuizIds
        .map(_text)
        .where((id) => id.isNotEmpty)
        .toSet();
    final created = createdQuizzes
        .map(normalizeQuiz)
        .where(
          (quiz) =>
              !deletedIds.contains(_text(quiz['id'])) &&
              _isVisibleAndInScope(quiz, profile, academicContext),
        )
        .toList();
    final legacy = _legacyQuizRecords(legacyQuestions)
        .where(
          (quiz) =>
              !deletedIds.contains(_text(quiz['id'])) &&
              _isVisibleAndInScope(quiz, profile, academicContext),
        )
        .toList();

    final quizById = <String, Map<String, dynamic>>{
      for (final quiz in created)
        if (_text(quiz['id']).isNotEmpty) _text(quiz['id']): quiz,
    };
    for (final legacyQuiz in legacy) {
      final id = _text(legacyQuiz['id']);
      final existing = quizById[id];
      if (existing == null) {
        quizById[id] = legacyQuiz;
      } else if (_questions(existing).isEmpty) {
        quizById[id] = {...existing, 'questions': legacyQuiz['questions']};
      }
    }

    final teacher = _normalize(profile.teacherId);
    final selected = <Map<String, dynamic>>[];
    for (final type in StudentQuizType.values) {
      final candidates = quizById.values
          .where((quiz) => quizType(quiz['quizType']) == type)
          .toList();
      final teacherOwned = teacher.isEmpty
          ? const <Map<String, dynamic>>[]
          : candidates.where((quiz) => ownerId(quiz) == teacher).toList();
      final pool = teacherOwned.isNotEmpty
          ? teacherOwned
          : candidates.where(_isSupervisorQuiz).toList();
      selected.addAll(pool);
    }

    selected.sort((left, right) {
      final typeOrder = quizType(left['quizType'])
          .index
          .compareTo(quizType(right['quizType']).index);
      if (typeOrder != 0) return typeOrder;
      final periodic = _number(left['periodicNumber'], fallback: 999)
          .compareTo(_number(right['periodicNumber'], fallback: 999));
      if (periodic != 0) return periodic;
      return _text(left['title']).compareTo(_text(right['title']));
    });
    return selected;
  }

  static Map<String, dynamic> normalizeQuiz(Map<String, dynamic> quiz) {
    final questions = _questions(quiz)
        .map((question) => <String, dynamic>{
              ...question,
              'quizId': _text(question['quizId']).isEmpty
                  ? _text(quiz['id'])
                  : _text(question['quizId']),
              'quizType': quizTypeValue(question['quizType'] ?? quiz['quizType']),
            })
        .toList();
    final requested = _number(
      quiz['questionsPerAttempt'] ?? quiz['questionCount'],
      fallback: questions.length,
    );
    return <String, dynamic>{
      ...quiz,
      'quizType': quizTypeValue(quiz['quizType']),
      'questions': questions,
      'questionsPerAttempt': requested <= 0 ? questions.length : requested,
      'questionCount': _number(quiz['questionCount'], fallback: questions.length),
      'isActive': quiz['isActive'] != false,
      'deleted': quiz['deleted'] == true,
    };
  }

  static List<Map<String, dynamic>> questionsForStudent(
    Map<String, dynamic> quiz, {
    required String studentId,
  }) {
    final questions = _questions(normalizeQuiz(quiz))
        .where(
          (question) =>
              _text(question['question']).isNotEmpty &&
              _asList(question['options']).where((option) => _text(option).isNotEmpty).length >= 2,
        )
        .toList();
    final requested = _number(
      quiz['questionsPerAttempt'] ?? quiz['questionCount'],
      fallback: questions.length,
    ).clamp(0, questions.length).toInt();
    final quizId = _text(quiz['id']);
    questions.sort((left, right) {
      final leftId = questionId(left, 0);
      final rightId = questionId(right, 0);
      final comparison = _stableHash('$studentId:$quizId:$leftId')
          .compareTo(_stableHash('$studentId:$quizId:$rightId'));
      return comparison != 0 ? comparison : leftId.compareTo(rightId);
    });
    return questions.take(requested).toList();
  }

  static bool isAnswerCorrect(Map<String, dynamic> question, Object? answer) {
    final options = _asList(question['options']).map(_text).toList();
    final selectedIndex = _answerIndex(answer, options.length);
    final correctIndex = _answerIndex(question['correctAnswer'], options.length);
    if (selectedIndex != null && correctIndex != null) {
      return selectedIndex == correctIndex;
    }
    return _normalize(answer) == _normalize(correctAnswerText(question));
  }

  static String correctAnswerText(Map<String, dynamic> question) {
    final options = _asList(question['options']).map(_text).toList();
    final rawAnswer = _text(question['correctAnswer']);
    final index = _answerIndex(rawAnswer, options.length);
    if (index != null) return options[index];
    return options.firstWhere(
      (option) => _normalize(option) == _normalize(rawAnswer),
      orElse: () => rawAnswer,
    );
  }

  static bool hasTeacherQuizResult(
    Iterable<Map<String, dynamic>> results,
    String quizId,
  ) =>
      results.any(
        (result) =>
            _text(result['quizId']) == quizId &&
            quizType(result['quizType']) == StudentQuizType.teacher,
      );

  static String questionId(Map<String, dynamic> question, int index) {
    final id = _text(question['id']);
    return id.isEmpty ? '${_text(question['question'])}-$index' : '$id-$index';
  }

  static bool _isVisibleAndInScope(
    Map<String, dynamic> quiz,
    StudentProfile profile,
    AcademicContext? academicContext,
  ) =>
      quiz['deleted'] != true &&
      quiz['isActive'] != false &&
      matchesAcademicScope(quiz, profile, academicContext: academicContext);

  static bool _isSupervisorQuiz(Map<String, dynamic> quiz) {
    final owner = ownerId(quiz);
    return owner == 'admin' || owner == 'supervisor';
  }

  static List<Map<String, dynamic>> _legacyQuizRecords(
    Iterable<Map<String, dynamic>> questions,
  ) {
    final grouped = <String, List<Map<String, dynamic>>>{};
    for (final rawQuestion in questions) {
      final question = Map<String, dynamic>.from(rawQuestion);
      if (question['deleted'] == true || question['isActive'] == false) continue;
      final owner = ownerId(question);
      final type = quizTypeValue(question['quizType']);
      final scope = ['grade', 'atram', 'subject', 'term', 'unit']
          .map((field) => _normalize(question[field]))
          .join('|');
      final id = _text(question['quizId']).isNotEmpty
          ? _text(question['quizId'])
          : 'legacy:$owner:$type:$scope';
      grouped.putIfAbsent(id, () => []).add(question);
    }

    return grouped.entries.map((entry) {
      final first = entry.value.first;
      final requested = _number(
        first['questionsPerAttempt'] ?? first['questionCount'],
        fallback: entry.value.length,
      );
      return normalizeQuiz(<String, dynamic>{
        'id': entry.key,
        'title': _text(first['quizTitle']).isEmpty
            ? (quizType(first['quizType']) == StudentQuizType.teacher
                ? 'اختبار المعلم'
                : 'الاختبار الدوري')
            : _text(first['quizTitle']),
        'quizType': first['quizType'],
        'periodicNumber': first['periodicNumber'],
        'questionCount': entry.value.length,
        'questionsPerAttempt': requested,
        'isActive': true,
        'createdBy': first['createdBy'],
        'teacherId': first['teacherId'],
        'teacher_id': first['teacher_id'],
        'grade': first['grade'],
        'atram': first['atram'],
        'subject': first['subject'],
        'term': first['term'],
        'unit': first['unit'],
        'questions': entry.value,
        'isLegacy': true,
      });
    }).toList();
  }

  static List<Map<String, dynamic>> _questions(Map<String, dynamic> quiz) =>
      _asList(quiz['questions']).whereType<Map>().map(_toStringMap).toList();

  static Map<String, dynamic> _toStringMap(Map value) =>
      value.map((key, item) => MapEntry(key.toString(), item));

  static List<dynamic> _asList(Object? value) => value is List ? value : const [];

  static int _stableHash(String value) {
    var hash = 2166136261;
    for (final unit in value.codeUnits) {
      hash ^= unit;
      hash = (hash * 16777619) & 0xffffffff;
    }
    return hash;
  }

  static int? _answerIndex(Object? value, int optionCount) {
    final raw = _text(value);
    final normalized = _normalize(raw);
    const latin = ['a', 'b', 'c', 'd'];
    const arabic = ['أ', 'ب', 'ج', 'د'];
    var index = latin.indexOf(normalized);
    if (index < 0) index = arabic.indexOf(raw);
    if (index < 0) {
      final numeric = int.tryParse(normalized);
      if (numeric != null) {
        if (numeric >= 1 && numeric <= optionCount) {
          index = numeric - 1;
        } else if (numeric >= 0 && numeric < optionCount) {
          index = numeric;
        }
      }
    }
    return index >= 0 && index < optionCount ? index : null;
  }

  static int _number(Object? value, {required int fallback}) =>
      int.tryParse(_text(value)) ?? fallback;

  static String _text(Object? value) => value?.toString().trim() ?? '';

  static String _normalize(Object? value) =>
      _text(value).toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
}