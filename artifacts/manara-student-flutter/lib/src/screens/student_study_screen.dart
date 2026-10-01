import 'dart:async';
import 'dart:math' as math;

import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';

import '../l10n/student_strings.dart';
import '../models/academic_context.dart';
import '../models/interactive_study.dart';
import '../models/student_profile.dart';
import '../services/student_content_service.dart';
import '../services/student_settings.dart';
import '../services/student_sound_service.dart';
import '../services/student_study_service.dart';
import '../theme/student_theme.dart';
import '../widgets/portal_watermark.dart';
import '../widgets/study_challenges.dart';
import '../widgets/student_avatar_view.dart';
import '../widgets/student_experience.dart';

/// «مغامرة الأذكياء ومهمة المذاكرة»: خريطةُ الدرس، وتحدٍّ قصصيٌّ فيه.
///
/// ── تبويبان لا شاشةٌ واحدة ──
/// الخريطةُ تُري الطفل شكلَ الدرس، والتحدي يسأله فيما رآه. وهما عملان
/// مختلفان: الأول يُقرأ ويُتأمّل، والثاني يُلعب. فجمعُهما في عمودٍ واحد
/// يجعل الطفل يمرّ على الخريطة بإصبعه ليصل إلى الزرّ، فلا ينظر إليها.
/// وتبويبان يجعلان كلاً منهما مكاناً يُقصد.
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

class _StudentStudyScreenState extends State<StudentStudyScreen>
    with SingleTickerProviderStateMixin {
  StudyPack? _pack;
  String? _error;
  bool _loading = true;

  late final TabController _tabs = TabController(length: 2, vsync: this)
    // والسحبُ بين التبويبين يحرّك المبدّل في الرأس كما يحرّكه الضغط.
    ..addListener(() {
      if (mounted) setState(() {});
    });
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

  @override
  void dispose() {
    _tabs.dispose();
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
    try {
      final pack = await widget.studyService.fetch(lessonId: lessonId);
      if (!mounted) return;
      setState(() {
        _pack = pack;
        _loading = false;
      });
    } on StudyServerFailure catch (failure) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = failure.message;
      });
    } on StudyFailure catch (failure) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = failure.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = tr('study.error.failed');
      });
    }
  }

  /// يبدأ تحدياً، ويختار غيرَ الذي سبق ما أمكن.
  ///
  /// عشوائيةٌ محضةٌ بين اثنين تُعيد الأول في نصف الجولات، والطفل يقرأ
  /// الحكايةَ نفسها فيظنّ البطاقة معطوبة.
  void _start([String branch = '']) {
    final pack = _pack;
    if (pack == null || pack.scenarios.isEmpty) return;
    if (branch.isNotEmpty) _branch = branch;
    final scoped = pack.forBranch(_branch);
    final others = scoped.where((item) => item != _scenario).toList();
    final pool = others.isEmpty ? scoped : others;
    setState(() {
      _scenario = pool[_random.nextInt(pool.length)];
      _at = 0;
      _correct = 0;
      _picked = null;
      _earned = null;
      _alreadyRewarded = false;
    });
    _tabs.animateTo(1);
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
      StudentSoundService.instance.play(StudentSoundCue.success);
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

  /// التبويبُ الظاهر: ٠ الخريطة، ١ التحدي.
  int get _tab => _tabs.index;

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: StudentSettings.direction,
      child: Scaffold(
        backgroundColor: StudentSurface.ground(context),
        body: Stack(
          children: [
            const PortalWatermark(asset: PortalBackgrounds.study),
            SafeArea(
              child: Column(
                children: [
                  _StudyHeader(
                    lessonName: widget.academicContext?.lesson ?? '',
                    showSwitcher: _pack != null,
                    tab: _tab,
                    onTab: (index) {
                      StudentSoundService.instance.playTap();
                      _tabs.animateTo(index);
                      setState(() {});
                    },
                  ),
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
    if (_loading) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(color: _StudyTokens.violet),
            const SizedBox(height: 14),
            Text(
              tr('study.preparing'),
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: StudentSurface.ink(context),
              ),
            ),
          ],
        ),
      );
    }
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

    return TabBarView(
      controller: _tabs,
      children: [
        _MapTab(
          mindMap: pack.mindMap,
          // ضغطةٌ على «تحدَّني في هذه المحطة» تفتح التبويب الثاني بتحدّيها.
          onChallengeBranch: (branch) {
            _start(branch);
            setState(() {});
          },
          onChallengeAll: () {
            _branch = '';
            _start();
            setState(() {});
          },
        ),
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
      ],
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

/// رأسُ الشاشة: الرجوع، والعنوانُ ودرسُه، والمبدّلُ بين الخريطة والتحدي.
///
/// ── مبدّلٌ لا تبويبات ──
/// شريطُ التبويبات الأصليّ خطٌّ رفيعٌ تحت كلمتين، لا يراه الطفلُ زرّاً. والمبدّلُ
/// زرّان كبيران بأيقونتيهما، والمختارُ منهما يرتفع على حافّته.
class _StudyHeader extends StatelessWidget {
  const _StudyHeader({
    required this.lessonName,
    required this.showSwitcher,
    required this.tab,
    required this.onTab,
  });

  final String lessonName;
  final bool showSwitcher;
  final int tab;
  final ValueChanged<int> onTab;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 12, 8),
      child: Column(
        children: [
          Row(
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
          if (showSwitcher) ...[
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                children: [
                  Expanded(
                    child: _SwitchPill(
                      icon: '🗺️',
                      label: tr('study.tabMap'),
                      selected: tab == 0,
                      color: _StudyTokens.violet,
                      onTap: () => onTab(0),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _SwitchPill(
                      icon: '⚡',
                      label: tr('study.tabStory'),
                      selected: tab == 1,
                      color: _StudyTokens.fuchsia,
                      onTap: () => onTab(1),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SwitchPill extends StatelessWidget {
  const _SwitchPill({
    required this.icon,
    required this.label,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  final String icon;
  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ledge = Color.lerp(color, Colors.black, 0.35)!;
    return Semantics(
      button: true,
      selected: selected,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          padding: EdgeInsets.only(bottom: selected ? 5 : 0),
          margin: EdgeInsets.only(top: selected ? 0 : 5),
          decoration: BoxDecoration(
            color: selected ? ledge : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
          ),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            decoration: BoxDecoration(
              color: selected ? color : StudentSurface.card(context),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: selected ? color : color.withValues(alpha: 0.35),
                width: 1.5,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(icon, style: const TextStyle(fontSize: 16)),
                const SizedBox(width: 8),
                Flexible(
                  // يصغر ولا يُقصّ: نصفُ «التحدي القصصي» لا يُقرأ.
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      label,
                      maxLines: 1,
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w900,
                        color: selected ? Colors.white : color,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
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
    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
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
    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
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
        Container(
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
        if (answered) ...[
          const SizedBox(height: 14),
          _Feedback(
            right: right,
            text: situation.because.isEmpty
                ? tr(right ? 'study.right' : 'study.wrong')
                : situation.because,
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
