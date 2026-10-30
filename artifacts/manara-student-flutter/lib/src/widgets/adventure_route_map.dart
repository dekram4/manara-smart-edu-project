import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/student_sound_service.dart';
import 'fitted_art_backdrop.dart';

/// خطوةٌ في خريطة المغامرة: مستوىً من شجرة المسار (الصف، المادة...).
@immutable
class AdventureStep {
  const AdventureStep({
    required this.label,
    required this.title,
    required this.prompt,
    required this.icon,
    required this.color,
    required this.value,
    required this.options,
    required this.onSelected,
    required this.artFor,
    this.numbered = false,
  });

  /// اسمُ المستوى تحت محطّته («الصف»).
  final String label;

  /// ما يُطلب من الطفل فوق الخيارات («اختر صفّك»).
  final String title;

  /// التوجيهُ الصوتيّ للخطوة، في `assets/audio/prompts/`.
  final String prompt;
  final IconData icon;
  final Color color;
  final String? value;
  final List<String> options;
  final ValueChanged<String> onSelected;

  /// صورةُ الخيار ([RouteArt]) — لكل خيارٍ صورة، فلا تبقى بطاقةٌ فارغة.
  final String Function(String option, int index) artFor;

  /// الوحداتُ والدروس: على كل بطاقةٍ رقمُها بالأرقام العربية، فيعرف الطفلُ
  /// ترتيبها وإن لم يقرأ اسمها.
  final bool numbered;

  bool get isChosen => (value ?? '').trim().isNotEmpty;
  bool get isOpen => options.isNotEmpty;
}

/// «١٢» لا «12»: أرقامُ الخريطة عربيةٌ أيّاً كانت لغةُ الواجهة.
String arabicDigits(int n) => '$n'.split('').map((d) => '٠١٢٣٤٥٦٧٨٩'[int.parse(d)]).join();

/// صورُ الخريطة وتوجيهاتُها، في `assets/images/` و`assets/audio/prompts/`.
///
/// لطفلٍ لا يقرأ بعد: الصفُّ بوابة، والمادةُ صورتُها، والفصلُ شمسٌ أو مطر،
/// والوحداتُ والدروس من صور مادّتها نفسها. ولا خيارَ بلا صورة: مادةٌ لا
/// تُعرف تأخذ من صور الثقافة العامة ([pool]).
class RouteArt {
  const RouteArt._();

  static const background = 'assets/images/routes/route_bg_custom.png';

  static const selectGrade = 'audio/prompts/select_grade.mp3';
  static const selectSubject = 'audio/prompts/select_subject.mp3';
  static const selectTerm = 'audio/prompts/select_term.mp3';
  static const selectUnit = 'audio/prompts/select_unit.mp3';
  static const selectLesson = 'audio/prompts/select_lesson.mp3';

  static const _routes = 'assets/images/routes/';
  static const _subjects = 'assets/images/subjects/';

  // ‏كلُّ مجموعةٍ أوّلُها صورةُ المادة، وما بعدها لوحداتها ودروسها: صورٌ مختلفة
  // ‏ما اتّسعت، فلا تتكرّر صورةٌ في قائمةٍ إلا إن زادت خياراتُها على صورها.
  static const quran = [
    '${_routes}subject_quran.png',
    '${_subjects}noorani.png',
    '${_subjects}ar_letters.png',
    '${_subjects}ar_letters_1.png',
  ];
  static const noorani = [
    '${_subjects}noorani.png',
    '${_routes}subject_quran.png',
    '${_subjects}ar_letters_1.png',
    '${_subjects}ar_letters_2.png',
  ];

  /// الحروفُ العربية: لوحةُ الحروف، ثم مكعّباتُها أ ب ت، ث ج ح...
  static const arabicLetters = [
    '${_subjects}ar_letters.png',
    '${_subjects}ar_letters_1.png',
    '${_subjects}ar_letters_2.png',
    '${_subjects}ar_letters_3.png',
    '${_subjects}ar_letters_4.png',
  ];

