import 'package:flutter/material.dart';

import '../l10n/student_strings.dart';
import '../models/student_gamification.dart';
import '../models/student_profile.dart';
import '../services/student_leaderboard_service.dart';
import '../services/student_settings.dart';
import '../theme/student_theme.dart';
import '../widgets/student_avatar_view.dart';
import '../widgets/student_experience.dart';

class StudentProgressScreen extends StatelessWidget {
  const StudentProgressScreen({
    required this.profile,
    this.stats,
    this.leaderboardService,
    super.key,
  });

  final StudentProfile profile;
  final StudentGamification? stats;

  /// قارئ لوحة الصدارة. غيابه يعني شاشةً بأرقام الطفل وحدها — وهو ما
  /// يجري في الاختبارات وفي أي مسارٍ لا جلسةَ خادمٍ له.
  final StudentLeaderboardService? leaderboardService;

  @override
  Widget build(BuildContext context) {
    final stats = this.stats ?? profile.gamification;
    return Directionality(
      textDirection: StudentSettings.direction,
      child: Scaffold(
        backgroundColor: StudentSurface.ground(context),
        appBar: AppBar(title: Text(tr('progress.title')), actions: const [StudentSoundToggle()]),
        body: ListView(
          padding: const EdgeInsets.all(18),
          children: [
            StudentScreenHero(
              title: tr('progress.title'),
              subtitle: tr('progress.subtitle'),
              icon: Icons.insights_rounded,
              colors: [const Color(0xFF0B8693), StudentSurface.ink(context)],
            ),
            const SizedBox(height: 14),
            // الشاشة محصورة في الثلاثة التي تهمّ الطالب: الجواهر، ونقاط
            // الخبرة، والمستوى — ثم عبارة تحفيزية تتغيّر بتغيّرها.
            //
            // أُزيلت بطاقة الشخصية وقائمة الإنجازات وملخّص (الدروس/الاختبارات/
            // الألعاب/المتوسط): كانت تزاحم الأرقام الثلاثة وتدفعها أسفل الطيّة،
            // والطالب يفتح هذه الشاشة ليرى رصيده لا ليقرأ تقريراً.
            StudentEntrance(child: _StatsCard(stats: stats)),
            const SizedBox(height: 14),
            StudentEntrance(
              delay: const Duration(milliseconds: 90),
              child: _CheerCard(stats: stats),
            ),
            if (leaderboardService != null)
              _LeaderboardSection(service: leaderboardService!),
          ],
        ),
      ),
    );
  }
}

class _StatsCard extends StatelessWidget {
  const _StatsCard({required this.stats});
  final StudentGamification stats;

  @override
  Widget build(BuildContext context) => Student3DCard(
        child: Card(
          color: const Color(0xFF0B8693),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(trf('progress.level', {'level': stats.level}), style: const TextStyle(color: Colors.white, fontSize: 25, fontWeight: FontWeight.w900)),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(trf('progress.xp', {'xp': stats.xp}), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900)),
                    Text('💎 ${stats.gems}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900)),
                    Text(trf('progress.streak', {'days': stats.streak}), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900)),
                  ],
                ),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: LinearProgressIndicator(value: stats.levelProgress / 100, minHeight: 11, backgroundColor: Colors.white30, color: Colors.amber),
                ),
                const SizedBox(height: 6),
                Text(trf('progress.toNextLevel', {'done': stats.levelProgress}), style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
        ),
      );
}

/// عبارة تشجيع تتبدّل بتبدّل رصيد الطالب.
///
/// ثابتة النص كانت ستفقد أثرها من ثاني زيارة؛ ربطها بالمستوى يجعلها تعترف
/// بما أنجزه الطالب فعلاً.
class _CheerCard extends StatelessWidget {
  const _CheerCard({required this.stats});

  final StudentGamification stats;

  String get _message {
    if (stats.level >= 5) return tr('progress.cheerHero');
    if (stats.level >= 3) return tr('progress.cheerStrong');
    if (stats.gems >= 10) return tr('progress.cheerGrowing');
    return tr('progress.cheerStart');
  }

  /// كم جوهرة تفصل الطالب عن الدفعة التالية من نقاط الخبرة (كل 10 جواهر).
  int get _gemsToNextReward => 10 - (stats.gems % 10);

