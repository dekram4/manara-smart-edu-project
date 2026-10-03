import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../l10n/student_strings.dart';
import '../models/student_content.dart';
import '../theme/student_theme.dart';
import 'playful_text.dart';

/// بطاقةُ لعبةٍ في «عالم الترفيه»: صورةُ اللعبة الأصلية، وشارةٌ مجسّمة، وزرُّ لعب.
///
/// ── لماذا صورةُ اللعبة نفسها ──
/// رمزٌ عامٌّ يجعل الألعابَ الستَّ متشابهة، فيختار الطفلُ بالاسم وحده. وصورةُ
/// اللعبة تقول ما هي قبل أن يقرأ. ولكل لعبةٍ من GameDistribution صورتُها هناك
/// (`img.gamedistribution.com/<id>-512x512.jpg`)؛ ولعبةٌ بلا صورةٍ تُرسم بتدرّج لونها.
///
/// ── والحركةُ هادئة ──
/// لمعةٌ تمرّ على الصورة كلَّ بضع ثوانٍ، وشارةٌ تطفو قليلاً، وضغطةٌ تُصغّر البطاقة:
/// ما يقول «هذه تُلعب» بلا أن يشغل العينَ عن الاختيار.
class ArcadeGameCard extends StatefulWidget {
  const ArcadeGameCard({
    required this.game,
    required this.index,
    required this.locked,
    required this.requiredLevel,
    required this.currentLevel,
    required this.onPressed,
    super.key,
  });

  final HtmlGame game;
  final int index;
  final bool locked;
  final int requiredLevel;
  final int currentLevel;
  final VoidCallback onPressed;

  @override
  State<ArcadeGameCard> createState() => _ArcadeGameCardState();
}

/// ألوانُ البطاقات بالتناوب.
const _palettes = <Color>[
  Color(0xFF7C3AED),
  Color(0xFFF59E0B),
  Color(0xFF10B981),
  Color(0xFF0EA5E9),
  Color(0xFFE11D48),
  Color(0xFFF97316),
];

/// شارةُ كلِّ لعبةٍ معروفة، ورموزٌ بالتناوب لغيرها.
const _badges = <String, String>{
  'd4a3629101574bc39bd8f9d1888ca58e': '🧠',
  '172e0bd0c40442dbae3d4adb42a98433': '⚡',
  '73c29ef316be4f0bb6d149d8b5a39ff3': '🏺',
  '99ba036a4225425794e2c423fbcf9842': '🚇',
  'd632553ef7264d99aa438310073a6dc3': '🏎️',
  '71b64121c58b4a95b7459e08086dcb00': '🤖',
};
const _fallbackBadges = ['🎮', '🧩', '🚀', '🎯', '🏆', '⭐'];

/// صورةُ لعبةٍ من GameDistribution، إن كان معرّفُها معرّفَها.
String? gameArtUrl(HtmlGame game) => RegExp(r'^[0-9a-f]{32}$').hasMatch(game.id)
    ? 'https://img.gamedistribution.com/${game.id}-512x512.jpg'
    : null;

Color _shade(Color color, double amount) =>
    Color.lerp(color, amount < 0 ? Colors.black : Colors.white, amount.abs())!;

