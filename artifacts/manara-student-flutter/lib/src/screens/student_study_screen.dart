import 'dart:async';
import 'dart:math' as math;

import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import '../widgets/lively.dart';
import '../theme/motion.dart';

import '../l10n/student_strings.dart';
import '../models/academic_context.dart';
import '../models/interactive_study.dart';
import '../models/student_gamification.dart';
import '../models/study_games.dart';
import '../models/student_profile.dart';
import '../services/student_content_service.dart';
import '../services/student_settings.dart';
import '../services/student_sound_service.dart';
import '../services/student_study_service.dart';
import '../services/study_rotation.dart';
import '../theme/student_theme.dart';
import '../widgets/portal_watermark.dart';
import '../widgets/study_challenges.dart';
import '../widgets/study_games.dart';
import '../widgets/student_avatar_view.dart';
import '../widgets/student_experience.dart';

/// «مغامرة الأذكياء ومهمة المذاكرة»: خريطةُ الدرس، وتحدٍّ قصصيٌّ فيه، وألعابُه.
///
/// ── صفحةٌ واحدةٌ لا تبويبات ──
/// الأقسامُ الثلاثة رحلةٌ واحدة تُقرأ من أعلى إلى أسفل: يمرّ الطفلُ على محطات
/// الدرس، ثم يُختبر فيها بحكاية، ثم يلعب بأسئلتها. ولكل قسمٍ رأسٌ كرتونيٌّ
/// بلونه يدلّ عليه، وبين الأقسام آثارُ أقدامٍ تقود إلى ما بعدها — فلا يبحث
/// الطفلُ عن تبويبٍ لا يراه زرّاً.
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

  /// لصرف الجواهر في ختام التحدي.
  final StudentContentService contentService;
  final AcademicContext? academicContext;

  @override
  State<StudentStudyScreen> createState() => _StudentStudyScreenState();
}

class _StudentStudyScreenState extends State<StudentStudyScreen> {
  StudyPack? _pack;
  String? _error;
  bool _loading = true;

  /// رأسُ «التحدي القصصي»: يُمرَّر إليه حين يبدأ تحدٍّ من الخريطة.
  final _storyKey = GlobalKey();
  late final ConfettiController _confetti =
      ConfettiController(duration: const Duration(milliseconds: 600));

  /// التحدي الجاري، وموضعُ الطفل منه.
  StudyScenario? _scenario;
  int _at = 0;
  int _correct = 0;
  int? _picked;

  /// الفرعُ الذي ضغطه الطالب، فيكون التحدي فيه لا في الدرس كلِّه.
  ///
  /// ── لماذا يُحفظ ──
  /// الطفل يقرأ فرعاً ثم يريد أن يُختبر فيه هو. ولو كان التحدي عامّاً لكان
  /// ضغطُ الفرع قراءةً بلا أثر — و`forBranch` ترتدّ إلى الحزمة كلِّها إن
  /// لم يكن للفرع تحدٍّ خاصّ، فلا يبقى زرٌّ لا يفعل شيئاً.
  String _branch = '';

  /// جواهرُ الجولة كما صرفها الخادم، أو `null` قبل أن تُصرف.
  int? _earned;
  bool _alreadyRewarded = false;
  bool _rewarding = false;

  final _random = math.Random();

  /// ما لعبه هذا الطالب من مغامرات هذا الدرس — لا يتكرّر قبل أخواته.
  StudyRotation? _rotation;

  @override
  void initState() {
    super.initState();
    // الصوتُ الترحيبي على مشغّل الأصوات المشترك.
    //
    // والواجهةُ لا تنطق سطرَ البوابة لهذه البطاقة — `ownsVoice` في
    // `_homeSections` — وإلا حلّ المقطعُ العامّ محلَّ هذا على المشغّل نفسه.
    // والمسارُ بلا بادئة `assets/`: حزمةُ الصوت تضيفها بنفسها، فمسارٌ
    // كاملٌ يصير `assets/assets/audio/...` فلا يُعثر عليه — ويُفتح المشهد
    // صامتاً بلا خطأٍ يظهر. وهو سببُ صمت هذه الشاشة، والملفُّ في مكانه.
    unawaited(StudentSoundService.instance.playClip('audio/booksound.mp3'));
    unawaited(_load());
  }

  /// ألعابُ الدرس تُطلب في قسمها وحده، لا مع الخريطة: الخريطةُ والتحدّي لا
  /// ينتظران توليدَ الألعاب على الخادم، والمحفوظُ منها يُعرض فوراً.
  Future<StudyGamesPack> _takeGames() => widget.studyService.fetchGames(lessonId: _lessonId);