  /// الأرقامُ العربية بأرقامها هي (١٢٣) — لا مكعّباتُ 1 2 3 ولا أدواتُ الهندسة.
  static const arabicNumbers = [
    '${_subjects}ar_digits_1.png',
    '${_subjects}ar_digits_2.png',
    '${_subjects}ar_digits_3.png',
    '${_subjects}ar_digits_4.png',
  ];
  static const englishLetters = [
    '${_routes}subject_en_letters.png',
    '${_subjects}en_learn.png',
    '${_subjects}en_subj_4.png',
    '${_subjects}en_subj_3.png',
    '${_subjects}en_subj_2.png',
  ];

  /// الأرقامُ الإنجليزية: هنا مكانُ مكعّبات 1 2 3.
  static const englishNumbers = [
    '${_routes}subject_en_numbers.png',
    '${_subjects}ar_numbers_conv.png',
    '${_subjects}math_6.png',
    '${_subjects}math_5.png',
  ];
  static const english = [
    '${_subjects}en_subj_1.png',
    '${_subjects}en_subj_2.png',
    '${_subjects}en_subj_3.png',
    '${_subjects}en_subj_4.png',
    '${_subjects}en_learn.png',
  ];
  static const math = [
    '${_subjects}math_1.png',
    '${_subjects}math_2.png',
    '${_subjects}math_3.png',
    '${_subjects}math_4.png',
    '${_subjects}math_5.png',
    '${_subjects}math_6.png',
  ];
  static const science = [
    '${_routes}subject_science.png',
    '${_subjects}science_1.png',
    '${_subjects}science_2.png',
    '${_subjects}science_3.png',
    '${_subjects}science_4.png',
  ];
  static const general = [
    '${_subjects}general_1.png',
    '${_subjects}general_2.png',
    '${_subjects}science_4.png',
    '${_subjects}en_subj_1.png',
  ];

  /// بوابتان تتناوبان على الصفوف.
  static String gate(int index) => '${_routes}gate_${index.isEven ? 1 : 2}.png';

  /// الفصلُ الأوّل شمس، والثاني غيمةُ مطر — وما بعدهما يتناوبان.
  static String term(int index) => '${_routes}term_${index.isEven ? 1 : 2}.png';

  static String _key(String name) => name
      .replaceAll(RegExp('[ً-ٰٟـ]'), '')
      .toLowerCase()
      .replaceAll(RegExp('[أإآٱ]'), 'ا')
      .replaceAll('ة', 'ه');

  /// صورُ المادة: أوّلُها صورتُها في بطاقتها، وكلُّها لوحداتها ودروسها.
  static List<String> pool(String subject) {
    final key = _key(subject);
    bool has(String pattern) => RegExp(pattern).hasMatch(key);
    final isEnglish = has('انجليز|انكليز|english');
    final isNumbers = has('ارقام|اعداد|numbers|digits');
    final isLetters = has('حروف|هجاء|letters|alphabet');
    if (has('نوران')) return noorani;
    if (has('قران|quran')) return quran;
    if (isEnglish && isLetters) return englishLetters;
    if (isEnglish && isNumbers) return englishNumbers;
    if (isEnglish) return english;
    if (isNumbers) return arabicNumbers;
    if (isLetters || has('عربي|arabic')) return arabicLetters;
    if (has('رياضيات|حساب|math')) return math;
    if (has('علوم|science')) return science;
    if (has('ثقاف|general')) return general;
    // مادةٌ لا تُعرف: صورةٌ من الثقافة العامة، ثابتةٌ لاسمها.
    // ‏دورانٌ لا إضافة: كلُّ صورةٍ مرّةً واحدة.
    final start = key.hashCode.abs() % general.length;
    return [for (var i = 0; i < general.length; i++) general[(start + i) % general.length]];
  }