class _ArcadeGameCardState extends State<ArcadeGameCard>
    with TickerProviderStateMixin {
  bool _pressed = false;
  bool _hovered = false;

  /// اللمعةُ التي تمرّ على الصورة، والشارةُ التي تطفو.
  late final AnimationController _shine = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 4200),
  );
  late final AnimationController _float = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2600),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final still = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (still || widget.locked) {
      _shine.stop();
      _float.stop();
    } else {
      // تبدأ كلُّ بطاقةٍ في لحظةٍ غير أختها: لا تلمع الستُّ معاً.
      if (!_shine.isAnimating) {
        _shine.value = (widget.index * 0.17) % 1;
        _shine.repeat();
      }
      if (!_float.isAnimating) {
        _float.value = (widget.index * 0.23) % 1;
        _float.repeat(reverse: true);
      }
    }
  }

  @override
  void dispose() {
    _shine.dispose();
    _float.dispose();
    super.dispose();
  }

  Color get _tint => widget.locked
      ? const Color(0xFF94A3B8)
      : _palettes[widget.index % _palettes.length];

  String get _badge =>
      _badges[widget.game.id] ??
      _fallbackBadges[widget.index % _fallbackBadges.length];

  int get _stars => widget.locked
      ? 0
      : (widget.currentLevel - widget.requiredLevel + 1).clamp(0, 3).toInt();

  @override
  Widget build(BuildContext context) {
    final tint = _tint;
    final dark = StudentSurface.isDark(context);
    final lift = _pressed ? 0.0 : (_hovered ? -5.0 : 0.0);
    return Semantics(
      button: true,
      label: widget.game.title,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          onTapDown: (_) => setState(() => _pressed = true),
          onTapCancel: () => setState(() => _pressed = false),
          onTapUp: (_) => setState(() => _pressed = false),
          onTap: widget.onPressed,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            transform: Matrix4.translationValues(0, lift, 0)
              ..scaleByDouble(_pressed ? 0.96 : 1, _pressed ? 0.96 : 1, 1, 1),
            transformAlignment: Alignment.center,
            // إطارٌ بتدرّج لون اللعبة: حدٌّ يلمع لا خطٌّ رمادي.
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(26),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [_shade(tint, 0.45), tint, _shade(tint, -0.2)],
              ),
              boxShadow: [
                BoxShadow(
                  color: tint.withValues(alpha: _hovered ? 0.5 : 0.32),
                  blurRadius: _hovered ? 26 : 16,
                  offset: Offset(0, _hovered ? 12 : 8),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: dark
                        ? [const Color(0xFF1E1B3A), const Color(0xFF15122B)]
                        : [Colors.white, _shade(tint, 0.9)],
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(flex: 11, child: _artwork(tint)),
                    Expanded(flex: 10, child: _body(tint, dark)),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _artwork(Color tint) {
    final url = gameArtUrl(widget.game);
    Widget fallback() => DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [_shade(tint, 0.35), tint, _shade(tint, -0.35)],
            ),
          ),
          child: Center(
            child: Text(_badge, style: const TextStyle(fontSize: 46)),
          ),
        );
    Widget art = url == null
        ? fallback()
        : Image.network(
            url,
            fit: BoxFit.cover,
            gaplessPlayback: true,
            // وحتى تصل الصورةُ: تدرّجُ اللعبة بشارتها، لا بطاقةٌ فارغة.
            loadingBuilder: (context, child, progress) =>
                progress == null ? child : fallback(),
            errorBuilder: (context, _, __) => fallback(),
          );
    if (widget.locked) {
      // مقفلة: الصورةُ رماديةٌ باهتة، فيُعرف قبل القراءة أنها لم تُفتح.
      art = ColorFiltered(
        colorFilter: const ColorFilter.matrix([
          0.2126,
          0.7152,
          0.0722,
          0,
          0,
          0.2126,
          0.7152,
          0.0722,
          0,
          0,
          0.2126,
          0.7152,
          0.0722,
          0,
          0,
          0,
          0,
          0,
          1,
          0,
        ]),
        child: art,
      );
    }
    return Stack(
      fit: StackFit.expand,
      clipBehavior: Clip.none,
      children: [
        art,
        // لمعةٌ زجاجية أعلى الصورة، وظلٌّ أسفلها تجلس عليه الشارة.
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.white.withValues(alpha: 0.22),
                Colors.transparent,
                Colors.black.withValues(alpha: widget.locked ? 0.55 : 0.35),
              ],
              stops: const [0, 0.45, 1],
            ),
          ),
        ),
        if (!widget.locked) _ShineSweep(animation: _shine),
        if (widget.locked)
          const Center(
              child: _Orb3D(emoji: '🔒', color: Color(0xFF64748B), size: 54)),
        PositionedDirectional(
          start: 10,
          bottom: 8,
          child: AnimatedBuilder(
            animation: _float,
            builder: (context, child) => Transform.translate(
              offset: Offset(0, -3 * math.sin(_float.value * math.pi)),
              child: child,
            ),
            child: _Orb3D(
                emoji: widget.locked ? '🎮' : _badge, color: tint, size: 44),
          ),
        ),
        if (!widget.locked)
          PositionedDirectional(
            end: 8,
            top: 8,
            child: _StarPill(stars: _stars),
          ),
      ],
    );
  }

  Widget _body(Color tint, bool dark) {
    final ink = dark ? Colors.white : _shade(tint, -0.55);
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            widget.game.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: StudentPlayfulFont.style(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: ink,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 2),
          Expanded(
            child: Text(
              widget.game.subtitle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11.5,
                height: 1.3,
                fontWeight: FontWeight.w700,
                color: StudentSurface.mutedInk(context),
              ),
            ),
          ),
          if (widget.locked) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: widget.requiredLevel <= 0
                    ? 1
                    : (widget.currentLevel / widget.requiredLevel)
                        .clamp(0.0, 1.0),
                minHeight: 5,
                backgroundColor: StudentSurface.track(context),
                valueColor: const AlwaysStoppedAnimation(Color(0xFFF59E0B)),
              ),
            ),
            const SizedBox(height: 6),
          ],
          _PlayPill(
            tint: tint,
            label: widget.locked
                ? trf('arcade.unlockAt', {'level': '${widget.requiredLevel}'})
                : '▶  ${tr('game.play')}',
          ),
        ],
      ),
    );
  }
}

