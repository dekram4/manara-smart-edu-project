import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../l10n/student_strings.dart';
import 'fit_text.dart';

/// شريطُ الترحيب أعلى شاشة البطاقات: اسمُ الطالب وصفُّه على تدرّجٍ يتلألأ،
/// ونجومٌ صغيرةٌ تومض حوله — ليشعر الطفلُ أن الشاشة له هو.
///
/// يضغطه الطالبُ فيقفز قفزةً صغيرة وتتلألأ نجومُه. و«تقليلُ الحركة» يُبقي
/// التدرّجَ ثابتاً والنجومَ ساكنة.
class StudentWelcomeBanner extends StatefulWidget {
  const StudentWelcomeBanner({super.key, required this.name, this.grade, this.now});

  final String name;

  /// أقصى عرضٍ للشريط على الجوال (ويكبر قليلاً على التابلت).
  static const double maxWidth = 440;
  final String? grade;

  /// للاختبار: الساعةُ التي تختار التحيّة.
  final DateTime? now;

  /// تحيّةُ الوقت: صباحٌ حتى الظهر، ثم مساء.
  static String greetingFor(DateTime time) =>
      time.hour >= 4 && time.hour < 12 ? tr('home.welcome.morning') : tr('home.welcome.evening');

  /// الاسمُ كما أدخله المعلّم كاملاً، بمسافاتٍ مفردة.
  static String fullName(String name) => name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).join(' ');

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
    // ‏الاسمُ كاملاً كما كتبه المعلّم — ثنائياً أو ثلاثياً — بلا اقتطاع.
    final name = StudentWelcomeBanner.fullName(widget.name);
    final grade = widget.grade?.trim() ?? '';
    // ‏شريطٌ أنيقٌ مدمج: يكبر قليلاً على التابلت والآيباد، ولا يمتدّ بعرض الشاشة.
    final scale = ((MediaQuery.maybeOf(context)?.size.shortestSide ?? 400) / 600).clamp(1.0, 1.2).toDouble();
    final greeting = StudentWelcomeBanner.greetingFor(widget.now ?? DateTime.now());
    return Semantics(
      label: '$greeting $name${grade.isEmpty ? '' : '، $grade'}',
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: StudentWelcomeBanner.maxWidth * scale),
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
                final hop = math.sin(_bounce.value * math.pi) * 5;
                return Transform.translate(
                  offset: Offset(0, -hop),
                  child: Container(
                    padding: EdgeInsets.fromLTRB(8 * scale, 6 * scale, 12 * scale, 6 * scale),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(999),
                      gradient: LinearGradient(
                        begin: Alignment(-1 + t, -1),
                        end: Alignment(1, 1 - t),
                        colors: colors,
                      ),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.85), width: 2),
                      boxShadow: [
                        BoxShadow(color: colors[0].withValues(alpha: 0.32), blurRadius: 12, offset: const Offset(0, 5)),
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
                    width: 36 * scale,
                    height: 36 * scale,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: 0.92),
                      boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 5, offset: Offset(0, 2))],
                    ),
                    child: Text('🌟', style: TextStyle(fontSize: 19 * scale)),
                  ),
                  SizedBox(width: 9 * scale),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          greeting,
                          key: const ValueKey('home-welcome-greeting'),
                          style: TextStyle(
                            fontSize: 11.5 * scale,
                            height: 1.1,
                            fontWeight: FontWeight.w800,
                            color: Colors.white.withValues(alpha: 0.95),
                            shadows: const [Shadow(color: Color(0x55000000), blurRadius: 3, offset: Offset(0, 1))],
                          ),
                        ),
                        if (name.isNotEmpty)
                          FitText(
                            '$name!',
                            textKey: const ValueKey('home-welcome-name'),
                            textAlign: TextAlign.start,
                            maxLines: 2,
                            maxFont: 18 * scale,
                            minFont: 12,
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              height: 1.15,
                              shadows: [Shadow(color: Color(0x66000000), blurRadius: 4, offset: Offset(0, 1))],
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (grade.isNotEmpty) ...[
                    SizedBox(width: 8 * scale),
                    Container(
                      key: const ValueKey('home-welcome-grade'),
                      constraints: BoxConstraints(maxWidth: 150 * scale),
                      padding: EdgeInsets.symmetric(horizontal: 9 * scale, vertical: 4 * scale),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.92),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        '🎒 $grade',
                        maxLines: 2,
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 12 * scale, fontWeight: FontWeight.w900, color: const Color(0xFF5B21B6)),
                      ),
                    ),
                  ],
                ],
              ),
            ),
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
