import 'package:flutter/material.dart';

import '../l10n/student_strings.dart';
import '../services/student_sound_service.dart';
import '../theme/student_theme.dart';
import 'student_experience.dart';

/// The question asked before a unit exam opens.
///
/// A unit exam is taken once: the app shows the saved result instead of
/// reopening it, so a child who taps it while still halfway through the
/// unit has spent their only attempt and cannot undo it. Nothing on the
/// card said so — the tap went straight to question one.
///
/// So the door asks first, and the wording carries the reason rather than
/// only the warning: what makes this exam different is that it does not
/// come back. «Not yet» is the safe answer and is placed first for the
/// thumb; the child is not nudged toward the irreversible choice.
///
/// Returns true only on an explicit yes. A tap outside, the back button and
/// «not yet» all mean no.
Future<bool> confirmUnitExam(BuildContext context) async {
  StudentSoundService.instance.playTap();
  final ready = await showDialog<bool>(
    context: context,
    barrierDismissible: true,
    barrierColor: const Color(0x99101828),
    builder: (context) => const _UnitExamDialog(),
  );
  return ready ?? false;
}

class _UnitExamDialog extends StatelessWidget {
  const _UnitExamDialog();

  @override
  Widget build(BuildContext context) {
    final ink = StudentSurface.ink(context);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      child: Container(
        padding: const EdgeInsets.fromLTRB(22, 26, 22, 20),
        decoration: BoxDecoration(
          color: StudentSurface.card(context),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: const Color(0xFFFFC61A), width: 3),
          boxShadow: const [
            BoxShadow(
              color: Color(0x33000000),
              blurRadius: 30,
              offset: Offset(0, 14),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🌟', style: TextStyle(fontSize: 54)),
            const SizedBox(height: 10),
            Text(
              tr('quiz.unitConfirmTitle'),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: ink,
                fontSize: 21,
                fontWeight: FontWeight.w900,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 10),
            // السبب لا التحذير وحده: ما يميّز اختبار الوحدة أنه لا يعود.
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF4D6),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFFFD98A), width: 1.5),
              ),
              child: Text(
                tr('quiz.unitConfirmBody'),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFF92400E),
                  fontSize: 13.5,
                  fontWeight: FontWeight.w800,
                  height: 1.4,
                ),
              ),
            ),
            const SizedBox(height: 18),
            _ChunkyButton(
              label: tr('quiz.unitConfirmYes'),
              color: const Color(0xFF00C853),
              onPressed: () {
                StudentSoundService.instance.playTap();
                Navigator.of(context).pop(true);
              },
            ),
            const SizedBox(height: 10),
            // «سأراجع أولاً» ليس إلغاءً باهتاً: هو الخيار الآمن، فيُعرض
            // زرّاً كاملاً لا سطراً رمادياً تحت الزرّ الملوّن.
            _ChunkyButton(
              label: tr('quiz.unitConfirmNo'),
              color: const Color(0xFF3A86FF),
              onPressed: () {
                StudentSoundService.instance.playTap();
                Navigator.of(context).pop(false);
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// A button with a darker ledge under it, so it reads as something solid to
/// press rather than a coloured rectangle.
class _ChunkyButton extends StatelessWidget {
  const _ChunkyButton({
    required this.label,
    required this.color,
    required this.onPressed,
  });

  final String label;
  final Color color;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return StudentPressScale(
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(18),
          child: Ink(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: Color.lerp(color, Colors.black, 0.3)!,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16.5,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
