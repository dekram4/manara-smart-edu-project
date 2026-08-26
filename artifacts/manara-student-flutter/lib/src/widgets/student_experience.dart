import 'dart:math' as math;

import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../services/student_sound_service.dart';

class StudentPageRoute<T> extends PageRouteBuilder<T> {
  StudentPageRoute({
    required WidgetBuilder builder,
    RouteSettings? settings,
  }) : super(
          settings: settings,
          transitionDuration: const Duration(milliseconds: 320),
          reverseTransitionDuration: const Duration(milliseconds: 240),
          pageBuilder: (context, animation, secondaryAnimation) => builder(context),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            if (MediaQuery.maybeOf(context)?.disableAnimations ?? false) return child;
            final curve = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
            return FadeTransition(
              opacity: curve,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0.035, 0.025),
                  end: Offset.zero,
                ).animate(curve),
                child: child,
              ),
            );
          },
        );
}

class StudentEntrance extends StatelessWidget {
  const StudentEntrance({
    required this.child,
    this.delay = Duration.zero,
    this.offset = 0.055,
    super.key,
  });

  final Widget child;
  final Duration delay;
  final double offset;

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.maybeOf(context)?.disableAnimations ?? false) return child;
    return child
        .animate(delay: delay)
        .fadeIn(duration: 320.ms, curve: Curves.easeOut)
        .slideY(begin: offset, end: 0, duration: 380.ms, curve: Curves.easeOutCubic);
  }
}

/// Gives student-facing cards a clearly visible arrival motion. This is kept
/// separate from page navigation so sections, games and reward cards feel
/// responsive even when the user stays on the same screen.
class StudentAnimatedCard extends StatelessWidget {
  const StudentAnimatedCard({
    required this.child,
    this.delay = Duration.zero,
    super.key,
  });

  final Widget child;
  final Duration delay;

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.maybeOf(context)?.disableAnimations ?? false) return child;
    return child
        .animate(delay: delay)
        .fadeIn(duration: 420.ms, curve: Curves.easeOut)
        .scale(
          begin: const Offset(0.9, 0.9),
          end: const Offset(1, 1),
          duration: 520.ms,
          curve: Curves.easeOutBack,
        );
  }
}

/// Subtle decorative light spots for student-facing entry screens.
///
/// They stay behind the content and stop animating when the device asks for
/// reduced motion.
class StudentAmbientOrbs extends StatelessWidget {
  const StudentAmbientOrbs({super.key});

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    final topOrb = DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xFF5EEAD4).withOpacity(0.12),
      ),
    );
    final bottomOrb = DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xFF818CF8).withOpacity(0.14),
      ),
    );

    Widget animate(Widget child, {required bool reverse}) {
      if (reduceMotion) return child;
      return child
          .animate(onPlay: (controller) => controller.repeat(reverse: reverse))
          .moveY(
            begin: reverse ? -8 : 8,
            end: reverse ? 8 : -8,
            duration: 3200.ms,
            curve: Curves.easeInOut,
          )
          .fade(
            begin: 0.68,
            end: 1,
            duration: 2400.ms,
            curve: Curves.easeInOut,
          );
    }

    return IgnorePointer(
      child: Stack(
        children: [
          PositionedDirectional(
            top: -72,
            end: -48,
            child: SizedBox(
              width: 210,
              height: 210,
              child: animate(topOrb, reverse: false),
            ),
          ),
          PositionedDirectional(
            bottom: -88,
            start: -54,
            child: SizedBox(
              width: 230,
              height: 230,
              child: animate(bottomOrb, reverse: true),
            ),
          ),
        ],
      ),
    );
  }
}

/// A quiet visual map for the student entry screens. The painter keeps the
/// background light and dimensional without turning the screen into a game
/// scene or competing with the form.
class StudentLearningWorld extends StatelessWidget {
  const StudentLearningWorld({super.key});

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    final sparkle = const Icon(
      Icons.auto_awesome_rounded,
      color: Color(0xFFF5C95D),
      size: 16,
    );