  @override
  Widget build(BuildContext context) => Student3DCard(
        child: Card(
          color: StudentSurface.card(context),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  _message,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 18,
                    height: 1.6,
                    fontWeight: FontWeight.w900,
                    color: StudentSurface.ink(context),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  trf('progress.gemsToNext', {'gems': _gemsToNextReward}),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: StudentSurface.mutedInk(context),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
}

/// لوحة صدارة الجواهر بين زملاء الصفّ.
///
/// ── قسمٌ لا شاشة ──
/// تُعرض داخل شاشة الجواهر لا في شاشةٍ ثانية: الطفل يفتح هذه الشاشة ليرى
/// رصيده، والسؤال الذي يليه مباشرةً هو «وأين أنا من أصحابي؟». ووضعُها
/// خلف زرٍّ آخر يجعل الجواب يحتاج نيّة.
///
/// ── وفشلُها صامت ──
/// إن تعذّرت القراءة اختفى القسم وبقيت أرقام الطفل. صفٌّ لا يُقرأ يجب أن
/// يُخفي بطاقةً لا أن يضع شريط خطأ فوق رصيدٍ سليم.
class _LeaderboardSection extends StatefulWidget {
  const _LeaderboardSection({required this.service});
  final StudentLeaderboardService service;

  @override
  State<_LeaderboardSection> createState() => _LeaderboardSectionState();
}

class _LeaderboardSectionState extends State<_LeaderboardSection> {
  LeaderboardResult? _result;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!_loading) setState(() => _loading = true);
    final result = await widget.service.fetch();
    if (!mounted) return;
    setState(() {
      _result = result;
      _loading = false;
    });
  }

  /// عنوان القسم وما تحته، أيّاً كان ما تحته.
  Widget _shell(BuildContext context, {required Widget child}) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 18),
          Row(
            children: [
              const Text('🏆', style: TextStyle(fontSize: 22)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  tr('board.title'),
                  style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w900,
                    color: StudentSurface.ink(context),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      );

  /// سببُ التعذّر بعبارةٍ يفهمها من يقرؤها على الشاشة.
  String _problemLine(LeaderboardProblem problem) => switch (problem) {
        LeaderboardProblem.noService => tr('board.error.noService'),
        LeaderboardProblem.noSession => tr('board.error.noSession'),
        LeaderboardProblem.notDeployed => tr('board.error.notDeployed'),
        LeaderboardProblem.refused => tr('board.error.refused'),
        LeaderboardProblem.badResponse => tr('board.error.badResponse'),
        LeaderboardProblem.offline => tr('board.error.offline'),
      };

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    final result = _result;
    // القسم لا يختفي عند التعثّر، بل يقول ما جرى.
    //
    // كان يُخفي نفسه في كل تعذّر، فيرى الطفل شاشةً بلا صدارة ويرى
    // صاحبُ المنصّة ميزةً «لم تُبنَ». والعنوانُ يبقى ظاهراً في الحالين،
    // فيُعرف أن هنا شيئاً وأنه متعثّر لا غائب.
    if (result == null || !result.ok) {
      return _shell(
        context,
        child: _Trouble(
          message: result == null
              ? tr('board.error.badResponse')
              : _problemLine(result.problem!),
          detail: result?.detail,
          onRetry: _load,
        ),
      );
    }
    final board = result.board!;
    // صفٌّ فيه طفلٌ واحد: لا تتويج على النفس، لكن يُقال ذلك ولا يُصمَت.
    if (board.total < 2) {
      return _shell(context, child: _Trouble(message: tr('board.alone')));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 18),
        Row(
          children: [
            const Text('🏆', style: TextStyle(fontSize: 22)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                tr('board.title'),
                style: TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w900,
                  color: StudentSurface.ink(context),
                ),
              ),
            ),
            Text(
              trf('board.count', {'n': '${board.total}'}),
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Color(0xFF64748B),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        StudentEntrance(child: _Podium(board: board)),
        if (board.rest.isNotEmpty) ...[
          const SizedBox(height: 12),
          for (final entry in board.rest)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _RankRow(entry: entry),
            ),
        ],
        if (board.listed) ...[
          const SizedBox(height: 14),
          StudentEntrance(
            delay: const Duration(milliseconds: 120),
            child: _MyStanding(board: board),
          ),
        ],
      ],
    );
  }
}

/// منصّة التتويج: الثلاثة الأوائل، والأول في الوسط وأعلى.
class _Podium extends StatelessWidget {
  const _Podium({required this.board});
  final Leaderboard board;

  static const _medals = ['🥇', '🥈', '🥉'];
  static const _colors = [
    Color(0xFFF59E0B),
    Color(0xFF94A3B8),
    Color(0xFFB45309),
  ];

  @override
  Widget build(BuildContext context) {
    final podium = board.podium;
    if (podium.isEmpty) return const SizedBox.shrink();
    // الترتيب البصري: الثاني ثم الأول ثم الثالث، فيتوسّط المتصدّرُ
    // المنصّة كما في التتويج الحقيقي. ومع نقصان العدد يُطوى ما لا وجود له.
    final order = <int>[if (podium.length > 1) 1, 0, if (podium.length > 2) 2];
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (final index in order)
          Expanded(
            child: _PodiumStep(
              entry: podium[index],
              medal: _medals[index],
              color: _colors[index],
              height: index == 0 ? 132.0 : (index == 1 ? 110.0 : 96.0),
            ),
          ),
      ],
    );
  }
}

class _PodiumStep extends StatelessWidget {
  const _PodiumStep({
    required this.entry,
    required this.medal,
    required this.color,
    required this.height,
  });

