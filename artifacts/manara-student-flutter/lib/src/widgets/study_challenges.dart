import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/student_strings.dart';
import '../models/interactive_study.dart';
import '../theme/student_theme.dart';
import 'student_avatar_view.dart';

/// حالُ الشخصية في المشهد.
///
/// ── لماذا حالاتٌ لا صورٌ ──
/// صورةُ الشخصية واحدةٌ مرسومة — لا ملفَّ لكل تعبير — فالتعبيرُ يُصنع
/// بحركتها لا بوجهها: تهتزّ قليلاً وهي تسأل، وتقفز وتُحيط بها هالةٌ عند
/// الإصابة، وتميل وتخبو عند الخطأ. والطفل يقرأ الحركةَ أسرعَ من الوجه.
enum StudyMood { asking, right, wrong }

/// شخصيةُ الطالب في مشهد التحدي.
class StudyAvatar extends StatelessWidget {
  const StudyAvatar({
    required this.appearance,
    required this.mood,
    this.size = 92,
    super.key,
  });

  final Map<String, dynamic>? appearance;
  final StudyMood mood;
  final double size;

  @override
  Widget build(BuildContext context) {
    final (offset, tilt, glow) = switch (mood) {
      // قفزةٌ إلى أعلى وهالةٌ ذهبية.
      StudyMood.right => (-14.0, 0.0, const Color(0xFFFBBF24)),
      // ميلةٌ وهالةٌ باهتة.
      StudyMood.wrong => (0.0, 0.08, const Color(0xFFDC2626)),
      StudyMood.asking => (0.0, 0.0, const Color(0xFF7C3AED)),
    };
    return AnimatedContainer(
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutBack,
      transform: Matrix4.translationValues(0, offset, 0)..rotateZ(tilt),
      transformAlignment: Alignment.bottomCenter,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: glow.withValues(alpha: mood == StudyMood.asking ? 0.20 : 0.45),
            blurRadius: mood == StudyMood.right ? 28 : 16,
            spreadRadius: mood == StudyMood.right ? 4 : 0,
          ),
        ],
      ),
      child: StudentAvatarView(size: size, appearance: appearance),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// ١ ── مسارُ القرار: بوّابتان تمشي الشخصيةُ إلى إحداهما
// ─────────────────────────────────────────────────────────────────────

/// ── لماذا بوّابتان لا أربعةُ أزرار ──
/// الاختيارُ من أربعةٍ عملٌ ذهنيّ مجرّد، والمشيُ إلى بوّابةٍ فعلٌ يُرى.
/// والشخصيةُ تنتقل إلى البوّابة التي اختارها الطفل، فيرى قرارَه يقع في
/// المشهد لا في لونِ زرّ.
class AvatarPathChallenge extends StatelessWidget {
  const AvatarPathChallenge({
    required this.situation,
    required this.appearance,
    required this.picked,
    required this.onPick,
    super.key,
  });

  final StudySituation situation;
  final Map<String, dynamic>? appearance;
  final int? picked;
  final ValueChanged<int> onPick;

