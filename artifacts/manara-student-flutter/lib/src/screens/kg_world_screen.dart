import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../l10n/student_strings.dart';
import '../services/kindergarten_voice_quiz.dart';
import '../services/student_settings.dart';
import '../services/student_sound_service.dart';
import '../theme/student_theme.dart';
import '../widgets/portal_watermark.dart';
import '../widgets/student_avatar_view.dart';
import '../widgets/student_experience.dart';
import 'kindergarten_voice_games.dart';
import 'magic_coloring_screen.dart';

/// «عالم الحكايات والمغامرات»: ألعابُ الروضة في «الثقافة العامة» في بطاقةٍ
/// واحدة.
///
/// ── ما فيها ──
/// «لوحة الألوان السحرية» في الصدارة — الجديدة، وأكبرُها — ثم الألعابُ
/// الصوتية الأربع كما كانت بطاقاتٍ في الرفّ: الألوان والأشكال والحساب وأسئلةُ
/// الروضة. كلُّ لعبةٍ تُفتح بشاشتها هي ([KgVoiceGameScreen] بنوعها، أو
/// [MagicColoringScreen])، فلا تتغيّر قاعدةٌ من قواعدها، والعودةُ منها إلى هنا
/// لا إلى الواجهة — فيتنقّل الطفلُ بين الألعاب بلا خروج.
class KgWorldScreen extends StatelessWidget {
  const KgWorldScreen({super.key});