  /// صورةُ المادة في بطاقتها.
  static String subject(String name) => pool(name).first;

  /// صورةُ الوحدة أو الدرس [index] في مادّته: تدور على صور المادة، تبدأ بعد
  /// صورة المادة نفسها إن كان لها غيرُها — فلا تشبه الوحدةُ الأولى المادة.
  static String item(String subject, int index) {
    final images = pool(subject);
    return images[(index + (images.length > 1 ? 1 : 0)) % images.length];
  }
}

/// «خريطةُ المغامرة»: شاشةُ اختيار المسار لطفلٍ لا يقرأ بعد.
///
/// فوق صفٍّ دراسيٍّ هادئٍ مضيء دربٌ من خمس محطّاتٍ مرقّمة — الصف، المادة،
/// الفصل، الوحدة، الدرس — تتوهّج الجاريةُ منها، وتحتها خياراتُها صوراً كبيرة.
/// ولكل خطوةٍ صوتٌ يقول ما يُطلب، يُسمع حين تصير جارية ويُعاد بلمس محطّتها أو
/// زرّ السمّاعة.
///
/// الاختيارُ نفسُه للشاشة ([AdventureStep.onSelected]): الخريطةُ تغيّر كيف يُختار
/// المستوى، لا ما يفعله اختيارُه.
class AdventureRouteMap extends StatefulWidget {
  const AdventureRouteMap({
    required this.steps,
    required this.activeIndex,
    required this.onActivate,
    this.bottomInset = 0,
    super.key,
  });

  final List<AdventureStep> steps;
  final int activeIndex;

  /// لُمست محطّةٌ: تصير الخطوةَ الجارية.
  final ValueChanged<int> onActivate;

  /// ما يُترك أسفلَ الخريطة لزرّ «ابدأ المغامرة».
  final double bottomInset;

  @override
  State<AdventureRouteMap> createState() => _AdventureRouteMapState();
}

/// حبرُ الخريطة: كحليٌّ عميق يُقرأ فوق الصفّ المضيء.
const _ink = Color(0xFF1E3A5F);
const _gold = Color(0xFFF59E0B);