  @override
  void dispose() {
    _confetti.dispose();
    super.dispose();
  }

  String get _lessonId => widget.academicContext?.selectedLesson.id ?? '';

  /// جواهرُ الجولة الجارية كما تُعرض للطفل، قبل أن يُسأل الخادم.
  ///
  /// ── ولماذا تُعرض قبل أن تُصرف ──
  /// الطفلُ يحتاج أن يرى «+٢» في اللحظة التي يُصيب فيها، لا بعد ثلاثة
  /// مواقف. وصرفُها في الخادم عند كل قرارٍ يعني ثلاثة طلباتٍ في الجولة،
  /// وحارسُ التكرار هناك مفتاحُه الدرسُ لا الموقف — فالثاني والثالث يعودان
  /// بصفر ولو أصاب.
  ///
  /// فالعرضُ فوريّ، والحسابُ يُسوَّى مرّةً في الختام: الخادم يحصر الجواهر
  /// بعدد المواقف ويمنع التكرار، وما يُعرض هنا هو ما سيُصرف — جوهرتان عن
  /// كل صحيح.
  int get _runGems => _correct * 2;

  Future<void> _load() async {
    final lessonId = _lessonId;
    if (lessonId.isEmpty) {
      setState(() {
        _loading = false;
        _error = tr('study.error.noLesson');
      });
      return;
    }
    // ‏المحفوظُ على الجهاز أوّلاً: البطاقةُ تُفتح في لحظتها، والجديدُ يحلّ محلّه
    // حين يصل من الخادم.
    final rotation = StudyRotation.load(studentId: widget.profile.id, lessonId: lessonId);
    final saved = await StudentStudyService.cachedPack(lessonId: lessonId);
    if (saved != null && mounted) {
      final turn = await rotation;
      if (!mounted) return;
      setState(() {
        _pack = saved;
        _rotation = turn;
        _loading = false;
      });
    }
    try {
      final results = await Future.wait<Object>([
        widget.studyService.fetch(lessonId: lessonId),
        rotation,
      ]);
      if (!mounted) return;
      setState(() {
        _pack = results[0] as StudyPack;
        _rotation = results[1] as StudyRotation;
        _loading = false;
        _error = null;
      });
    } on StudyServerFailure catch (failure) {
      if (!mounted || _pack != null) return;
      setState(() {
        _loading = false;
        _error = failure.message;
      });
    } on StudyFailure catch (failure) {
      if (!mounted || _pack != null) return;
      setState(() {
        _loading = false;
        _error = failure.message;
      });
    } catch (_) {
      // الخادمُ تعذّر والمحفوظُ معروض: يبقى، بلا رسالة خطأ.
      if (!mounted || _pack != null) return;
      setState(() {
        _loading = false;
        _error = tr('study.error.failed');
      });
    }
  }

