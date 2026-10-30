import 'dart:math' as math;

import 'package:flutter/material.dart';


/// مُدَد الحركة ومنحنياتها، منقولةً بأرقامها من مواصفة الحركة
/// (LAMSA_ANIMATION_SPEC.md §1، الجدولان D وE).
///
/// ── مصدرٌ واحد للأرقام ──
/// كلُّ حركةٍ جديدة في التطبيق تأخذ مدّتها ومنحناها من هنا، فإن عُدّل رقمٌ
/// بعد مقارنته بالفيديو جنباً إلى جنب عُدّل في موضعٍ واحد. والحركاتُ الأصلية
/// في منارة — توزيعُ البطاقات وتنفّسُها ونابضُ الضغط والشخصيات — لا تقرأ من
/// هنا ولا تتغيّر.
class MotionDurations {
  const MotionDurations._();

  static const skeletonToArt = Duration(milliseconds: 90);
  static const morph = Duration(milliseconds: 260);
  static const morphContent = Duration(milliseconds: 160);
  static const avatarStagger = Duration(milliseconds: 80);
  static const avatarFade = Duration(milliseconds: 200);
  static const scrimIn = Duration(milliseconds: 180);
  static const promoIn = Duration(milliseconds: 220);
  static const promoOut = Duration(milliseconds: 280);
  static const pressIn = Duration(milliseconds: 80);
  static const pressOut = Duration(milliseconds: 140);
  static const overlayOut = Duration(milliseconds: 240);
  static const playerCardIn = Duration(milliseconds: 220);

  /// الشاشةُ السوداء قبل بطاقة المشغّل (§5.7: «≈ 0.7 s»).
  static const playerBlackHold = Duration(milliseconds: 700);

  /// تلاشي الأسود عن المشغّل (§6.6).
  static const playerBlackOut = Duration(milliseconds: 160);
}

class MotionCurves {
  const MotionCurves._();

  /// الدخول والتحوّل: `bezier(0.2, 0.0, 0.0, 1.0)`.
  static const decel = Cubic(0.2, 0.0, 0.0, 1.0);

  /// الخروج بالتلاشي: `bezier(0.4, 0.0, 0.2, 1.0)`.
  static const std = Cubic(0.4, 0.0, 0.2, 1.0);

  /// `bezier(0.3, 0.0, 1.0, 1.0)`.
  static const accel = Cubic(0.3, 0.0, 1.0, 1.0);

  /// `Easing.out(Easing.back(1.4))`: ارتدادٌ خفيف عند الظهور.
  static const backOut = _BackOutCurve(1.4);
}

/// `Easing.out(Easing.back(s))` في Reanimated: `1 - back(1 - t)` حيث
/// `back(t) = t² ((s + 1) t − s)`.
class _BackOutCurve extends Curve {
  const _BackOutCurve(this.overshoot);

  final double overshoot;

  @override
  double transformInternal(double t) {
    final u = 1 - t;
    return 1 - u * u * ((overshoot + 1) * u - overshoot);
  }
}

/// ألوان المواصفة التي تحتاجها هذه الحركات وحدها — لا تُستبدل بها ألوانُ منارة.
class MotionColors {
  const MotionColors._();

  static const cardPressed = Color(0xFFEADFF7);
  static const scrim = Color(0xD120083C); // rgba(32, 8, 60, 0.82)
  static const teal = Color(0xFF17A695);
  static const lockYellow = Color(0xFFFFE600);
  static const orbitTeal = Color(0xFF2BB8A3);
  static const orbitPurple = Color(0xFF5A1A7A);
}

bool _reduceMotion(BuildContext context) =>
    MediaQuery.maybeOf(context)?.disableAnimations ?? false;

// ═══════════════════════════════════════════════════════════════════════
// §5.1 — الفنّ يظهر بعد البطاقة الهيكلية
// ═══════════════════════════════════════════════════════════════════════

