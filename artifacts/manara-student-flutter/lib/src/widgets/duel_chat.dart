
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/student_strings.dart';
import '../models/duel_chat.dart';
import '../services/student_settings.dart';
import '../theme/student_theme.dart';
import 'student_avatar_view.dart';

/// فقاعةُ كلامٍ كرتونيةٌ فوق الشخصية، تظهر ثلاثَ ثوانٍ ثم تتلاشى.
///
/// ── ولماذا فوق الشخصية لا في قائمةِ محادثة ──
/// قائمةٌ تُقرأ تحتاج أن يترك الطفلُ السؤالَ وينظر إليها، وهو في مباراةٍ
/// بالثواني. والفقاعةُ تُرى بطرف العين ثم تذهب، فلا تُزاحم اللعبة.
///
/// ── وثلاثُ ثوانٍ لا أقلّ ولا أكثر ──
/// أقلُّ من ذلك يُفوّتها على من كان ينظر إلى خياراته، وأكثرُ يجعل فقاعتين
/// تتراكبان حين يُرسل الخصمُ رسالتين.
const duelBubbleLife = Duration(seconds: 3);

class DuelSpeechBubble extends StatelessWidget {
  const DuelSpeechBubble({
    required this.message,
    required this.appearance,
    required this.mine,
    required this.speaking,
    super.key,
  });

  /// الرسالةُ المعروضة، أو `null` فلا يُرسم شيء.
  final DuelChatMessage? message;
  final Map<String, dynamic>? appearance;

  /// أرسلتُها أنا؟ يُغيّر لونَ الفقاعة وجهةَ ذيلها.
  final bool mine;

  /// أيُشغَّل مقطعُها الآن؟ فتنبض أيقونةُ السماعة.
  final bool speaking;

  @override
  Widget build(BuildContext context) {
    final live = message;
    // ── والمساحةُ محفوظةٌ حاضرةً وغائبة ──
    // لو انكمش هذا عند غياب الرسالة لتحرّكت الحلبةُ تحته كلَّما وصلت رسالة،
    // فينتقل زرٌّ تحت إصبع الطفل لحظةَ ضغطه.
    return SizedBox(
      height: 92,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 280),
        opacity: live == null ? 0 : 1,
        child: live == null
            ? const SizedBox.shrink()
            : Column(
                mainAxisAlignment: MainAxisAlignment.end,
                crossAxisAlignment:
                    mine ? CrossAxisAlignment.start : CrossAxisAlignment.end,
                children: [
                  _Bubble(
                    message: live,
                    mine: mine,
                    speaking: speaking,
                  ),
                  const SizedBox(height: 2),
                  StudentAvatarView(
                    size: 34,
                    appearance: appearance,
                    showRing: false,
                  ),
                ],
              ),
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({
    required this.message,
    required this.mine,
    required this.speaking,
  });

  final DuelChatMessage message;
  final bool mine;
  final bool speaking;

  @override
  Widget build(BuildContext context) {
    final fill = mine ? const Color(0xFFDCFCE7) : const Color(0xFFEDE9FE);
    final ink = mine ? const Color(0xFF14532D) : const Color(0xFF3B2A6B);
    return Container(
      constraints: const BoxConstraints(maxWidth: 190),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(16),
          topRight: const Radius.circular(16),
          // الزاويةُ الحادّةُ ذيلُ الفقاعة: تشير إلى صاحبها.
          bottomLeft: Radius.circular(mine ? 4 : 16),
          bottomRight: Radius.circular(mine ? 16 : 4),
        ),
        boxShadow: const [
          BoxShadow(color: Color(0x22000000), blurRadius: 6, offset: Offset(0, 2)),
        ],
      ),
      child: message.isVoice
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _PulsingSpeaker(active: speaking, ink: ink),
                const SizedBox(width: 8),
                // ── و`Flexible` لا `Text` مكشوف ──
                // السماعةُ تنبض فيكبر عرضُها، والسطرُ يطول بالترجمة. فمجموعُهما
                // يتجاوز عرضَ الفقاعة فيفيض الصفُّ — والفيضُ شريطٌ أصفرٌ على
                // شاشة طفل، لا خطأٌ في سجلّ.
                Flexible(
                  child: Text(
                    tr('duel.chat.voiceNote'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      color: ink,
                    ),
                  ),
                ),
              ],
            )
          : Text(
              message.text,
              style: TextStyle(
                fontSize: 14,
                height: 1.4,
                fontWeight: FontWeight.w900,
                color: ink,
              ),
            ),
    );
  }
}

