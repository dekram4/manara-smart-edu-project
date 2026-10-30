import 'dart:async';
import 'dart:math' as math;

import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';

import '../l10n/student_strings.dart';
import '../models/academic_context.dart';
import '../models/student_gamification.dart';
import '../models/study_games.dart';
import '../models/student_profile.dart';
import '../services/student_content_service.dart';
import '../services/student_settings.dart';
import '../services/student_sound_service.dart';
import '../services/student_study_service.dart';
import '../theme/student_theme.dart';
import '../widgets/portal_watermark.dart';
import '../widgets/study_games.dart';
import '../widgets/student_experience.dart';

/// «مغامرة الأذكياء ومهمة المذاكرة»: ألعابُ الدرس وحدها.
///
/// أربعُ ألعابٍ تفاعلية — البالونات والصيدُ والقطارُ والمقلاع — بأسئلةٍ
/// مستخرجةٍ من نصّ الدرس الذي أدخله المعلّم، فيذاكر الطفلُ درسَه وهو يلعب.
/// لا خريطةَ ولا تحدّيَ قصصيّ: البطاقةُ تُفتح على الألعاب مباشرة.
class StudentStudyScreen extends StatefulWidget {
  const StudentStudyScreen({
    required this.profile,
    required this.studyService,
    required this.contentService,
    this.academicContext,
    super.key,
  });

  final StudentProfile profile;
  final StudentStudyService studyService;

  /// لصرف مكافأة اللعبة.
  final StudentContentService contentService;
  final AcademicContext? academicContext;

  @override
  State<StudentStudyScreen> createState() => _StudentStudyScreenState();
}

class _StudentStudyScreenState extends State<StudentStudyScreen> {
  late final ConfettiController _confetti =
      ConfettiController(duration: const Duration(milliseconds: 600));

  @override
  void initState() {
    super.initState();
    // الصوتُ الترحيبي على مشغّل الأصوات المشترك.
    //
    // والواجهةُ لا تنطق سطرَ البوابة لهذه البطاقة — `ownsVoice` في
    // `_homeSections` — وإلا حلّ المقطعُ العامّ محلَّ هذا على المشغّل نفسه.
    // والمسارُ بلا بادئة `assets/`: حزمةُ الصوت تضيفها بنفسها.
    unawaited(StudentSoundService.instance.playClip('audio/booksound.mp3'));
  }

  /// ألعابُ الدرس من الخادم، والمحفوظُ منها يُعرض فوراً.
  Future<StudyGamesPack> _takeGames() => widget.studyService.fetchGames(lessonId: _lessonId);

  @override
  void dispose() {
    _confetti.dispose();
    super.dispose();
  }

  String get _lessonId => widget.academicContext?.selectedLesson.id ?? '';

