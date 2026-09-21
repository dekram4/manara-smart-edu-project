import 'package:flutter_test/flutter_test.dart';
import 'package:manara_student/src/models/student_profile.dart';

/// Which subjects a student may enter.
///
/// The rule lives on the profile so the path screen and the change-lesson
/// sheet ask the same question. If each filtered for itself they would
/// drift, and a child would reach through one door what the other refused.
void main() {
  StudentProfile profileWith(Object? assigned) =>
      StudentProfile.fromStudentRow({
        'id': 's1',
        'data': {
          'name': 'جوري',
          'username': 'jori',
          if (assigned != null) 'assignedSubjects': assigned,
        },
      });

  group('an empty assignment means every subject', () {
    test('a record saved before the field existed keeps every subject', () {
      final profile = profileWith(null);
      expect(profile.assignedSubjects, isEmpty);
      expect(profile.allowsSubject('العلوم'), isTrue);
      expect(profile.allowsSubject('الرياضيات'), isTrue);
    });

    test('an explicitly empty list is the same as none', () {
      expect(profileWith(<String>[]).allowsSubject('العلوم'), isTrue);
    });
  });

  group('a named assignment shuts out everything else', () {
    test('one subject', () {
      final profile = profileWith(['العلوم']);
      expect(profile.allowsSubject('العلوم'), isTrue);
      expect(profile.allowsSubject('الرياضيات'), isFalse);
    });

    test('several subjects', () {
      final profile = profileWith(['العلوم', 'الرياضيات']);
      expect(profile.allowsSubject('العلوم'), isTrue);
      expect(profile.allowsSubject('الرياضيات'), isTrue);
      expect(profile.allowsSubject('اللغة العربية'), isFalse);
    });

    test('stray spacing and case do not lock a child out', () {
      // ‏الاسم يُكتب في لوحة ويُقارن في تطبيق، فلا يُعوَّل على تطابق حرفي.
      final profile = profileWith(['  العلوم  ']);
      expect(profile.allowsSubject('العلوم'), isTrue);
    });
  });

  group('reading the field', () {
    test('blank entries are dropped rather than becoming a subject', () {
      expect(profileWith(['العلوم', '', '   ']).assignedSubjects, ['العلوم']);
    });

    test('a comma-separated string is accepted too', () {
      // ‏صيغة قد تصل من استيراد أو من تحرير يدوي للسجلّ.
      expect(
        profileWith('العلوم, الرياضيات').assignedSubjects,
        ['العلوم', 'الرياضيات'],
      );
    });

    test('a value of the wrong shape leaves the student unrestricted', () {
      // ‏الخطأ يميل إلى الفتح لا إلى الإغلاق: حقلٌ تالف يجب ألّا يحبس
      // ‏طفلاً خارج موادّه كلّها.
      expect(profileWith(42).allowsSubject('العلوم'), isTrue);
    });
  });
}
