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

  late final TabController _tabs = TabController(length: 2, vsync: this);
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
    unawaited(
      StudentSoundService.instance.playClip('assets/audio/booksound.mp3'),
    );
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

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: StudentSettings.direction,
      child: Scaffold(
        backgroundColor: StudentSurface.ground(context),
        appBar: AppBar(
          title: Text(tr('portal.study')),
          centerTitle: true,
          actions: const [StudentSoundToggle()],
          bottom: _pack == null
              ? null
              : TabBar(
                  controller: _tabs,
                  tabs: [
                    Tab(text: tr('study.tabMap')),
                    Tab(text: tr('study.tabStory')),
                  ],
                ),
        ),
        body: Stack(
          children: [
            const PortalWatermark(asset: PortalBackgrounds.study),
            SafeArea(child: _body(context)),
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
            const CircularProgressIndicator(color: Color(0xFF7C3AED)),
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
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('📚', style: TextStyle(fontSize: 46)),
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
              _WideButton(
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
        _MindMapTab(
          mindMap: pack.mindMap,
          // ضغطةٌ على «تحدَّني في هذا الفرع» تفتح التبويب الثاني بتحدّي
          // الفرع نفسه.
          onChallengeBranch: _start,
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
// التبويب الأول: الخريطة
// ─────────────────────────────────────────────────────────────────────

/// خريطةُ مفاهيمَ شجرية، تُسحب وتُكبَّر بإصبعين.
///
/// ── لماذا `InteractiveViewer` ──
/// الشجرةُ تكبر بعدد الفروع وبطول شرحها، وشاشةُ هاتفٍ لا تحملها كلَّها
/// بحجمٍ يُقرأ. فإمّا أن يُصغَّر الخطُّ حتى لا يُقرأ، أو يُقصَّ الشرحُ حتى
/// لا يُفهم، أو يُعطى الطفلُ أن يسحب ويكبّر. والثالثُ وحده يُبقي الخريطة
/// خريطةً.
///
/// والفرعُ يُضغط فينفتح شرحُه: الشجرةُ تُقرأ أوّلاً بعناوينها — وهي شكلُ
/// الدرس — ثم يُفتح ما يُراد منها. وفتحُها كلَّها يجعلها نصّاً مسكوباً في
/// هيئة شجرة.
class _MindMapTab extends StatefulWidget {
  const _MindMapTab({required this.mindMap, required this.onChallengeBranch});

  final StudyMindMap mindMap;

  /// يُنادى باسم الفرع حين يطلب الطالب تحدّيه.
  final ValueChanged<String> onChallengeBranch;

  @override
  State<_MindMapTab> createState() => _MindMapTabState();
}

class _MindMapTabState extends State<_MindMapTab> {
  final _view = TransformationController();
  final _open = <int>{};

  @override
  void dispose() {
    _view.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  tr('study.mapHint'),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: StudentSurface.mutedInk(context),
                  ),
                ),
              ),
              IconButton(
                tooltip: tr('study.mapReset'),
                onPressed: () => _view.value = Matrix4.identity(),
                icon: const Icon(Icons.center_focus_strong_rounded),
                color: const Color(0xFF7C3AED),
              ),
            ],
          ),
        ),
        Expanded(
          child: InteractiveViewer(
            transformationController: _view,
            minScale: 0.6,
            maxScale: 3.0,
            boundaryMargin: const EdgeInsets.all(80),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
              child: _Tree(
                mindMap: widget.mindMap,
                onChallengeBranch: widget.onChallengeBranch,
                open: _open,
                onToggle: (index) => setState(() {
                  if (!_open.remove(index)) _open.add(index);
                }),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _Tree extends StatelessWidget {
  const _Tree({
    required this.mindMap,
    required this.open,
    required this.onToggle,
    required this.onChallengeBranch,
  });

  final ValueChanged<String> onChallengeBranch;
  final StudyMindMap mindMap;
  final Set<int> open;
  final ValueChanged<int> onToggle;

  static const _tint = Color(0xFF7C3AED);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // الجذع.
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: const LinearGradient(
              colors: [Color(0xFF7C3AED), Color(0xFFC026D3)],
              begin: AlignmentDirectional.topStart,
              end: AlignmentDirectional.bottomEnd,
            ),
            boxShadow: [
              BoxShadow(
                color: _tint.withValues(alpha: 0.30),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            children: [
              const Text('🧠', style: TextStyle(fontSize: 22)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  mindMap.title,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 2),
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Text(
            tr('study.tapBranch'),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: StudentSurface.mutedInk(context),
            ),
          ),
        ),
        for (var index = 0; index < mindMap.branches.length; index += 1)
          _BranchNode(
            branch: mindMap.branches[index],
            onChallenge: onChallengeBranch,
            opened: open.contains(index),
            last: index == mindMap.branches.length - 1,
            onTap: () => onToggle(index),
          ),
      ],
    );
  }
}

/// عقدةُ فرعٍ: خطٌّ نازلٌ من الجذع، وزاويةٌ إليها، وشرحٌ يُفتح بضغطة.
class _BranchNode extends StatelessWidget {
  const _BranchNode({
    required this.branch,
    required this.opened,
    required this.last,
    required this.onTap,
    required this.onChallenge,
  });

  final ValueChanged<String> onChallenge;
  final StudyBranch branch;
  final bool opened;
  final bool last;
  final VoidCallback onTap;

  static const _tint = Color(0xFF7C3AED);

  /// ── و`IntrinsicHeight` لازم، وهذا موضعُ عطبٍ كان ──
  ///
  /// خطُّ الوصل يُرسم بـ`CustomPaint` يمتدّ بارتفاع الفرع، وذلك يقتضي
  /// `CrossAxisAlignment.stretch` في الصفّ. و`stretch` يمرّر إلى أبنائه
  /// ارتفاعَ الصفّ الأقصى — وهو هنا لا نهائيّ، لأن الصفَّ داخل عمود.
  ///
  /// فكان يُرفع خطأُ تخطيطٍ عند كل فرع: «BoxConstraints forces an infinite
  /// height». والخطأُ في التخطيط لا يُسقط التطبيق، بل يُهمل رسمَ الشجرة
  /// ويُبقي جذعَها وحده — وهو ما رآه الطالب: عقدةُ العنوان بلا فروع.
  ///
  /// و`IntrinsicHeight` يقيس أبناءَ الصفّ أوّلاً فيصير ارتفاعُه معلوماً،
  /// فيمرّ `stretch`. وثمنُه قياسٌ ثانٍ لكل فرعٍ — وهي أربعةٌ أو خمسة، لا
  /// قائمةٌ طويلة.
  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          width: 28,
          child: CustomPaint(
            painter: _ElbowPainter(color: _tint, stopAtElbow: last),
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Material
                // شفافٌ لا ملوَّن: اللونُ في الحدّ والخلفيةِ أدناه.
                (
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(16),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: onTap,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOut,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    color: _tint.withValues(alpha: opened ? 0.14 : 0.07),
                    border: Border.all(
                      color: _tint.withValues(alpha: opened ? 0.55 : 0.28),
                      width: 1.4,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          // رمزُ الفرع إن أرسله النموذج، ونقطةٌ إن لم
                          // يُرسله: الفرعُ بلا علامةٍ في صدره يبدو سطراً
                          // في قائمة لا عقدةً في شجرة.
                          Text(
                            branch.icon.isEmpty ? '•' : branch.icon,
                            style: const TextStyle(fontSize: 16),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              branch.title,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w900,
                                color: StudentSurface.ink(context),
                              ),
                            ),
                          ),
                          AnimatedRotation(
                            turns: opened ? 0.5 : 0,
                            duration: const Duration(milliseconds: 180),
                            child: const Icon(
                              Icons.expand_more_rounded,
                              size: 20,
                              color: _tint,
                            ),
                          ),
                        ],
                      ),
                      if (opened) ...[
                        const SizedBox(height: 6),
                        Text(
                          branch.summary,
                          style: TextStyle(
                            fontSize: 13.5,
                            height: 1.55,
                            fontWeight: FontWeight.w600,
                            color: StudentSurface.mutedInk(context),
                          ),
                        ),
                        const SizedBox(height: 10),
                        // ── وتحدٍّ في هذا الفرع بعينه ──
                        // الطفل قرأ الفرعَ الآن، فهذه أنسبُ لحظةٍ ليُختبر
                        // فيه: ما قرأه حاضرٌ في ذهنه. وزرٌّ في الفرع نفسه
                        // يربط القراءةَ بالاختبار، بدل زرٍّ عامٍّ في تبويبٍ
                        // آخر لا يعرف ما قرأ.
                        Align(
                          alignment: AlignmentDirectional.centerStart,
                          child: TextButton.icon(
                            onPressed: () => onChallenge(branch.title),
                            icon: const Icon(Icons.bolt_rounded, size: 18),
                            label: Text(tr('study.challengeBranch')),
                            style: TextButton.styleFrom(
                              foregroundColor: _tint,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              textStyle: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
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

/// خطٌّ ينزل من الجذع ثم ينعطف إلى الفرع.
///
/// وآخرُ فرعٍ ينقطع خطُّه عند زاويته: خطٌّ يمضي إلى أسفل الشجرة يوحي بفرعٍ
/// لم يُرسَم.
class _ElbowPainter extends CustomPainter {
  const _ElbowPainter({required this.color, required this.stopAtElbow});

  final Color color;
  final bool stopAtElbow;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withValues(alpha: 0.45)
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final x = size.width / 2;
    final y = size.height / 2 + 6;
    canvas.drawLine(Offset(x, 0), Offset(x, stopAtElbow ? y : size.height), paint);
    canvas.drawLine(Offset(x, y), Offset(size.width, y), paint);
  }

  @override
  bool shouldRepaint(_ElbowPainter old) =>
      old.color != color || old.stopAtElbow != stopAtElbow;
}

// ─────────────────────────────────────────────────────────────────────
// التبويب الثاني: التحدي
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
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
      children: [
        if (current == null) ...[
          if (earned != null) ...[
            StudentEntrance(
              child: _OutcomeCard(
                gems: earned!,
                alreadyRewarded: alreadyRewarded,
              ),
            ),
            const SizedBox(height: 16),
          ],
          StudentEntrance(
            child: _WideButton(
              label: tr(earned == null ? 'study.start' : 'study.again'),
              onPressed: busy ? null : onStart,
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
    return Card(
      color: StudentSurface.card(context),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    scenario.title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      color: StudentSurface.ink(context),
                    ),
                  ),
                ),
                // عدّادُ جواهر الجولة، يتحرّك مع كل إصابة.
                if (runGems > 0) ...[
                  _GemChip(gems: runGems),
                  const SizedBox(width: 8),
                ],
                Text(
                  trf('study.step', {
                    'n': '${at + 1}',
                    'total': '${scenario.situations.length}',
                  }),
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    color: StudentSurface.mutedInk(context),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            // ── والشكلُ يتبع النمط، والحسابُ واحد ──
            //
            // ثلاثةُ أنماطٍ تسأل السؤالَ نفسه بأفعالٍ مختلفة: يمشي إلى
            // بوّابة، ويسحب بطاقةً، ويفرقع فقاعة. وكلُّها تعود بـ`onPick`
            // بموضعٍ في `options` — فلا يعرف محرّكُ المكافآت أنماطاً، ولا
            // يتبدّل شرطُ الجوهرتين بتبدّل الشكل.
            //
            // وأربعةُ أزرارٍ متشابهة كانت تصير عادةً في الموقف الثاني.
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
            if (answered) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  Text(
                    right ? '✅' : '💡',
                    style: const TextStyle(fontSize: 20),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      situation.because.isEmpty
                          ? tr(right ? 'study.right' : 'study.wrong')
                          : situation.because,
                      style: TextStyle(
                        fontSize: 13.5,
                        height: 1.5,
                        fontWeight: FontWeight.w700,
                        color: StudentSurface.mutedInk(context),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _WideButton(
                label: tr(
                  at + 1 < scenario.situations.length
                      ? 'study.next'
                      : 'study.finish',
                ),
                onPressed: busy ? null : onNext,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// شارةُ جواهر الجولة: تظهر فور أوّل إصابة وتكبر معها.
class _GemChip extends StatelessWidget {
  const _GemChip({required this.gems});

  final int gems;

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      // تنبض عند كل زيادة: `key` يتبدّل بالعدد فيُعاد بناؤها.
      key: ValueKey(gems),
      scale: 1,
      duration: const Duration(milliseconds: 220),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          color: const Color(0xFFFEF3C7),
          border: Border.all(color: const Color(0xFFF59E0B)),
        ),
        child: Text(
          trf('study.gemNow', {'gems': '$gems'}),
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w900,
            color: Color(0xFF92400E),
          ),
        ),
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
        : const [Color(0xFFDDD6FE), Color(0xFFC4B5FD)];
    final ink = rewarded ? const Color(0xFF78350F) : const Color(0xFF4C1D95);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: LinearGradient(
          colors: colors,
          begin: AlignmentDirectional.topStart,
          end: AlignmentDirectional.bottomEnd,
        ),
      ),
      child: Row(
        children: [
          Text(rewarded ? '🎉' : '🔄', style: const TextStyle(fontSize: 28)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              rewarded
                  ? trf('study.earned', {'gems': '$gems'})
                  // وإعادةُ الدرس لا تُكافأ: يُقال ذلك صريحاً فلا يظنّ
                  // الطفلُ العدّادَ معطوباً.
                  : tr(alreadyRewarded ? 'study.noRepeat' : 'study.noGems'),
              style: TextStyle(
                fontSize: 14.5,
                height: 1.55,
                fontWeight: FontWeight.w800,
                color: ink,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// زرٌّ عريضٌ بتدرّج، ينكمش تحت الإصبع.
class _WideButton extends StatefulWidget {
  const _WideButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback? onPressed;

  @override
  State<_WideButton> createState() => _WideButtonState();
}

class _WideButtonState extends State<_WideButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final disabled = widget.onPressed == null;
    return Opacity(
      opacity: disabled ? 0.5 : 1,
      child: AnimatedScale(
        scale: _pressed && !disabled ? 0.96 : 1,
        duration: const Duration(milliseconds: 110),
        curve: Curves.easeOut,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: const LinearGradient(
              colors: [Color(0xFF7C3AED), Color(0xFFC026D3)],
              begin: AlignmentDirectional.topStart,
              end: AlignmentDirectional.bottomEnd,
            ),
            boxShadow: disabled || _pressed
                ? const []
                : [
                    BoxShadow(
                      color: const Color(0xFF7C3AED).withValues(alpha: 0.32),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ],
          ),
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(18),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: widget.onPressed,
              onTapDown: disabled ? null : (_) => setState(() => _pressed = true),
              onTapUp: disabled ? null : (_) => setState(() => _pressed = false),
              onTapCancel:
                  disabled ? null : () => setState(() => _pressed = false),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  widget.label,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
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
