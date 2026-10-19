/// صلاحيات بطاقات الطالب محسوبةً من القواعد نفسها — نسخةُ التطبيق من
/// `effectiveCards` في الخادم (`api-server/src/lib/cardPermissions.ts`).
///
/// ── لماذا يحسبها التطبيق أيضاً ──
/// الخادم هو المصدر، ويُسأل أولاً. لكن نسخةً من التطبيق بُنيت بعنوان خادمٍ
/// قديم لم تسأله قطّ، ففشل الطلب وبقيت كلُّ البطاقات مفتوحة وقد أغلقها
/// المعلم. والقواعدُ محفوظةٌ أيضاً في `app_kv/smartEdu_cardPermissions` الذي
/// يقرؤه التطبيق من Supabase مباشرةً — فإن لم يُجب الخادم حُسبت هنا بالقاعدة
/// ذاتها، ولا يتوقّف القفلُ على صحّة عنوان الخادم.
class CardPermissionRules {
  const CardPermissionRules._();

  /// معرّفات البطاقات كما في الخادم: ما بعد `portal.` في مفاتيح عناوينها.
  static const cardIds = <String>[
    'lesson',
    'cinema',
    'games',
    'personality',
    'tutor',
    'quiz',
    'solver',
    'meeting',
    'chat',
    'challenge',
    'study',
  ];

  /// الكلُّ مفتوح، ثم قاعدةُ صفّ الطالب (معلّمُه وصفُّه) وقاعدتُه هو —
  /// بترتيب زمنهما: القرارُ الأحدث يغلب، فإغلاقُ المعلم بطاقةً لصفّه يصل كلَّ
  /// طلابه ولو كان لأحدهم استثناءٌ أقدم.
  ///
  /// [studentIds] كلُّ معرّفات الطالب: معرّفُ الصفّ في الجدول ومعرّفُ
  /// السجلّ — القاعدةُ تُطابق أيّاً منهما. و[teacherIdentities] أسماءُ معلّمه
  /// مسوّاةً بـ [normalize].
  static Map<String, bool> effective({
    required List<Object?> rules,
    required Set<String> studentIds,
    required String? grade,
    required Set<String> teacherIdentities,
  }) {
    final result = {for (final id in cardIds) id: true};
    final studentGrade = normalize(grade);
    final ids = studentIds.map((id) => id.trim()).where((id) => id.isNotEmpty).toSet();

    final classRules = <Map<String, dynamic>>[];
    Map<String, dynamic>? studentRule;
    for (final raw in rules) {
      if (raw is! Map) continue;
      final rule = Map<String, dynamic>.from(raw);
      final scope = _text(rule['scope']);
      if (scope == 'class') {
        final teacher = normalize(rule['teacher_id'] ?? rule['teacherId']);
        final ruleGrade = normalize(rule['grade_id'] ?? rule['gradeId']);
        if (teacher.isNotEmpty &&
            teacherIdentities.contains(teacher) &&
            ruleGrade.isNotEmpty &&
            ruleGrade == studentGrade) {
          classRules.add(rule);
        }
      } else if (scope == 'student') {
        final studentId = _text(rule['student_id'] ?? rule['studentId']);
        if (studentId.isNotEmpty && ids.contains(studentId)) studentRule = rule;
      }
    }
    // ‏الأقدمُ أوّلاً فيغلبه الأحدث؛ وعند تساوي الزمن الصفُّ ثم الطالب.
    final ordered = [...classRules, if (studentRule != null) studentRule];
    final indexed = [for (var i = 0; i < ordered.length; i++) (i, ordered[i])];
    indexed.sort((a, b) {
      final byTime = _stamp(a.$2).compareTo(_stamp(b.$2));
      return byTime != 0 ? byTime : a.$1.compareTo(b.$1);
    });
    for (final (_, rule) in indexed) {
      _apply(result, rule['cards']);
    }
    return result;
  }

  static int _stamp(Map<String, dynamic> rule) =>
      DateTime.tryParse(_text(rule['updated_at'] ?? rule['updatedAt']))
          ?.millisecondsSinceEpoch ??
      0;

  static void _apply(Map<String, bool> result, Object? cards) {
    if (cards is! Map) return;
    cards.forEach((key, value) {
      if (value is bool && result.containsKey(key)) result[key as String] = value;
    });
  }

  static String _text(Object? value) => value?.toString().trim() ?? '';

  /// تسويةٌ عربية للمقارنة — مطابقةٌ لـ `scopeKey` في الخادم.
  static String normalize(Object? value) {
    final raw = value?.toString().trim().toLowerCase() ?? '';
    return raw
        .replaceAll(RegExp('[ً-ْٰـ]'), '')
        .replaceAll(RegExp('[أإآٱ]'), 'ا')
        .replaceAll('ى', 'ي')
        .replaceAll('ة', 'ه')
        .replaceAllMapped(
          RegExp('[٠-٩]'),
          (m) => '${m[0]!.codeUnitAt(0) - 0x0660}',
        )
        .replaceAllMapped(
          RegExp('[۰-۹]'),
          (m) => '${m[0]!.codeUnitAt(0) - 0x06F0}',
        )
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }
}
