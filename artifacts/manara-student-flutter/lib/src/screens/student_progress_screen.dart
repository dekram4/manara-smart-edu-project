import 'package:flutter/material.dart';

import '../models/student_gamification.dart';
import '../models/student_profile.dart';
import '../widgets/student_experience.dart';

class StudentProgressScreen extends StatelessWidget {
  const StudentProgressScreen({required this.profile, this.stats, super.key});

  final StudentProfile profile;
  final StudentGamification? stats;

  @override
  Widget build(BuildContext context) {
    final stats = this.stats ?? profile.gamification;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF4F8FF),
        appBar: AppBar(title: const Text('تقدمي وإنجازاتي'), actions: const [StudentSoundToggle()]),
        body: ListView(
          padding: const EdgeInsets.all(18),
          children: [
            const StudentScreenHero(
              title: 'تقدمي وإنجازاتي',
              subtitle: 'تابع إنجازاتك وتطورك، وكل خطوة تقربك من هدفك.',
              icon: Icons.insights_rounded,
              colors: [Color(0xFF0B8693), Color(0xFF274E76)],
            ),
            const SizedBox(height: 14),
            StudentEntrance(child: _StatsCard(stats: stats)),
            const SizedBox(height: 18),
            const StudentEntrance(
              delay: Duration(milliseconds: 80),
              child: Text('الإنجازات المفتوحة', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
            ),
            const SizedBox(height: 10),
            if (stats.achievements.isEmpty)
              const StudentEntrance(
                delay: Duration(milliseconds: 120),
                child: Student3DCard(
                  child: Card(
                    child: Padding(
                      padding: EdgeInsets.all(22),
                      child: Text('لا توجد إنجازات بعد. أكمل درسًا أو اختبارًا لتبدأ رحلتك.', textAlign: TextAlign.center),
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
            const StudentEntrance(
              delay: Duration(milliseconds: 240),
              child: Text('ملخص التعلم', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
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
                        _SummaryRow(icon: Icons.quiz_rounded, label: 'الاختبارات المكتملة', value: '${stats.totalQuizzes}'),
                        _SummaryRow(icon: Icons.menu_book_rounded, label: 'الدروس المكتملة', value: '${stats.totalLessons}'),
                        _SummaryRow(icon: Icons.sports_esports_rounded, label: 'الألعاب المكتملة', value: '${stats.totalGames}'),
                        _SummaryRow(icon: Icons.insights_rounded, label: 'متوسط الاختبارات', value: '${stats.averageScore}%'),
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
                Text('المستوى ${stats.level}', style: const TextStyle(color: Colors.white, fontSize: 25, fontWeight: FontWeight.w900)),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('⭐ XP ${stats.xp}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900)),
                    Text('💎 ${stats.gems}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900)),
                    Text('🔥 ${stats.streak} يوم', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900)),
                  ],
                ),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: LinearProgressIndicator(value: stats.levelProgress / 100, minHeight: 11, backgroundColor: Colors.white30, color: Colors.amber),
                ),
                const SizedBox(height: 6),
                Text('${stats.levelProgress} / 100 XP إلى المستوى التالي', style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w700)),
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