    return IgnorePointer(
      child: Stack(
        fit: StackFit.expand,
        children: [
          const CustomPaint(painter: _LearningWorldPainter()),
          PositionedDirectional(
            top: 42,
            start: 28,
            child: _FloatingWorldBadge(
              child: const Icon(
                Icons.menu_book_rounded,
                color: Color(0xFF0B6977),
                size: 20,
              ),
              duration: const Duration(milliseconds: 4200),
              delay: const Duration(milliseconds: 120),
              reduceMotion: reduceMotion,
            ),
          ),
          PositionedDirectional(
            top: 116,
            end: 28,
            child: _FloatingWorldBadge(
              child: sparkle,
              duration: const Duration(milliseconds: 3600),
              delay: const Duration(milliseconds: 360),
              reduceMotion: reduceMotion,
            ),
          ),
          PositionedDirectional(
            bottom: 44,
            end: 42,
            child: _FloatingWorldBadge(
              child: const Icon(
                Icons.star_rounded,
                color: Color(0xFFE27962),
                size: 18,
              ),
              duration: const Duration(milliseconds: 3900),
              delay: const Duration(milliseconds: 220),
              reduceMotion: reduceMotion,
            ),
          ),
        ],
      ),
    );
  }
}

/// Animated subject cards for the student login illustration. They are
/// decorative, sit behind the login story, and honor the system motion setting.
class StudentSubjectOrbit extends StatefulWidget {
  const StudentSubjectOrbit({
    this.compact = false,
    super.key,
  });

  final bool compact;

  @override
  State<StudentSubjectOrbit> createState() => _StudentSubjectOrbitState();
}

class _StudentSubjectOrbitState extends State<StudentSubjectOrbit>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 15),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (reduceMotion) {
      return _SubjectOrbitLayout(progress: 0, compact: widget.compact);
    }

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) => _SubjectOrbitLayout(
        progress: _controller.value,
        compact: widget.compact,
      ),
    );
  }
}

class _SubjectOrbitLayout extends StatelessWidget {
  const _SubjectOrbitLayout({
    required this.progress,
    required this.compact,
  });

  final double progress;
  final bool compact;

  static const _subjects = <_SubjectOrbitSpec>[
    _SubjectOrbitSpec(
      label: 'رياضيات',
      icon: Icons.calculate_rounded,
      primary: Color(0xFFEAA54E),
      secondary: Color(0xFFF6D77A),
      alignment: Alignment(-0.91, -0.28),
      phase: 0.0,
    ),
    _SubjectOrbitSpec(
      label: 'علوم',
      icon: Icons.science_rounded,
      primary: Color(0xFF55AFA4),
      secondary: Color(0xFF9CE0D2),
      alignment: Alignment(0.9, -0.02),
      phase: 0.27,
    ),
    _SubjectOrbitSpec(
      label: 'لغة',
      icon: Icons.auto_stories_rounded,
      primary: Color(0xFF9684D3),
      secondary: Color(0xFFC6BAF2),
      alignment: Alignment(-0.82, 0.74),
      phase: 0.52,
    ),
    _SubjectOrbitSpec(
      label: 'تقنية',
      icon: Icons.memory_rounded,
      primary: Color(0xFFE07D68),
      secondary: Color(0xFFF4B7A3),
      alignment: Alignment(0.88, 0.72),
      phase: 0.78,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: IgnorePointer(
        child: Stack(
          fit: StackFit.expand,
          children: _subjects
              .map(
                (subject) => _AnimatedSubjectOrb(
                  subject: subject,
                  progress: progress,
                  compact: compact,
                ),
              )
              .toList(),
        ),
      ),
    );
  }
}

class _AnimatedSubjectOrb extends StatelessWidget {
  const _AnimatedSubjectOrb({
    required this.subject,
    required this.progress,
    required this.compact,
  });

  final _SubjectOrbitSpec subject;
  final double progress;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final cycle = (progress + subject.phase) * math.pi * 2;
    final rise = math.sin(cycle) * (compact ? 5.0 : 8.0);
    final tilt = math.sin(cycle) * 0.07;
    final turn = math.cos(cycle) * 0.18;