/// أيقونةُ سماعةٍ تنبض ما دام المقطعُ يُشغَّل.
class _PulsingSpeaker extends StatefulWidget {
  const _PulsingSpeaker({required this.active, required this.ink});

  final bool active;
  final Color ink;

  @override
  State<_PulsingSpeaker> createState() => _PulsingSpeakerState();
}

class _PulsingSpeakerState extends State<_PulsingSpeaker>
    with SingleTickerProviderStateMixin {
  late final AnimationController _beat = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 620),
  );

  @override
  void initState() {
    super.initState();
    if (widget.active) _beat.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(covariant _PulsingSpeaker old) {
    super.didUpdateWidget(old);
    if (widget.active == old.active) return;
    // ويتوقّف عند السكون على حجمه الطبيعي: نبضةٌ جمدت في منتصفها تبدو عطباً.
    if (widget.active) {
      _beat.repeat(reverse: true);
    } else {
      _beat.animateTo(0, duration: const Duration(milliseconds: 160));
    }
  }

  @override
  void dispose() {
    _beat.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: Tween<double>(begin: 1, end: 1.28).animate(
        CurvedAnimation(parent: _beat, curve: Curves.easeInOut),
      ),
      child: Icon(Icons.volume_up_rounded, size: 19, color: widget.ink),
    );
  }
}

/// الزرُّ العائم الذي يفتح الدردشة.
///
/// ── وموضعُه الزاويةُ السفلية في جهة النهاية ──
/// السؤالُ في أعلى البطاقة والخياراتُ تحته، وزرٌّ فوقهما يغطّي ما يُقرأ أو ما
/// يُضغط. وهذه الزاويةُ آخرُ ما يقع عليه الإصبعُ في قراءةٍ من اليمين.
class DuelChatButton extends StatelessWidget {
  const DuelChatButton({required this.onPressed, this.unread = false, super.key});

  final VoidCallback onPressed;

  /// نقطةٌ تقول إن وصلت رسالةٌ وهو مغلق.
  final bool unread;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Material(
          color: const Color(0xFF7C3AED),
          shape: const CircleBorder(),
          elevation: 3,
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onPressed,
            child: SizedBox(
              width: 48,
              height: 48,
              child: Tooltip(
                message: tr('duel.chat.open'),
                child: const Icon(
                  Icons.chat_bubble_rounded,
                  color: Colors.white,
                  size: 22,
                ),
              ),
            ),
          ),
        ),
        if (unread)
          Positioned(
            top: 2,
            right: 2,
            child: Container(
              width: 11,
              height: 11,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFF59E0B),
                border: Border.all(color: Colors.white, width: 1.6),
              ),
            ),
          ),
      ],
    );
  }
}

/// نافذةُ الدردشة: نصٌّ قصير، وإيموجي، وعباراتٌ سريعة، وزرُّ تسجيل.
class DuelChatSheet extends StatefulWidget {
  const DuelChatSheet({
    required this.onSendText,
    required this.onHoldStart,
    required this.onHoldEnd,
    required this.recording,
    required this.cooldownLeft,
    super.key,
  });

  /// يُرسل نصّاً أو إيموجي. يعود بـ`false` إن مُنع — فاصلٌ أو قناةٌ ساقطة.
  final bool Function(String text) onSendText;

  /// بدايةُ الضغط المطوّل على الميكروفون ونهايتُه.
  final VoidCallback onHoldStart;
  final void Function({required bool cancelled}) onHoldEnd;

  /// أيسجّل الآن؟ يأتي من فوق لأنّ المسجّل قد يتوقّف وحده عند انتهاء المدّة.
  final ValueListenable<bool> recording;

  /// ما بقي من المنع، لتُعرض حالُ الزرّ.
  final ValueListenable<Duration> cooldownLeft;

  @override
  State<DuelChatSheet> createState() => _DuelChatSheetState();
}

class _DuelChatSheetState extends State<DuelChatSheet> {
  final _field = TextEditingController();

  @override
  void dispose() {
    _field.dispose();
    super.dispose();
  }

