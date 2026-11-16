/// «وضع الزائر الاستكشافي»: ما يُفتح للزائر وما يُغلق، في موضعٍ واحد.
///
/// الزائرُ يدخل حسابَ عرضٍ حقيقيّاً على الخادم (روضة منارة المعرفة أو الصف
/// الرابع) يشاركه كلُّ الزوّار. فالخادمُ لا يحفظ له شيئاً (جواهرُه ومستواه
/// أصفار)، وهذه القواعدُ تقيّد ما بداخل كل بطاقة. وكلُّ شاشةٍ تسأل هنا، فلا
/// تفترق القاعدةُ بين موضعٍ وآخر.
library;

import '../models/student_profile.dart';

enum DemoTrack { kg, grade4 }

class DemoMode {
  DemoMode._();

  static DemoTrack? _track;

  /// المسارُ التجريبيّ الجاري، أو `null` لحسابٍ حقيقيّ.
  static DemoTrack? get track => _track;
  static bool get active => _track != null;

  /// يُضبط عند الدخول وعند الخروج.
  static void enterFor(StudentProfile? profile) {
    _track = profile == null || !profile.isDemo
        ? null
        : profile.demoTrack == 'grade4'
            ? DemoTrack.grade4
            : DemoTrack.kg;
  }

  static void exit() => _track = null;

  // ── المسار: المادة، والفصل، والوحدة، والدرس ──

  /// الصفُّ الرابع: الرياضياتُ وحدها. الروضة: كلُّ المواد.
  static bool allowsSubject(String subject) {
    if (_track != DemoTrack.grade4) return true;
    final s = subject.replaceAll(RegExp('[ًٌٍَُِّْ]'), '');
    return s.contains('رياضيات') || s.toLowerCase().contains('math');
  }

  /// الفصلُ الأوّل والوحدةُ الأولى وحدهما ([index] ترتيبُهما في القائمة).
  static bool allowsTerm(int index) => !active || index == 0;
  static bool allowsUnit(int index) => !active || index == 0;

  /// الدرسان الأوّل والثاني.
  static bool allowsLesson(int index) => !active || index < 2;

  // ── ما بداخل البطاقات ──

  /// قلمي السحري: أوّلُ خمسة حروف وأوّلُ خمسة أرقام، عربيةً وإنجليزية.
  static const tracingItems = 5;

  /// المذاكرة: «المقلاع» وحده.
  static const studyGame = 'slingshot';

  /// سينما منارة: فيديو واحد. عالم الترفيه: لعبةٌ واحدة. شخصيتي: شخصيتان.
  static const cinemaVideos = 1;
  static const entertainmentGames = 1;
  static const avatars = 2;

  /// مركز الاختبارات: سؤالان لكل درس.
  static const quizQuestions = 2;

  /// لعبةُ الألوان في عالم الحكايات: سؤالان بالعربية وسؤالان بالإنجليزية.
  static const kgColorQuestions = 2;

  /// الدردشة: محادثتان كتابيتان ومحادثتان صوتيتان مع حسابٍ افتراضيّ، بلا صور.
  static const chatTexts = 2;
  static const chatVoices = 2;

  /// تعليم القرآن: سورةُ الفاتحة وحدها.
  static bool allowsSurah(String name) => !active || name.contains('الفاتحة') || name.toLowerCase().contains('fatiha');

  /// يقصّ [items] إلى [limit] للزائر، ويتركها كما هي لغيره.
  static List<T> limit<T>(List<T> items, int limit) =>
      active && items.length > limit ? items.sublist(0, limit) : items;

  /// بطاقاتٌ تُعرَّف للزائر برسالةٍ تشرحها، ولا تُفتح.
  static const teaserCards = {'solver', 'meeting', 'challenge', 'tutor'};
}