    return Align(
      alignment: subject.alignment,
      child: Transform.translate(
        offset: Offset(0, rise),
        child: Transform(
          alignment: Alignment.center,
          transform: Matrix4.identity()
            ..setEntry(3, 2, 0.0012)
            ..rotateY(turn)
            ..rotateZ(tilt),
          child: Opacity(
            opacity: compact ? 0.82 : 0.92,
            child: _SubjectOrbitCard(subject: subject, compact: compact),
          ),
        ),
      ),
    );
  }
}

class _SubjectOrbitCard extends StatelessWidget {
  const _SubjectOrbitCard({
    required this.subject,
    required this.compact,
  });

  final _SubjectOrbitSpec subject;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final width = compact ? 62.0 : 76.0;
    final height = compact ? 68.0 : 82.0;
    final iconSize = compact ? 25.0 : 31.0;

    return SizedBox(
      width: width,
      height: height,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            right: 7,
            bottom: -6,
            left: 7,
            height: 18,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: subject.primary.withOpacity(0.52),
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 10,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
            ),
          ),
          Container(
            alignment: Alignment.center,
            padding: EdgeInsets.fromLTRB(
              6,
              compact ? 6 : 8,
              6,
              compact ? 5 : 7,
            ),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [subject.secondary, subject.primary],
              ),
              borderRadius: BorderRadius.circular(compact ? 19 : 22),
              border: Border.all(color: Colors.white.withOpacity(0.64), width: 1.2),
              boxShadow: [
                BoxShadow(
                  color: subject.primary.withOpacity(0.38),
                  blurRadius: 15,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: compact ? 36 : 42,
                  height: compact ? 36 : 42,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.88),
                    shape: BoxShape.circle,
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x240F2F46),
                        blurRadius: 7,
                        offset: Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Icon(subject.icon, size: iconSize, color: subject.primary),
                ),
                SizedBox(height: compact ? 3 : 5),
                Text(
                  subject.label,
                  maxLines: 1,
                  overflow: TextOverflow.fade,
                  style: TextStyle(
                    color: const Color(0xFF173B50),
                    fontSize: compact ? 9 : 10,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SubjectOrbitSpec {
  const _SubjectOrbitSpec({
    required this.label,
    required this.icon,
    required this.primary,
    required this.secondary,
    required this.alignment,
    required this.phase,
  });

  final String label;
  final IconData icon;
  final Color primary;
  final Color secondary;
  final Alignment alignment;
  final double phase;
}

class _FloatingWorldBadge extends StatelessWidget {
  const _FloatingWorldBadge({
    required this.child,
    required this.duration,
    required this.delay,
    required this.reduceMotion,
  });

  final Widget child;
  final Duration duration;
  final Duration delay;
  final bool reduceMotion;

  @override
  Widget build(BuildContext context) {
    final badge = Container(
      width: 42,
      height: 42,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: const Color(0xFFFFFCF3).withOpacity(0.8),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: const Color(0xFFE3D5A9)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1A274E76),
            blurRadius: 14,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );

    if (reduceMotion) return badge;
    return badge
        .animate(delay: delay, onPlay: (controller) => controller.repeat(reverse: true))
        .moveY(begin: 0, end: -9, duration: duration, curve: Curves.easeInOut);
  }
}

class _LearningWorldPainter extends CustomPainter {
  const _LearningWorldPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final wash = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topRight,
        end: Alignment.bottomLeft,
        colors: [
          Color(0xFFFFF6DD),
          Color(0xFFF6F7F0),
          Color(0xFFE8F3F0),
        ],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, wash);

    final tealRing = Paint()
      ..color = const Color(0xFF147D83).withOpacity(0.08)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 22;
    canvas.drawCircle(
      Offset(size.width * 0.02, size.height * 0.14),
      size.shortestSide * 0.24,
      tealRing,
    );

    final lilac = Paint()
      ..color = const Color(0xFF7663C7).withOpacity(0.09)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(
      Offset(size.width * 0.96, size.height * 0.9),
      size.shortestSide * 0.25,
      lilac,
    );

    final dots = Paint()..color = const Color(0xFF183047).withOpacity(0.11);
    for (var row = 0; row < 7; row++) {
      for (var column = 0; column < 9; column++) {
        final point = Offset(
          size.width * 0.08 + column * 22,
          size.height * 0.08 + row * 22,
        );
        canvas.drawCircle(point, 1.1, dots);
      }
    }

    final path = Paint()
      ..color = const Color(0xFFE2B85E).withOpacity(0.17)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;
    final curve = Path()
      ..moveTo(size.width * 0.08, size.height * 0.78)
      ..cubicTo(
        size.width * 0.28,
        size.height * 0.62,
        size.width * 0.44,
        size.height * 0.94,
        size.width * 0.64,
        size.height * 0.74,
      )
      ..cubicTo(
        size.width * 0.77,
        size.height * 0.6,
        size.width * 0.87,
        size.height * 0.68,
        size.width * 1.04,
        size.height * 0.52,
      );
    canvas.drawPath(curve, path);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// The student-facing character used as a visual anchor on entry screens.
class StudentCompanion extends StatelessWidget {
  const StudentCompanion({
    this.size = 190,
    this.showLabel = true,
    super.key,
  });

  final double size;
  final bool showLabel;

  @override
  Widget build(BuildContext context) {
    final imageSize = size * 0.83;
    final reduceMotion = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    final character = Transform(
      alignment: Alignment.center,
      transform: Matrix4.identity()
        ..setEntry(3, 2, 0.001)
        ..rotateZ(-0.035),
      child: Image.asset(
        'assets/images/manara-student-login-companion-cutout.png',
        width: imageSize,
        height: imageSize,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => Container(
          width: imageSize * 0.72,
          height: imageSize * 0.72,
          decoration: BoxDecoration(
            color: const Color(0xFFF1C664),
            borderRadius: BorderRadius.circular(34),
            boxShadow: const [
              BoxShadow(
                color: Color(0x3D0B2D3D),
                blurRadius: 16,
                offset: Offset(0, 10),
              ),
            ],
          ),
          child: const Icon(
            Icons.school_rounded,
            color: Color(0xFF173B50),
            size: 58,
          ),
        ),
      ),
    );

    return Semantics(
      label: 'رفيق منارة التعليمي',
      image: true,
      child: SizedBox(
        width: size,
        height: size + (showLabel ? 34 : 0),
        child: Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: [
            Positioned(
              bottom: 10,
              child: Container(
                width: size * 0.76,
                height: size * 0.22,
                decoration: BoxDecoration(
                  color: const Color(0xFF0B2D3D).withOpacity(0.18),
                  borderRadius: BorderRadius.circular(100),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF0B2D3D).withOpacity(0.14),
                      blurRadius: 18,
                      spreadRadius: 2,
                    ),
                  ],
                ),
              ),
            ),
            reduceMotion
                ? character
                : character
                    .animate(
                      onPlay: (controller) => controller.repeat(reverse: true),
                    )
                    .moveY(
                      begin: 0,
                      end: -7,
                      duration: 2100.ms,
                      curve: Curves.easeInOut,
                    ),
            if (showLabel)
              Positioned(
                bottom: -2,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFFBEE),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFE4D39A)),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x1F183047),
                        blurRadius: 12,
                        offset: Offset(0, 6),
                      ),
                    ],
                  ),
                  child: const Text(
                    'أنا معك في الرحلة',
                    style: TextStyle(
                      color: Color(0xFF6F5729),
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// A compact animated avatar used to make student cards feel personal without
/// needing a remote avatar or a heavyweight canvas.
class StudentCardAvatar extends StatelessWidget {
  const StudentCardAvatar({
    required this.icon,
    this.accent = const Color(0xFF0B8693),
    this.size = 58,
    this.label,
    super.key,
  });

  final IconData icon;
  final Color accent;
  final double size;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    final avatar = Semantics(
      label: label ?? 'رمز رحلة الطالب',
      child: SizedBox(
        width: size,
        height: size,
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topRight,
                  end: Alignment.bottomLeft,
                  colors: [Colors.white, accent.withOpacity(0.24)],
                ),
                border: Border.all(color: Colors.white.withOpacity(0.76), width: 2),
                boxShadow: [
                  BoxShadow(
                    color: accent.withOpacity(0.32),
                    blurRadius: 14,
                    offset: const Offset(0, 7),
                  ),
                ],
              ),
              child: SizedBox(
                width: size,
                height: size,
                child: Icon(icon, color: accent, size: size * 0.48),
              ),
            ),
            PositionedDirectional(
              top: -2,
              end: -1,
              child: Container(
                width: size * 0.28,
                height: size * 0.28,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: Color(0xFFF6C95D),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.auto_awesome_rounded,
                  size: size * 0.16,
                  color: Color(0xFF6F5729),
                ),
              ),
            ),
          ],
        ),
      ),
    );

    if (reduceMotion) return avatar;
    return avatar
        .animate(onPlay: (controller) => controller.repeat(reverse: true))
        .moveY(begin: 0, end: -4, duration: 1900.ms, curve: Curves.easeInOut)
        .rotate(begin: -0.012, end: 0.012, duration: 1900.ms, curve: Curves.easeInOut);
  }
}