/// `frameBuilder` لصورة بطاقة: البطاقةُ وعنوانُها أولاً، والفنُّ يدخل بتلاشٍ
/// في [MotionDurations.skeletonToArt] حين يُفكّ ترميزه. وما حُمّل متزامناً
/// (من الذاكرة) يظهر كما هو بلا حركة — لا وميض عند العودة إلى الشاشة.
Widget motionArtFrameBuilder(
  BuildContext context,
  Widget child,
  int? frame,
  bool wasSynchronouslyLoaded,
) {
  if (wasSynchronouslyLoaded || _reduceMotion(context)) return child;
  return AnimatedOpacity(
    opacity: frame == null ? 0 : 1,
    duration: MotionDurations.skeletonToArt,
    curve: Curves.easeOut,
    child: child,
  );
}

// ═══════════════════════════════════════════════════════════════════════
// §5.4 — انتقالُ القسم
// ═══════════════════════════════════════════════════════════════════════

/// انتقالُ القسم: المحتوى في لحظته، وشريطٌ رفيعٌ أعلاه ما دام يُحمَّل.
///
/// ── لماذا لا غطاءَ ولا مُحمِّل ──
/// كانت الشاشةُ تُغطّى بتعتيمٍ ومُحمِّلِ الشخصيتين الدوّارتين حتى يصل المحتوى،
/// فيلمس الطفلُ البطاقة ويرى شخصيتين تدوران ثانيتين أو ثلاثاً قبل أن يرى
/// شيئاً منها. والآن تُفتح البطاقةُ فوراً بخلفيتها وما يُعرض منها، وما يُحمَّل
/// يكتفي بشريطٍ رفيعٍ في أعلاها لا يحجب ولا يمنع اللمس.
class MotionSectionOverlay extends StatelessWidget {
  const MotionSectionOverlay({
    required this.ready,
    required this.child,
    this.label,
    super.key,
  });

  final bool ready;
  final Widget child;