class _AdventureRouteMapState extends State<AdventureRouteMap> with TickerProviderStateMixin {
  late final AnimationController _clock = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2400),
  );

  /// انجرافُ الخلفية البطيء ونجومُها الطافية: دورةٌ طويلة لا تُلحظ إلا هادئة.
  late final AnimationController _drift = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 24),
  );

  bool get _still => MediaQuery.maybeOf(context)?.disableAnimations ?? false;

  @override
  void initState() {
    super.initState();
    // التوجيهُ الأوّل بعد ترحيب الشاشة، لا فوقه.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _speak(afterGreeting: true);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_still) {
      _clock
        ..stop()
        ..value = 0.5;
      _drift
        ..stop()
        ..value = 0;
    } else {
      if (!_clock.isAnimating) _clock.repeat();
      if (!_drift.isAnimating) _drift.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(AdventureRouteMap old) {
    super.didUpdateWidget(old);
    if (old.activeIndex != widget.activeIndex) _speak();
  }

  @override
  void dispose() {
    _clock.dispose();
    _drift.dispose();
    super.dispose();
  }

  AdventureStep? get _active =>
      widget.activeIndex >= 0 && widget.activeIndex < widget.steps.length ? widget.steps[widget.activeIndex] : null;

  void _speak({bool afterGreeting = false}) {
    final step = _active;
    if (step == null) return;
    unawaited(StudentSoundService.instance.speakPathPrompt(step.prompt, afterGreeting: afterGreeting));
  }

  void _activate(int index) {
    if (!widget.steps[index].isOpen) return;
    HapticFeedback.selectionClick();
    StudentSoundService.instance.playTap();
    if (index == widget.activeIndex) {
      _speak();
    } else {
      widget.onActivate(index);
    }
  }

  void _choose(AdventureStep step, String option) {
    HapticFeedback.lightImpact();
    step.onSelected(option);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, box) {
      if (!box.maxWidth.isFinite || !box.maxHeight.isFinite || box.maxWidth <= 1 || box.maxHeight <= 1) {
        return const ColoredBox(color: Color(0xFFFFF7E8));
      }
      final size = box.biggest;
      // ‏هاتفٌ أفقيٌّ قصير: دربٌ أقصرُ وفُسَحٌ أضيق، فيبقى للخيارات مكان.
      final compact = size.height < 440;
      final trailHeight = compact ? 80.0 : (size.shortestSide * 0.22).clamp(96.0, 140.0).toDouble();
      final gap = compact ? 2.0 : 6.0;
      final active = _active;
      return Stack(
        fit: StackFit.expand,
        children: [
          RouteBackdrop(drift: _drift),
          Padding(
            padding: EdgeInsets.fromLTRB(8, 54, 8, widget.bottomInset),
            child: Column(
              children: [
                SizedBox(
                  height: trailHeight,
                  child: AnimatedBuilder(
                    animation: _clock,
                    builder: (context, _) => _Trail(
                      steps: widget.steps,
                      activeIndex: widget.activeIndex,
                      pulse: _clock.value,
                      onTap: _activate,
                    ),
                  ),
                ),
                if (active != null) ...[
                  SizedBox(height: gap),
                  _PromptTitle(step: active, onReplay: _speak, compact: compact),
                  SizedBox(height: gap),
                  Expanded(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 320),
                      switchInCurve: Curves.easeOutBack,
                      transitionBuilder: (child, animation) => FadeTransition(
                        opacity: animation,
                        child: ScaleTransition(
                          scale: Tween<double>(begin: 0.92, end: 1).animate(animation),
                          child: child,
                        ),
                      ),
                      child: _Choices(
                        key: ValueKey('adventure-choices-${widget.activeIndex}'),
                        stepIndex: widget.activeIndex,
                        step: active,
                        clock: _clock,
                        onChoose: (option) => _choose(active, option),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      );
    });
  }
}

/// الخلفيةُ: صفٌّ دراسيٌّ ينجرف ببطءٍ شديد، تحت غشاءٍ أبيضَ خفيف وتمويهٍ
/// يسير يجعلانه هادئاً لا يزاحم الخيارات — ونجومٌ وفقاعاتٌ تطفو فوقه.
class RouteBackdrop extends StatefulWidget {
  /// [drift]: ساعةُ الخريطة إن وُجدت؛ وإلا فللخلفية ساعتُها — كما خلف ترحيب
  /// الشاشة وهي تقرأ المسار.
  const RouteBackdrop({this.drift, super.key});

  final Animation<double>? drift;

  @override
  State<RouteBackdrop> createState() => _RouteBackdropState();
}

class _RouteBackdropState extends State<RouteBackdrop> with SingleTickerProviderStateMixin {
  AnimationController? _own;

  Animation<double> get drift => widget.drift ?? (_own ??= AnimationController(
        vsync: this,
        duration: const Duration(seconds: 24),
      ));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final own = widget.drift == null ? drift as AnimationController : null;
    if (own == null) return;
    if (MediaQuery.maybeOf(context)?.disableAnimations ?? false) {
      own.stop();
    } else if (!own.isAnimating) {
      own.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _own?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Stack(
        fit: StackFit.expand,
        children: [
          FittedArtBackdrop(
            asset: RouteArt.background,
            drift: drift,
            imageKey: const ValueKey('adventure-background'),
            blur: 1.6,
          ),
          // ‏غشاءٌ أبيض: الصورةُ حاضرةٌ ولا تشدّ العين عن الخيارات.
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xB3FFFFFF), Color(0x8CFFFFFF), Color(0xA6FFFFFF)],
              ),
            ),
          ),
          RepaintBoundary(child: CustomPaint(painter: _FloatPainter(drift))),
        ],
      ),
    );
  }
}

