import 'dart:async';
import 'dart:math' as math;

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
import '../widgets/student_experience.dart';
import '../widgets/student_icon_notice.dart';

/// بطاقةُ المذاكرة الذكية: خريطةٌ ذهنية للدرس، ومغامرةٌ قصصية فيه.
///
/// ── لماذا الاثنان في شاشةٍ واحدة ──
/// الخريطةُ تُري الطفل شكلَ الدرس قبل أن يُسأل فيه، والمغامرةُ تسأله فيما
/// رآه. فلو فُصلتا لفتح المغامرةَ بلا أن ينظر إلى الخريطة — وهي التي
/// تجعل أسئلتها مفهومةً لا تخميناً.
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

  /// لصرف الجواهر في ختام المغامرة.
  final StudentContentService contentService;
  final AcademicContext? academicContext;

  @override
  State<StudentStudyScreen> createState() => _StudentStudyScreenState();
}

class _StudentStudyScreenState extends State<StudentStudyScreen> {
  StudyPack? _pack;
  String? _error;
  bool _loading = true;

  /// المغامرةُ الجارية، وموضعُ الطفل منها.
  StudyScenario? _scenario;
  int _at = 0;
  int _correct = 0;

  /// ما اختاره في الموقف الحاضر، قبل أن ينتقل.
  int? _picked;

  /// جواهرُ هذه الجولة، أو `null` قبل أن تُصرف.
  int? _earned;
  bool _alreadyRewarded = false;
  bool _rewarding = false;

  final _random = math.Random();

  @override
  void initState() {
    super.initState();
    // الصوتُ الترحيبي على مشغّل الأصوات المشترك: يسكت عند الكتم، وعند
    // إطفاء الشاشة، ويوقفه فيديو إن بدأ. انظر [StudentSoundService.playClip].
    unawaited(StudentSoundService.instance.playClip('assets/audio/booksound.mp3'));
    unawaited(_load());
  }

  String get _lessonId => widget.academicContext?.selectedLesson.id ?? '';

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

  /// يبدأ مغامرةً، ويختار غيرَ التي سبقت ما أمكن.
  ///
  /// ── لماذا لا يُكتفى بالعشوائية ──
  /// عشوائيةٌ محضةٌ بين اثنتين تُعيد الأولى في نصف الجولات، والطفل يقرأ
  /// الحكايةَ نفسها فيظنّ البطاقة معطوبة. فتُستبعد السابقةُ ما دام ثَمّ
  /// غيرُها.
  void _start() {
    final pack = _pack;
    if (pack == null || pack.scenarios.isEmpty) return;
    final others = pack.scenarios.where((item) => item != _scenario).toList();
    final pool = others.isEmpty ? pack.scenarios : others;
    setState(() {
      _scenario = pool[_random.nextInt(pool.length)];
      _at = 0;
      _correct = 0;
      _picked = null;
      _earned = null;
      _alreadyRewarded = false;
    });
  }