  /// ── المكافأةُ يقرّرها الخادم ──
  /// المعرّفُ `درس::لعبة`، والخادمُ يقرأ جواهرَها ونقاطَها من سجلّ الدرس
  /// ويصرفها مرّةً لكل لعبة — فالإعادةُ للمتعة لا لجمع الجواهر.
  Future<RewardResult?> _rewardGame(StudyGame game) async {
    final result = await widget.contentService.rewardActivity(
      profile: widget.profile,
      activityType: 'study_game',
      activityId: '$_lessonId::${game.id}',
    );
    if (result.gems > 0 && mounted) _confetti.play();
    return result;
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: StudentSettings.direction,
      child: Scaffold(
        backgroundColor: StudentSurface.ground(context),
        body: Stack(
          children: [
            const PortalWatermark(asset: PortalBackgrounds.study),
            const Positioned.fill(child: _CartoonSky()),
            SafeArea(
              child: Column(
                children: [
                  _StudyHeader(lessonName: widget.academicContext?.lesson ?? ''),
                  Expanded(child: _body(context)),
                ],
              ),
            ),
            // الورقُ المتناثر فوق الكلّ، ولا يستقبل لمسة.
            Align(
              alignment: Alignment.topCenter,
              child: IgnorePointer(
                child: ConfettiWidget(
                  confettiController: _confetti,
                  blastDirection: math.pi / 2,
                  emissionFrequency: 0,
                  numberOfParticles: 18,
                  maxBlastForce: 18,
                  minBlastForce: 8,
                  gravity: 0.25,
                  shouldLoop: false,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _body(BuildContext context) {
    if (_lessonId.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('📚', style: TextStyle(fontSize: 52)),
              const SizedBox(height: 14),
              Text(
                tr('study.error.noLesson'),
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 15, height: 1.6, fontWeight: FontWeight.w800, color: StudentSurface.ink(context)),
              ),
            ],
          ),
        ),
      );
    }
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 36),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 920),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              StudentEntrance(
                child: _SectionBanner(
                  emoji: '🎮',
                  title: tr('study.tabGames'),
                  subtitle: tr('study.section.games'),
                  colors: const [Color(0xFFF59E0B), Color(0xFFEC4899)],
                ),
              ),
              const SizedBox(height: 12),
              StudyGamesTab(
                load: _takeGames,
                cached: () => StudentStudyService.cachedGames(lessonId: _lessonId),
                onWin: _rewardGame,
                // ‏كلُّ لعبٍ بعد الأوّل أسئلةٌ جديدة من النصّ الكامل للدرس، لا تكرّر ما رآه.
                fresh: (base, exclude) => widget.studyService.fetchFreshGame(
                  lessonId: _lessonId,
                  type: base.type,
                  exclude: exclude,
                ),
                seenKey: 'study.seen.${widget.profile.id}.$_lessonId',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// الرأس
// ─────────────────────────────────────────────────────────────────────

/// رأسُ الشاشة: الرجوع، والعنوانُ ودرسُه، وزرُّ الصوت.
class _StudyHeader extends StatelessWidget {
  const _StudyHeader({required this.lessonName});

  final String lessonName;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 12, 8),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).maybePop(),
            tooltip: MaterialLocalizations.of(context).backButtonTooltip,
            icon: const BackButtonIcon(),
            color: StudentSurface.ink(context),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // يصغر ولا يُقصّ: «مغامرة الأذكياء ومهمة المذاكرة» أطولُ من
                // عرض هاتف، و«…» في عنوان الشاشة يُخفي نصفَ اسمها.
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: AlignmentDirectional.centerStart,
                  child: Text(
                    tr('portal.study'),
                    maxLines: 1,
                    style: TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w900,
                      color: StudentSurface.ink(context),
                    ),
                  ),
                ),
                if (lessonName.trim().isNotEmpty)
                  Text(
                    lessonName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                      color: StudentSurface.mutedInk(context),
                    ),
                  ),
              ],
            ),
          ),
          const StudentSoundToggle(),
        ],
      ),
    );
  }
}

/// رأسُ قسمٍ في الصفحة: شريطٌ كرتونيٌّ بلونه على حافّةٍ أغمق، ورمزٌ يتمايل
/// في دائرة، ونجومٌ تلمع. ومن طلب تقليلَ الحركة يراه ساكناً بألوانه.
class _SectionBanner extends StatefulWidget {
  const _SectionBanner({
    required this.emoji,
    required this.title,
    required this.subtitle,
    required this.colors,
  });

  final String emoji;
  final String title;
  final String subtitle;
  final List<Color> colors;

  @override
  State<_SectionBanner> createState() => _SectionBannerState();
}

