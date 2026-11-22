import 'package:flutter/material.dart';

import '../l10n/student_strings.dart';
import 'arena_widgets.dart';
import 'duel_tug_of_war.dart';
import 'student_avatar_view.dart';

/// شريطُ المقارنة: نقاطي أمام نقاطه، ومن يتقدّم يُرى.
///
/// ── ولماذا شريطٌ فوق الحلبة وهي تعرض التقدّم ──
/// الحلبةُ تعرض عددَ الإجابات الصحيحة — خطواتٍ على مضمارٍ أو بالوناتٍ مفرقعة
/// — وهو ما يُفهَم بالنظر. والنقاطُ شيءٌ آخر: فيها سرعةُ الجواب، فقد يتساوى
/// عدّادان وتفترق النقاط. وعلى النقاط يُحسم الفوز، فتُعرض صريحةً بالرقم لا
/// مستنتَجةً من شكل.
class DuelVersusBar extends StatelessWidget {
  const DuelVersusBar({
    required this.myName,
    required this.rivalName,
    required this.myAppearance,
    required this.rivalAppearance,
    required this.myPoints,
    required this.rivalPoints,
    required this.live,
    this.showTug = false,
    super.key,
  });

  /// شدُّ الحبل بدل شريط الزخم — للزائر أمام الروبوت، حيث لا حلبةَ أخرى.
  final bool showTug;

  final String myName;
  final String rivalName;
  final Map<String, dynamic>? myAppearance;
  final Map<String, dynamic>? rivalAppearance;
  final int myPoints;
  final int rivalPoints;
  final bool live;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: const LinearGradient(
          colors: [Color(0xFF312E81), Color(0xFF6D28D9), Color(0xFF9D174D)],
          stops: [0.0, 0.55, 1.0],
          begin: AlignmentDirectional.topStart,
          end: AlignmentDirectional.bottomEnd,
        ),
        border: Border.all(
            color: ArenaPalette.goldLight.withValues(alpha: 0.7), width: 1.4),
        boxShadow: [
          const BoxShadow(
            color: Color(0x33000000),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
          BoxShadow(
            color: ArenaPalette.violet.withValues(alpha: 0.35),
            blurRadius: 18,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: _Side(
                  name: myName,
                  appearance: myAppearance,
                  points: myPoints,
                  ahead: myPoints > rivalPoints,
                  mirrored: false,
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'VS',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: 1.5,
                      ),
                    ),
                    // «يلعب الآن» أثناء النزال، ولا شيءَ في النتيجة: المبارزةُ
                    // حيّةٌ دائماً، و«يلعب لاحقاً» بقيّةُ نمطٍ لم يعد.
                    if (live)
                      Text(
                        tr('duel.liveNow'),
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w800,
                          color: Colors.white.withValues(alpha: 0.82),
                        ),
                      ),
                  ],
                ),
              ),
              Expanded(
                child: _Side(
                  name: rivalName.isEmpty ? tr('duel.rival') : rivalName,
                  appearance: rivalAppearance,
                  points: rivalPoints,
                  ahead: rivalPoints > myPoints,
                  mirrored: true,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // شدُّ الحبل: الشخصيتان تشدّان، والرايةُ تسير إلى المتقدّم بالنقاط.
          if (showTug)
            DuelTugOfWar(
              myPoints: myPoints,
              rivalPoints: rivalPoints,
              myAppearance: myAppearance,
              rivalAppearance: rivalAppearance,
            )
          else
            DuelMomentumBar(myPoints: myPoints, rivalPoints: rivalPoints),
        ],
      ),
    );
  }
}

/// شريطُ الزخم: حصّةُ نقاطي من نقاطنا معاً — أزرقُ من جهتي وورديٌّ من جهته،
/// والحدُّ بينهما يسير إلى من يتقدّم. في البداية والتعادل في المنتصف.
///
/// رقمان يُقرآن، وهذا يُرى بطرف العين: من يسحب الحبلَ الآن.
class DuelMomentumBar extends StatelessWidget {
  const DuelMomentumBar(
      {required this.myPoints, required this.rivalPoints, super.key});

