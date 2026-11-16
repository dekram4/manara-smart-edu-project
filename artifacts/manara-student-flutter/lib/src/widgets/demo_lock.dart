import 'package:flutter/material.dart';

import '../l10n/student_strings.dart';
import '../services/student_sound_service.dart';

/// رسالةُ ما أُغلق في وضع الزائر: يُفتح كلُّه في الحساب الرسمي.
void showDemoLocked(BuildContext context) {
  StudentSoundService.instance.play(StudentSoundCue.warning);
  ScaffoldMessenger.maybeOf(context)
    ?..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      key: const ValueKey('demo-locked'),
      behavior: SnackBarBehavior.floating,
      backgroundColor: const Color(0xFF92400E),
      content: Row(children: [
        const Icon(Icons.lock_rounded, color: Color(0xFFFDE68A)),
        const SizedBox(width: 10),
        Expanded(child: Text(tr('demo.lockedInDemo'), style: const TextStyle(fontWeight: FontWeight.w800))),
      ]),
    ));
}

/// عنصرٌ مقفلٌ في وضع الزائر: باهتٌ وعليه قفلٌ ذهبيّ، ولمستُه تقول لماذا.
class DemoLocked extends StatelessWidget {
  const DemoLocked({super.key, required this.locked, required this.child});

  final bool locked;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!locked) return child;
    return Stack(alignment: Alignment.center, children: [
      Opacity(opacity: 0.4, child: IgnorePointer(child: child)),
      Positioned.fill(
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: () => showDemoLocked(context),
            child: const Center(
              child: CircleAvatar(
                radius: 22,
                backgroundColor: Color(0xFFF59E0B),
                child: Icon(Icons.lock_rounded, color: Colors.white),
              ),
            ),
          ),
        ),
      ),
    ]);
  }
}