  void _pick(int choice) {
    final scenario = _scenario;
    if (scenario == null || _picked != null) return;
    final situation = scenario.situations[_at];
    setState(() {
      _picked = choice;
      if (situation.isCorrect(choice)) _correct += 1;
    });
    StudentSoundService.instance.play(
      situation.isCorrect(choice)
          ? StudentSoundCue.success
          : StudentSoundCue.warning,
    );
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

  /// ── صرفُ الجواهر: الخادم يقرّر، والشاشة تعرض ──
  ///
  /// جوهرتان عن كل قرارٍ صحيح، وللمرّة الأولى وحدها. وسجلُّ الأنشطة في
  /// الخادم هو الحارس: `activityId` معرّفُ الدرس، فإعادةُ المغامرة — ولو
  /// بسيناريو آخر — تعود بـ`alreadyRewarded` وبصفر جواهر.
  ///
  /// والحصرُ هناك أيضاً: الخادم يقصر الجواهر على عدد المواقف، فلا يُقبل
  /// طلبٌ يدّعي أكثر ممّا في الحزمة.
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
      if (result.gems > 0) StudentSoundService.instance.playApplause();
    } catch (_) {
      if (!mounted) return;
      // الجواهرُ لم تُصرف، والمغامرةُ تمّت. فيُقال ذلك ولا تُعاد الجولة.
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
        ),
        body: Stack(
          children: [
            const PortalWatermark(asset: PortalBackgrounds.study),
            SafeArea(child: _body(context)),
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
          child: Text(
            error,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15,
              height: 1.6,
              fontWeight: FontWeight.w800,
              color: StudentSurface.ink(context),
            ),
          ),
        ),
      );
    }
    final pack = _pack;
    if (pack == null) return const SizedBox.shrink();

    final scenario = _scenario;
    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
      children: [
        if (scenario == null) ...[
          StudentEntrance(child: _MindMapCard(mindMap: pack.mindMap)),
          const SizedBox(height: 16),
          if (_earned != null)
            StudentEntrance(
              child: _OutcomeCard(
                gems: _earned!,
                alreadyRewarded: _alreadyRewarded,
              ),
            ),
          if (_earned != null) const SizedBox(height: 16),
          StudentEntrance(
            delay: const Duration(milliseconds: 120),
            child: _StartButton(
              label: tr(_earned == null ? 'study.start' : 'study.again'),
              onPressed: _rewarding ? null : _start,
            ),
          ),
        ] else
          StudentEntrance(
            child: _SituationCard(
              scenario: scenario,
              at: _at,
              picked: _picked,
              busy: _rewarding,
              onPick: _pick,
              onNext: _next,
            ),
          ),
      ],
    );
  }
}

/// الخريطةُ الذهنية: جذعٌ وفروعٌ تنزل منه.
///
/// ── لماذا شجرةٌ مرسومةٌ لا قائمة ──
/// القائمةُ تقول ما في الدرس، والشجرةُ تقول كيف يتفرّع — وهي ما يبقى في
/// ذهن الطفل حين يُسأل بعد أسبوع. والخطُّ النازل من الجذع إلى كل فرعٍ
/// يفعل ذلك بلا حزمةِ رسمٍ ولا صورة.
class _MindMapCard extends StatelessWidget {
  const _MindMapCard({required this.mindMap});

  final StudyMindMap mindMap;

  static const _tint = Color(0xFF7C3AED);