  /// يبدأ تحدياً لم يُلعب في هذا الدرس بعد، ما أمكن.
  ///
  /// عشوائيةٌ محضةٌ بين اثنين تُعيد الأول في نصف الجولات، والطفل يقرأ
  /// الحكايةَ نفسها فيظنّ البطاقة معطوبة. فيُختار ممّا لم يلعبه هذا الطالب
  /// في هذا الدرس — محفوظاً بين الجلسات ([StudyRotation]) — ثم تبدأ دورة.
  void _start([String branch = '']) {
    final pack = _pack;
    if (pack == null || pack.scenarios.isEmpty) return;
    if (branch.isNotEmpty) _branch = branch;
    final scoped = pack.forBranch(_branch);
    final rotation = _rotation;
    final chosenTitle = rotation?.pick(
      [for (final item in scoped) item.title],
      current: _scenario?.title,
      random: _random,
    );
    final others = scoped.where((item) => item != _scenario).toList();
    final pool = others.isEmpty ? scoped : others;
    final chosen = scoped.firstWhere(
      (item) => item.title == chosenTitle,
      orElse: () => pool[_random.nextInt(pool.length)],
    );
    setState(() {
      _scenario = chosen;
      _at = 0;
      _correct = 0;
      _picked = null;
      _earned = null;
      _alreadyRewarded = false;
    });
    // ‏الحكايةُ تحت الخريطة: تُمرَّر إليها الصفحة.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final story = _storyKey.currentContext;
      if (story != null && mounted) {
        unawaited(Scrollable.ensureVisible(story, duration: const Duration(milliseconds: 450), curve: Curves.easeInOutCubic));
      }
    });
  }

  void _pick(int choice) {
    final scenario = _scenario;
    if (scenario == null || _picked != null) return;
    final situation = scenario.situations[_at];
    final right = situation.isCorrect(choice);
    setState(() {
      _picked = choice;
      if (right) _correct += 1;
    });
    if (right) {
      // مؤثّرُ الفوز في اللحظة نفسها: الطفل يرى الورقَ يتناثر و«+٢»
      // تظهر، فيعرف أنه أصاب قبل أن يقرأ سطر الشرح.
      _confetti.play();
      StudentSoundService.instance.playCheer();
    } else {
      StudentSoundService.instance.play(StudentSoundCue.warning);
    }
  }

  Future<void> _next() async {
    final scenario = _scenario;
    if (scenario == null) return;
    if (_at + 1 < scenario.situations.length) {
      setState(() {
        _at += 1;
        _picked = null;
      });
      return;
    }
    await _finish(scenario);
  }

  /// ── تسويةُ الجواهر: الخادم يقرّر ──
  ///
  /// جوهرتان عن كل قرارٍ صحيح، وللمرّة الأولى وحدها. وسجلُّ الأنشطة في
  /// الخادم هو الحارس: `activityId` معرّفُ الدرس، فإعادةُ التحدي — ولو
  /// بسيناريو آخر — تعود بـ`alreadyRewarded` وبصفر جواهر.
  Future<void> _finish(StudyScenario scenario) async {
    setState(() => _rewarding = true);
    try {
      final result = await widget.contentService.rewardActivity(
        profile: widget.profile,
        activityType: 'story',
        activityId: _lessonId,
        correctAnswers: _correct,
        quizTotal: scenario.situations.length,
      );
      if (!mounted) return;
      setState(() {
        _earned = result.gems;
        _alreadyRewarded = result.alreadyRewarded;
        _rewarding = false;
        _scenario = null;
      });
      if (result.gems > 0) {
        _confetti.play();
        StudentSoundService.instance.playApplause();
        StudentSoundService.instance.playReward();
      }
    } catch (_) {
      if (!mounted) return;
      // الجواهرُ لم تُصرف، والتحدي تمّ. فيُقال ذلك ولا تُعاد الجولة.
      setState(() {
        _earned = 0;
        _alreadyRewarded = false;
        _rewarding = false;
        _scenario = null;
      });
    }
  }

  /// «ألعاب الدرس»: سحبٌ وإسقاط، ومطابقة، وأسئلةُ الدرس في أربع ألعاب.
  ///
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
                  // انتقال القسم (مواصفة الحركة §5.4): المحتوى فوراً، وشريطٌ
                  // رفيعٌ أعلاه ما دام يُحضَّر.
                  Expanded(
                    child: MotionSectionOverlay(
                      ready: !_loading,
                      label: tr('study.preparing'),
                      child: _loading ? const SizedBox.expand() : _body(context),
                    ),
                  ),
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
    final error = _error;
    if (error != null) {
      return Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('📚', style: TextStyle(fontSize: 52)),
              const SizedBox(height: 14),
              Text(
                error,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  height: 1.6,
                  fontWeight: FontWeight.w800,
                  color: StudentSurface.ink(context),
                ),
              ),
              const SizedBox(height: 18),
              _StudyButton(
                label: tr('study.again'),
                onPressed: () {
                  setState(() {
                    _loading = true;
                    _error = null;
                  });
                  unawaited(_load());
                },
              ),
            ],
          ),
        ),
      );
    }
    final pack = _pack;
    if (pack == null) return const SizedBox.shrink();

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
                  emoji: '🗺️',
                  title: tr('study.tabMap'),
                  subtitle: tr('study.section.map'),
                  colors: const [_StudyTokens.violet, Color(0xFF6366F1)],
                ),
              ),
              const SizedBox(height: 12),
              _MapTab(
                mindMap: pack.mindMap,
                // ‏«تحدَّني في هذه المحطة» يبدأ تحدّيها وتُمرَّر الصفحةُ إليه.
                onChallengeBranch: _start,
                onChallengeAll: () {
                  _branch = '';
                  _start();
                },
              ),
              const _Footsteps(color: _StudyTokens.fuchsia),
              StudentEntrance(
                delay: const Duration(milliseconds: 120),
                child: _SectionBanner(
                  key: _storyKey,
                  emoji: '⚡',
                  title: tr('study.tabStory'),
                  subtitle: tr('study.section.story'),
                  colors: const [_StudyTokens.fuchsia, Color(0xFFDB2777)],
                ),
              ),
              const SizedBox(height: 12),
              _StoryTab(
                appearance: widget.profile.appearance,
                branch: _branch,
                scenario: _scenario,
                at: _at,
                picked: _picked,
                runGems: _runGems,
                earned: _earned,
                alreadyRewarded: _alreadyRewarded,
                busy: _rewarding,
                onStart: _start,
                onPick: _pick,
                onNext: _next,
              ),
              const _Footsteps(color: _StudyTokens.gold),
              StudentEntrance(
                delay: const Duration(milliseconds: 240),
                child: _SectionBanner(
                  emoji: '🎮',
                  title: tr('study.tabGames'),
                  subtitle: tr('study.section.games'),
                  colors: const [Color(0xFFF59E0B), Color(0xFFEC4899)],
                ),
              ),
              const SizedBox(height: 12),
              StudyGamesTab(
                embedded: true,
                load: _takeGames,
                cached: () => StudentStudyService.cachedGames(lessonId: _lessonId),
                onWin: _rewardGame,
                // ‏إعادةُ اللعب نسخةٌ جديدة من النصّ الكامل للدرس، لا تكرّر ما رآه.
                fresh: (base, exclude) => widget.studyService.fetchFreshGame(
                  lessonId: _lessonId,
                  type: base.type,
                  exclude: exclude,
                ),
                seenKey: 'study.seen.${widget.profile.id}.$_lessonId',
                // ‏«تتبّع واكتب» و«تسميع القرآن» خرجتا إلى بطاقتين في الواجهة
                // ‏(«قلمي السحري» و«أبطال تسميع القرآن»): لا تتكرّران هنا.
                allowTracing: false,
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

/// ألوانُ المذاكرة: بنفسجيٌّ للخريطة والفهم، وفوشيّ للتحدي، وذهبٌ للجواهر.
class _StudyTokens {
  static const violet = Color(0xFF7C3AED);
  static const fuchsia = Color(0xFFC026D3);
  static const gold = Color(0xFFF59E0B);
  static const green = Color(0xFF16A34A);

  /// لونُ كل محطةٍ في الخريطة، بالتناوب: محطاتٌ متجاورةٌ لا تتشابه.
  static const stations = [
    Color(0xFF7C3AED),
    Color(0xFF0EA5E9),
    Color(0xFFDB2777),
    Color(0xFF16A34A),
    Color(0xFFF59E0B),
    Color(0xFF6366F1),
  ];
}

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
    super.key,
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

/// آثارُ أقدامٍ بين قسمين: تقود الطفلَ إلى ما بعدها.
class _Footsteps extends StatelessWidget {
  const _Footsteps({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (var i = 0; i < 4; i++)
            Padding(
              padding: EdgeInsets.only(top: i.isEven ? 0 : 10, left: 6, right: 6),
              child: Container(
                width: 10,
                height: 14,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.25 + i * 0.15),
                  borderRadius: const BorderRadius.all(Radius.elliptical(5, 7)),
                ),
              ),
            ),
        ],
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

// ─────────────────────────────────────────────────────────────────────
// الخريطة: مسارُ محطات
// ─────────────────────────────────────────────────────────────────────

/// خريطةُ الدرس مساراً من محطاتٍ مرقّمة، لا شجرةً تُسحب وتُكبَّر.
///
/// ── لماذا مسارٌ لا شجرة ──
/// الشجرةُ في هاتفٍ لا تُقرأ إلا بإصبعين: تُكبَّر لتُقرأ، فيضيع شكلُها، وتُصغَّر
/// ليُرى شكلُها، فلا يُقرأ. والدرسُ هنا فروعٌ من جذعٍ واحد — مستوىً واحد —
/// فهي في الحقيقة قائمةٌ مرتّبة. فتُعرض كذلك: محطةٌ بعد محطة، برقمها ولونها،
/// يمرّ عليها الطفلُ بإبهامه كما يمرّ على مسارٍ في لعبة.
///
/// والمحطةُ تُفتح بضغطة: العناوينُ وحدها تُري شكلَ الدرس، والشرحُ لمن طلبه.
class _MapTab extends StatefulWidget {
  const _MapTab({
    required this.mindMap,
    required this.onChallengeBranch,
    required this.onChallengeAll,
  });

  final StudyMindMap mindMap;
  final ValueChanged<String> onChallengeBranch;
  final VoidCallback onChallengeAll;

  @override
  State<_MapTab> createState() => _MapTabState();
}

class _MapTabState extends State<_MapTab> {
  final _open = <int>{};

  @override
  Widget build(BuildContext context) {
    final branches = widget.mindMap.branches;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        StudentEntrance(
          child: _MapHero(
            title: widget.mindMap.title,
            stations: branches.length,
            onChallengeAll: widget.onChallengeAll,
          ),
        ),
        const SizedBox(height: 14),
        for (var index = 0; index < branches.length; index++)
          StudentEntrance(
            delay: Duration(milliseconds: 60 * math.min(index, 6)),
            child: _Station(
              number: index + 1,
              branch: branches[index],
              color:
                  _StudyTokens.stations[index % _StudyTokens.stations.length],
              opened: _open.contains(index),
              last: index == branches.length - 1,
              onToggle: () {
                StudentSoundService.instance.playTap();
                setState(() {
                  if (!_open.remove(index)) _open.add(index);
                });
              },
              onChallenge: () =>
                  widget.onChallengeBranch(branches[index].title),
            ),
          ),
      ],
    );
  }
}

