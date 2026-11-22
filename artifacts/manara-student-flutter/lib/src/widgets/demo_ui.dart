import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/student_strings.dart';

/// هويّةُ واجهات الزائر والباقات: ذهبٌ دافئ وبنفسجُ منارة، بحركةٍ خفيفة.
///
/// كلُّ زرٍّ ونافذةٍ جديدة تُبنى من هنا، فلا يبدو شيءٌ منها مضافاً من خارج
/// التطبيق. والحركةُ تسكن حين يطلب الجهازُ تقليلها (`disableAnimations`).
abstract final class DemoPalette {
  static const goldLight = Color(0xFFFDE68A);
  static const gold = Color(0xFFF59E0B);
  static const goldDeep = Color(0xFFB45309);
  static const goldInk = Color(0xFF451A03);

  static const violetLight = Color(0xFFA78BFA);
  static const violet = Color(0xFF7C3AED);
  static const violetDeep = Color(0xFF4B267F);
  static const magenta = Color(0xFFDB2777);

  static const goldGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [goldLight, gold, goldDeep],
    stops: [0, 0.55, 1],
  );

  static const violetGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [violetDeep, violet, magenta],
    stops: [0, 0.6, 1],
  );

  static const whatsappGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF34D399), Color(0xFF16A34A), Color(0xFF166534)],
  );
}

bool _still(BuildContext context) => MediaQuery.maybeOf(context)?.disableAnimations ?? false;

/// ينضغط قليلاً تحت الإصبع ويرتدّ — للأزرار والبطاقات كلِّها.
class DemoPressable extends StatefulWidget {
  const DemoPressable({super.key, required this.child, this.onTap, this.scale = 0.95});

  final Widget child;
  final VoidCallback? onTap;
  final double scale;

  @override
  State<DemoPressable> createState() => _DemoPressableState();
}

class _DemoPressableState extends State<DemoPressable> {
  bool _down = false;

  void _set(bool down) {
    if (widget.onTap == null || _down == down) return;
    setState(() => _down = down);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _set(true),
      onTapUp: (_) => _set(false),
      onTapCancel: () => _set(false),
      onTap: widget.onTap == null
          ? null
          : () {
              HapticFeedback.lightImpact();
              widget.onTap!();
            },
      child: AnimatedScale(
        scale: _down ? widget.scale : 1,
        duration: Duration(milliseconds: _still(context) ? 0 : 110),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}

/// بريقٌ يمرّ على [child] كلَّ ثوانٍ — لمعةُ الذهب على الزرّ الرئيس.
class DemoShimmer extends StatefulWidget {
  const DemoShimmer({super.key, required this.child, this.period = const Duration(milliseconds: 2600)});

  final Widget child;
  final Duration period;

  @override
  State<DemoShimmer> createState() => _DemoShimmerState();
}

class _DemoShimmerState extends State<DemoShimmer> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: widget.period);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_still(context)) {
      _c.stop();
    } else if (!_c.isAnimating) {
      _c.repeat();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_still(context)) return widget.child;
    return AnimatedBuilder(
      animation: _c,
      child: widget.child,
      builder: (context, child) {
        // ‏الثلثُ الأوّل من الدورة يمرّ فيه البريق، والباقي سكون.
        final t = (_c.value * 3).clamp(0.0, 1.0);
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (rect) => LinearGradient(
            begin: Alignment(-1.6 + 3.2 * t, -0.4),
            end: Alignment(-0.9 + 3.2 * t, 0.4),
            colors: [Colors.white.withValues(alpha: 0), Colors.white.withValues(alpha: 0.42), Colors.white.withValues(alpha: 0)],
          ).createShader(rect),
          child: child,
        );
      },
    );
  }
}