  @override
  Widget build(BuildContext context) {
    return Card(
      color: StudentSurface.card(context),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // الجذع.
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: const LinearGradient(
                  colors: [Color(0xFF7C3AED), Color(0xFFC026D3)],
                  begin: AlignmentDirectional.topStart,
                  end: AlignmentDirectional.bottomEnd,
                ),
                boxShadow: [
                  BoxShadow(
                    color: _tint.withValues(alpha: 0.28),
                    blurRadius: 14,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Row(
                children: [
                  const Text('🧠', style: TextStyle(fontSize: 20)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      mindMap.title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            for (final branch in mindMap.branches)
              _Branch(branch: branch, tint: _tint),
          ],
        ),
      ),
    );
  }
}

class _Branch extends StatelessWidget {
  const _Branch({required this.branch, required this.tint});

  final StudyBranch branch;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // الخطُّ النازل من الجذع، ثم الزاوية إلى الفرع.
        SizedBox(
          width: 26,
          child: CustomPaint(painter: _ElbowPainter(color: tint)),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                color: tint.withValues(alpha: 0.08),
                border: Border.all(color: tint.withValues(alpha: 0.30)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    branch.title,
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w900,
                      color: StudentSurface.ink(context),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    branch.summary,
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.5,
                      fontWeight: FontWeight.w600,
                      color: StudentSurface.mutedInk(context),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// خطٌّ ينزل ثم ينعطف إلى الفرع.
///
/// ولا يُعكس مع الاتجاه: الشجرةُ تنزل من الجذع في كل لغة، والانعطافُ إلى
/// داخل البطاقة — و`Row` في `Directionality` يقلب موضعَ العمود نفسه، فما
/// يُرسم هنا يقع في جهته صحيحاً بلا حسابٍ للاتجاه.
class _ElbowPainter extends CustomPainter {
  const _ElbowPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withValues(alpha: 0.45)
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final x = size.width / 2;
    final y = size.height / 2 + 5;
    canvas.drawLine(Offset(x, 0), Offset(x, y), paint);
    canvas.drawLine(Offset(x, y), Offset(size.width, y), paint);
  }

  @override
  bool shouldRepaint(_ElbowPainter old) => old.color != color;
}

/// موقفٌ واحد وخياراته.
class _SituationCard extends StatelessWidget {
  const _SituationCard({
    required this.scenario,
    required this.at,
    required this.picked,
    required this.busy,
    required this.onPick,
    required this.onNext,
  });

  final StudyScenario scenario;
  final int at;
  final int? picked;
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
            const SizedBox(height: 12),
            Text(
              situation.prompt,
              style: TextStyle(
                fontSize: 15,
                height: 1.6,
                fontWeight: FontWeight.w700,
                color: StudentSurface.ink(context),
              ),
            ),
            const SizedBox(height: 14),
            for (var index = 0; index < situation.options.length; index += 1)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _OptionTile(
                  text: situation.options[index],
                  // ── ولونُ الخيار يُقال بعد الاختيار وحده ──
                  // الصحيحُ يُلوَّن أخضر والمُختارُ الخطأ أحمر، وما لم
                  // يُختر يبقى محايداً. ولو لُوِّن الصحيحُ قبل الاختيار
                  // لأُجيب السؤالُ بالعين لا بالفهم.
                  state: !answered
                      ? _OptionState.idle
                      : index == situation.answer
                          ? _OptionState.right
                          : index == picked
                              ? _OptionState.wrong
                              : _OptionState.idle,
                  onTap: answered ? null : () => onPick(index),
                ),
              ),
            if (answered) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  StudentIconNotice(
                    emoji: right ? '✅' : '💡',
                    label: situation.because.isEmpty
                        ? tr(right ? 'study.right' : 'study.wrong')
                        : situation.because,
                    tone: right
                        ? StudentNoticeTone.earning
                        : StudentNoticeTone.practice,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      situation.because.isEmpty
                          ? tr(right ? 'study.right' : 'study.wrong')
                          : situation.because,
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.5,
                        fontWeight: FontWeight.w700,
                        color: StudentSurface.mutedInk(context),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _StartButton(
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

enum _OptionState { idle, right, wrong }

class _OptionTile extends StatelessWidget {
  const _OptionTile({
    required this.text,
    required this.state,
    required this.onTap,
  });

  final String text;
  final _OptionState state;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final (border, fill, ink) = switch (state) {
      _OptionState.right => (
          const Color(0xFF16A34A),
          const Color(0xFFDCFCE7),
          const Color(0xFF14532D),
        ),
      _OptionState.wrong => (
          const Color(0xFFDC2626),
          const Color(0xFFFEE2E2),
          const Color(0xFF7F1D1D),
        ),
      _OptionState.idle => (
          const Color(0xFF7C3AED).withValues(alpha: 0.30),
          Colors.transparent,
          StudentSurface.ink(context),
        ),
    };
    return Material(
      color: fill,
      borderRadius: BorderRadius.circular(14),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: border, width: 1.4),
          ),
          child: Text(
            text,
            style: TextStyle(
              fontSize: 14,
              height: 1.45,
              fontWeight: FontWeight.w800,
              color: ink,
            ),
          ),
        ),
      ),
    );
  }
}

/// ما حصده الطفل في ختام المغامرة.
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
          Text(rewarded ? '🎉' : '🔄', style: const TextStyle(fontSize: 26)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              rewarded
                  ? trf('study.earned', {'gems': '$gems'})
                  // وإعادةُ الدرس لا تُكافأ: يُقال ذلك صريحاً فلا يظنّ
                  // الطفلُ العدّادَ معطوباً.
                  : tr(alreadyRewarded ? 'study.noRepeat' : 'study.noGems'),
              style: TextStyle(
                fontSize: 14,
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
class _StartButton extends StatefulWidget {
  const _StartButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback? onPressed;

  @override
  State<_StartButton> createState() => _StartButtonState();
}

class _StartButtonState extends State<_StartButton> {
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
              onTapCancel: disabled ? null : () => setState(() => _pressed = false),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 15),
                child: Text(
                  widget.label,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 15.5,
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