/// نجومٌ وفقاعاتٌ ملوّنة تطفو ببطء وتتلألأ — خفيفةٌ لا تُلهي.
class _FloatPainter extends CustomPainter {
  _FloatPainter(this.clock) : super(repaint: clock);

  final Animation<double> clock;

  static const _colors = [
    Color(0xFFFBBF24),
    Color(0xFF60A5FA),
    Color(0xFFF472B6),
    Color(0xFF34D399),
    Color(0xFFA78BFA),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final t = clock.value;
    for (var i = 0; i < 14; i++) {
      final seed = i * 0.6180339;
      final x = (seed * 7.3 % 1) * size.width;
      final rise = ((t * (0.6 + (i % 3) * 0.2) + seed) % 1);
      final y = size.height * (1.05 - rise * 1.1);
      final sway = math.sin((t * 2 + seed) * 2 * math.pi) * 14;
      final r = 3.0 + (i % 4) * 2.2;
      final color = _colors[i % _colors.length];
      final twinkle = 0.35 + 0.35 * math.sin((t * 6 + seed * 9) * 2 * math.pi).abs();
      final center = Offset(x + sway, y);
      if (i.isEven) {
        canvas.drawCircle(center, r, Paint()..color = color.withValues(alpha: 0.28 * twinkle + 0.1));
      } else {
        _star(canvas, center, r * 1.4, Paint()..color = color.withValues(alpha: 0.4 * twinkle + 0.15));
      }
    }
  }

  void _star(Canvas canvas, Offset c, double r, Paint paint) {
    final path = Path();
    for (var k = 0; k < 10; k++) {
      final a = -math.pi / 2 + k * math.pi / 5;
      final rr = k.isEven ? r : r * 0.45;
      final p = c + Offset(math.cos(a), math.sin(a)) * rr;
      k == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
    }
    canvas.drawPath(path..close(), paint);
  }

  @override
  bool shouldRepaint(_FloatPainter old) => false;
}

/// الدربُ: خمسُ محطّاتٍ مرقّمة يصل بينها خطٌّ، والجاريةُ تنبض.
class _Trail extends StatelessWidget {
  const _Trail({required this.steps, required this.activeIndex, required this.pulse, required this.onTap});

  final List<AdventureStep> steps;
  final int activeIndex;
  final double pulse;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, box) {
      final count = steps.length;
      final slot = box.maxWidth / count;
      // ‏تحت القرص سطران: اسمُ المستوى وما اختير فيه.
      final disc = math.min(slot * 0.6, box.maxHeight - 50).clamp(28.0, 120.0).toDouble();
      return Stack(
        children: [
          // الخطُّ بين المحطّات: ما قُطع منه ذهبيّ، وما بقي منقّط.
          Positioned.fill(
            child: CustomPaint(
              painter: _TrailPainter(
                count: count,
                reached: activeIndex,
                rtl: Directionality.of(context) == TextDirection.rtl,
                discCenterY: disc / 2 + 4,
                pulse: pulse,
              ),
            ),
          ),
          Row(
            children: [
              for (var i = 0; i < count; i++)
                SizedBox(
                  width: slot,
                  child: _Station(
                    key: ValueKey('adventure-station-$i'),
                    step: steps[i],
                    index: i,
                    active: i == activeIndex,
                    disc: disc,
                    pulse: pulse,
                    onTap: () => onTap(i),
                  ),
                ),
            ],
          ),
        ],
      );
    });
  }
}

class _TrailPainter extends CustomPainter {
  _TrailPainter({
    required this.count,
    required this.reached,
    required this.rtl,
    required this.discCenterY,
    required this.pulse,
  });

  final int count;
  final int reached;
  final bool rtl;
  final double discCenterY;
  final double pulse;

