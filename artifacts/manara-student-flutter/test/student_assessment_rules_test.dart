import 'package:flutter_test/flutter_test.dart';
import 'package:manara_student/src/models/student_assessment.dart';
import 'package:manara_student/src/models/student_profile.dart';

void main() {
  const student = StudentProfile(
    id: 'student-1',
    username: 'student',
    name: 'طالب منارة',
    role: 'student',
    teacherId: 'teacher-1',
    grade: 'السادس',
    atram: 'الفصل الأول',
    subject: 'الرياضيات',
    term: 'الترم الأول',
    unit: 'الوحدة الأولى',
  );

  Map<String, dynamic> quiz({
    required String id,
    required String owner,
    String type = 'periodic',
    String grade = 'السادس',
    int questionsPerAttempt = 2,
  }) =>
      {
        'id': id,
        'title': id,
        'createdBy': owner,
        'quizType': type,
        'grade': grade,
        'atram': 'الفصل الأول',
        'subject': 'الرياضيات',
        'term': 'الترم الأول',
        'unit': 'الوحدة الأولى',
        'isActive': true,
        'questionsPerAttempt': questionsPerAttempt,
        'questions': [
          {
            'id': '$id-q1',
            'question': 'سؤال ١',
            'options': ['أ', 'ب', 'ج'],
            'correctAnswer': 'A',
          },
          {
            'id': '$id-q2',
            'question': 'سؤال ٢',
            'options': ['١', '٢', '٣'],
            'correctAnswer': '2',
          },
          {
            'id': '$id-q3',
            'question': 'سؤال ٣',
            'options': ['س', 'ص', 'ع'],
            'correctAnswer': 'ص',
          },
        ],
      };

  group('StudentAssessmentRules.selectAvailableQuizzes', () {
    test('prefers the assigned teacher and never exposes another teacher', () {
      final results = StudentAssessmentRules.selectAvailableQuizzes(
        createdQuizzes: [
          quiz(id: 'teacher-periodic', owner: 'teacher-1'),
          quiz(id: 'admin-periodic', owner: 'admin'),
          quiz(id: 'other-periodic', owner: 'teacher-2'),
          quiz(id: 'admin-teacher', owner: 'supervisor', type: 'teacher'),
        ],
        legacyQuestions: const [],
        profile: student,
      );

      expect(results.map((item) => item['id']), ['teacher-periodic', 'admin-teacher']);
    });

    test('uses a supervisor assessment only when the teacher has no matching type', () {
      final results = StudentAssessmentRules.selectAvailableQuizzes(
        createdQuizzes: [
          quiz(id: 'admin-periodic', owner: 'admin'),
          quiz(id: 'other-periodic', owner: 'teacher-2'),
        ],
        legacyQuestions: const [],
        profile: student,
      );

      expect(results, hasLength(1));
      expect(results.single['id'], 'admin-periodic');
    });

    test('does not show an active quiz marked deleted by synchronized tombstones', () {
      final results = StudentAssessmentRules.selectAvailableQuizzes(
        createdQuizzes: [
          quiz(id: 'visible-teacher-quiz', owner: 'teacher-1'),
          quiz(id: 'stale-deleted-quiz', owner: 'teacher-1'),
        ],
        legacyQuestions: const [],
        deletedQuizIds: const ['stale-deleted-quiz'],
        profile: student,
      );

      expect(results.map((item) => item['id']), ['visible-teacher-quiz']);
    });

    test('does not duplicate a modern quiz with its legacy question-bank group', () {
      final results = StudentAssessmentRules.selectAvailableQuizzes(
        createdQuizzes: [
          quiz(id: 'modern-periodic', owner: 'teacher-1'),
        ],
        legacyQuestions: [
          {
            'question': 'سؤال قديم لنفس الاختبار',
            'options': ['أ', 'ب'],
            'correctAnswer': 'أ',
            'quizTitle': 'modern-periodic',
            'quizType': 'periodic',
            'createdBy': 'teacher-1',
            'grade': 'السادس',
            'atram': 'الفصل الأول',
            'subject': 'الرياضيات',
            'term': 'الترم الأول',
            'unit': 'الوحدة الأولى',
          },
        ],
        profile: student,
      );

      expect(results, hasLength(1));
      expect(results.single['id'], 'modern-periodic');
    });

    test('requires the selected academic scope where it is provided', () {
      final results = StudentAssessmentRules.selectAvailableQuizzes(
        createdQuizzes: [
          quiz(id: 'same-path', owner: 'teacher-1'),
          quiz(id: 'other-grade', owner: 'teacher-1', grade: 'الخامس'),
        ],
        legacyQuestions: const [],
        profile: student,
      );

      expect(results.map((item) => item['id']), ['same-path']);
    });

    test('groups compatible legacy questions into an available quiz', () {
      final results = StudentAssessmentRules.selectAvailableQuizzes(
        createdQuizzes: const [],
        legacyQuestions: [
          {
            'id': 'legacy-question',
            'question': 'ما ناتج ١ + ١؟',
            'options': ['١', '٢', '٣'],
            'correctAnswer': '٢',
            'quizId': 'legacy-quiz',
            'quizTitle': 'اختبار قديم',
            'quizType': 'teacher',
            'createdBy': 'teacher-1',
            'grade': 'السادس',
            'atram': 'الفصل الأول',
            'subject': 'الرياضيات',
            'term': 'الترم الأول',
            'unit': 'الوحدة الأولى',
          },
        ],
        profile: student,
      );

      expect(results, hasLength(1));
      expect(results.single['id'], 'legacy-quiz');
      expect(results.single['questions'], hasLength(1));
      expect(StudentAssessmentRules.isTeacherQuiz(results.single), isTrue);
    });
  });

  group('StudentAssessmentRules.question and result behavior', () {
    test('selects a stable student-specific question set', () {
      final assessment = quiz(
        id: 'bank',
        owner: 'teacher-1',
        questionsPerAttempt: 2,
      );

      final first = StudentAssessmentRules.questionsForStudent(
        assessment,
        studentId: 'student-1',
      );
      final second = StudentAssessmentRules.questionsForStudent(
        assessment,
        studentId: 'student-1',
      );

      expect(first.map((item) => item['id']).toList(), second.map((item) => item['id']).toList());
      expect(first, hasLength(2));
    });

    test('scores letter, index, and answer-text formats consistently', () {
      final assessment = quiz(id: 'scoring', owner: 'teacher-1');
      final questions = assessment['questions'] as List<Map<String, dynamic>>;

      expect(StudentAssessmentRules.isAnswerCorrect(questions[0], 'أ'), isTrue);
      expect(StudentAssessmentRules.isAnswerCorrect(questions[1], '٢'), isTrue);
      expect(StudentAssessmentRules.isAnswerCorrect(questions[2], 'ص'), isTrue);
      expect(StudentAssessmentRules.correctAnswerText(questions[0]), 'أ');
    });

    test('only a teacher-quiz result blocks a further teacher attempt', () {
      const teacherQuizId = 'teacher-quiz';
      expect(
        StudentAssessmentRules.hasTeacherQuizResult([
          {'quizId': teacherQuizId, 'quizType': 'periodic'},
        ], teacherQuizId),
        isFalse,
      );
      expect(
        StudentAssessmentRules.hasTeacherQuizResult([
          {'quizId': teacherQuizId, 'quizType': 'teacher'},
        ], teacherQuizId),
        isTrue,
      );
    });
  });
}