/// زرٌّ بتدرّج: ذهبيّ للفعل الرئيس، أو بنفسجيّ، أو أخضرُ واتساب.
///
/// النصُّ يصغر ولا يُقصّ (`FittedBox`)، والزرُّ يمتدّ بعرض ما يُعطى إن طُلب.
class DemoGradientButton extends StatelessWidget {
  const DemoGradientButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.gradient = DemoPalette.goldGradient,
    this.foreground = DemoPalette.goldInk,
    this.expand = true,
    this.height = 54,
    this.shimmer = false,
    this.busy = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final Gradient gradient;
  final Color foreground;
  final bool expand;
  final double height;
  final bool shimmer;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !busy;
    final glow = gradient.colors[gradient.colors.length ~/ 2];
    Widget body = Container(
      height: height,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(height / 2),
        border: Border.all(color: Colors.white.withValues(alpha: 0.55), width: 1.6),
        boxShadow: enabled
            ? [BoxShadow(color: glow.withValues(alpha: 0.45), blurRadius: 18, offset: const Offset(0, 7))]
            : const [],
      ),
      alignment: Alignment.center,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (busy)
            SizedBox.square(
              dimension: 20,
              child: CircularProgressIndicator(strokeWidth: 2.6, color: foreground),
            )
          else if (icon != null)
            Icon(icon, color: foreground, size: 24),
          if (busy || icon != null) const SizedBox(width: 10),
          Text(
            label,
            maxLines: 1,
            style: TextStyle(color: foreground, fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: 0.2),
          ),
        ]),
      ),
    );
    if (shimmer && enabled) body = DemoShimmer(child: body);
    body = Opacity(opacity: enabled || busy ? 1 : 0.55, child: body);
    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      child: DemoPressable(
        onTap: enabled ? onPressed : null,
        child: expand ? SizedBox(width: double.infinity, child: body) : body,
      ),
    );
  }
}

/// دخولٌ متدرّج: يظهر العنصرُ صاعداً مع تلاشٍ، بعد غيره بقليل ([index]).
class DemoEntrance extends StatelessWidget {
  const DemoEntrance({super.key, required this.index, required this.child});

  final int index;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (_still(context)) return child;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 380 + 70 * math.min(index, 8)),
      curve: Curves.easeOutCubic,
      child: child,
      builder: (context, t, child) {
        // ‏كلُّ عنصرٍ ينتظر دورَه في أوّل الحركة، ثم يدخل.
        final delay = math.min(index, 8) * 0.07;
        final p = ((t - delay) / (1 - delay)).clamp(0.0, 1.0);
        return Opacity(
          opacity: p,
          child: Transform.translate(offset: Offset(0, 18 * (1 - p)), child: child),
        );
      },
    );
  }
}

/// رأسُ النوافذ: شريطٌ بنفسجيٌّ متدرّج وشارةٌ ذهبيّة في وسطه.
class DemoHeaderBadge extends StatelessWidget {
  const DemoHeaderBadge({super.key, required this.emoji, this.size = 64});

  final String emoji;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: DemoPalette.goldGradient,
        border: Border.all(color: Colors.white, width: 3),
        boxShadow: [BoxShadow(color: DemoPalette.gold.withValues(alpha: 0.5), blurRadius: 16)],
      ),
      alignment: Alignment.center,
      child: Text(emoji, style: TextStyle(fontSize: size * 0.46)),
    );
  }
}

/// نافذةٌ بهويّة الزائر: رأسٌ بنفسجيّ وشارةٌ ذهبيّة، وجسمٌ يتمرّر إن طال،
/// وأزرارٌ تلتفّ في الشاشات الضيّقة بدل أن تتداخل.
Future<T?> showDemoDialog<T>({
  required BuildContext context,
  Key? key,
  required String emoji,
  required String title,
  required Widget body,
  required List<Widget> actions,
}) {
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: true,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor: const Color(0xAA1E1033),
    transitionDuration: Duration(milliseconds: _still(context) ? 0 : 260),
    pageBuilder: (context, _, __) => _DemoDialog(
      key: key,
      emoji: emoji,
      title: title,
      body: body,
      actions: actions,
    ),
    transitionBuilder: (context, animation, _, child) {
      final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutBack, reverseCurve: Curves.easeIn);
      return FadeTransition(
        opacity: animation,
        child: ScaleTransition(scale: Tween(begin: 0.88, end: 1.0).animate(curved), child: child),
      );
    },
  );
}

class _DemoDialog extends StatelessWidget {
  const _DemoDialog({super.key, required this.emoji, required this.title, required this.body, required this.actions});

