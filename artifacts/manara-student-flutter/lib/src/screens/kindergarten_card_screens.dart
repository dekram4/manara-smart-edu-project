import 'dart:async';
import 'dart:math' as math;

import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';

import '../l10n/student_strings.dart';
import '../models/academic_context.dart';
import '../models/student_gamification.dart';
import '../models/study_games.dart';
import '../models/student_profile.dart';
import '../services/quran_recitation.dart';
import '../services/student_content_service.dart';
import '../services/student_settings.dart';
import '../services/student_sound_service.dart';
import '../services/tracing_sets.dart';
import '../theme/student_theme.dart';
import '../widgets/portal_watermark.dart';
import '../widgets/quran_recitation_game.dart';
import '../widgets/tracing_game.dart';

/// بطاقتا الروضة المستقلّتان في الواجهة، بجانب «شرح الدرس»:
/// «أبطال التسميع» لدرس حفظ السور القصيرة، و«قلمي السحري» لدروس الحروف
/// والأرقام.
///
/// ── لماذا خرجتا من بطاقة المذاكرة ──
/// كانتا لعبتين في آخر رفّ ألعاب المذاكرة: يصلهما الطفلُ بعد ثلاث ضغطات
/// وتبويبٍ وانتظارِ توليد ألعاب الدرس على الخادم. وهما لبُّ الدرس في
/// الروضة — يكتب الحرف ويسمّع السورة — فصار لكلٍّ منهما بابُها.
///
/// والمكافأةُ كما كانت حرفاً بحرف: المعرّفُ `درس::tracing` و`درس::quran`،
/// فما صُرف من قبل لا يُصرف مرّةً أخرى.

/// مقطعا الترحيب، بلا بادئة `assets/`: حزمةُ الصوت تضيفها.
const writingWelcomeClip = 'audio/encouragement/welcome_writing.mp3';
const recitationWelcomeClip = 'audio/encouragement/welcome_recitation.mp3';

/// «أبطال التسميع»: لعبةُ تسميع القرآن الكريم في بطاقتها.
class QuranRecitationCardScreen extends StatefulWidget {
  const QuranRecitationCardScreen({
    required this.profile,
    required this.contentService,
    required this.academicContext,
    super.key,
  });

  final StudentProfile profile;
  final StudentContentService contentService;
  final AcademicContext academicContext;

  @override
  State<QuranRecitationCardScreen> createState() => _QuranRecitationCardScreenState();
}

class _QuranRecitationCardScreenState extends State<QuranRecitationCardScreen> {
  late final ConfettiController _confetti =
      ConfettiController(duration: const Duration(milliseconds: 600));

  @override
  void initState() {
    super.initState();
    unawaited(StudentSoundService.instance.playClip(recitationWelcomeClip));
  }

  @override
  void dispose() {
    _confetti.dispose();
    super.dispose();
  }

  /// سورةٌ سُمِّعت كاملةً صحيحة: الخادمُ يصرف مكافأتها مرّةً لكل سورة.
  Future<RewardResult?> _rewardRecited(QuranSurah surah) async {
    final result = await widget.contentService.rewardActivity(
      profile: widget.profile,
      activityType: 'study_game',
      activityId: '${widget.academicContext.lessonId}::quran',
      quranSurah: surah.id,
    );
    if (result.gems > 0 && mounted) _confetti.play();
    return result;
  }

  @override
  Widget build(BuildContext context) {
    return _CardScaffold(
      background: PortalBackgrounds.study,
      confetti: _confetti,
      // ‏للعبة شريطُها: رجوعٌ واسمُ السورة.
      child: QuranRecitationGame(
        key: const ValueKey('quran-game'),
        onRecited: _rewardRecited,
        onBack: () => Navigator.of(context).maybePop(),
      ),
    );
  }
}

/// «قلمي السحري»: لعبةُ «تتبّع واكتب» للحروف والأرقام في بطاقتها.
class WritingCardScreen extends StatefulWidget {
  const WritingCardScreen({
    required this.profile,
    required this.contentService,
    required this.academicContext,
    super.key,
  });

  final StudentProfile profile;
  final StudentContentService contentService;
  final AcademicContext academicContext;

  @override
  State<WritingCardScreen> createState() => _WritingCardScreenState();
}

class _WritingCardScreenState extends State<WritingCardScreen> {
  late final ConfettiController _confetti =
      ConfettiController(duration: const Duration(milliseconds: 600));

  /// المجموعةُ كاملةً على الجهاز: تُفتح البطاقةُ على الحروف فوراً.
  late final StudyGame? _game = writingGameFor(
    grade: widget.academicContext.grade,
    subject: widget.academicContext.subject,
  );

  @override
  void initState() {
    super.initState();
    unawaited(StudentSoundService.instance.playClip(writingWelcomeClip));
  }

  @override
  void dispose() {
    _confetti.dispose();
    super.dispose();
  }

  Future<RewardResult?> _rewardTraced(TracingItem item) async {
    final result = await widget.contentService.rewardActivity(
      profile: widget.profile,
      activityType: 'study_game',
      activityId: '${widget.academicContext.lessonId}::$tracingGameId',
      tracingItem: item.text,
    );
    if (result.gems > 0 && mounted) _confetti.play();
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final game = _game;
    const green = Color(0xFF16A34A);
    return _CardScaffold(
      background: PortalBackgrounds.lesson,
      confetti: _confetti,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 6, 12, 2),
            child: Row(
              children: [
                IconButton(
                  key: const ValueKey('writing-back'),
                  onPressed: () => Navigator.of(context).maybePop(),
                  icon: const Icon(Icons.arrow_back_rounded),
                  color: StudentSurface.ink(context),
                ),
                const Text('✍️', style: TextStyle(fontSize: 24)),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    tr('portal.write'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: StudentSurface.vivid(context, green),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (game != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: Text(
                game.instructions,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: StudentSurface.mutedInk(context),
                ),
              ),
            ),
          const SizedBox(height: 8),
          Expanded(
            child: game == null
                ? Center(
                    child: Text(
                      tr('portal.write.unavailable'),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: StudentSurface.ink(context),
                      ),
                    ),
                  )
                : TracingGame(
                    key: const ValueKey('writing-game'),
                    game: game,
                    onTraced: _rewardTraced,
                  ),
          ),
        ],
      ),
    );
  }
}

/// أرضيّةُ البطاقتين: خلفيّةُ البوابة بإضاءتها، والورقُ المتناثر فوق الكلّ.
class _CardScaffold extends StatelessWidget {
  const _CardScaffold({
    required this.background,
    required this.confetti,
    required this.child,
  });

  final String background;
  final ConfettiController confetti;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: StudentSettings.direction,
      child: Scaffold(
        backgroundColor: StudentSurface.ground(context),
        body: Stack(
          children: [
            PortalWatermark(asset: background),
            SafeArea(child: child),
            Align(
              alignment: Alignment.topCenter,
              child: IgnorePointer(
                child: ConfettiWidget(
                  confettiController: confetti,
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
}