/// A shared visual welcome inside opened student cards. It keeps each
/// destination recognisable while the actual lesson, quiz, or meeting content
/// remains untouched below it.
class StudentScreenHero extends StatelessWidget {
  const StudentScreenHero({
    required this.title,
    required this.subtitle,
    required this.icon,
    this.colors = const [Color(0xFF0B8693), Color(0xFF274E76)],
    this.dark = false,
    this.showCompanion = true,
    super.key,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final List<Color> colors;
  final bool dark;
  final bool showCompanion;

  @override
  Widget build(BuildContext context) {
    final foreground = dark ? Colors.white : const Color(0xFF183047);
    final supporting = dark ? const Color(0xFFD8F4F0) : const Color(0xFF466273);

    return StudentAnimatedCard(
      child: Container(
        clipBehavior: Clip.antiAlias,
        padding: const EdgeInsetsDirectional.fromSTEB(18, 16, 14, 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: LinearGradient(
            begin: AlignmentDirectional.topStart,
            end: AlignmentDirectional.bottomEnd,
            colors: dark
                ? colors
                : [colors.first.withOpacity(0.18), Colors.white],
          ),
          border: Border.all(
            color: dark ? Colors.white.withOpacity(0.15) : colors.first.withOpacity(0.22),
          ),
          boxShadow: [
            BoxShadow(
              color: colors.first.withOpacity(dark ? 0.24 : 0.12),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            PositionedDirectional(
              top: -42,
              end: showCompanion ? 58 : -25,
              child: Container(
                width: 116,
                height: 116,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: dark ? Colors.white.withOpacity(0.10) : colors.first.withOpacity(0.08),
                ),
              ),
            ),
            Row(
              children: [
                StudentCardAvatar(
                  icon: icon,
                  accent: dark ? const Color(0xFFBFFBFA) : colors.first,
                  label: title,
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          color: foreground,
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: supporting,
                          height: 1.35,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                if (showCompanion) ...[
                  const SizedBox(width: 6),
                  const StudentCompanion(size: 68, showLabel: false),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Highlights controls when they contain the current choice or own focus.
class StudentFocusGlow extends StatefulWidget {
  const StudentFocusGlow({
    required this.child,
    this.isSelected = false,
    this.hasError = false,
    this.borderRadius = const BorderRadius.all(Radius.circular(20)),
    super.key,
  });

  final Widget child;
  final bool isSelected;
  final bool hasError;
  final BorderRadius borderRadius;

  @override
  State<StudentFocusGlow> createState() => _StudentFocusGlowState();
}

class _StudentFocusGlowState extends State<StudentFocusGlow> {
  var _hasFocus = false;

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    final emphasized = _hasFocus || widget.isSelected;
    final color = widget.hasError
        ? const Color(0xFFF43F5E)
        : emphasized
            ? const Color(0xFF0B8693)
            : const Color(0xFFD7E3EF);

    return Focus(
      onFocusChange: (hasFocus) {
        if (mounted && _hasFocus != hasFocus) setState(() => _hasFocus = hasFocus);
      },
      child: AnimatedScale(
        scale: reduceMotion || !_hasFocus ? 1 : 1.012,
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOutCubic,
        child: AnimatedContainer(
          duration: reduceMotion ? Duration.zero : const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          decoration: BoxDecoration(
            borderRadius: widget.borderRadius,
            border: Border.all(color: color, width: emphasized || widget.hasError ? 1.5 : 1),
            boxShadow: _hasFocus || widget.hasError
                ? [
                    BoxShadow(
                      color: color.withOpacity(widget.hasError ? 0.18 : 0.16),
                      blurRadius: 18,
                      spreadRadius: 1,
                    ),
                  ]
                : const [],
          ),
          child: widget.child,
        ),
      ),
    );
  }
}

/// A compact selection summary that makes the current academic path obvious.
class StudentSelectionBadge extends StatelessWidget {
  const StudentSelectionBadge({
    required this.label,
    required this.subtitle,
    super.key,
  });

  final String label;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    final content = Semantics(
      label: '$label. $subtitle',
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFECFDF5),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFF6EE7B7)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x1A059669),
              blurRadius: 16,
              offset: Offset(0, 7),
            ),
          ],
        ),
        child: Row(
          children: [
            const CircleAvatar(
              radius: 19,
              backgroundColor: Color(0xFF059669),
              child: Icon(Icons.check_rounded, color: Colors.white),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      color: Color(0xFF065F46),
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: Color(0xFF047857),
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );

    if (reduceMotion) return content;
    return content
        .animate(key: ValueKey('$label-$subtitle'))
        .fadeIn(duration: 220.ms)
        .slideY(begin: 0.08, end: 0, duration: 280.ms, curve: Curves.easeOutCubic)
        .scale(begin: const Offset(0.96, 0.96), duration: 260.ms, curve: Curves.easeOutBack);
  }
}

/// Adds a visible but lightweight press response without owning the tap.
/// Existing InkWell buttons inside the child continue to receive the action.
class StudentPressScale extends StatefulWidget {
  const StudentPressScale({required this.child, super.key});

  final Widget child;

  @override
  State<StudentPressScale> createState() => _StudentPressScaleState();
}

class _StudentPressScaleState extends State<StudentPressScale> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (mounted && _pressed != value) setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.maybeOf(context)?.disableAnimations ?? false) {
      return widget.child;
    }
    return Listener(
      onPointerDown: (_) => _setPressed(true),
      onPointerUp: (_) => _setPressed(false),
      onPointerCancel: (_) => _setPressed(false),
      child: AnimatedScale(
        scale: _pressed ? 0.965 : 1,
        duration: const Duration(milliseconds: 120),
        curve: _pressed ? Curves.easeOut : Curves.elasticOut,
        child: widget.child,
      ),
    );
  }
}

/// A calm continuous reward cue for XP, gems and completed achievements.
class StudentRewardPulse extends StatelessWidget {
  const StudentRewardPulse({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.maybeOf(context)?.disableAnimations ?? false) return child;
    return child
        .animate(onPlay: (controller) => controller.repeat(reverse: true))
        .scale(
          begin: const Offset(0.96, 0.96),
          end: const Offset(1.045, 1.045),
          duration: 1400.ms,
          curve: Curves.easeInOut,
        );
  }
}

class StudentSoundToggle extends StatelessWidget {
  const StudentSoundToggle({super.key});

  @override
  Widget build(BuildContext context) {
    final sound = StudentSoundService.instance;
    return ValueListenableBuilder<bool>(
      valueListenable: sound.muted,
      builder: (context, isMuted, _) => IconButton(
        onPressed: sound.toggleMuted,
        tooltip: isMuted ? 'تشغيل الأصوات' : 'كتم الأصوات',
        icon: Icon(isMuted ? Icons.volume_off_rounded : Icons.volume_up_rounded),
      ),
    );
  }
}

class StudentCelebration extends StatelessWidget {
  const StudentCelebration({required this.controller, super.key});

  final ConfettiController controller;

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.maybeOf(context)?.disableAnimations ?? false) {
      return const SizedBox.shrink();
    }
    return IgnorePointer(
      child: Align(
        alignment: Alignment.topCenter,
        child: ConfettiWidget(
          confettiController: controller,
          blastDirectionality: BlastDirectionality.explosive,
          emissionFrequency: 0.08,
          numberOfParticles: 42,
          maxBlastForce: 28,
          minBlastForce: 7,
          gravity: 0.16,
          colors: const [
            Color(0xFF0B8693),
            Color(0xFFF59E0B),
            Color(0xFF6D28D9),
            Color(0xFFF43F5E),
          ],
        ),
      ),
    );
  }
}