enum VideoSourceType { embed, mp4 }

enum TutorExperienceType { virtualTeacher, liveMeeting }

enum TutorExperienceStatus {
  ready,
  missingAcademicContext,
  unavailable,
  unsafeUrl,
}

class TutorExperienceSelection {
  const TutorExperienceSelection({
    required this.type,
    required this.status,
    this.lesson,
    this.url,
  });

  final TutorExperienceType type;
  final TutorExperienceStatus status;
  final LessonContent? lesson;
  final String? url;

  bool get isReady => status == TutorExperienceStatus.ready && url != null;
}

class LessonVideo {
  const LessonVideo({
    required this.id,
    required this.url,
    required this.sourceType,
    required this.title,
    this.description,
  });

  final String id;
  final String url;
  final VideoSourceType sourceType;
  final String title;
  final String? description;
}

class HtmlGame {
  const HtmlGame({
    required this.id,
    required this.url,
    required this.title,
    required this.subtitle,
    this.requiredLevel = 0,
  });

  final String id;
  final String url;
  final String title;
  final String subtitle;
  final int requiredLevel;
}

class LessonContent {
  const LessonContent({
    required this.id,
    required this.lessonId,
    required this.grade,
    required this.atram,
    required this.subject,
    required this.term,
    required this.unit,
    required this.lessonName,
    required this.createdAt,
    this.ownerId,
    required this.videos,
    required this.games,
    this.lessonText,
    this.avatarInteractionUrl,
    this.liveMeetingUrl,
  });

  final String id;
  final String lessonId;
  final String grade;
  final String atram;
  final String subject;
  final String term;
  final String unit;
  final String lessonName;
  final String createdAt;
  final String? ownerId;
  final String? lessonText;
  final String? avatarInteractionUrl;
  final String? liveMeetingUrl;
  final List<LessonVideo> videos;
  final List<HtmlGame> games;

  String get scopeLabel => [grade, subject, term, unit, lessonName]
      .where((value) => value.trim().isNotEmpty)
      .join(' • ');
}
/// قاعدة فتح الألعاب حسب المستوى.
///
/// اللعبة رقم N تُفتح عند المستوى N: الفهرس 0 عند المستوى 1، والفهرس 1 عند
/// المستوى 2. والمستوى 0 — مستوى الطالب الجديد — تبقى معه كل الألعاب مقفلة.
///
/// موضوعة هنا لا داخل شاشة الألعاب لأن الشاشة خاصة بملفها فلا يبلغها اختبار،
/// وهذه قاعدة يسهل أن تنزلق بمقدار واحد دون أن يظهر الانزلاق في الاستعمال
/// العادي — كل لعبة تُفتح قبل أوانها أو بعده بمستوى، ولا شيء يشتكي.
abstract final class GameUnlockRule {
  /// المستوى الذي تُفتح عنده اللعبة رقم [index].
  static int requiredLevelFor(int index) => index + 1;

  /// هل اللعبة رقم [index] مفتوحة عند [level]؟
  static bool isUnlocked(int index, int level) =>
      level >= requiredLevelFor(index);

  /// كم لعبة يفتحها [level] — وهي المستوى نفسه، ولا تقلّ عن صفر.
  static int unlockedCount(int level) => level < 0 ? 0 : level;
}