  @override
  Widget build(BuildContext context) {
    final answered = picked != null;
    final right = answered && situation.isCorrect(picked!);
    return Column(
      children: [
        Text(
          situation.prompt,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 15.5,
            height: 1.6,
            fontWeight: FontWeight.w800,
            color: StudentSurface.ink(context),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            for (var index = 0; index < situation.options.length; index += 1) ...[
              if (index > 0) const SizedBox(width: 10),
              Expanded(
                child: _Gate(
                  label: situation.options[index],
                  // البوّابةُ تُفتح إن كانت صحيحةً بعد الاختيار.
                  open: answered && index == situation.answer,
                  shut: answered && index == picked && !right,
                  onTap: answered ? null : () => onPick(index),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 14),
        // الشخصيةُ تنزاح نحو البوّابة المختارة.
        AnimatedAlign(
          duration: const Duration(milliseconds: 320),
          curve: Curves.easeOutCubic,
          alignment: !answered
              ? Alignment.center
              : picked == 0
                  ? Alignment.centerLeft
                  : Alignment.centerRight,
          child: StudyAvatar(
            appearance: appearance,
            mood: !answered
                ? StudyMood.asking
                : right
                    ? StudyMood.right
                    : StudyMood.wrong,
          ),
        ),
      ],
    );
  }
}

class _Gate extends StatelessWidget {
  const _Gate({
    required this.label,
    required this.open,
    required this.shut,
    required this.onTap,
  });

  final String label;
  final bool open;
  final bool shut;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final (border, fill, ink) = open
        ? (
            const Color(0xFF16A34A),
            const Color(0xFFDCFCE7),
            const Color(0xFF14532D),
          )
        : shut
            ? (
                const Color(0xFFDC2626),
                const Color(0xFFFEE2E2),
                const Color(0xFF7F1D1D),
              )
            : (
                const Color(0xFF7C3AED),
                const Color(0x147C3AED),
                StudentSurface.ink(context),
              );
    return Material(
      color: fill,
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: border, width: 1.6),
          ),
          child: Column(
            children: [
              Text(
                open ? '🚪' : (shut ? '🧱' : '🚪'),
                style: const TextStyle(fontSize: 26),
              ),
              const SizedBox(height: 6),
              Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13.5,
                  height: 1.4,
                  fontWeight: FontWeight.w800,
                  color: ink,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// ٢ ── سفاري الحقائق: بطاقةٌ تُسحب يميناً أو يساراً
// ─────────────────────────────────────────────────────────────────────

/// ── لماذا سحبٌ لا زرّان ──
/// الحكمُ على معلومةٍ «صحيحةٌ أم مشوَّهة» قرارٌ سريع، والسحبُ يناسب سرعته:
/// يمينٌ صحيحة، ويسارٌ خطأ. ومعه اهتزازةٌ لمسيّة، فيصل الجوابُ إلى إصبعه
/// قبل أن يقرأ سطر الشرح.
///
/// وزرّان تحتها لمن لا يصل السحبُ عنده — جهازٌ لا يهتزّ، أو إصبعٌ لا يُتقن
/// السحب: فلا يُحبس الطفل خارج التحدي لأن إيماءةً لم تُفهم.
class SwipeFactChallenge extends StatefulWidget {
  const SwipeFactChallenge({
    required this.situation,
    required this.appearance,
    required this.picked,
    required this.onPick,
    super.key,
  });

  final StudySituation situation;
  final Map<String, dynamic>? appearance;
  final int? picked;

  /// صفرٌ «صحيحة»، وواحدٌ «مشوَّهة».
  final ValueChanged<int> onPick;

  @override
  State<SwipeFactChallenge> createState() => _SwipeFactChallengeState();
}

class _SwipeFactChallengeState extends State<SwipeFactChallenge> {
  double _drag = 0;

  /// ما بعده يُحسب سحباً لا اهتزازَ إصبع.
  static const _threshold = 70.0;

  void _settle() {
    if (widget.picked != null) return;
    if (_drag.abs() < _threshold) {
      setState(() => _drag = 0);
      return;
    }
    // يمينٌ «صحيحة» في العربية كما في الإنجليزية: البطاقةُ تُدفع إلى جهة
    // القبول، والاتّجاهُ لا يُعكس مع اللغة — فالإيماءةُ مألوفةٌ من تطبيقاتٍ
    // أخرى، وعكسُها يُخطئ من يعرفها.
    widget.onPick(_drag > 0 ? 0 : 1);
    setState(() => _drag = 0);
    HapticFeedback.mediumImpact();
  }

  @override
  Widget build(BuildContext context) {
    final answered = widget.picked != null;
    final right = answered && widget.situation.isCorrect(widget.picked!);
    final tint = _drag > 20
        ? const Color(0xFF16A34A)
        : _drag < -20
            ? const Color(0xFFDC2626)
            : const Color(0xFF7C3AED);
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('🔴 ${tr('study.swipeWrong')}',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFFDC2626),
                )),
            Text('${tr('study.swipeRight')} 🟢',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF16A34A),
                )),
          ],
        ),
        const SizedBox(height: 10),
        GestureDetector(
          onHorizontalDragUpdate: answered
              ? null
              : (details) => setState(() => _drag += details.delta.dx),
          onHorizontalDragEnd: answered ? null : (_) => _settle(),
          child: AnimatedContainer(
            duration: Duration(milliseconds: _drag == 0 ? 220 : 0),
            curve: Curves.easeOut,
            transform: Matrix4.translationValues(_drag, 0, 0)
              ..rotateZ(_drag / 1400),
            transformAlignment: Alignment.center,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              color: StudentSurface.card(context),
              border: Border.all(color: tint, width: 1.8),
              boxShadow: [
                BoxShadow(
                  color: tint.withValues(alpha: 0.22),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              children: [
                const Text('🦁', style: TextStyle(fontSize: 26)),
                const SizedBox(height: 8),
                Text(
                  widget.situation.prompt,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 15.5,
                    height: 1.6,
                    fontWeight: FontWeight.w800,
                    color: StudentSurface.ink(context),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        // البديلُ الملموس عن الإيماءة.
        if (!answered)
          Row(
            children: [
              Expanded(
                child: _SwipeButton(
                  label: '🔴 ${tr('study.swipeWrong')}',
                  tint: const Color(0xFFDC2626),
                  onTap: () {
                    HapticFeedback.mediumImpact();
                    widget.onPick(1);
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _SwipeButton(
                  label: '🟢 ${tr('study.swipeRight')}',
                  tint: const Color(0xFF16A34A),
                  onTap: () {
                    HapticFeedback.mediumImpact();
                    widget.onPick(0);
                  },
                ),
              ),
            ],
          ),
        const SizedBox(height: 12),
        StudyAvatar(
          appearance: widget.appearance,
          mood: !answered
              ? StudyMood.asking
              : right
                  ? StudyMood.right
                  : StudyMood.wrong,
          size: 80,
        ),
      ],
    );
  }
}

class _SwipeButton extends StatelessWidget {
  const _SwipeButton({
    required this.label,
    required this.tint,
    required this.onTap,
  });

  final String label;
  final Color tint;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material
        (
      color: tint.withValues(alpha: 0.10),
      borderRadius: BorderRadius.circular(14),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: tint, width: 1.4),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w900,
              color: tint,
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// ٣ ── رادارُ المحقّق: ثلاثُ فقاعاتٍ إحداها متسلّلة
// ─────────────────────────────────────────────────────────────────────

/// ── لماذا فقاعاتٌ تُفرقَع ──
/// السؤالُ «أيُّها خطأ؟» يقلب عملَ الطفل: يقرأ الثلاثَ ويقيسها بالدرس بدل
/// أن يبحث عن الصحيح ويتوقّف. والفرقعةُ تجعل الحكمَ فعلاً له أثرٌ يُرى.
class SpotImposterChallenge extends StatelessWidget {
  const SpotImposterChallenge({
    required this.situation,
    required this.appearance,
    required this.picked,
    required this.onPick,
    super.key,
  });

  final StudySituation situation;
  final Map<String, dynamic>? appearance;
  final int? picked;
  final ValueChanged<int> onPick;

  @override
  Widget build(BuildContext context) {
    final answered = picked != null;
    final right = answered && situation.isCorrect(picked!);
    return Column(
      children: [
        Text(
          situation.prompt,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 15.5,
            height: 1.6,
            fontWeight: FontWeight.w800,
            color: StudentSurface.ink(context),
          ),
        ),
        const SizedBox(height: 14),
        StudyAvatar(
          appearance: appearance,
          mood: !answered
              ? StudyMood.asking
              : right
                  ? StudyMood.right
                  : StudyMood.wrong,
          size: 78,
        ),
        const SizedBox(height: 14),
        for (var index = 0; index < situation.options.length; index += 1)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _Bubble(
              text: situation.options[index],
              // المفرقَعةُ هي المتسلّلة بعد الكشف، وتبقى الصحيحتان.
              popped: answered && index == situation.answer,
              // وما ضغطه الطفلُ خطأً يُعلَّم دون أن يُفرقَع.
              missed: answered && index == picked && !right,
              onTap: answered ? null : () {
                HapticFeedback.selectionClick();
                onPick(index);
              },
            ),
          ),
      ],
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({
    required this.text,
    required this.popped,
    required this.missed,
    required this.onTap,
  });

  final String text;
  final bool popped;
  final bool missed;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final tint = popped
        ? const Color(0xFF16A34A)
        : missed
            ? const Color(0xFFDC2626)
            : const Color(0xFF0B8693);
    return AnimatedOpacity(
      // المتسلّلةُ تخبو بعد فرقعتها: أثرٌ يُرى للحكم.
      opacity: popped ? 0.45 : 1,
      duration: const Duration(milliseconds: 260),
      child: Material(
        color: tint.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: tint, width: 1.5),
            ),
            child: Row(
              children: [
                Text(
                  popped ? '💥' : (missed ? '❌' : '🫧'),
                  style: const TextStyle(fontSize: 18),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    text,
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.45,
                      fontWeight: FontWeight.w800,
                      decoration: popped ? TextDecoration.lineThrough : null,
                      color: StudentSurface.ink(context),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
