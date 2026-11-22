/// «وضع الزائر الاستكشافي»: ما يُفتح للزائر وما يُغلق، في موضعٍ واحد.
///
/// الزائرُ يدخل حسابَ عرضٍ على الجهاز وحده (روضة منارة المعرفة أو الصف
/// الرابع) — محتواه في [DemoContent]، وجواهرُه ومستواه أصفار. وهذه القواعدُ
/// تقيّد ما بداخل كل بطاقة. والقاعدةُ العامّة: **كلُّ شيءٍ يظهر**، والمفتوحُ
/// أوّلُه وحده، والباقي بقفلٍ ذهبيّ يقول «في الحساب الرسمي». وكلُّ شاشةٍ تسأل
/// هنا، فلا تفترق القاعدةُ بين موضعٍ وآخر.
library;

import '../models/student_profile.dart';
import 'demo_catalog.dart';

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

  static void exit() {
    _track = null;
    DemoCatalog.clear();
  }

  /// عنوانُ الخادم لشاشة الباقات: زرُّ «احصل على حساب رسمي» في رسالة القفل.
  static String plansBaseUrl = '';

  // ── المسار ──
  // ‏صفحةُ المسارات كالحساب العادي تماماً: كلُّ المواد والفصول والوحدات
  // ‏والدروس ظاهرةٌ مفتوحة. والقيودُ كلُّها بعد الدخول، داخل البطاقات.

  // ── ما بداخل البطاقات ──

  /// قلمي السحري: كلُّ الحروف والأرقام ظاهرة، وأوّلُ أربعةٍ مفتوحة من كلٍّ
  /// منها (الحروف العربية والإنجليزية، والأرقام العربية والإنجليزية).
  static const tracingItems = 4;
  static bool allowsTracing(int index) => !active || index < tracingItems;

  /// المذاكرة: «المقلاع» وحده — على الرفّ وفي شريط التبديل داخل اللعبة.
  static const studyGame = 'slingshot';
  static bool allowsStudyGame(String style) => !active || style == studyGame;

  /// شرح الدرس: كلُّ مقاطع الدرس ظاهرة، والأوّلُ وحده يعمل.
  static const lessonSegments = 1;
  static bool allowsSegment(int index) => !active || index < lessonSegments;

  /// سينما منارة: كلُّ الفيديوهات ظاهرة وواحدٌ يعمل. عالم الترفيه: كلُّ
  /// الألعاب ظاهرة وواحدةٌ تعمل. شخصيتي: شخصيتان.
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
  static const teaserCards = {'meeting', 'tutor'};

  /// «حلّ المسائل»: سؤالان (مكتوبان أو بالصوت أو بالصورة)، ثم القفل.
  static const solverQuestions = 2;

  /// «تحدَّ زملاءك»: مباراةٌ مع شخصيةٍ افتراضية بثلاثة أسئلة.
  static const duelQuestions = 3;
}
