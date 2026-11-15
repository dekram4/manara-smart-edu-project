import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../l10n/student_strings.dart';

/// شريطُ الترحيب أعلى شاشة البطاقات: اسمُ الطالب وصفُّه على تدرّجٍ يتلألأ،
/// ونجومٌ صغيرةٌ تومض حوله — ليشعر الطفلُ أن الشاشة له هو.
///
/// يضغطه الطالبُ فيقفز قفزةً صغيرة وتتلألأ نجومُه. و«تقليلُ الحركة» يُبقي
/// التدرّجَ ثابتاً والنجومَ ساكنة.
class StudentWelcomeBanner extends StatefulWidget {
  const StudentWelcomeBanner({super.key, required this.name, this.grade, this.now});

  final String name;
  final String? grade;

  /// للاختبار: الساعةُ التي تختار التحيّة.
  final DateTime? now;

  /// تحيّةُ الوقت: صباحٌ حتى الظهر، ثم مساء.
  static String greetingFor(DateTime time) =>
      time.hour >= 4 && time.hour < 12 ? tr('home.welcome.morning') : tr('home.welcome.evening');

  /// الاسمُ الأوّل وحده: «سارة» لا «سارة محمد أحمد» — أقربُ للطفل وأقصرُ في الشريط.
  static String firstName(String name) {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '';
    // ‏«عبد الله» اسمٌ واحد.
    if (parts.length > 1 && (parts.first == 'عبد' || parts.first == 'أبو')) return '${parts[0]} ${parts[1]}';
    return parts.first;
  }

  @override
  State<StudentWelcomeBanner> createState() => _StudentWelcomeBannerState();
}

class _StudentWelcomeBannerState extends State<StudentWelcomeBanner> with TickerProviderStateMixin {
  late final AnimationController _shimmer =
      AnimationController(vsync: this, duration: const Duration(seconds: 6));
  late final AnimationController _bounce =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 520));
  bool _still = false;

  static const _gradients = [
    [Color(0xFFFF6FB5), Color(0xFFFFB347), Color(0xFF7C5CFF)],
    [Color(0xFF7C5CFF), Color(0xFF22D3EE), Color(0xFFFF6FB5)],
  ];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _still = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (_still) {
      _shimmer
        ..stop()
        ..value = 0.3;
    } else if (!_shimmer.isAnimating) {
      _shimmer.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _shimmer.dispose();
    _bounce.dispose();
    super.dispose();
  }

  void _celebrate() {
    if (_still) return;
    _bounce.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final first = StudentWelcomeBanner.firstName(widget.name);
    final grade = widget.grade?.trim() ?? '';
    final greeting = StudentWelcomeBanner.greetingFor(widget.now ?? DateTime.now());
    return Semantics(
      label: '$greeting $first${grade.isEmpty ? '' : '، $grade'}',
      child: GestureDetector(
        key: const ValueKey('home-welcome-banner'),
        onTap: _celebrate,
        child: AnimatedBuilder(
          animation: Listenable.merge([_shimmer, _bounce]),
          builder: (context, child) {
            final t = Curves.easeInOut.transform(_shimmer.value);
            final colors = [
              for (var i = 0; i < 3; i++) Color.lerp(_gradients[0][i], _gradients[1][i], t)!,
            ];
            final hop = math.sin(_bounce.value * math.pi) * 8;
            return Transform.translate(
              offset: Offset(0, -hop),
              child: Container(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(26),
                  gradient: LinearGradient(
                    begin: Alignment(-1 + t, -1),
                    end: Alignment(1, 1 - t),
                    colors: colors,
                  ),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.85), width: 2.5),
                  boxShadow: [
                    BoxShadow(color: colors[0].withValues(alpha: 0.38), blurRadius: 20, offset: const Offset(0, 8)),
                  ],
                ),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned.fill(
                      child: IgnorePointer(
                        child: CustomPaint(
                          painter: _SparklePainter(phase: _shimmer.value, burst: _bounce.value),
                        ),
                      ),
                    ),
                    child!,
                  ],
                ),
              ),
            );
          },
          child: Row(
            children: [
              Container(
                width: 54,
                height: 54,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.92),
                  boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 8, offset: Offset(0, 3))],
                ),
                child: const Text('🌟', style: TextStyle(fontSize: 30)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: AlignmentDirectional.centerStart,
                      child: Text(
                        first.isEmpty ? greeting : '$greeting $first!',
                        key: const ValueKey('home-welcome-name'),
                        maxLines: 1,
                        style: const TextStyle(
                          fontSize: 25,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          height: 1.15,
                          shadows: [Shadow(color: Color(0x66000000), blurRadius: 6, offset: Offset(0, 2))],
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        if (grade.isNotEmpty)
                          Container(
                            key: const ValueKey('home-welcome-grade'),
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.9),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              '🎒 $grade',
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Color(0xFF5B21B6)),
                            ),
                          ),
                        Text(
                          tr('home.welcome.tagline'),
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Colors.white),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// نجومٌ صغيرةٌ ثابتةُ المواضع تومض بالتناوب، وتكبر لحظةَ الضغط.
class _SparklePainter extends CustomPainter {
  _SparklePainter({required this.phase, required this.burst});

  final double phase;
  final double burst;

  static const _spots = [
    Offset(0.08, 0.18), Offset(0.32, 0.85), Offset(0.55, 0.12), Offset(0.7, 0.78),
    Offset(0.86, 0.22), Offset(0.95, 0.65), Offset(0.45, 0.5),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white;
    for (var i = 0; i < _spots.length; i++) {
      final twinkle = 0.5 + 0.5 * math.sin((phase * 2 + i / _spots.length) * 2 * math.pi);
      final r = (2.2 + 2.8 * twinkle) * (1 + burst * 1.2);
      paint.color = Colors.white.withValues(alpha: 0.35 + 0.55 * twinkle);
      final c = Offset(_spots[i].dx * size.width, _spots[i].dy * size.height);
      final path = Path()
        ..moveTo(c.dx, c.dy - r * 2)
        ..quadraticBezierTo(c.dx, c.dy, c.dx + r * 2, c.dy)
        ..quadraticBezierTo(c.dx, c.dy, c.dx, c.dy + r * 2)
        ..quadraticBezierTo(c.dx, c.dy, c.dx - r * 2, c.dy)
        ..quadraticBezierTo(c.dx, c.dy, c.dx, c.dy - r * 2)
        ..close();
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(_SparklePainter old) => old.phase != phase || old.burst != burst;
}