  final LeaderboardEntry entry;
  final String medal;
  final Color color;
  final double height;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // شخصيةُ الزميل كما اختارها هو، بالويدجت نفسه الذي يرسم
            // شخصية صاحب الجهاز — فلا يفترق مظهرُ الاثنين.
            StudentAvatarView(
              size: height >= 130 ? 56 : 46,
              appearance: entry.appearance,
            ),
            const SizedBox(height: 4),
            Text(medal, style: const TextStyle(fontSize: 22)),
            const SizedBox(height: 2),
            Text(
              entry.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                fontWeight: entry.isMe ? FontWeight.w900 : FontWeight.w700,
                color: StudentSurface.ink(context),
              ),
            ),
            const SizedBox(height: 6),
            Container(
              height: height,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [color, color.withValues(alpha: 0.72)],
                ),
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(14)),
                border: entry.isMe
                    ? Border.all(color: const Color(0xFF0B8693), width: 3)
                    : null,
              ),
              alignment: Alignment.center,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${entry.gems}',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ),
                  ),
                  const Text('💎', style: TextStyle(fontSize: 15)),
                ],
              ),
            ),
          ],
        ),
      );
}

/// صفٌّ في بقيّة القائمة.
class _RankRow extends StatelessWidget {
  const _RankRow({required this.entry});
  final LeaderboardEntry entry;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: entry.isMe
              ? const Color(0xFF0B8693).withValues(alpha: 0.12)
              : StudentSurface.glass(context, 0.86),
          borderRadius: BorderRadius.circular(14),
          border: entry.isMe
              ? Border.all(color: const Color(0xFF0B8693), width: 2)
              : null,
        ),
        child: Row(
          children: [
            SizedBox(
              width: 32,
              child: Text(
                '${entry.rank}',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: entry.isMe
                      ? const Color(0xFF0B8693)
                      : const Color(0xFF64748B),
                ),
              ),
            ),
            StudentAvatarView(
              size: 34,
              showRing: false,
              appearance: entry.appearance,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                entry.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: entry.isMe ? FontWeight.w900 : FontWeight.w700,
                  color: StudentSurface.ink(context),
                ),
              ),
            ),
            Text(
              '${entry.gems} 💎',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w900,
                color: StudentSurface.ink(context),
              ),
            ),
          ],
        ),
      );
}

/// بطاقة الطالب نفسه: مركزه، والفارق، وعبارةٌ تتبع مركزه.
class _MyStanding extends StatelessWidget {
  const _MyStanding({required this.board});
  final Leaderboard board;

  /// العبارة بحسب المركز.
  ///
  /// ثلاث حالات لا واحدة: المتصدّر يُمدح على ما بلغ، والقريب يُدلّ على ما
  /// بقي، والبعيد يُوعَد بما يقرّبه. وعبارةٌ واحدةٌ للجميع تقول للمتصدّر
  /// «اجمع أكثر لتصل» وهو في القمّة.
  String _cheer() {
    if (board.myRank == 1) return tr('board.cheer.first');
    if (board.gemsToNext > 0 && board.gemsToNext <= 10) {
      return trf('board.cheer.close', {'n': '${board.gemsToNext}'});
    }
    return tr('board.cheer.climb');
  }

  @override
  Widget build(BuildContext context) {
    final me = board.me;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0B8693), Color(0xFF075E68)],
        ),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              StudentAvatarView(size: 44, appearance: me?.appearance),
              const SizedBox(width: 6),
              Text(
                board.myRank == 1 ? '👑' : '🎯',
                style: const TextStyle(fontSize: 22),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  trf('board.myRank', {
                    'rank': '${board.myRank}',
                    'total': '${board.total}',
                  }),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
              ),
              if (me != null)
                Text(
                  '${me.gems} 💎',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            _cheer(),
            style: const TextStyle(
              fontSize: 14,
              height: 1.55,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}


/// بطاقةُ تعثّرٍ في مكان اللوحة: ما جرى، وزرُّ إعادة محاولة.
///
/// ليست شريط خطأٍ أحمر: الطفل ليس من يُصلح هذا، ولونُ الإنذار يُقلقه بلا
/// فائدة. والتفصيل — ما قاله الخادم حرفياً — يُعرض بخطٍّ أصغر لمن يقرؤه
/// من الكبار، فهو ما يُشخَّص منه العطل.
class _Trouble extends StatelessWidget {
  const _Trouble({required this.message, this.detail, this.onRetry});

  final String message;
  final String? detail;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: StudentSurface.glass(context, 0.86),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: const Color(0xFF0B8693).withValues(alpha: 0.35),
            width: 1.5,
          ),
        ),
        child: Column(
          children: [
            const Text('🏅', style: TextStyle(fontSize: 30)),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                height: 1.5,
                fontWeight: FontWeight.w700,
                color: StudentSurface.ink(context),
              ),
            ),
            if (detail != null && detail!.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                detail!,
                textAlign: TextAlign.center,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 11,
                  color: Color(0xFF64748B),
                ),
              ),
            ],
            if (onRetry != null) ...[
              const SizedBox(height: 10),
              TextButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: Text(tr('board.retry')),
              ),
            ],
          ],
        ),
      );
}
