/// قاعدةُ فتح فيديوهات السينما بالجواهر — في موضعٍ واحد يُختبر.
///
/// كل 5 جواهر مكتسبة تفتح فيديو واحداً، بالترتيب: الأول بـ 5، والثاني بـ 10،
/// والثالث بـ 15… والجواهرُ لا تُصرف بالمشاهدة: الرصيدُ هو ما اكتُسب، والفتحُ
/// يُحسب منه في كل مرة.
class CinemaUnlockRules {
  const CinemaUnlockRules._();

  static const gemsPerVideo = 5;

  /// عددُ الفيديوهات المفتوحة برصيد [gems].
  static int unlockedCount(int gems) => gems <= 0 ? 0 : gems ~/ gemsPerVideo;

  static bool isUnlocked(int index, int gems) => index < unlockedCount(gems);

  /// الجواهرُ التي يحتاجها الفيديو ذو الموضع [index] ليُفتح.
  static int requiredGems(int index) => (index + 1) * gemsPerVideo;

  /// ما ينقص الطالبَ ليفتحه — صفرٌ إن كان مفتوحاً.
  static int missingGems(int index, int gems) {
    final missing = requiredGems(index) - gems;
    return missing > 0 ? missing : 0;
  }
}

/// إلى أين يذهب الطالب من نافذة الفيديو المقفل ليكسب جواهر.
enum CinemaEarnRoute { lesson, quiz }
