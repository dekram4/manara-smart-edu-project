import 'package:flutter/material.dart';

import '../l10n/student_strings.dart';
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
    super.key,
  });

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
          colors: [Color(0xFF4C1D95), Color(0xFF7C3AED)],
          begin: AlignmentDirectional.topStart,
          end: AlignmentDirectional.bottomEnd,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Row(
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
                Text(
                  tr(live ? 'duel.liveNow' : 'duel.ghost'),
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
            StudentAvatarView(size: 36, appearance: appearance, showRing: false),
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
class DuelPointsCounter extends StatelessWidget {
  const DuelPointsCounter({
    required this.points,
    this.highlight = false,
    super.key,
  });

  final int points;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: points.toDouble()),
      duration: const Duration(milliseconds: 520),
      curve: Curves.easeOutCubic,
      builder: (context, value, _) => Text(
        '${value.round()}',
        style: TextStyle(
          fontSize: highlight ? 21 : 19,
          fontWeight: FontWeight.w900,
          color: highlight ? const Color(0xFFFDE68A) : Colors.white,
          height: 1.1,
        ),
      ),
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