class _MapHero extends StatelessWidget {
  const _MapHero({
    required this.title,
    required this.stations,
    required this.onChallengeAll,
  });

  final String title;
  final int stations;
  final VoidCallback onChallengeAll;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          begin: AlignmentDirectional.topStart,
          end: AlignmentDirectional.bottomEnd,
          colors: [_StudyTokens.violet, _StudyTokens.fuchsia],
        ),
        boxShadow: [
          BoxShadow(
            color: _StudyTokens.violet.withValues(alpha: 0.35),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('🧠', style: TextStyle(fontSize: 30)),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 19,
                    height: 1.35,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            trf('study.mapIntro', {'n': '$stations'}),
            style: const TextStyle(
              color: Color(0xFFF5D0FE),
              fontSize: 13.5,
              height: 1.5,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 14),
          _StudyButton(
            label: tr('study.challengeWhole'),
            icon: '⚡',
            onPressed: onChallengeAll,
            color: Colors.white,
            ink: _StudyTokens.violet,
          ),
        ],
      ),
    );
  }
}

/// محطةٌ في المسار: رقمٌ في دائرةٍ ملوّنةٍ على خطّ المسار، وبطاقةٌ تنفتح.
class _Station extends StatelessWidget {
  const _Station({
    required this.number,
    required this.branch,
    required this.color,
    required this.opened,
    required this.last,
    required this.onToggle,
    required this.onChallenge,
  });