  @override
  void paint(Canvas canvas, Size size) {
    final slot = size.width / count;
    double x(int i) => rtl ? size.width - slot * (i + 0.5) : slot * (i + 0.5);
    for (var i = 0; i + 1 < count; i++) {
      final a = Offset(x(i), discCenterY);
      final b = Offset(x(i + 1), discCenterY);
      final walked = i < reached;
      final paint = Paint()
        ..strokeWidth = walked ? 6 : 4
        ..strokeCap = StrokeCap.round
        ..color = walked ? _gold : _ink.withValues(alpha: 0.35);
      if (walked) {
        canvas.drawLine(
          a,
          b,
          Paint()
            ..strokeWidth = 14
            ..strokeCap = StrokeCap.round
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6)
            ..color = _gold.withValues(alpha: 0.3 + 0.2 * math.sin(pulse * 2 * math.pi).abs()),
        );
        canvas.drawLine(a, b, paint);
      } else {
        // نقاطٌ تسير نحو المحطّة التالية.
        final length = (b - a).distance;
        final dir = (b - a) / length;
        const gap = 14.0;
        final shift = pulse * gap;
        for (var d = shift; d < length; d += gap) {
          canvas.drawCircle(a + dir * d, 2.6, paint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(_TrailPainter old) =>
      old.reached != reached || old.pulse != pulse || old.rtl != rtl || old.count != count;
}

/// محطّةٌ على الدرب: رقمُها، وصورةُ ما اختير فيها (أو أيقونتُها)، واسمُها
/// تحتها، وما اختير فيها.
class _Station extends StatelessWidget {
  const _Station({
    required this.step,
    required this.index,
    required this.active,
    required this.disc,
    required this.pulse,
    required this.onTap,
    super.key,
  });

  final AdventureStep step;
  final int index;
  final bool active;
  final double disc;
  final double pulse;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final glow = active ? 0.5 + 0.5 * math.sin(pulse * 2 * math.pi) : 0.0;
    final chosenIndex = step.isChosen ? step.options.indexOf(step.value!) : -1;
    final art = step.isChosen ? step.artFor(step.value!, math.max(0, chosenIndex)) : null;
    final badge = disc * 0.36;
    return Semantics(
      button: true,
      selected: active,
      label: '${step.label}: ${step.value ?? ''}',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Opacity(
          opacity: step.isOpen ? 1 : 0.45,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 4),
              Transform.scale(
                scale: active ? 1.08 + 0.04 * glow : 1,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: disc,
                      height: disc,
                      padding: EdgeInsets.all(disc * 0.1),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [Colors.white, Color.lerp(step.color, Colors.white, 0.55)!],
                        ),
                        border: Border.all(
                          color: active ? _gold : step.color,
                          width: active ? 4 : 2.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: (active ? _gold : step.color).withValues(alpha: 0.35 + 0.35 * glow),
                            blurRadius: 8 + 14 * glow,
                            spreadRadius: 1 + 3 * glow,
                          ),
                        ],
                      ),
                      child: art == null
                          ? FittedBox(child: Icon(step.icon, color: step.color))
                          : Image.asset(art, fit: BoxFit.contain, cacheWidth: 192),
                    ),
                    // ‏رقمُ المحطّة بالأرقام العربية.
                    PositionedDirectional(
                      top: -badge * 0.15,
                      start: -badge * 0.15,
                      child: Container(
                        key: ValueKey('adventure-station-number-$index'),
                        width: badge,
                        height: badge,
                        alignment: Alignment.center,
                        // ‏كحليٌّ لا أخضر: الأخضرُ علامةُ «اختير» وحدها.
                        decoration: BoxDecoration(
                          color: active ? _gold : _ink,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        child: FittedBox(
                          child: Padding(
                            padding: const EdgeInsets.all(3),
                            child: Text(
                              arabicDigits(index + 1),
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18),
                            ),
                          ),
                        ),
                      ),
                    ),
                    if (step.isChosen)
                      PositionedDirectional(
                        end: -2,
                        bottom: -2,
                        child: Container(
                          width: badge,
                          height: badge,
                          decoration: BoxDecoration(
                            color: const Color(0xFF22C55E),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                          child: const FittedBox(child: Icon(Icons.check_rounded, color: Colors.white)),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              Text(
                step.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: active ? const Color(0xFFB45309) : _ink,
                  fontSize: 15,
                  height: 1.2,
                  fontWeight: FontWeight.w900,
                  shadows: const [Shadow(color: Colors.white, blurRadius: 6)],
                ),
              ),
              // ‏ما اختير في المستوى: للكبير يقرؤه، وللعائد يرى مسارَه كما تركه.
              if (step.isChosen)
                Text(
                  step.value!,
                  key: ValueKey('adventure-value-$index'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: _ink,
                    fontSize: 14,
                    height: 1.25,
                    fontWeight: FontWeight.w800,
                    shadows: [Shadow(color: Colors.white, blurRadius: 6)],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// ما يُطلب الآن، وزرُّ السمّاعة يعيد قوله.
class _PromptTitle extends StatelessWidget {
  const _PromptTitle({required this.step, required this.onReplay, this.compact = false});

  final AdventureStep step;
  final VoidCallback onReplay;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Material(
          color: step.color,
          shape: const CircleBorder(side: BorderSide(color: Colors.white, width: 2)),
          elevation: 4,
          child: InkWell(
            key: const ValueKey('adventure-prompt'),
            customBorder: const CircleBorder(),
            onTap: () {
              HapticFeedback.selectionClick();
              onReplay();
            },
            child: Padding(
              padding: EdgeInsets.all(compact ? 5 : 8),
              child: Icon(Icons.volume_up_rounded, color: Colors.white, size: compact ? 20 : 26),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Flexible(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              step.title,
              style: TextStyle(
                color: _ink,
                fontSize: compact ? 22 : 30,
                fontWeight: FontWeight.w900,
                shadows: const [
                  Shadow(color: Colors.white, blurRadius: 10),
                  Shadow(color: Colors.white, blurRadius: 4),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// خياراتُ الخطوة الجارية: بطاقاتٌ كبيرة تُلمس، تتمرّر إن كثرت.
class _Choices extends StatelessWidget {
  const _Choices({
    required this.stepIndex,
    required this.step,
    required this.clock,
    required this.onChoose,
    super.key,
  });

  final int stepIndex;
  final AdventureStep step;
  final Animation<double> clock;
  final ValueChanged<String> onChoose;

  /// أكبرُ بطاقةٍ تملأ بها الخياراتُ المساحة: كلُّ عددٍ من الأعمدة يُجرَّب،
  /// ويُختار ما يعطي البطاقةَ أكبرَ ارتفاع. البطاقةُ أعرضُ من نصف ارتفاعها
  /// بقليل ([_aspect]).
  static ({int columns, double height}) _grid(int count, Size area) {
    var best = (columns: count, height: 0.0);
    for (var columns = 1; columns <= count; columns++) {
      final rows = (count / columns).ceil();
      final byWidth = (area.width - _gap * (columns - 1)) / columns / _aspect;
      final byHeight = (area.height - _gap * (rows - 1)) / rows;
      final height = math.min(byWidth, byHeight);
      if (height > best.height) best = (columns: columns, height: height);
    }
    return best;
  }

  static const _gap = 14.0;
  static const _aspect = 0.82;
  static const _maxCard = 260.0;

  /// أصغرُ بطاقةٍ تُقرأ صورتُها بإصبع طفل: ما دونها يصير شريطاً يتمرّر.
  static const _minCard = 120.0;

  Widget _card(int j, double height) => _ChoiceCard(
        key: ValueKey('adventure-option-$stepIndex-$j'),
        label: step.options[j],
        index: j,
        art: step.artFor(step.options[j], j),
        numbered: step.numbered,
        color: step.color,
        selected: step.options[j] == step.value,
        width: height * _aspect,
        height: height,
        clock: clock,
        onTap: () => onChoose(step.options[j]),
      );

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, box) {
      final options = step.options;
      final grid = _grid(options.length, box.biggest);
      if (grid.height >= _minCard) {
        // تتّسع كلُّها: شبكةٌ في الوسط تملأ ما بين الدرب والزرّ.
        final card = math.min(grid.height, _maxCard);
        return Center(
          child: SingleChildScrollView(
            key: ValueKey('adventure-options-$stepIndex'),
            child: Wrap(
              alignment: WrapAlignment.center,
              spacing: _gap,
              runSpacing: _gap,
              children: [for (var j = 0; j < options.length; j++) _card(j, card)],
            ),
          ),
        );
      }
      // كثرت: صفٌّ واحدٌ يتمرّر بإصبعه، ببطاقاتٍ بحجمٍ يُلمس.
      final card = math.min(box.maxHeight, _maxCard);
      return Center(
        child: SizedBox(
          height: card,
          child: ListView.separated(
            key: ValueKey('adventure-options-$stepIndex'),
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 7),
            itemCount: options.length,
            separatorBuilder: (_, __) => const SizedBox(width: _gap),
            itemBuilder: (context, j) => _card(j, card),
          ),
        ),
      );
    });
  }
}

class _ChoiceCard extends StatelessWidget {
  const _ChoiceCard({
    required this.label,
    required this.index,
    required this.art,
    required this.numbered,
    required this.color,
    required this.selected,
    required this.width,
    required this.height,
    required this.clock,
    required this.onTap,
    super.key,
  });

  final String label;
  final int index;
  final String art;
  final bool numbered;
  final Color color;
  final bool selected;
  final double width;
  final double height;
  final Animation<double> clock;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final artSize = height * 0.62;
    final badge = (height * 0.2).clamp(22.0, 44.0).toDouble();
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedBuilder(
          animation: clock,
          builder: (context, child) {
            // تطفو البطاقاتُ قليلاً، كلٌّ في وقته.
            final bob = math.sin((clock.value + index * 0.17) * 2 * math.pi) * 4;
            return Transform.translate(offset: Offset(0, bob), child: child);
          },
          child: AnimatedScale(
            scale: selected ? 1.06 : 1,
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutBack,
            child: Container(
              width: width,
              height: height,
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 6),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(26),
                color: Colors.white.withValues(alpha: 0.94),
                border: Border.all(
                  color: selected ? _gold : color.withValues(alpha: 0.55),
                  width: selected ? 4 : 2.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: (selected ? _gold : color).withValues(alpha: selected ? 0.55 : 0.28),
                    blurRadius: selected ? 22 : 12,
                    spreadRadius: selected ? 2 : 0,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  SizedBox(
                    height: artSize,
                    child: Stack(
                      alignment: Alignment.center,
                      clipBehavior: Clip.none,
                      children: [
                        Image.asset(art, fit: BoxFit.contain, cacheWidth: 384),
                        if (numbered)
                          PositionedDirectional(
                            top: 0,
                            start: 0,
                            child: Container(
                              key: ValueKey('adventure-option-number-$index'),
                              width: badge,
                              height: badge,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: _ink,
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 2),
                                boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
                              ),
                              child: FittedBox(
                                child: Padding(
                                  padding: const EdgeInsets.all(4),
                                  child: Text(
                                    arabicDigits(index + 1),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 22,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        if (selected)
                          PositionedDirectional(
                            top: 0,
                            end: 0,
                            child: Container(
                              padding: const EdgeInsets.all(3),
                              decoration: BoxDecoration(
                                color: const Color(0xFF22C55E),
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 2),
                              ),
                              child: const Icon(Icons.check_rounded, color: Colors.white, size: 22),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Expanded(
                    child: Center(
                      child: Text(
                        label,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: _ink,
                          fontSize: 16,
                          height: 1.25,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
