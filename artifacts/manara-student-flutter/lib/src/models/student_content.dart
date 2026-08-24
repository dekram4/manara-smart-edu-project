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
  });

  final String id;
  final String url;
  final String title;
  final String subtitle;
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