import 'package:flutter_test/flutter_test.dart';

import 'package:manara_student/src/l10n/student_strings.dart';
import 'package:manara_student/src/services/student_settings.dart';

/// The challenge screen's title was hard-coded to "تحدي العلوم", so a pupil
/// working through a maths lesson read "Science Challenge" over questions
/// built from their own maths text.
///
/// The title is now a template filled from the subject chosen on the path
/// screen. These pin both halves: the substitution happens, and the fallback
/// is reserved for the case where no subject was chosen at all.
void main() {
  setUp(StudentSettings.resetForTest);

  test('the title carries the chosen subject, not a fixed one', () {
    for (final subject in ['الرياضيات', 'لغتي', 'العلوم', 'الاجتماعيات']) {
      final title = trf('challenge.title', {'subject': subject});
      expect(title, 'تحدي $subject');
      expect(title.contains('{subject}'), isFalse,
          reason: 'the placeholder survived into the visible title');
    }
  });

  test('no subject leaves a sensible generic title', () {
    expect(tr('challenge.titleFallback'), 'تحدي المادة');
  });

  test('the fallback is not itself a template', () {
    // A fallback containing {subject} would print the braces on screen.
    expect(tr('challenge.titleFallback').contains('{'), isFalse);
  });

  test('both language tables define the title and its fallback', () {
    // The English table is consulted first when the app is in English; a key
    // missing there silently falls back to Arabic mid-sentence.
    for (final key in ['challenge.title', 'challenge.titleFallback']) {
      expect(StudentStrings.keys, contains(key));
      expect(StudentStrings.englishKeys, contains(key),
          reason: '$key is missing from the English table');
    }
  });
}
