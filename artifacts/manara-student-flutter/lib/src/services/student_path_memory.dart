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
    this.savedAt,
  });

  final String grade;
  final String subject;
  final String term;
  final String unit;
  final String lessonId;
  final String lessonName;

  /// متى اختير. يُقارن به المحفوظُ هنا بالمحفوظ في السجلّ على الخادم، فيُفتح
  /// الأحدث منهما. `null` لمسارٍ حُفظ قبل وجود هذا الحقل.
  final DateTime? savedAt;

  factory StoredPath.of(AcademicContext context, {DateTime? savedAt}) => StoredPath(
        grade: context.grade,
        subject: context.subject,
        term: context.term,
        unit: context.unit,
        lessonId: context.lessonId,
        lessonName: context.lesson,
        savedAt: savedAt,
      );

  Map<String, String> toJson() => {
        'grade': grade,
        'subject': subject,
        'term': term,
        'unit': unit,
        'lessonId': lessonId,
        'lessonName': lessonName,
        if (savedAt != null) 'savedAt': savedAt!.toUtc().toIso8601String(),
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
      savedAt: DateTime.tryParse(text('savedAt')),
    );
    return path.grade.isEmpty || path.subject.isEmpty ? null : path;
  }
}

/// يحفظ آخرَ مسارٍ للطالب على الجهاز وفي سجلّه على الخادم، ويستعيده عند الدخول.
///
/// ── ما كان يحدث ──
/// كان المسارُ يُختار في كل دخولٍ من جديد ابتداءً من مادة الطالب في ملفّه — التي
/// أسندها المعلم، كالإنجليزية — لا من الدرس الذي توقّف عنده. فيختار العلومَ ويخرج،
/// ويعود فيجد نفسه في الإنجليزية. ودخولٌ بجلسةٍ محفوظةٍ كان يفتح الواجهةَ بلا درسٍ
/// أصلاً.
///
/// ── ولكل طالبٍ مفتاحُه ──
/// جهازُ البيت يتشاركه إخوة: مسارُ أحدهم لا يُفتح للآخر.
///
/// ── ويتبع الطالبَ لا الجهاز ──
/// كان على الجهاز وحده، فطالبٌ دخل من تابلت آخر بدأ الاختيارَ من جديد. والآن
/// يُرفع أيضاً إلى سجلّه (`data.lastPath`) ويعود مع ملفّه عند الدخول، ويُفتح
/// الأحدثُ من النسختين.
class StudentPathMemory {
  const StudentPathMemory._();

  static String _key(String studentId) => 'student.path.$studentId';

  /// [upload]: يرفع المسارَ إلى سجلّ الطالب. فشلُه لا يُسقط الحفظَ المحليّ.
  static Future<void> save(
    String studentId,
    AcademicContext context, {
    Future<void> Function(Map<String, String> path)? upload,
  }) async {
    if (studentId.isEmpty) return;
    final json = StoredPath.of(context, savedAt: DateTime.now()).toJson();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key(studentId), jsonEncode(json));
    } catch (error) {
      // مسارٌ لم يُحفظ يُختار ثانيةً في الدخول القادم، ولا يُسقط شيئاً.
      debugPrint('[path] not saved: $error');
    }
    if (upload == null) return;
    try {
      await upload(json);
    } catch (error) {
      // يبقى على هذا الجهاز، ويُرفع مع الاختيار القادم.
      debugPrint('[path] not uploaded: $error');
    }
  }

  /// [remote]: المسارُ المحفوظ في سجلّ الطالب (`StudentProfile.lastPath`).
  /// يُفتح الأحدثُ منه ومن المحفوظ هنا؛ والمحليُّ القديم بلا تاريخ يغلبه
  /// المرفوع.
  static Future<StoredPath?> load(String studentId, {Object? remote}) async {
    if (studentId.isEmpty) return null;
    StoredPath? local;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key(studentId));
      local = raw == null ? null : StoredPath.fromJson(jsonDecode(raw));
    } catch (_) {
      local = null;
    }
    return newer(local, StoredPath.fromJson(remote));
  }

  /// الأحدثُ من مسارين؛ وعند التعادل أو غياب التاريخين يُقدَّم [local].
  static StoredPath? newer(StoredPath? local, StoredPath? remote) {
    if (local == null) return remote;
    if (remote == null) return local;
    final localAt = local.savedAt;
    final remoteAt = remote.savedAt;
    if (remoteAt == null) return local;
    if (localAt == null) return remote;
    return remoteAt.isAfter(localAt) ? remote : local;
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