  final int myPoints;
  final int rivalPoints;

  /// حصّتي من النقاط، ونصفٌ حين لا نقاط.
  static double shareOf(int mine, int theirs) {
    final total = mine + theirs;
    return total <= 0 ? 0.5 : (mine / total).clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(end: shareOf(myPoints, rivalPoints)),
      duration: const Duration(milliseconds: 520),
      curve: Curves.easeOutCubic,
      builder: (context, share, _) => SizedBox(
        key: const ValueKey('duel-momentum'),
        height: 10,
        child: LayoutBuilder(
          builder: (context, box) {
            final split = (box.maxWidth * share).clamp(0.0, box.maxWidth);
            return Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(99),
                      gradient: LinearGradient(
                        begin: AlignmentDirectional.centerStart,
                        end: AlignmentDirectional.centerEnd,
                        colors: const [
                          ArenaPalette.me,
                          ArenaPalette.me,
                          ArenaPalette.rival,
                          ArenaPalette.rival
                        ],
                        stops: [0, share, share, 1],
                      ),
                      border: Border.all(
                          color: Colors.white.withValues(alpha: 0.6)),
                    ),
                  ),
                ),
                PositionedDirectional(
                  start: split - 7,
                  top: -2,
                  child: Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: ArenaPalette.goldLight,
                      border: Border.all(color: Colors.white, width: 2),
                      boxShadow: const [
                        BoxShadow(
                            color: Color(0xAAF59E0B),
                            blurRadius: 8,
                            spreadRadius: 1)
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _Side extends StatelessWidget {
  const _Side({
    required this.name,
    required this.appearance,
    required this.points,
    required this.ahead,
    required this.mirrored,
  });

  final String name;
  final Map<String, dynamic>? appearance;
  final int points;
  final bool ahead;

  /// جهةُ النهاية: الصورةُ بعد الرقم لا قبله، فيتقابل اللاعبان.
  final bool mirrored;

  @override
  Widget build(BuildContext context) {
    // ── والمتقدّمُ يكبر قليلاً ويُتوَّج ──
    // رقمان متجاوران لا يُقرأ فرقُهما بطرف العين، وعينُ الطفل على خياراته.
    final face = AnimatedScale(
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutBack,
      scale: ahead ? 1.12 : 1,
      child: SizedBox(
        width: 40,
        height: 44,
        child: Stack(
          alignment: Alignment.bottomCenter,
          children: [
            Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: mirrored ? ArenaPalette.rival : ArenaPalette.me,
                boxShadow: [
                  BoxShadow(
                    color: (mirrored ? ArenaPalette.rival : ArenaPalette.me)
                        .withValues(alpha: ahead ? 0.8 : 0.4),
                    blurRadius: ahead ? 12 : 6,
                  ),
                ],
              ),
              child: StudentAvatarView(
                  size: 34, appearance: appearance, showRing: false),
            ),
            if (ahead)
              const Align(
                alignment: Alignment.topCenter,
                child: Text('👑', style: TextStyle(fontSize: 13)),
              ),
          ],
        ),
      ),
    );

    final label = Column(
      crossAxisAlignment:
          mirrored ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Text(
          name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w800,
            color: Colors.white.withValues(alpha: 0.9),
          ),
        ),
        DuelPointsCounter(points: points, highlight: ahead),
      ],
    );

    return Row(
      mainAxisAlignment:
          mirrored ? MainAxisAlignment.end : MainAxisAlignment.start,
      children: mirrored
          ? [Flexible(child: label), const SizedBox(width: 6), face]
          : [face, const SizedBox(width: 6), Flexible(child: label)],
    );
  }
}

/// عدّادُ النقاط، يصعد إلى قيمته الجديدة ولا يقفز.
///
/// ── ولماذا حركةٌ لا قفزة ──
/// «١٢ ← ٢٧» في إطارٍ واحدٍ لا تُرى، فلا يعرف الطفلُ أنه نال نقاطاً ولا كم.
/// والصعودُ في نصف ثانيةٍ يقول «زادت» بلا أن يُقرأ الرقمان.
class DuelPointsCounter extends StatefulWidget {
  const DuelPointsCounter({
    required this.points,
    this.highlight = false,
    super.key,
  });