  final int number;
  final StudyBranch branch;
  final Color color;
  final bool opened;
  final bool last;
  final VoidCallback onToggle;
  final VoidCallback onChallenge;

  @override
  Widget build(BuildContext context) {
    // ── و`IntrinsicHeight` لخطّ المسار ──
    // الخطُّ يمتدّ بارتفاع البطاقة، والبطاقةُ تطول حين تنفتح. وبلا قياسٍ أوّلٍ
    // لارتفاع الصفّ يُمرَّر للخطّ ارتفاعٌ لا نهائيٌّ من العمود فيسقط التخطيط.
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 44,
            child: Column(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  margin: const EdgeInsets.only(top: 10),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: color,
                    border: Border.all(color: Colors.white, width: 2.5),
                    boxShadow: [
                      BoxShadow(
                          color: color.withValues(alpha: 0.45), blurRadius: 8),
                    ],
                  ),
                  child: Text(
                    '$number',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                if (!last)
                  Expanded(
                    child: Container(
                      width: 3,
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(2),
                        color: color.withValues(alpha: 0.30),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Material(
                color: StudentSurface.card(context),
                borderRadius: BorderRadius.circular(18),
                clipBehavior: Clip.antiAlias,
                elevation: opened ? 3 : 1,
                shadowColor: color.withValues(alpha: 0.4),
                child: InkWell(
                  onTap: onToggle,
                  child: Container(
                    decoration: BoxDecoration(
                      border: BorderDirectional(
                        start: BorderSide(color: color, width: 5),
                      ),
                    ),
                    padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
                    child: AnimatedSize(
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeOut,
                      alignment: AlignmentDirectional.topStart,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              // رمزُ المحطة إن أرسله النموذج.
                              if (branch.icon.isNotEmpty) ...[
                                Text(branch.icon,
                                    style: const TextStyle(fontSize: 18)),
                                const SizedBox(width: 8),
                              ],
                              Expanded(
                                child: Text(
                                  branch.title,
                                  style: TextStyle(
                                    fontSize: 15.5,
                                    height: 1.35,
                                    fontWeight: FontWeight.w900,
                                    color: StudentSurface.ink(context),
                                  ),
                                ),
                              ),
                              AnimatedRotation(
                                turns: opened ? 0.5 : 0,
                                duration: const Duration(milliseconds: 180),
                                child: Icon(
                                  Icons.expand_more_rounded,
                                  size: 22,
                                  color: color,
                                ),
                              ),
                            ],
                          ),
                          if (opened) ...[
                            const SizedBox(height: 8),
                            Text(
                              branch.summary,
                              style: TextStyle(
                                fontSize: 14,
                                height: 1.65,
                                fontWeight: FontWeight.w600,
                                color: StudentSurface.mutedInk(context),
                              ),
                            ),
                            const SizedBox(height: 12),
                            // ── وتحدٍّ في هذه المحطة بعينها ──
                            // الطفلُ قرأها الآن، فهذه أنسبُ لحظةٍ ليُختبر فيها:
                            // ما قرأه حاضرٌ في ذهنه.
                            _StudyButton(
                              label: tr('study.challengeBranch'),
                              icon: '⚡',
                              onPressed: onChallenge,
                              color: color,
                              compact: true,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// التحدي
// ─────────────────────────────────────────────────────────────────────

class _StoryTab extends StatelessWidget {
  const _StoryTab({
    required this.appearance,
    required this.branch,
    required this.scenario,
    required this.at,
    required this.picked,
    required this.runGems,
    required this.earned,
    required this.alreadyRewarded,
    required this.busy,
    required this.onStart,
    required this.onPick,
    required this.onNext,
  });

  final Map<String, dynamic>? appearance;
  final String branch;
  final StudyScenario? scenario;
  final int at;
  final int? picked;
  final int runGems;
  final int? earned;
  final bool alreadyRewarded;
  final bool busy;
  final VoidCallback onStart;
  final ValueChanged<int> onPick;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final current = scenario;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (current == null) ...[
          if (earned != null) ...[
            StudentEntrance(
              child:
                  _OutcomeCard(gems: earned!, alreadyRewarded: alreadyRewarded),
            ),
            const SizedBox(height: 16),
          ],
          StudentEntrance(
            child: _StartCard(
              appearance: appearance,
              branch: branch,
              again: earned != null,
              busy: busy,
              onStart: onStart,
            ),
          ),
        ] else
          StudentEntrance(
            child: _SituationCard(
              appearance: appearance,
              scenario: current,
              at: at,
              picked: picked,
              runGems: runGems,
              busy: busy,
              onPick: onPick,
              onNext: onNext,
            ),
          ),
      ],
    );
  }
}

/// بطاقةُ البدء: ما سيحدث، وما يُكسب، وزرٌّ واحد.
class _StartCard extends StatelessWidget {
  const _StartCard({
    required this.appearance,
    required this.branch,
    required this.again,
    required this.busy,
    required this.onStart,
  });

  final Map<String, dynamic>? appearance;
  final String branch;
  final bool again;
  final bool busy;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: StudentSurface.card(context),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(
            color: _StudyTokens.fuchsia.withValues(alpha: 0.35), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: _StudyTokens.fuchsia.withValues(alpha: 0.18),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          StudentAvatarView(size: 96, appearance: appearance),
          const SizedBox(height: 14),
          Text(
            tr('study.storyTitle'),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: StudentSurface.ink(context),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            branch.isEmpty
                ? tr('study.storyIntro')
                : trf('study.branchScope', {'branch': branch}),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              height: 1.55,
              fontWeight: FontWeight.w700,
              color: StudentSurface.mutedInk(context),
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              _Chip(
                  icon: '🎯',
                  text: tr('study.chipDecisions'),
                  color: _StudyTokens.violet),
              _Chip(
                  icon: '💎',
                  text: tr('study.chipGems'),
                  color: _StudyTokens.gold),
            ],
          ),
          const SizedBox(height: 18),
          _StudyButton(
            label: tr(again ? 'study.again' : 'study.start'),
            icon: '🚀',
            onPressed: busy ? null : onStart,
            color: _StudyTokens.fuchsia,
          ),
        ],
      ),
    );
  }
}

class _SituationCard extends StatelessWidget {
  const _SituationCard({
    required this.appearance,
    required this.scenario,
    required this.at,
    required this.picked,
    required this.runGems,
    required this.busy,
    required this.onPick,
    required this.onNext,
  });

  final Map<String, dynamic>? appearance;
  final StudyScenario scenario;
  final int at;
  final int? picked;
  final int runGems;
  final bool busy;
  final ValueChanged<int> onPick;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final situation = scenario.situations[at];
    final answered = picked != null;
    final right = answered && situation.isCorrect(picked!);
    final total = scenario.situations.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── شريطُ التقدّم مقطّعاً بالمواقف ──
        // «٢ من ٣» يُقرأ، والمقاطعُ تُرى: كم مضى وكم بقي بنظرة.
        Row(
          children: [
            Expanded(
              child: Row(
                children: [
                  for (var i = 0; i < total; i++) ...[
                    if (i > 0) const SizedBox(width: 6),
                    Expanded(
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        height: 8,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(99),
                          color: i < at || (i == at && answered)
                              ? _StudyTokens.fuchsia
                              : i == at
                                  ? _StudyTokens.fuchsia.withValues(alpha: 0.45)
                                  : StudentSurface.mutedInk(context)
                                      .withValues(alpha: 0.18),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 10),
            Text(
              trf('study.step', {'n': '${at + 1}', 'total': '$total'}),
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w900,
                color: StudentSurface.mutedInk(context),
              ),
            ),
            if (runGems > 0) ...[
              const SizedBox(width: 8),
              _GemChip(gems: runGems),
            ],
          ],
        ),
        const SizedBox(height: 14),
        // كلُّ موقفٍ يقفز إلى مكانه، ويتوهّج حين يُصاب ويهتزّ حين يُخطأ —
        // لحظةً ثم يهدأ.
        LivelyStagger(
          key: ValueKey('situation-${scenario.title}-$at'),
          index: 0,
          child: LivelyShake(
          active: answered && !right,
          child: LivelyGlow(
          active: answered && right,
          radius: 24,
          child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: StudentSurface.card(context),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: _StudyTokens.violet.withValues(alpha: 0.14),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                scenario.title,
                style: TextStyle(
                  fontSize: 15.5,
                  fontWeight: FontWeight.w900,
                  color: _StudyTokens.violet.withValues(alpha: 0.95),
                ),
              ),
              const SizedBox(height: 14),
              // ── والشكلُ يتبع النمط، والحسابُ واحد ──
              // ثلاثةُ أنماطٍ تسأل السؤالَ نفسه بأفعالٍ مختلفة، وكلُّها تعود
              // بـ\`onPick\` بموضعٍ في \`options\`.
              switch (situation.type) {
                StudyChallengeType.avatarPath => AvatarPathChallenge(
                    situation: situation,
                    appearance: appearance,
                    picked: picked,
                    onPick: onPick,
                  ),
                StudyChallengeType.swipeFact => SwipeFactChallenge(
                    situation: situation,
                    appearance: appearance,
                    picked: picked,
                    onPick: onPick,
                  ),
                StudyChallengeType.spotImposter => SpotImposterChallenge(
                    situation: situation,
                    appearance: appearance,
                    picked: picked,
                    onPick: onPick,
                  ),
              },
            ],
          ),
        ),
        ),
        ),
        ),
        if (answered) ...[
          const SizedBox(height: 14),
          // والشرحُ بعد القرار يقفز إلى مكانه كذلك.
          LivelyStagger(
            key: ValueKey('feedback-${scenario.title}-$at'),
            index: 0,
            child: _Feedback(
              right: right,
              text: situation.because.isEmpty
                  ? tr(right ? 'study.right' : 'study.wrong')
                  : situation.because,
            ),
          ),
          const SizedBox(height: 14),
          _StudyButton(
            label: tr(at + 1 < total ? 'study.next' : 'study.finish'),
            icon: at + 1 < total ? '➡️' : '🏁',
            onPressed: busy ? null : onNext,
            color: _StudyTokens.violet,
          ),
        ],
      ],
    );
  }
}