  /// ما يقرؤه قارئ الشاشة أثناء التحميل.
  final String? label;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        child,
        if (!ready)
          Align(
            alignment: Alignment.topCenter,
            child: IgnorePointer(
              child: Semantics(
                label: label,
                liveRegion: true,
                child: const LinearProgressIndicator(
                  key: ValueKey('section-loading'),
                  minHeight: 3,
                  backgroundColor: Colors.transparent,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// §5.3 / §6.4 — النافذة المنبثقة
// ═══════════════════════════════════════════════════════════════════════

/// يُظهر نافذةً بحركة المواصفة: الستارةُ تتلاشى داخلةً، والبطاقةُ تكبر من
/// 0.9 إلى 1 مع ظهورها في [MotionDurations.promoIn] بارتدادٍ خفيف
/// ([MotionCurves.backOut])، وتخرج كلتاهما بالتلاشي في
/// [MotionDurations.promoOut] ([MotionCurves.std]).
///
/// بديلٌ عن `showDialog` بالمعاملات نفسها التي يستعملها التطبيق.
Future<T?> showMotionDialog<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool barrierDismissible = true,
  Color? barrierColor,
}) {
  return Navigator.of(context).push<T>(
    _MotionDialogRoute<T>(
      builder: builder,
      barrierDismissible: barrierDismissible,
      barrierColor: barrierColor ?? MotionColors.scrim,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      capturedThemes: InheritedTheme.capture(
        from: context,
        to: Navigator.of(context).context,
      ),
    ),
  );
}

class _MotionDialogRoute<T> extends PopupRoute<T> {
  _MotionDialogRoute({
    required this.builder,
    required this.barrierDismissible,
    required this.barrierColor,
    required this.barrierLabel,
    required this.capturedThemes,
  });

  final WidgetBuilder builder;
  final CapturedThemes capturedThemes;

  @override
  final bool barrierDismissible;

  @override
  final Color barrierColor;

  @override
  final String? barrierLabel;

  @override
  Duration get transitionDuration => MotionDurations.promoIn;

  @override
  Duration get reverseTransitionDuration => MotionDurations.promoOut;

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) {
    return capturedThemes.wrap(
      SafeArea(child: Builder(builder: builder)),
    );
  }

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    if (_reduceMotion(context)) {
      return FadeTransition(opacity: animation, child: child);
    }
    final scale = CurvedAnimation(
      parent: animation,
      curve: MotionCurves.backOut,
      reverseCurve: MotionCurves.std,
    );
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        final reversing = animation.status == AnimationStatus.reverse;
        // دخولاً: `min(1, v × 1.4)` كما في §6.4. وخروجاً: تلاشٍ بالمنحنى std.
        final opacity = reversing
            ? MotionCurves.std.transform(animation.value)
            : math.min(1.0, animation.value * 1.4);
        return Opacity(
          opacity: opacity.clamp(0.0, 1.0),
          child: Transform.scale(scale: 0.9 + 0.1 * scale.value, child: child),
        );
      },
      child: child,
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// §5.2 / §6.3 — قائمةُ الاختيار: ظهورٌ متتابع، وغيرُ المختار نصفُ شفاف
// ═══════════════════════════════════════════════════════════════════════

/// عنصرٌ في قائمة اختيار (الشخصيات): يدخل بعد سابقه بـ
/// [MotionDurations.avatarStagger] في [MotionDurations.avatarFade]، من 0.9
/// إلى 1. وغيرُ المختار بشفافية 0.5، والانتقال بينهما في المدّة نفسها.
class MotionStaggeredPick extends StatelessWidget {
  const MotionStaggeredPick({
    required this.index,
    required this.selected,
    required this.child,
    this.startDelay = Duration.zero,
    super.key,
  });

  final int index;
  final bool selected;
  final Widget child;

  /// يبدأ التتابع بعده — نهايةُ تحوّل الحاوية إن فُتحت الشاشة به.
  final Duration startDelay;

  @override
  Widget build(BuildContext context) {
    final reduce = _reduceMotion(context);
    final delay = startDelay + MotionDurations.avatarStagger * index;
    return AnimatedOpacity(
      opacity: selected ? 1 : 0.5,
      duration: reduce ? Duration.zero : MotionDurations.avatarFade,
      child: reduce
          ? child
          : TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: delay + MotionDurations.avatarFade,
              builder: (context, raw, child) {
                // التأخير جزءٌ من المدّة: ما قبله ثابتٌ عند الصفر.
                final total =
                    (delay + MotionDurations.avatarFade).inMicroseconds;
                final wait = delay.inMicroseconds / (total == 0 ? 1 : total);
                final v = wait >= 1
                    ? raw
                    : ((raw - wait) / (1 - wait)).clamp(0.0, 1.0);
                return Opacity(
                  opacity: v,
                  child: Transform.scale(scale: 0.9 + 0.1 * v, child: child),
                );
              },
              child: child,
            ),
    );
  }
}

/// تحوّل الحاوية (§5.2): الصفحةُ تنمو من مستطيل ما لُمس — صورةُ الشخصية في
/// الشريط — إلى الشاشة كلها في [MotionDurations.morph] بمنحنى
/// [MotionCurves.decel]. اللوحُ أبيضُ بشفافية 0.4 يصير معتماً عند 60%، والمحتوى
/// يظهر بعدها. والإغلاقُ عكسُه بالمنحنى std.
Widget motionContainerTransform({
  required BuildContext context,
  required Animation<double> animation,
  required Rect source,
  required Widget child,
}) {
  if (_reduceMotion(context)) {
    return FadeTransition(opacity: animation, child: child);
  }
  return AnimatedBuilder(
    animation: animation,
    child: child,
    builder: (context, child) {
      final reversing = animation.status == AnimationStatus.reverse;
      final p = (reversing ? MotionCurves.std : MotionCurves.decel)
          .transform(animation.value);
      final screen = Offset.zero & MediaQuery.sizeOf(context);
      final rect = Rect.lerp(source, screen, p)!;
      // اللوح: يظهر في أول 5%، أبيضُ 0.4 ثم معتمٌ عند 60%.
      final panelOpacity = (animation.value / 0.05).clamp(0.0, 1.0);
      final white = p < 0.6 ? 0.4 + (p / 0.6) * 0.6 : 1.0;
      final content = ((p - 0.6) / 0.4).clamp(0.0, 1.0);
      final radius = p < 1 ? 12 + 4 * p : 0.0;
      return Stack(
        children: [
          Positioned.fromRect(
            rect: rect,
            child: Opacity(
              opacity: panelOpacity,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(radius),
                child: ColoredBox(
                  color: Colors.white.withValues(alpha: white),
                  child: Opacity(
                    opacity: content,
                    // المحتوى بمقاس الشاشة دائماً، والحاويةُ تقصّه: لا يُعاد
                    // تخطيطُ الصفحة في كل إطار وهي تنمو.
                    child: OverflowBox(
                      alignment: Alignment.topLeft,
                      minWidth: screen.width,
                      maxWidth: screen.width,
                      minHeight: screen.height,
                      maxHeight: screen.height,
                      child: Transform.translate(
                        offset: -rect.topLeft,
                        child: child,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    },
  );
}

/// مستطيلُ عنصرٍ على الشاشة، لبدء [motionContainerTransform] منه.
Rect? motionRectOf(BuildContext context) {
  final box = context.findRenderObject();
  if (box is! RenderBox || !box.hasSize || !box.attached) return null;
  return box.localToGlobal(Offset.zero) & box.size;
}

// ═══════════════════════════════════════════════════════════════════════
// §5.7 / §6.6 — دخولُ المشغّل
// ═══════════════════════════════════════════════════════════════════════

/// شاشةٌ سوداء بمؤشّرٍ أبيض رفيع وزرّ إغلاقٍ أبيض مستدير، مدّة
/// [MotionDurations.playerBlackHold]، ثم يتلاشى الأسود في
/// [MotionDurations.playerBlackOut] وتظهر بطاقةُ المشغّل من 0.96 إلى 1 مع
/// ظهورها في [MotionDurations.playerCardIn] ([MotionCurves.decel]).
class MotionPlayerEntrance extends StatefulWidget {
  const MotionPlayerEntrance({required this.child, super.key});

  final Widget child;

  @override
  State<MotionPlayerEntrance> createState() => _MotionPlayerEntranceState();
}

class _MotionPlayerEntranceState extends State<MotionPlayerEntrance>
    with TickerProviderStateMixin {
  late final AnimationController _black = AnimationController(
    vsync: this,
    duration: MotionDurations.playerBlackOut,
    value: 1,
  );
  late final AnimationController _card = AnimationController(
    vsync: this,
    duration: MotionDurations.playerCardIn,
  );
  late final Animation<double> _cardCurve =
      CurvedAnimation(parent: _card, curve: MotionCurves.decel);
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (_reduceMotion(context)) {
      _black.value = 0;
      _card.value = 1;
      return;
    }
    Future<void>.delayed(MotionDurations.playerBlackHold, () {
      if (!mounted) return;
      _black.reverse();
      _card.forward();
    });
  }

  @override
  void dispose() {
    _black.dispose();
    _card.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        AnimatedBuilder(
          animation: _cardCurve,
          child: widget.child,
          builder: (context, child) => Opacity(
            opacity: _cardCurve.value.clamp(0.0, 1.0),
            child: Transform.scale(
              scale: 0.96 + 0.04 * _cardCurve.value,
              child: child,
            ),
          ),
        ),
        AnimatedBuilder(
          animation: _black,
          builder: (context, _) {
            if (_black.value == 0) return const SizedBox.shrink();
            return Opacity(
              opacity: _black.value,
              child: ColoredBox(
                color: Colors.black,
                child: SafeArea(
                  child: Stack(
                    children: [
                      const Center(
                        child: SizedBox(
                          width: 34,
                          height: 34,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        ),
                      ),
                      PositionedDirectional(
                        top: 12,
                        start: 12,
                        child: _MotionCloseButton(
                          onPressed: () => Navigator.of(context).maybePop(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

/// زرُّ إغلاقٍ أبيض مستدير بعلامة X فيروزية، يخفت إلى 0.55 تحت الإصبع (§5.3).
class _MotionCloseButton extends StatefulWidget {
  const _MotionCloseButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  State<_MotionCloseButton> createState() => _MotionCloseButtonState();
}

class _MotionCloseButtonState extends State<_MotionCloseButton> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: MaterialLocalizations.of(context).closeButtonTooltip,
      child: GestureDetector(
        onTapDown: (_) => setState(() => _down = true),
        onTapUp: (_) => setState(() => _down = false),
        onTapCancel: () => setState(() => _down = false),
        onTap: widget.onPressed,
        child: AnimatedOpacity(
          opacity: _down ? 0.55 : 1,
          duration: Duration(milliseconds: _down ? 60 : 100),
          child: Container(
            width: 40,
            height: 40,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.close_rounded,
                color: MotionColors.teal, size: 24),
          ),
        ),
      ),
    );
  }
}
