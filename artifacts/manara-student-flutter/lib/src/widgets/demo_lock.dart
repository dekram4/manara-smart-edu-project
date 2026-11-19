import 'package:flutter/material.dart';

import '../l10n/student_strings.dart';
import '../services/student_sound_service.dart';
import 'demo_ui.dart';
import 'guest_contact.dart';

/// ما أُغلق في وضع الزائر: نافذةُ «مخصص للطلاب المسجلين» وزرّا التواصل مع
/// المشرف — لا باقاتٌ ولا اشتراكٌ ولا دفع (سياساتُ Google Play وApp Store).
///
/// ‏[message]: سطرٌ يقول ما انتهى في هذا الموضع، فوق النصّ الإداريّ.
void showDemoLocked(BuildContext context, {String? message}) {
  StudentSoundService.instance.play(StudentSoundCue.warning);
  showGuestRegisteredOnly(context, note: message, key: const ValueKey('demo-locked'));
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

/// أسئلةُ الاختبار المحجوبة عن الزائر: يرى عددها مقفلاً، ثم «مخصص للطلاب
/// المسجلين» وزرّا التواصل مع المشرف.
class DemoLockedQuestions extends StatelessWidget {
  const DemoLockedQuestions({super.key, required this.count, required this.shown});

  /// كم سؤالاً حُجب، وكم ظهر قبلها (لترقيم المحجوب).
  final int count;
  final int shown;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('demo-quiz-locked'),
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        gradient: DemoPalette.goldGradient,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: DemoPalette.gold.withValues(alpha: 0.35), blurRadius: 16, offset: const Offset(0, 6))],
      ),
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
        decoration: BoxDecoration(
          gradient: DemoPalette.violetGradient,
          borderRadius: BorderRadius.circular(22),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: DemoPalette.goldGradient,
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: const Icon(Icons.lock_rounded, color: DemoPalette.goldInk, size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                trf('demo.quiz.lockedCount', {'n': count}),
                style: const TextStyle(color: DemoPalette.goldLight, fontWeight: FontWeight.w900, fontSize: 16),
              ),
            ),
          ]),
          const SizedBox(height: 12),
          // ‏المحجوبُ ظاهرٌ بعدده ورقمه، لا بنصّه.
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (var i = 0; i < count; i++)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: DemoPalette.goldLight.withValues(alpha: 0.6)),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.lock_rounded, size: 14, color: DemoPalette.goldLight),
                  const SizedBox(width: 5),
                  Text(
                    trf('demo.quiz.lockedItem', {'n': shown + i + 1}),
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
                  ),
                ]),
              ),
          ]),
          const SizedBox(height: 12),
          const GuestContactPanel(),
        ]),
      ),
    );
  }
}

/// ما بقي للزائر من تجربةٍ محدودة («تبقّى لك سؤالان»): شارةٌ ذهبية.
class DemoQuotaChip extends StatelessWidget {
  const DemoQuotaChip({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        gradient: DemoPalette.goldGradient,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: DemoPalette.gold.withValues(alpha: 0.3), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.auto_awesome_rounded, size: 16, color: DemoPalette.goldInk),
        const SizedBox(width: 6),
        Flexible(
          child: Text(text, style: const TextStyle(fontWeight: FontWeight.w900, color: DemoPalette.goldInk)),
        ),
      ]),
    );
  }
}

/// انتهت تجربةُ الزائر في هذا الموضع: بطاقةٌ بنفسجيةٌ بإطارٍ ذهبيّ، ورسالتُها،
/// ثم «مخصص للطلاب المسجلين» وزرّا التواصل مع المشرف.
class DemoLockedCard extends StatelessWidget {
  const DemoLockedCard({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        gradient: DemoPalette.goldGradient,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: DemoPalette.gold.withValues(alpha: 0.35), blurRadius: 16, offset: const Offset(0, 6))],
      ),
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
        decoration: BoxDecoration(gradient: DemoPalette.violetGradient, borderRadius: BorderRadius.circular(22)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: DemoPalette.goldGradient,
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: const Icon(Icons.lock_rounded, color: DemoPalette.goldInk, size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, height: 1.5),
              ),
            ),
          ]),
          const SizedBox(height: 14),
          const GuestContactPanel(),
        ]),
      ),
    );
  }
}