/// شارةٌ مجسّمة: كرةٌ مضاءةٌ من أعلى اليسار، بلمعةٍ وحافةٍ بيضاء وظلّ.
class _Orb3D extends StatelessWidget {
  const _Orb3D({required this.emoji, required this.color, required this.size});

  final String emoji;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                center: const Alignment(-0.35, -0.45),
                radius: 0.95,
                colors: [_shade(color, 0.55), color, _shade(color, -0.4)],
                stops: const [0, 0.55, 1],
              ),
              border: Border.all(color: Colors.white, width: 2.4),
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.55),
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                ),
                const BoxShadow(
                  color: Color(0x40000000),
                  blurRadius: 3,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            alignment: Alignment.center,
            child: Text(
              emoji,
              style: TextStyle(
                fontSize: size * 0.48,
                shadows: const [
                  Shadow(
                      color: Color(0x55000000),
                      blurRadius: 4,
                      offset: Offset(0, 2))
                ],
              ),
            ),
          ),
          // اللمعةُ: بيضاويٌّ أبيضُ في أعلى الكرة.
          Positioned(
            left: size * 0.2,
            top: size * 0.12,
            child: Container(
              width: size * 0.34,
              height: size * 0.18,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(size),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.white.withValues(alpha: 0.75),
                    Colors.white.withValues(alpha: 0),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// لمعةٌ مائلةٌ تعبر الصورةَ في أوّل كلِّ دورة، ثم تسكن.
class _ShineSweep extends StatelessWidget {
  const _ShineSweep({required this.animation});

  final Animation<double> animation;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: animation,
        builder: (context, _) {
          final t = animation.value;
          if (t > 0.32) return const SizedBox.shrink();
          final travel = Curves.easeInOut.transform(t / 0.32);
          return LayoutBuilder(
            builder: (context, box) {
              final band = box.maxWidth * 0.45;
              final x = -band + (box.maxWidth + band * 2) * travel;
              return Stack(
                children: [
                  Positioned(
                    left: x - band,
                    top: -box.maxHeight * 0.3,
                    bottom: -box.maxHeight * 0.3,
                    width: band,
                    child: Transform.rotate(
                      angle: 0.35,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.white.withValues(alpha: 0),
                              Colors.white.withValues(alpha: 0.38),
                              Colors.white.withValues(alpha: 0),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

/// نجومُ التقدّم في اللعبة، فوق الصورة.
class _StarPill extends StatelessWidget {
  const _StarPill({required this.stars});

  final int stars;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.38),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < 3; i++)
            Icon(
              i < stars ? Icons.star_rounded : Icons.star_outline_rounded,
              size: 14,
              color: i < stars ? const Color(0xFFFBBF24) : Colors.white70,
            ),
        ],
      ),
    );
  }
}

/// زرُّ اللعب: مجسّمٌ بحافةٍ سفليةٍ داكنة، ولمعةٍ أعلاه.
class _PlayPill extends StatelessWidget {
  const _PlayPill({required this.tint, required this.label});

  final Color tint;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [_shade(tint, 0.25), tint],
        ),
        boxShadow: [
          BoxShadow(color: _shade(tint, -0.3), offset: const Offset(0, 3)),
          BoxShadow(
              color: tint.withValues(alpha: 0.35),
              blurRadius: 8,
              offset: const Offset(0, 5)),
        ],
      ),
      child: Text(
        label,
        textAlign: TextAlign.center,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: StudentPlayfulFont.style(
          fontSize: 13.5,
          fontWeight: FontWeight.w900,
          color: Colors.white,
        ),
      ),
    );
  }
}