  static const _voiceGames = [
    _GameTile(
      key: ValueKey('kgworld-colors'),
      titleKey: 'portal.colors',
      image: 'assets/images/kg_colors.png',
      colors: [Color(0xFFBE185D), Color(0xFFF472B6)],
      kind: KgVoiceGameKind.colors,
    ),
    _GameTile(
      key: ValueKey('kgworld-shapes'),
      titleKey: 'portal.shapes',
      image: 'assets/images/kg_shapes.png',
      colors: [Color(0xFF0369A1), Color(0xFF22D3EE)],
      kind: KgVoiceGameKind.shapes,
    ),
    _GameTile(
      key: ValueKey('kgworld-math'),
      titleKey: 'portal.math',
      image: 'assets/images/kg_math.png',
      colors: [Color(0xFF15803D), Color(0xFF84CC16)],
      kind: KgVoiceGameKind.math,
    ),
    _GameTile(
      key: ValueKey('kgworld-general'),
      titleKey: 'portal.general',
      image: 'assets/images/kg_general.png',
      colors: [Color(0xFF6D28D9), Color(0xFFC084FC)],
      kind: KgVoiceGameKind.general,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final still = MediaQuery.of(context).disableAnimations;
    return Directionality(
      textDirection: StudentSettings.direction,
      child: Scaffold(
        backgroundColor: StudentSurface.ground(context),
        body: Stack(
          children: [
            const PortalWatermark(asset: PortalBackgrounds.games, opacity: 0.24),
            SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final wide = constraints.maxWidth > constraints.maxHeight * 1.15 && constraints.maxWidth > 640;
                  final tiles = [
                    for (var i = 0; i < _voiceGames.length; i++) _entrance(_voiceGames[i], i + 1, still),
                  ];
                  final featured = _entrance(const _ColoringTile(key: ValueKey('kgworld-coloring')), 0, still);
                  return CustomScrollView(
                    slivers: [
                      SliverToBoxAdapter(child: _header(context, still)),
                      if (wide)
                        SliverPadding(
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
                          sliver: SliverToBoxAdapter(
                            child: SizedBox(
                              height: math.max(300, constraints.maxHeight - 130),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Expanded(flex: 5, child: featured),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    flex: 6,
                                    child: Column(
                                      children: [
                                        for (var row = 0; row < 2; row++) ...[
                                          if (row > 0) const SizedBox(height: 14),
                                          Expanded(
                                            child: Row(
                                              crossAxisAlignment: CrossAxisAlignment.stretch,
                                              children: [
                                                Expanded(child: tiles[row * 2]),
                                                const SizedBox(width: 14),
                                                Expanded(child: tiles[row * 2 + 1]),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        )
                      else ...[
                        SliverPadding(
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 14),
                          sliver: SliverToBoxAdapter(child: SizedBox(height: 210, child: featured)),
                        ),
                        SliverPadding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                          sliver: SliverGrid(
                            gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                              maxCrossAxisExtent: 260,
                              mainAxisSpacing: 14,
                              crossAxisSpacing: 14,
                              childAspectRatio: constraints.maxWidth < 380 ? 0.92 : 1.05,
                            ),
                            delegate: SliverChildListDelegate(tiles),
                          ),
                        ),
                      ],
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _entrance(Widget child, int order, bool still) {
    if (still) return child;
    return child
        .animate(delay: Duration(milliseconds: 90 * order))
        .fadeIn(duration: 380.ms)
        .slideY(begin: 0.18, end: 0, duration: 460.ms, curve: Curves.easeOutBack)
        .scaleXY(begin: 0.92, end: 1, duration: 460.ms, curve: Curves.easeOutBack);
  }

  Widget _header(BuildContext context, bool still) {
    // ‏شخصيّةُ الطفل التي اختارها — هي من يدعوه إلى اللعب.
    Widget mascot = const StudentAvatarView(size: 68);
    if (!still) {
      mascot = mascot
          .animate(onPlay: (c) => c.repeat(reverse: true))
          .moveY(begin: 0, end: -6, duration: 1200.ms, curve: Curves.easeInOut);
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 6, 16, 8),
      child: Row(
        children: [
          IconButton(
            key: const ValueKey('kgworld-back'),
            onPressed: () => Navigator.of(context).maybePop(),
            icon: const Icon(Icons.arrow_back_rounded),
            color: StudentSurface.ink(context),
          ),
          mascot,
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                ShaderMask(
                  shaderCallback: (rect) => const LinearGradient(
                    colors: [Color(0xFF7C3AED), Color(0xFFEC4899), Color(0xFFF59E0B)],
                  ).createShader(rect),
                  child: Text(
                    tr('portal.kgworld'),
                    maxLines: 2,
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Colors.white, height: 1.15),
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(
                    color: StudentSurface.glass(context),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: const Color(0xFFF9A8D4)),
                  ),
                  child: Text(
                    tr('kgworld.pick'),
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: StudentSurface.ink(context)),
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

void _open(BuildContext context, Widget screen) {
  HapticFeedback.selectionClick();
  StudentSoundService.instance.play(StudentSoundCue.navigation);
  Navigator.of(context).push(StudentPageRoute<void>(immersive: true, builder: (_) => screen));
}

/// لوحٌ يكبر قليلاً تحت الإصبع ويعود — ضغطةٌ يراها الطفل.
class _Pressable extends StatefulWidget {
  const _Pressable({required this.onTap, required this.child, required this.semantics});

  final VoidCallback onTap;
  final Widget child;
  final String semantics;

  @override
  State<_Pressable> createState() => _PressableState();
}

class _PressableState extends State<_Pressable> {
  bool _down = false;

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        label: widget.semantics,
        child: GestureDetector(
          onTapDown: (_) => setState(() => _down = true),
          onTapCancel: () => setState(() => _down = false),
          onTapUp: (_) => setState(() => _down = false),
          onTap: widget.onTap,
          child: AnimatedScale(
            scale: _down ? 0.95 : 1,
            duration: const Duration(milliseconds: 120),
            child: widget.child,
          ),
        ),
      );
}

BoxDecoration _tileDecoration(List<Color> colors) => BoxDecoration(
      gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: colors),
      borderRadius: BorderRadius.circular(26),
      border: Border.all(color: Colors.white.withValues(alpha: 0.7), width: 2.5),
      boxShadow: [
        BoxShadow(color: colors.last.withValues(alpha: 0.45), blurRadius: 18, offset: const Offset(0, 8)),
      ],
    );

class _GameTile extends StatelessWidget {
  const _GameTile({
    required this.titleKey,
    required this.image,
    required this.colors,
    required this.kind,
    super.key,
  });

  final String titleKey;
  final String image;
  final List<Color> colors;
  final KgVoiceGameKind kind;

  @override
  Widget build(BuildContext context) => _Pressable(
        semantics: tr(titleKey),
        onTap: () => _open(context, KgVoiceGameScreen(kind: kind)),
        child: Container(
          decoration: _tileDecoration(colors),
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              Align(
                alignment: AlignmentDirectional.topEnd,
                child: Container(
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.25), shape: BoxShape.circle),
                  child: const Icon(Icons.mic_rounded, color: Colors.white, size: 18),
                ),
              ),
              Expanded(
                child: Image.asset(image, fit: BoxFit.contain, errorBuilder: (_, __, ___) => const SizedBox()),
              ),
              const SizedBox(height: 6),
              Text(
                tr(titleKey),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  shadows: [Shadow(color: Color(0x55000000), blurRadius: 4, offset: Offset(0, 2))],
                ),
              ),
              Text(
                tr('$titleKey.sub'),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white.withValues(alpha: 0.9)),
              ),
            ],
          ),
        ),
      );
}

/// بطاقةُ «لوحة الألوان السحرية»: أكبرُ من أخواتها، وعليها «جديد».
class _ColoringTile extends StatelessWidget {
  const _ColoringTile({super.key});

  static const _colors = [Color(0xFFF97316), Color(0xFFEC4899), Color(0xFF8B5CF6)];

  @override
  Widget build(BuildContext context) => _Pressable(
        semantics: tr('portal.coloring'),
        onTap: () => _open(context, const MagicColoringScreen()),
        child: Container(
          decoration: _tileDecoration(_colors),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            children: [
              // ‏بقعُ ألوانٍ تزيّن اللوح.
              for (final (x, y, r, c) in const [
                (0.08, 0.12, 26.0, Color(0xFFFDE047)),
                (0.92, 0.18, 20.0, Color(0xFF34D399)),
                (0.85, 0.85, 30.0, Color(0xFF60A5FA)),
                (0.14, 0.88, 18.0, Color(0xFFF472B6)),
              ])
                Align(
                  alignment: Alignment(x * 2 - 1, y * 2 - 1),
                  child: Container(
                    width: r * 2,
                    height: r * 2,
                    decoration: BoxDecoration(color: c.withValues(alpha: 0.55), shape: BoxShape.circle),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFDE047),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              '✨ ${tr('kgworld.new')}',
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: Color(0xFF7C2D12)),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            tr('portal.coloring'),
                            maxLines: 2,
                            style: const TextStyle(
                              fontSize: 24,
                              height: 1.15,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              shadows: [Shadow(color: Color(0x66000000), blurRadius: 6, offset: Offset(0, 2))],
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            tr('portal.coloring.desc'),
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white.withValues(alpha: 0.95)),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    const _PaletteBadge(),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
}

/// لوحُ الرسّام بألوانه وفرشاته — يدور على مهلٍ.
class _PaletteBadge extends StatelessWidget {
  const _PaletteBadge();

  @override
  Widget build(BuildContext context) {
    Widget badge = Container(
      width: 104,
      height: 104,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 12, offset: Offset(0, 6))],
        border: Border.all(color: const Color(0xFFFDE68A), width: 4),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          for (var i = 0; i < 6; i++)
            Transform.translate(
              offset: Offset(32 * math.cos(i * math.pi / 3), 32 * math.sin(i * math.pi / 3)),
              child: Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const [
                    Color(0xFFEF4444),
                    Color(0xFFF59E0B),
                    Color(0xFFFDE047),
                    Color(0xFF22C55E),
                    Color(0xFF3B82F6),
                    Color(0xFFA855F7),
                  ][i],
                ),
              ),
            ),
          const Icon(Icons.brush_rounded, size: 34, color: Color(0xFF7C3AED)),
        ],
      ),
    );
    if (!MediaQuery.of(context).disableAnimations) {
      badge = badge
          .animate(onPlay: (c) => c.repeat(reverse: true))
          .rotate(begin: -0.03, end: 0.03, duration: 1600.ms, curve: Curves.easeInOut);
    }
    return badge;
  }
}