  final int points;
  final bool highlight;

  @override
  State<DuelPointsCounter> createState() => _DuelPointsCounterState();
}

/// ‏ومع الصعود «+N» ذهبيةٌ تطفو فوق الرقم وتخبو: كم كسب، بنظرةٍ واحدة.
class _DuelPointsCounterState extends State<DuelPointsCounter> {
  int _gain = 0;
  int _pops = 0;

  @override
  void didUpdateWidget(DuelPointsCounter old) {
    super.didUpdateWidget(old);
    if (widget.points > old.points) {
      _gain = widget.points - old.points;
      _pops++;
    }
  }

  @override
  Widget build(BuildContext context) {
    final still = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    final counter = TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: widget.points.toDouble()),
      duration: const Duration(milliseconds: 520),
      curve: Curves.easeOutCubic,
      builder: (context, value, _) => Text(
        '${value.round()}',
        style: TextStyle(
          fontSize: widget.highlight ? 21 : 19,
          fontWeight: FontWeight.w900,
          color: widget.highlight ? const Color(0xFFFDE68A) : Colors.white,
          height: 1.1,
        ),
      ),
    );
    if (_pops == 0 || still) return counter;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        counter,
        PositionedDirectional(
          start: 0,
          top: -4,
          child: IgnorePointer(
            child: TweenAnimationBuilder<double>(
              key: ValueKey('duel-gain-$_pops'),
              tween: Tween(begin: 0, end: 1),
              duration: const Duration(milliseconds: 950),
              curve: Curves.easeOutCubic,
              builder: (context, t, child) => t >= 1
                  ? const SizedBox.shrink()
                  : Transform.translate(
                      offset: Offset(0, -22 * t),
                      child: Opacity(
                          opacity: (1 - t).clamp(0.0, 1.0), child: child),
                    ),
              child: Text(
                '+$_gain',
                style: const TextStyle(
                  color: Color(0xFFFDE047),
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  shadows: [Shadow(color: Color(0xAAF59E0B), blurRadius: 6)],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// عدّادُ السؤال التنازلي.
///
/// ── ولماذا رقمٌ وشريطٌ معاً ──
/// الرقمُ يُقرأ فيُعرف كم بقي بالضبط، والشريطُ يُرى بطرف العين وعينُ الطفل
/// على خياراته. وأحدُهما وحده يُفوّت أحدَ الأمرين.
class DuelCountdown extends StatelessWidget {
  const DuelCountdown({required this.left, required this.window, super.key});

  final Duration left;
  final Duration window;

  @override
  Widget build(BuildContext context) {
    final total = window.inMilliseconds;
    final share =
        total <= 0 ? 0.0 : (left.inMilliseconds / total).clamp(0.0, 1.0);
    // ── والثلاثُ الأخيرةُ حمراءُ وأكبر ──
    // ثلاثُ ثوانٍ تكفي أن يُقرأ خيارٌ ويُضغط، فهي آخرُ لحظةٍ يُفيد فيها
    // التنبيه. وتنبيهٌ أبكرُ يجعل العدّادَ كلَّه إنذاراً فلا يُنبّه شيء.
    final urgent = left.inMilliseconds <= 3000;
    final tint = urgent ? const Color(0xFFDC2626) : const Color(0xFF16A34A);
    // والسقفُ `ceil` لا `round`: من بقي له ٢٠٠ مللي يرى «١» لا «٠»، والصفرُ
    // المعروضُ وللسؤال بقيّةٌ يُقرأ عطباً.
    final seconds = (left.inMilliseconds / 1000).ceil();
    return Row(
      children: [
        AnimatedScale(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutBack,
          scale: urgent ? 1.2 : 1,
          child: SizedBox(
            width: 26,
            child: Text(
              '$seconds',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                color: tint,
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: share,
              minHeight: 9,
              backgroundColor: tint.withValues(alpha: 0.14),
              valueColor: AlwaysStoppedAnimation<Color>(tint),
            ),
          ),
        ),
      ],
    );
  }
}