class _SectionBannerState extends State<_SectionBanner> with SingleTickerProviderStateMixin {
  late final AnimationController _sway =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 2200));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.maybeOf(context)?.disableAnimations ?? false) {
      _sway
        ..stop()
        ..value = 0.5;
    } else if (!_sway.isAnimating) {
      _sway.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _sway.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = widget.colors;
    final ledge = Color.lerp(colors.first, Colors.black, 0.35)!;
    return Container(
      padding: const EdgeInsets.only(bottom: 5),
      decoration: BoxDecoration(
        color: ledge,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: colors.first.withValues(alpha: 0.35), blurRadius: 18, offset: const Offset(0, 8))],
      ),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white.withValues(alpha: 0.8), width: 2),
          gradient: LinearGradient(
            colors: colors,
            begin: AlignmentDirectional.topStart,
            end: AlignmentDirectional.bottomEnd,
          ),
        ),
        child: AnimatedBuilder(
          animation: _sway,
          builder: (context, _) {
            final t = Curves.easeInOut.transform(_sway.value);
            return Row(
              children: [
                Transform.rotate(
                  angle: (t - 0.5) * 0.35,
                  child: Transform.scale(
                    scale: 1 + 0.08 * t,
                    child: Container(
                      width: 54,
                      height: 54,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: 0.28),
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: Text(widget.emoji, style: const TextStyle(fontSize: 28)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.title,
                        style: const TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          shadows: [Shadow(color: Color(0x55000000), offset: Offset(0, 2), blurRadius: 3)],
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        widget.subtitle,
                        style: const TextStyle(fontSize: 12.5, height: 1.35, fontWeight: FontWeight.w800, color: Colors.white),
                      ),
                    ],
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Opacity(opacity: 0.35 + 0.65 * t, child: const Text('✨', style: TextStyle(fontSize: 18))),
                    Opacity(opacity: 1 - 0.65 * t, child: const Text('⭐', style: TextStyle(fontSize: 13))),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// سماءٌ كرتونيّةٌ خلف الصفحة: فقاعاتٌ ونجومٌ ملوّنةٌ باهتة تطفو ببطء.
/// في طبقةٍ وحدها فلا تُعيد رسمَ الصفحة، وتسكن لمن طلب تقليلَ الحركة.
class _CartoonSky extends StatefulWidget {
  const _CartoonSky();

  @override
  State<_CartoonSky> createState() => _CartoonSkyState();
}

class _CartoonSkyState extends State<_CartoonSky> with SingleTickerProviderStateMixin {
  late final AnimationController _drift = AnimationController(vsync: this, duration: const Duration(seconds: 16));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.maybeOf(context)?.disableAnimations ?? false) {
      _drift.stop();
    } else if (!_drift.isAnimating) {
      _drift.repeat();
    }
  }

  @override
  void dispose() {
    _drift.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: RepaintBoundary(
        child: CustomPaint(painter: _SkyPainter(_drift, dark: Theme.of(context).brightness == Brightness.dark)),
      ),
    );
  }
}

class _SkyPainter extends CustomPainter {
  _SkyPainter(this.drift, {required this.dark}) : super(repaint: drift);

  final Animation<double> drift;
  final bool dark;

  static const _colors = [
    Color(0xFF7C3AED),
    Color(0xFFEC4899),
    Color(0xFFF59E0B),
    Color(0xFF0EA5E9),
    Color(0xFF16A34A),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final t = drift.value;
    for (var i = 0; i < 14; i++) {
      final color = _colors[i % _colors.length].withValues(alpha: dark ? 0.16 : 0.1);
      final x = size.width * ((i * 0.173 + 0.07) % 1) + math.sin((t + i * 0.13) * 2 * math.pi) * 18;
      final y = size.height * (1 - ((t * (0.35 + (i % 4) * 0.12) + i * 0.071) % 1.0));
      final r = 10.0 + (i % 5) * 7;
      if (i % 3 == 0) {
        // ‏نجمةٌ بخمس رؤوس.
        final path = Path();
        for (var k = 0; k < 10; k++) {
          final a = -math.pi / 2 + k * math.pi / 5 + t * math.pi * 2 * (i.isEven ? 1 : -1) * 0.25;
          final rr = k.isEven ? r : r * 0.45;
          final p = Offset(x + math.cos(a) * rr, y + math.sin(a) * rr);
          if (k == 0) {
            path.moveTo(p.dx, p.dy);
          } else {
            path.lineTo(p.dx, p.dy);
          }
        }
        canvas.drawPath(path..close(), Paint()..color = color);
      } else {
        canvas.drawCircle(Offset(x, y), r, Paint()..color = color);
        canvas.drawCircle(Offset(x - r * 0.35, y - r * 0.35), r * 0.25, Paint()..color = Colors.white.withValues(alpha: dark ? 0.08 : 0.35));
      }
    }
  }

  @override
  bool shouldRepaint(_SkyPainter old) => old.dark != dark;
}
