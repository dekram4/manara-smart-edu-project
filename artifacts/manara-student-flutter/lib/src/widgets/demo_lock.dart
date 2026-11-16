import 'package:flutter/material.dart';

import '../l10n/student_strings.dart';
import '../services/student_sound_service.dart';
import 'demo_ui.dart';

/// رسالةُ ما أُغلق في وضع الزائر: يُفتح كلُّه في الحساب الرسمي.
void showDemoLocked(BuildContext context) {
  StudentSoundService.instance.play(StudentSoundCue.warning);
  ScaffoldMessenger.maybeOf(context)
    ?..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      key: const ValueKey('demo-locked'),
      behavior: SnackBarBehavior.floating,
      backgroundColor: DemoPalette.violetDeep,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: DemoPalette.gold, width: 1.5),
      ),
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
            child: Center(
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: DemoPalette.goldGradient,
                  border: Border.all(color: Colors.white, width: 2.5),
                  boxShadow: [BoxShadow(color: DemoPalette.gold.withValues(alpha: 0.55), blurRadius: 14)],
                ),
                child: const Icon(Icons.lock_rounded, color: DemoPalette.goldInk, size: 22),
              ),
            ),
          ),
        ),
      ),
    ]);
  }
}
