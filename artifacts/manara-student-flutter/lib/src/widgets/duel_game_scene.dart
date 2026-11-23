import 'package:flutter/material.dart';

import '../services/student_duel_service.dart';

/// مشاهدُ ألعاب «تحدَّ زملاءك» المتحرّكة (GIF)، ملفٌّ لكلّ لعبة:
///  • سباقُ الحواجز وشدُّ الحبل: بعدد اللاعبين في الجولة، من ٢ إلى ٥.
///  • بستانُ الأرقام: جمعُ الفواكه. وأبراجُ التحدي: بناءُ الجدار.
///
/// والمساراتُ مكتوبةً كاملةً لا مبنيّةً بالأرقام: فيراها اختبارُ الأصول
/// (`asset_policy_test`) ويتحقّق أنّ كلَّ ملفٍّ منها موجودٌ ومعلن.
const Map<int, String> _hurdles = {
  2: 'assets/images/duel_games/hurdle-race-2-players.gif',
  3: 'assets/images/duel_games/hurdle-race-3-players.gif',
  4: 'assets/images/duel_games/hurdle-race-4-players.gif',
  5: 'assets/images/duel_games/hurdle-race-5-players.gif',
};

const Map<int, String> _tugs = {
  2: 'assets/images/duel_games/tug-of-war-2-players.gif',
  3: 'assets/images/duel_games/tug-of-war-3-players.gif',
  4: 'assets/images/duel_games/tug-of-war-4-players.gif',
  5: 'assets/images/duel_games/tug-of-war-5-players.gif',
};

const _fruits = 'assets/images/duel_games/fruit-collecting.gif';
const _wall = 'assets/images/duel_games/wall-building.gif';

/// أقلُّ عددٍ وأكثرُه لمشاهد العدد.
const duelSceneMinPlayers = 2;
const duelSceneMaxPlayers = 5;

/// مشهدُ [game] لجولةٍ فيها [players] لاعباً.
///
/// ── وعددٌ خارج المشاهد لا يُسقط شيئاً ──
/// قبل أن يدخل أحد (لاعبٌ واحد) يُعرض مشهدُ اثنين، وغرفةٌ كاملةٌ بستّة لاعبين
/// تُعرض بمشهد خمسة — أقربُ مشهدٍ موجود، لا ملفٌّ لا وجود له.
String duelGameScene(DuelGame game, int players) {
  final n = players.clamp(duelSceneMinPlayers, duelSceneMaxPlayers);
  return switch (game) {
    DuelGame.sprint => _hurdles[n]!,
    DuelGame.tug => _tugs[n]!,
    DuelGame.balloons => _fruits,
    DuelGame.gems => _wall,
  };
}

/// كلُّ المشاهد، لمن يريد تحميلها مسبقاً.
List<String> get allDuelGameScenes => [..._hurdles.values, ..._tugs.values, _fruits, _wall];

/// يحمّل مشهدَ الجولة قبل أن يُعرض، فلا يظهر فارغاً لحظةَ فتح الحلبة.
Future<void> precacheDuelScene(BuildContext context, DuelGame game, int players) async {
  try {
    await precacheImage(AssetImage(duelGameScene(game, players)), context);
  } catch (_) {
    // ‏لا بأس: [DuelGameScene] يعرض بديلَه.
  }
}

/// المشهدُ المتحرّك للّعبة، بزوايا مستديرة.
///
/// ومن طلب تقليلَ الحركة يراه صورةً ثابتة ([TickerMode]). وملفٌّ تعذّر فكُّه
/// يُعرض مكانه لوحٌ ملوّن باسم اللعبة — لا مربّعٌ أحمر ولا فراغ.
/// و[gaplessPlayback] يُبقي الإطارَ السابق حين يتبدّل المشهد (انضمّ لاعب)،
/// فلا يومض فارغاً.
class DuelGameScene extends StatelessWidget {
  const DuelGameScene({
    required this.game,
    required this.players,
    this.height,
    this.radius = 18,
    this.overlay,
    super.key,
  });