  final String emoji;
  final String title;
  final Widget body;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    return SafeArea(
      child: Center(
        child: Padding(
          padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + media.viewInsets.bottom),
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: 460, maxHeight: media.size.height * 0.9),
            child: Material(
              color: dark ? const Color(0xFF221536) : Colors.white,
              elevation: 18,
              shadowColor: DemoPalette.violet.withValues(alpha: 0.5),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(28),
                side: BorderSide(color: DemoPalette.gold.withValues(alpha: 0.7), width: 2),
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Container(
                  decoration: const BoxDecoration(gradient: DemoPalette.violetGradient),
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
                  child: Column(children: [
                    DemoHeaderBadge(emoji: emoji, size: 58),
                    const SizedBox(height: 10),
                    Text(
                      title,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900),
                    ),
                  ]),
                ),
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                    child: DefaultTextStyle.merge(
                      style: TextStyle(fontSize: 15.5, height: 1.6, color: dark ? Colors.white : const Color(0xFF1F2937)),
                      child: body,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  child: Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 10,
                    runSpacing: 10,
                    children: actions,
                  ),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

/// لوحةُ اختيار مسار الزائر: بطاقتان متدرّجتان تنضغطان، جنباً إلى جنب على
/// الشاشات العريضة وتحت بعضهما على الجوال. تعيد `kg` أو `grade4`.
class DemoTrackSheet extends StatelessWidget {
  const DemoTrackSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final tracks = [
      ('kg', '🧸', tr('demo.track.kg'), tr('demo.track.kgHint'), const [Color(0xFFEC4899), Color(0xFFF59E0B)]),
      ('grade4', '📘', tr('demo.track.grade4'), tr('demo.track.grade4Hint'), const [Color(0xFF2563EB), DemoPalette.violet]),
    ];
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: media.size.height * 0.92),
      child: Container(
        decoration: BoxDecoration(
          color: dark ? const Color(0xFF221536) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
          border: Border.all(color: DemoPalette.gold.withValues(alpha: 0.6), width: 1.5),
        ),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(18, 10, 18, 18),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Center(
                child: Container(
                  width: 44,
                  height: 5,
                  decoration: BoxDecoration(color: DemoPalette.violetLight, borderRadius: BorderRadius.circular(4)),
                ),
              ),
              const SizedBox(height: 14),
              const Center(child: DemoHeaderBadge(emoji: '🧭', size: 60)),
              const SizedBox(height: 10),
              Text(tr('demo.pickTrack'),
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900, color: dark ? Colors.white : DemoPalette.violetDeep)),
              const SizedBox(height: 4),
              Text(tr('demo.pickTrackHint'),
                  textAlign: TextAlign.center,
                  style: TextStyle(fontWeight: FontWeight.w700, color: dark ? Colors.white70 : const Color(0xFF6B7280))),
              const SizedBox(height: 16),
              LayoutBuilder(builder: (context, box) {
                final side = box.maxWidth >= 440;
                final cards = [
                  for (final (i, t) in tracks.indexed)
                    DemoEntrance(
                      index: i,
                      child: _TrackCard(id: t.$1, emoji: t.$2, title: t.$3, hint: t.$4, colors: t.$5),
                    ),
                ];
                if (side) {
                  return IntrinsicHeight(
                    child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      Expanded(child: cards[0]),
                      const SizedBox(width: 12),
                      Expanded(child: cards[1]),
                    ]),
                  );
                }
                return Column(children: [cards[0], const SizedBox(height: 12), cards[1]]);
              }),
              const SizedBox(height: 14),
              Text(tr('demo.instant'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontWeight: FontWeight.w800, color: DemoPalette.goldDeep)),
            ]),
          ),
        ),
      ),
    );
  }
}

class _TrackCard extends StatelessWidget {
  const _TrackCard({required this.id, required this.emoji, required this.title, required this.hint, required this.colors});

  final String id;
  final String emoji;
  final String title;
  final String hint;
  final List<Color> colors;

  @override
  Widget build(BuildContext context) {
    return DemoPressable(
      key: ValueKey('demo-track-$id'),
      onTap: () => Navigator.pop(context, id),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: colors),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white.withValues(alpha: 0.6), width: 2),
          boxShadow: [BoxShadow(color: colors.last.withValues(alpha: 0.4), blurRadius: 18, offset: const Offset(0, 8))],
        ),
        child: Row(children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.22), shape: BoxShape.circle),
            alignment: Alignment.center,
            child: Text(emoji, style: const TextStyle(fontSize: 30)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              Text(title, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900, height: 1.3)),
              const SizedBox(height: 4),
              Text(hint, style: TextStyle(color: Colors.white.withValues(alpha: 0.92), fontSize: 13, fontWeight: FontWeight.w700, height: 1.4)),
            ]),
          ),
          const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white, size: 18),
        ]),
      ),
    );
  }
}
