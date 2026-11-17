import 'package:flutter/material.dart';

import '../l10n/student_strings.dart';
import '../screens/plans_screen.dart';
import '../services/demo_mode.dart';
import '../services/student_sound_service.dart';
import 'demo_ui.dart';

/// رسالةُ ما أُغلق في وضع الزائر: يُفتح كلُّه في الحساب الرسمي — وزرُّها
/// يفتح مقارنةَ الباقات وطلبَ الاشتراك مباشرةً.
///
/// ‏[message]: نصُّ القفل لهذا الموضع، وإلا «يُفتح في الحساب الرسمي».
void showDemoLocked(BuildContext context, {String? message}) {
  StudentSoundService.instance.play(StudentSoundCue.warning);
  // ‏يُلتقط الآن: لمسةُ الزرّ قد تأتي بعد أن تُغلق الشاشةُ التي أظهرت الرسالة.
  final navigator = Navigator.maybeOf(context);
  ScaffoldMessenger.maybeOf(context)
    ?..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      key: const ValueKey('demo-locked'),
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 5),
      action: navigator == null
          ? null
          : SnackBarAction(
              key: const ValueKey('demo-locked-get-account'),
              label: tr('demo.getAccount'),
              textColor: DemoPalette.goldLight,
              onPressed: () => navigator.push(
                MaterialPageRoute<void>(builder: (_) => PlansScreen(apiBaseUrl: DemoMode.plansBaseUrl)),
              ),
            ),
      backgroundColor: DemoPalette.violetDeep,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: DemoPalette.gold, width: 1.5),
      ),
      content: Row(children: [
        const Icon(Icons.lock_rounded, color: Color(0xFFFDE68A)),
        const SizedBox(width: 10),
        Expanded(child: Text(message ?? tr('demo.lockedInDemo'), style: const TextStyle(fontWeight: FontWeight.w800))),
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

/// أسئلةُ الاختبار المحجوبة عن الزائر: يرى عددها مقفلاً، ورسالةً ذهبية تدعوه
/// إلى الحساب الرسمي لإكمالها وفتح المنهج كاملاً.
class DemoLockedQuestions extends StatelessWidget {
  const DemoLockedQuestions({super.key, required this.count, required this.shown});

  /// كم سؤالاً حُجب، وكم ظهر قبلها (لترقيم المحجوب).
  final int count;
  final int shown;

  @override
  Widget build(BuildContext context) {
    final navigator = Navigator.maybeOf(context);
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
          Text(
            tr('demo.quiz.lockedMore'),
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, height: 1.5),
          ),
          const SizedBox(height: 12),
          DemoGradientButton(
            key: const ValueKey('demo-quiz-get-account'),
            label: tr('demo.getAccount'),
            icon: Icons.workspace_premium_rounded,
            shimmer: true,
            height: 50,
            onPressed: navigator == null
                ? null
                : () => navigator.push(
                      MaterialPageRoute<void>(builder: (_) => PlansScreen(apiBaseUrl: DemoMode.plansBaseUrl)),
                    ),
          ),
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
/// وزرٌّ إلى الباقات وطلب الاشتراك.
class DemoLockedCard extends StatelessWidget {
  const DemoLockedCard({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final navigator = Navigator.maybeOf(context);
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
          const SizedBox(height: 12),
          DemoGradientButton(
            label: tr('demo.getAccount'),
            icon: Icons.workspace_premium_rounded,
            shimmer: true,
            height: 50,
            onPressed: navigator == null
                ? null
                : () => navigator.push(
                      MaterialPageRoute<void>(builder: (_) => PlansScreen(apiBaseUrl: DemoMode.plansBaseUrl)),
                    ),
          ),
        ]),
      ),
    );
  }
}
