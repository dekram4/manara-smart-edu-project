import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/academic_context.dart';

/// آخرُ مسارٍ اختاره الطالب: الصفُّ والمادةُ والفصلُ والوحدةُ والدرس.
class StoredPath {
  const StoredPath({
    required this.grade,
    required this.subject,
    required this.term,
    required this.unit,
    required this.lessonId,
    required this.lessonName,
  });

  final String grade;
  final String subject;
  final String term;
  final String unit;
  final String lessonId;
  final String lessonName;

  factory StoredPath.of(AcademicContext context) => StoredPath(
        grade: context.grade,
        subject: context.subject,
        term: context.term,
        unit: context.unit,
        lessonId: context.lessonId,
        lessonName: context.lesson,
      );

  Map<String, String> toJson() => {
        'grade': grade,
        'subject': subject,
        'term': term,
        'unit': unit,
        'lessonId': lessonId,
        'lessonName': lessonName,
      };

  static StoredPath? fromJson(Object? raw) {
    if (raw is! Map) return null;
    String text(String key) => raw[key] is String ? (raw[key] as String).trim() : '';
    final path = StoredPath(
      grade: text('grade'),
      subject: text('subject'),
      term: text('term'),
      unit: text('unit'),
      lessonId: text('lessonId'),
      lessonName: text('lessonName'),
    );
    return path.grade.isEmpty || path.subject.isEmpty ? null : path;
  }
}

/// يحفظ آخرَ مسارٍ للطالب على الجهاز، ويستعيده عند الدخول.
///
/// ── ما كان يحدث ──
/// كان المسارُ يُختار في كل دخولٍ من جديد ابتداءً من مادة الطالب في ملفّه — التي
/// أسندها المعلم، كالإنجليزية — لا من الدرس الذي توقّف عنده. فيختار العلومَ ويخرج،
/// ويعود فيجد نفسه في الإنجليزية. ودخولٌ بجلسةٍ محفوظةٍ كان يفتح الواجهةَ بلا درسٍ
/// أصلاً.
///
/// ── ولكل طالبٍ مفتاحُه ──
/// جهازُ البيت يتشاركه إخوة: مسارُ أحدهم لا يُفتح للآخر.
class StudentPathMemory {
  const StudentPathMemory._();

  static String _key(String studentId) => 'student.path.$studentId';

  static Future<void> save(String studentId, AcademicContext context) async {
    if (studentId.isEmpty) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key(studentId), jsonEncode(StoredPath.of(context).toJson()));
    } catch (error) {
      // مسارٌ لم يُحفظ يُختار ثانيةً في الدخول القادم، ولا يُسقط شيئاً.
      debugPrint('[path] not saved: $error');
    }
  }

  static Future<StoredPath?> load(String studentId) async {
    if (studentId.isEmpty) return null;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key(studentId));
      return raw == null ? null : StoredPath.fromJson(jsonDecode(raw));
    } catch (_) {
      return null;
    }
  }

  /// يُعيد بناءَ المسار المحفوظ من شجرة الدروس اليوم، أو `null` إن لم يعد قائماً.
  ///
  /// ── ولا يُصدَّق المحفوظُ وحده ──
  /// درسٌ حُذف، أو وحدةٌ نُقلت، أو مادّةٌ قصرها المعلمُ عن الطالب بعد أن اختارها:
  /// فتحُ مسارٍ قديمٍ كما هو يُريه درساً لم يعد له. فكلُّ مستوىً يُطابَق بما في
  /// الشجرة الآن، والدرسُ بمعرّفه ثم باسمه. وما لا يُطابَق يُرجَع فيه إلى الاختيار.
  static AcademicContext? restore(
    AcademicSelectionData data,
    StoredPath path, {
    bool Function(String subject)? allowsSubject,
  }) {
    String? find(List<String> values, String wanted) {
      final key = _normalize(wanted);
      for (final value in values) {
        if (_normalize(value) == key) return value;
      }
      return null;
    }

    final grade = find(data.grades, path.grade);
    if (grade == null) return null;
    final subject = find(data.subjectsFor(grade: grade), path.subject);
    if (subject == null || !(allowsSubject?.call(subject) ?? true)) return null;
    final term = find(data.termsFor(grade: grade, subject: subject), path.term);
    if (term == null) return null;
    final unit = find(
      data.unitsFor(grade: grade, subject: subject, term: term),
      path.unit,
    );
    if (unit == null) return null;
    final lessons = data.lessonsFor(
      grade: grade,
      subject: subject,
      term: term,
      unit: unit,
    );
    final lesson = lessons.where((l) => l.id == path.lessonId).firstOrNull ??
        lessons
            .where((l) => _normalize(l.lessonName) == _normalize(path.lessonName))
            .firstOrNull;
    if (lesson == null) return null;
    return AcademicContext(
      grade: grade,
      subject: subject,
      term: term,
      unit: unit,
      selectedLesson: lesson,
    );
  }

  static String _normalize(String value) => value.trim().toLowerCase();
}