  final DuelGame game;
  final int players;

  /// ارتفاعٌ ثابت (المشهدُ يُقصّ ليملأه)، أو نسبةُ ١٦:٩ إن غاب.
  final double? height;
  final double radius;

  /// ما يُرسم فوق المشهد (اسمُ اللعبة، شارة «مباشر»…).
  final Widget? overlay;

  @override
  Widget build(BuildContext context) {
    final path = duelGameScene(game, players);
    final still = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    final image = TickerMode(
      enabled: !still && TickerMode.valuesOf(context).enabled,
      child: Image.asset(
        path,
        key: ValueKey(path),
        fit: BoxFit.cover,
        gaplessPlayback: true,
        filterQuality: FilterQuality.medium,
        excludeFromSemantics: true,
        errorBuilder: (context, _, __) => _SceneFallback(game: game),
      ),
    );
    final scene = ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: Stack(
        fit: StackFit.expand,
        children: [
          image,
          if (overlay != null) overlay!,
        ],
      ),
    );
    return Semantics(
      image: true,
      label: game.label,
      child: KeyedSubtree(
        key: ValueKey('duel-scene-${game.id}'),
        child: height != null ? SizedBox(height: height, child: scene) : AspectRatio(aspectRatio: 16 / 9, child: scene),
      ),
    );
  }
}

class _SceneFallback extends StatelessWidget {
  const _SceneFallback({required this.game});

  final DuelGame game;

  @override
  Widget build(BuildContext context) {
    final (emoji, colors) = switch (game) {
      DuelGame.sprint => ('🏃', const [Color(0xFF8B5CF6), Color(0xFF4C1D95)]),
      DuelGame.balloons => ('🍎', const [Color(0xFFEC4899), Color(0xFF9D174D)]),
      DuelGame.tug => ('💪', const [Color(0xFFF97316), Color(0xFF9A3412)]),
      DuelGame.gems => ('🧱', const [Color(0xFF06B6D4), Color(0xFF155E75)]),
    };
    return DecoratedBox(
      key: const ValueKey('duel-scene-fallback'),
      decoration: BoxDecoration(gradient: LinearGradient(colors: colors)),
      child: Center(child: Text(emoji, style: const TextStyle(fontSize: 44))),
    );
  }
}

/// شارةٌ صغيرةٌ فوق المشهد: اسمُ اللعبة أو عددُ اللاعبين.
class DuelSceneChip extends StatelessWidget {
  const DuelSceneChip({required this.text, this.color = const Color(0xCC1E1B4B), super.key});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: Colors.white.withValues(alpha: 0.6)),
        ),
        child: Text(
          text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w900),
        ),
      );
}

/// يُبرز المشهدَ لحظةَ يكسب أحدٌ نقطة: وهجٌ ذهبيّ وقفزةٌ صغيرة، ثم يهدأ.
class DuelScenePulse extends StatefulWidget {
  const DuelScenePulse({required this.score, required this.child, super.key});

  /// مجموعُ ما كسبه اللاعبون: يكبر فيُبرز.
  final int score;
  final Widget child;

  @override
  State<DuelScenePulse> createState() => _DuelScenePulseState();
}

class _DuelScenePulseState extends State<DuelScenePulse> with SingleTickerProviderStateMixin {
  late final AnimationController _pulse =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 700));

  @override
  void didUpdateWidget(DuelScenePulse old) {
    super.didUpdateWidget(old);
    final still = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (widget.score > old.score && !still) _pulse.forward(from: 0);
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _pulse,
        child: widget.child,
        builder: (context, child) {
          final t = _pulse.isAnimating ? Curves.easeOut.transform(1 - _pulse.value) : 0.0;
          return Transform.scale(
            scale: 1 + 0.025 * t,
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  if (t > 0)
                    BoxShadow(color: const Color(0xFFF59E0B).withValues(alpha: 0.65 * t), blurRadius: 26 * t, spreadRadius: 3 * t),
                ],
              ),
              child: child,
            ),
          );
        },
      );
}
