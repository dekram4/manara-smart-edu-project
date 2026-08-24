import 'package:flutter_test/flutter_test.dart';
import 'package:manara_student/src/models/academic_context.dart';
import 'package:manara_student/src/models/student_content.dart';
import 'package:manara_student/src/models/student_profile.dart';
import 'package:manara_student/src/services/student_content_service.dart';

void main() {
  const profile = StudentProfile(
    id: 'student-1',
    username: 'student',
    name: 'طالب منارة',
    role: 'student',
    teacherId: 'teacher-1',
  );

  final context = AcademicContext(
    grade: 'السادس',
    atram: 'الفصل الأول',
    subject: 'الرياضيات',
    term: 'الترم الأول',
    unit: 'الوحدة الأولى',
    selectedLesson: _lesson(id: 'selected-lesson', ownerId: 'teacher-1'),
  );

  TutorExperienceSelection select(
    List<LessonContent> lessons, {
    StudentProfile? student,
    AcademicContext? selectedContext,
    TutorExperienceType type = TutorExperienceType.virtualTeacher,
  }) {
    return StudentContentService.resolveTutorExperience(
      lessons: lessons,
      profile: student ?? profile,
      academicContext: selectedContext ?? context,
      type: type,
    );
  }

  group('virtual teacher experience selection', () {
    test('prefers the assigned teacher over administrator content', () {
      final selection = select([
        _lesson(
          id: 'admin-link',
          ownerId: 'admin',
          avatarUrl: 'https://admin.example/avatar',
          createdAt: '2026-01-02T00:00:00Z',
        ),
        _lesson(
          id: 'teacher-link',
          ownerId: 'teacher-1',
          avatarUrl: 'https://teacher.example/avatar',
          createdAt: '2026-01-01T00:00:00Z',
        ),
        _lesson(
          id: 'other-teacher-link',
          ownerId: 'teacher-2',
          avatarUrl: 'https://other-teacher.example/avatar',
          createdAt: '2026-01-03T00:00:00Z',
        ),
      ]);

      expect(selection.status, TutorExperienceStatus.ready);
      expect(selection.lesson?.id, 'teacher-link');
      expect(selection.url, 'https://teacher.example/avatar');
    });

    test('uses administrator content when the assigned teacher has no link', () {
      final selection = select([
        _lesson(id: 'teacher-empty', ownerId: 'teacher-1'),
        _lesson(
          id: 'admin-link',
          ownerId: 'supervisor',
          avatarUrl: 'https://admin.example/avatar',
        ),
      ]);

      expect(selection.status, TutorExperienceStatus.ready);
      expect(selection.lesson?.id, 'admin-link');
    });

    test('never returns another teacher link when the student has no teacher', () {
      const unassignedStudent = StudentProfile(
        id: 'student-2',
        username: 'unassigned',
        name: 'طالب بلا معلم',
        role: 'student',
      );
      final selection = select(
        [
          _lesson(
            id: 'other-teacher',
            ownerId: 'teacher-2',
            avatarUrl: 'https://other-teacher.example/avatar',
          ),
        ],
        student: unassignedStudent,
      );

      expect(selection.status, TutorExperienceStatus.unavailable);
      expect(selection.lesson, isNull);
      expect(selection.url, isNull);
    });

    test('rejects lessons outside the selected academic path', () {
      final selection = select([
        _lesson(
          id: 'other-unit',
          ownerId: 'teacher-1',
          unit: 'الوحدة الثانية',
          avatarUrl: 'https://teacher.example/other-unit',
        ),
      ]);

      expect(selection.status, TutorExperienceStatus.unavailable);
    });

    test('requires a complete academic selection', () {
      final partialContext = AcademicContext(
        grade: 'السادس',
        atram: '',
        subject: 'الرياضيات',
        term: 'الترم الأول',
        unit: 'الوحدة الأولى',
        selectedLesson: _lesson(id: 'partial-selected', ownerId: 'teacher-1'),
      );
      final selection = select(
        [
          _lesson(
            id: 'teacher-link',
            ownerId: 'teacher-1',
            avatarUrl: 'https://teacher.example/avatar',
          ),
        ],
        selectedContext: partialContext,
      );

      expect(selection.status, TutorExperienceStatus.missingAcademicContext);
    });

    test('reports an unsafe teacher URL instead of falling back to admin', () {
      final selection = select([
        _lesson(
          id: 'admin-link',
          ownerId: 'admin',
          avatarUrl: 'https://admin.example/avatar',
        ),
        _lesson(
          id: 'teacher-unsafe',
          ownerId: 'teacher-1',
          avatarUrl: 'http://teacher.example/avatar',
        ),
      ]);

      expect(selection.status, TutorExperienceStatus.unsafeUrl);
      expect(selection.lesson?.id, 'teacher-unsafe');
      expect(selection.url, isNull);
    });

    test('uses the same scoped priority rules for live meetings', () {
      final selection = select(
        [
          _lesson(
            id: 'admin-meeting',
            ownerId: 'admin',
            liveMeetingUrl: 'https://admin.example/meeting',
          ),
          _lesson(
            id: 'teacher-meeting',
            ownerId: 'teacher-1',
            liveMeetingUrl: 'https://teacher.example/meeting',
          ),
        ],
        type: TutorExperienceType.liveMeeting,
      );

      expect(selection.status, TutorExperienceStatus.ready);
      expect(selection.lesson?.id, 'teacher-meeting');
      expect(selection.url, 'https://teacher.example/meeting');
    });
  });
}

LessonContent _lesson({
  required String id,
  required String? ownerId,
  String grade = 'السادس',
  String atram = 'الفصل الأول',
  String subject = 'الرياضيات',
  String term = 'الترم الأول',
  String unit = 'الوحدة الأولى',
  String createdAt = '2026-01-01T00:00:00Z',
  String? avatarUrl,
  String? liveMeetingUrl,
}) {
  return LessonContent(
    id: id,
    lessonId: id,
    grade: grade,
    atram: atram,
    subject: subject,
    term: term,
    unit: unit,
    lessonName: 'الدرس $id',
    createdAt: createdAt,
    ownerId: ownerId,
    avatarInteractionUrl: avatarUrl,
    liveMeetingUrl: liveMeetingUrl,
    videos: const [],
    games: const [],
  );
}