  void _send(String text) {
    final clean = sanitizeChatText(text);
    if (clean.isEmpty) return;
    if (widget.onSendText(clean)) _field.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: StudentSettings.direction,
      child: Padding(
        // ولوحةُ المفاتيح ترفع النافذة: حقلٌ تحتها لا يُرى ما يُكتب فيه.
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 18),
          decoration: BoxDecoration(
            color: StudentSurface.card(context),
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    color:
                        StudentSurface.mutedInk(context).withValues(alpha: 0.3),
                  ),
                ),
              ),
              _QuickRow(onPick: _send),
              const SizedBox(height: 10),
              _EmojiRow(onPick: _send),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _field,
                      maxLength: duelChatMaxChars,
                      textInputAction: TextInputAction.send,
                      onSubmitted: _send,
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800,
                        color: StudentSurface.ink(context),
                      ),
                      decoration: InputDecoration(
                        hintText: tr('duel.chat.hint'),
                        counterText: '',
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  _SendButton(onTap: () => _send(_field.text)),
                ],
              ),
              const SizedBox(height: 12),
              _HoldToRecord(
                recording: widget.recording,
                onHoldStart: widget.onHoldStart,
                onHoldEnd: widget.onHoldEnd,
              ),
              const SizedBox(height: 8),
              // سطرُ الفاصل: الطفلُ يضغط فلا يُرسل، ولا يعرف لماذا.
              ValueListenableBuilder<Duration>(
                valueListenable: widget.cooldownLeft,
                builder: (context, left, _) => Text(
                  left == Duration.zero
                      ? tr('duel.chat.footer')
                      : trf('duel.chat.wait', {
                          'seconds': '${left.inMilliseconds ~/ 1000 + 1}',
                        }),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 11.5,
                    height: 1.5,
                    fontWeight: FontWeight.w800,
                    color: left == Duration.zero
                        ? StudentSurface.mutedInk(context)
                        : const Color(0xFFB45309),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuickRow extends StatelessWidget {
  const _QuickRow({required this.onPick});

  final ValueChanged<String> onPick;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final key in duelQuickPhraseKeys)
            Padding(
              padding: const EdgeInsetsDirectional.only(end: 8),
              child: ActionChip(
                label: Text(tr(key)),
                labelStyle: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF3B2A6B),
                ),
                backgroundColor: const Color(0xFFEDE9FE),
                side: BorderSide(
                  color: const Color(0xFF7C3AED).withValues(alpha: 0.25),
                ),
                onPressed: () => onPick(tr(key)),
              ),
            ),
        ],
      ),
    );
  }
}

class _EmojiRow extends StatelessWidget {
  const _EmojiRow({required this.onPick});

  final ValueChanged<String> onPick;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        for (final emoji in duelEmojis)
          Material(
            color: const Color(0xFFF5F3FF),
            shape: const CircleBorder(),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () => onPick(emoji),
              child: SizedBox(
                // ٤٤ لا أقلّ: إصبعُ طفلٍ على إيموجي بحجم الحرف يُخطئ جارَه.
                width: 44,
                height: 44,
                child: Center(
                  child: Text(emoji, style: const TextStyle(fontSize: 21)),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _SendButton extends StatelessWidget {
  const _SendButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF7C3AED),
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          width: 46,
          height: 46,
          child: Tooltip(
            message: tr('duel.chat.send'),
            child: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
          ),
        ),
      ),
    );
  }
}

/// زرُّ الميكروفون: يُسجّل ما دام الإصبعُ عليه.
///
/// ── والإفلاتُ يُرسل، والسحبُ خارجَه يُلغي ──
/// طفلٌ بدأ التسجيل ثم غيّر رأيه يحتاج مخرجاً لا يُرسل. وهو في كل تطبيقِ
/// رسائلَ يعرفه: يسحب إصبعَه بعيداً.
class _HoldToRecord extends StatelessWidget {
  const _HoldToRecord({
    required this.recording,
    required this.onHoldStart,
    required this.onHoldEnd,
  });

  final ValueListenable<bool> recording;
  final VoidCallback onHoldStart;
  final void Function({required bool cancelled}) onHoldEnd;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: recording,
      builder: (context, live, _) {
        return Listener(
          onPointerDown: (_) {
            HapticFeedback.mediumImpact();
            onHoldStart();
          },
          onPointerUp: (_) => onHoldEnd(cancelled: false),
          onPointerCancel: (_) => onHoldEnd(cancelled: true),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(vertical: 13),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              color: live
                  ? const Color(0xFFDC2626).withValues(alpha: 0.12)
                  : const Color(0xFF7C3AED).withValues(alpha: 0.08),
              border: Border.all(
                color: live
                    ? const Color(0xFFDC2626)
                    : const Color(0xFF7C3AED).withValues(alpha: 0.3),
                width: 1.5,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  live ? Icons.fiber_manual_record_rounded : Icons.mic_rounded,
                  size: 20,
                  color: live
                      ? const Color(0xFFDC2626)
                      : const Color(0xFF7C3AED),
                ),
                const SizedBox(width: 8),
                Text(
                  tr(live ? 'duel.chat.recording' : 'duel.chat.hold'),
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w900,
                    color: live
                        ? const Color(0xFF991B1B)
                        : StudentSurface.ink(context),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
