import 'package:flutter/material.dart';

import '../l10n/student_strings.dart';
import '../models/student_gamification.dart';
import '../models/student_profile.dart';
import '../services/student_settings.dart';
import '../theme/student_theme.dart';
import '../widgets/student_avatar_view.dart';
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
              colors: [Color(0xFF0B8693), Color(0xFF274E76)],
            ),
            const SizedBox(height: 14),
            const StudentEntrance(
              delay: Duration(milliseconds: 40),
              child: _ProgressAnimationCard(),
            ),
            const SizedBox(height: 14),
            StudentEntrance(child: _StatsCard(stats: stats)),
            const SizedBox(height: 18),
            StudentEntrance(
              delay: const Duration(milliseconds: 80),
              child: Text(tr('progress.achievements'), style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
            ),
            const SizedBox(height: 10),
            if (stats.achievements.isEmpty)
              StudentEntrance(
                delay: const Duration(milliseconds: 120),
                child: Student3DCard(
                  child: Card(
                    child: Padding(
                      padding: EdgeInsets.all(22),
                      child: Text(tr('progress.noAchievements'), textAlign: TextAlign.center),
                    ),
                  ),
                ),
              )
            else
              ...stats.achievements.asMap().entries.map((entry) => StudentEntrance(
                    delay: Duration(milliseconds: 120 + (entry.key * 40)),
                    child: Student3DCard(
                      child: Card(
                        child: ListTile(
                          leading: Text(entry.value.icon, style: const TextStyle(fontSize: 30)),
                          title: Text(entry.value.title, style: const TextStyle(fontWeight: FontWeight.w900)),
                          subtitle: Text(entry.value.description),
                        ),
                      ),
                    ),
                  )),
            const SizedBox(height: 18),
            StudentEntrance(
              delay: const Duration(milliseconds: 240),
              child: Text(tr('progress.summary'), style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
            ),
            const SizedBox(height: 10),
            StudentEntrance(
              delay: const Duration(milliseconds: 280),
              child: Student3DCard(
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        _SummaryRow(icon: Icons.quiz_rounded, label: tr('progress.quizzesDone'), value: '${stats.totalQuizzes}'),
                        _SummaryRow(icon: Icons.menu_book_rounded, label: tr('progress.lessonsDone'), value: '${stats.totalLessons}'),
                        _SummaryRow(icon: Icons.sports_esports_rounded, label: tr('progress.gamesDone'), value: '${stats.totalGames}'),
                        _SummaryRow(icon: Icons.insights_rounded, label: tr('progress.quizAverage'), value: '${stats.averageScore}%'),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProgressAnimationCard extends StatelessWidget {
  const _ProgressAnimationCard();

  @override
  Widget build(BuildContext context) => Student3DCard(
        child: Card(
          color: const Color(0xFFE8F6F5),
          elevation: 0,
          child: Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(18, 10, 12, 10),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tr('progress.yourCharacter'),
                        style: const TextStyle(
                          color: Color(0xFF0B5F69),
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        tr('progress.encourage'),
                        style: const TextStyle(
                          color: Color(0xFF365B62),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                Semantics(
                  label: tr('progress.yourCharacter'),
                  child: const StudentAvatarView(size: 100),
                ),
              ],
            ),
          ),
        ),
      );
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

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.icon, required this.label, required this.value});
  final IconData icon;
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(children: [Icon(icon, color: const Color(0xFF0B8693)), const SizedBox(width: 10), Expanded(child: Text(label)), Text(value, style: const TextStyle(fontWeight: FontWeight.w900))]),
      );
}