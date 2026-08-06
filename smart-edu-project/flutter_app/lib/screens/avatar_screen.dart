import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';

class AvatarScreen extends StatelessWidget {
  const AvatarScreen({super.key});

  static const avatars = [
    '🧑‍🚀',
    '👩‍🎨',
    '🧙‍♂️',
    '🦸‍♀️',
    '🧑‍🔬',
    '🧚‍♀️',
    '🐼',
    '🦊',
  ];

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    return Scaffold(
      appBar: AppBar(title: const Text('خصص شخصيتك', style: TextStyle(fontWeight: FontWeight.w900))),
      body: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          children: [
            const SizedBox(height: 18),
            AnimatedSwitcher(duration: const Duration(milliseconds: 250), child: Text(state.avatar, key: ValueKey(state.avatar), style: const TextStyle(fontSize: 100))),
            const SizedBox(height: 10),
            const Text('اختر شخصيتك المفضلة', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
            const SizedBox(height: 24),
            GridView.count(
              shrinkWrap: true,
              crossAxisCount: 4,
              mainAxisSpacing: 14,
              crossAxisSpacing: 14,
             children: avatars.map((avatar) {
               final unlocked = state.unlockedAvatars.contains(avatar);
               final cost = AppState.avatarCosts[avatar] ?? 0;
               return InkWell(
                 borderRadius: BorderRadius.circular(20),
                 onTap: () async {
                   final selected = await state.setAvatar(avatar);
                   if (!selected && context.mounted && !unlocked) {
                     ScaffoldMessenger.of(context).showSnackBar(
                       SnackBar(content: Text('تحتاج إلى $cost جوهرة لفتح هذه الشخصية')),
                     );
                   }
                 },
                 child: Ink(
                   decoration: BoxDecoration(
                     color: state.avatar == avatar
                         ? ManaraColors.lavender
                         : Colors.white,
                     borderRadius: BorderRadius.circular(20),
                     border: Border.all(
                       color: state.avatar == avatar
                           ? ManaraColors.purple
                           : Colors.transparent,
                       width: 2,
                     ),
                   ),
                   child: Stack(
                     alignment: Alignment.center,
                     children: [
                       Opacity(
                         opacity: unlocked ? 1 : .35,
                         child: Text(
                           avatar,
                           style: const TextStyle(fontSize: 36),
                         ),
                       ),
                       if (!unlocked)
                         Positioned(
                           top: 6,
                           right: 6,
                           child: Text(
                             '$cost 💎',
                             style: const TextStyle(
                               fontSize: 10,
                               fontWeight: FontWeight.w900,
                               color: ManaraColors.purple,
                             ),
                           ),
                         ),
                     ],
                   ),
                 ),
               );
             }).toList(),
            ),
            const Spacer(),
            const Text('يمكن فتح شخصيات جديدة باستخدام الجواهر 💎', style: TextStyle(color: ManaraColors.muted)),
          ],
        ),
      ),
    );
  }
}