/// ما بعد القرار: أخضرُ لصحيح، وذهبيٌّ لفكرةٍ تُتعلّم — لا أحمرُ يُشعر بالعقاب.
class _Feedback extends StatelessWidget {
  const _Feedback({required this.right, required this.text});

  final bool right;
  final String text;

  @override
  Widget build(BuildContext context) {
    final color = right ? _StudyTokens.green : _StudyTokens.gold;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: 0.55), width: 1.5),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(right ? '✅' : '💡', style: const TextStyle(fontSize: 22)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tr(right ? 'study.feedbackRight' : 'study.feedbackLearn'),
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    color: color,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  text,
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.55,
                    fontWeight: FontWeight.w700,
                    color: StudentSurface.ink(context),
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

/// شارةُ جواهر الجولة: تظهر فور أوّل إصابة، وتنبض مع كل واحدة.
class _GemChip extends StatelessWidget {
  const _GemChip({required this.gems});

  final int gems;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      key: ValueKey(gems),
      tween: Tween(begin: 1.3, end: 1),
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutBack,
      builder: (context, scale, child) =>
          Transform.scale(scale: scale, child: child),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          color: const Color(0xFFFEF3C7),
          border: Border.all(color: _StudyTokens.gold, width: 1.5),
        ),
        child: Text(
          trf('study.gemNow', {'gems': '$gems'}),
          style: const TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w900,
            color: Color(0xFF92400E),
          ),
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.icon, required this.text, required this.color});

  final String icon;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(icon, style: const TextStyle(fontSize: 14)),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
                color: StudentSurface.ink(context),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// ما حصده الطفل في ختام التحدي.
