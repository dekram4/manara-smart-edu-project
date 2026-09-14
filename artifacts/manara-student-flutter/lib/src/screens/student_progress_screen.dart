import 'package:flutter/material.dart';

import '../l10n/student_strings.dart';
import '../models/student_gamification.dart';
import '../models/student_profile.dart';
import '../services/student_settings.dart';
import '../theme/student_theme.dart';
import '../widgets/student_experience.dart';

class StudentProgressScreen extends StatelessWidget {
  const StudentProgressScreen({required this.profile, this.stats, super.key});

  final StudentProfile profile;
  final StudentGamification? stats;

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
