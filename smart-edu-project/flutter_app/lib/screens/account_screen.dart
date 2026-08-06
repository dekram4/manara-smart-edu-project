import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/app_models.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import 'avatar_screen.dart';

class AccountScreen extends StatelessWidget {
  const AccountScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final roleColor = ManaraColors.rolePrimary(state.role);
    return Scaffold(
      appBar: AppBar(title: const Text('حسابي', style: TextStyle(fontWeight: FontWeight.w900))),
      body: ListView(
        padding: const EdgeInsets.all(22),
        children: [
          Center(
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                CircleAvatar(
                  radius: 48,
                  backgroundColor: roleColor.withOpacity(.14),
                  child: Text(state.avatar, style: const TextStyle(fontSize: 42)),
                ),
                Positioned(
                  bottom: -4,
                  left: -4,
                  child: Material(
                    color: roleColor,
                    shape: const CircleBorder(),
                    child: IconButton(
                      tooltip: 'تخصيص الشخصية',
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const AvatarScreen()),
                      ),
                      icon: const Icon(Icons.edit, color: Colors.white, size: 18),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Center(child: Text(state.displayName, style: const TextStyle(fontSize: 23, fontWeight: FontWeight.w900))),
          const SizedBox(height: 4),
          Center(child: Text(state.role?.label ?? '', style: const TextStyle(color: ManaraColors.muted))),
          const SizedBox(height: 28),
           _InfoRow(label: 'المعرّف', value: state.userId ?? 'غير متاح', icon: Icons.badge_outlined, color: roleColor),
          if (state.role?.name == 'student') ...[
             _InfoRow(label: 'الصف', value: state.student?.primaryGrade ?? 'الصف الرابع', icon: Icons.school_outlined, color: roleColor),
             _InfoRow(label: 'XP', value: '${state.xp}', icon: Icons.star_outline, color: roleColor),
             _InfoRow(label: 'الجواهر', value: '${state.gems}', icon: Icons.diamond_outlined, color: roleColor),
          ],
          const SizedBox(height: 20),
          SwitchListTile.adaptive(
            value: state.soundEnabled,
            onChanged: (value) {
              state.setSoundEnabled(value);
              state.speech.enabled = value;
            },
            title: const Text('الأصوات والمؤثرات'),
            secondary: const Icon(Icons.volume_up_outlined),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(onPressed: () => state.logout(), icon: const Icon(Icons.logout), label: const Text('تسجيل الخروج')),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value, required this.icon, required this.color});
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(17)),
         child: Row(children: [Icon(icon, color: color), const SizedBox(width: 12), Text(label, style: const TextStyle(color: ManaraColors.muted)), const Spacer(), Text(value, style: const TextStyle(fontWeight: FontWeight.bold))]),
      );
}