class _OutcomeCard extends StatelessWidget {
  const _OutcomeCard({required this.gems, required this.alreadyRewarded});

  final int gems;
  final bool alreadyRewarded;

  @override
  Widget build(BuildContext context) {
    final rewarded = gems > 0;
    final colors = rewarded
        ? const [Color(0xFFFDE68A), Color(0xFFFBBF24)]
        : const [Color(0xFFEDE9FE), Color(0xFFDDD6FE)];
    final ink = rewarded ? const Color(0xFF78350F) : const Color(0xFF4C1D95);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          colors: colors,
          begin: AlignmentDirectional.topStart,
          end: AlignmentDirectional.bottomEnd,
        ),
        boxShadow: [
          BoxShadow(
            color: colors.last.withValues(alpha: 0.45),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Text(rewarded ? '🎉' : '🔄', style: const TextStyle(fontSize: 34)),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              rewarded
                  ? trf('study.earned', {'gems': '$gems'})
                  // وإعادةُ الدرس لا تُكافأ: يُقال ذلك صريحاً فلا يظنّ الطفلُ
                  // العدّادَ معطوباً.
                  : tr(alreadyRewarded ? 'study.noRepeat' : 'study.noGems'),
              style: TextStyle(
                fontSize: 15.5,
                height: 1.55,
                fontWeight: FontWeight.w900,
                color: ink,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// زرٌّ مجسّم: وجهٌ على حافّةٍ أغمق، يغوص فيها تحت الإصبع.
class _StudyButton extends StatefulWidget {
  const _StudyButton({
    required this.label,
    required this.onPressed,
    this.icon,
    this.color = _StudyTokens.violet,
    this.ink = Colors.white,
    this.compact = false,
  });

  final String label;
  final String? icon;
  final VoidCallback? onPressed;
  final Color color;
  final Color ink;
  final bool compact;

  @override
  State<_StudyButton> createState() => _StudyButtonState();
}

class _StudyButtonState extends State<_StudyButton> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final disabled = widget.onPressed == null;
    const ledge = 5.0;
    final sink = _down && !disabled ? ledge : 0.0;
    final ledgeColor = Color.lerp(widget.color, Colors.black, 0.3)!;
    return Semantics(
      button: true,
      enabled: !disabled,
      label: widget.label,
      child: ExcludeSemantics(
        child: Opacity(
          opacity: disabled ? 0.5 : 1,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: disabled ? null : (_) => setState(() => _down = true),
            onTapUp: disabled ? null : (_) => setState(() => _down = false),
            onTapCancel: disabled ? null : () => setState(() => _down = false),
            onTap: widget.onPressed,
            child: Padding(
              padding: EdgeInsets.only(top: sink),
              child: Container(
                padding: EdgeInsets.only(bottom: ledge - sink),
                decoration: BoxDecoration(
                  color: ledgeColor,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Container(
                  width: widget.compact ? null : double.infinity,
                  padding: EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: widget.compact ? 10 : 15,
                  ),
                  decoration: BoxDecoration(
                    color: widget.color,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Row(
                    mainAxisSize:
                        widget.compact ? MainAxisSize.min : MainAxisSize.max,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (widget.icon != null) ...[
                        Text(widget.icon!,
                            style: const TextStyle(fontSize: 16)),
                        const SizedBox(width: 8),
                      ],
                      Flexible(
                        child: Text(
                          widget.label,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: widget.compact ? 14 : 16,
                            fontWeight: FontWeight.w900,
                            color: widget.ink,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
