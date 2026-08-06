import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import 'avatar_screen.dart';

class AchievementsScreen extends StatelessWidget {
  const AchievementsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('إنجازاتي', style: TextStyle(fontWeight: FontWeight.w900)),
        actions: [
          IconButton(
            tooltip: 'تخصيص الشخصية',
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AvatarScreen())),
            icon: const Icon(Icons.face_retouching_natural_outlined),
          ),
        ],
      ),
      body: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 30),
        children: [
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [ManaraColors.deepPurple, ManaraColors.purple]),
              borderRadius: BorderRadius.circular(26),
            ),
            child: Row(
              children: [
                Text(state.avatar, style: const TextStyle(fontSize: 52)),
                const SizedBox(width: 14),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('رحلتك الرائعة', style: TextStyle(color: Colors.white70)),
                  Text('المستوى ${state.level}', style: const TextStyle(color: Colors.white, fontSize: 25, fontWeight: FontWeight.w900)),
                  Text('${state.xp} XP • ${state.gems} 💎', style: const TextStyle(color: Colors.white70)),
                ])),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const Text('الشارات والإنجازات', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
          const SizedBox(height: 12),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: state.achievements.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, mainAxisSpacing: 12, crossAxisSpacing: 12, childAspectRatio: 1.1),
            itemBuilder: (_, index) {
              final achievement = state.achievements[index];
              return Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: achievement.unlocked ? ManaraColors.lavender : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Text(achievement.icon, style: TextStyle(fontSize: 38, color: achievement.unlocked ? null : Colors.grey)),
                  const SizedBox(height: 8),
                  Text(achievement.title, style: const TextStyle(fontWeight: FontWeight.w900)),
                  const SizedBox(height: 4),
                  Text(achievement.description, textAlign: TextAlign.center, style: const TextStyle(color: ManaraColors.muted, fontSize: 11)),
                ]),
              );
            },
          ),
          const SizedBox(height: 26),
          const Text('أبطال الصف', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
          const SizedBox(height: 10),
          ...['سلمان أحمد', 'ليان محمد', 'نور خالد'].asMap().entries.map((entry) => ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                leading: CircleAvatar(backgroundColor: entry.key == 0 ? ManaraColors.orange : ManaraColors.lavender, child: Text('${entry.key + 1}')),
                title: Text(entry.value, style: const TextStyle(fontWeight: FontWeight.bold)),
                trailing: Text('${980 - entry.key * 125} XP', style: const TextStyle(color: ManaraColors.purple, fontWeight: FontWeight.bold)),
              )),
        ],
      ),
    );
  }
}