import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/student_strings.dart';
import '../models/duel_chat.dart';
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
          BoxShadow(
              color: Color(0x22000000), blurRadius: 6, offset: Offset(0, 2)),
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

/// زرُّ كتم الدردشة: محادثةٌ مفتوحة، أو مكتومة.
///
/// ── ولماذا زرٌّ مستقلٌّ لا وظيفةٌ ثانيةٌ في زرّ الدردشة ──
/// زرٌّ واحدٌ يفتح ويكتم يُضغط خطأً في مباراةٍ بالثواني، فيُكتم الطفلُ الدردشةَ
/// وهو يريد أن يقرأ رسالةً. وهذا أصغرُ منه وفوقه، وأثرُه ظاهرٌ في لونه
/// وأيقونته.
class DuelMuteToggle extends StatelessWidget {
  const DuelMuteToggle({
    required this.muted,
    required this.onPressed,
    super.key,
  });

  final bool muted;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: muted ? const Color(0xFFDC2626) : Colors.white,
      shape: const CircleBorder(),
      elevation: 2,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onPressed,
        child: SizedBox(
          // ٤٠ لا أقلّ: أصغرُ من زرّ الدردشة ليُقرأ تابعاً له، ولا يصغر عن
          // مساحةِ لمسٍ يبلغها إصبعُ طفل.
          width: 40,
          height: 40,
          child: Tooltip(
            message: tr(muted ? 'duel.chat.unmute' : 'duel.chat.mute'),
            child: Icon(
              muted
                  ? Icons.notifications_off_rounded
                  : Icons.notifications_active_rounded,
              size: 19,
              color: muted ? Colors.white : const Color(0xFF7C3AED),
            ),
          ),
        ),
      ),
    );
  }
}

/// زرُّ الرسالة الصوتية تحت الخيارات: يُسجّل ما دام الإصبعُ عليه، ويُرسل حين يُرفع.
///
/// ── والسحبُ خارجَه يُلغي ──
/// طفلٌ بدأ التسجيل ثم غيّر رأيه يحتاج مخرجاً لا يُرسل: يسحب إصبعَه بعيداً.
class DuelVoiceButton extends StatelessWidget {
  const DuelVoiceButton({
    required this.recording,
    required this.onHoldStart,
    required this.onHoldEnd,
    super.key,
  });

  final ValueListenable<bool> recording;
  final VoidCallback onHoldStart;
  final void Function({required bool cancelled}) onHoldEnd;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: recording,
      builder: (context, live, _) {
        return Semantics(
          button: true,
          label: tr('duel.voice.hold'),
          child: Listener(
            onPointerDown: (_) {
              HapticFeedback.mediumImpact();
              onHoldStart();
            },
            onPointerUp: (_) => onHoldEnd(cancelled: false),
            onPointerCancel: (_) => onHoldEnd(cancelled: true),
            child: AnimatedScale(
              scale: live ? 1.04 : 1,
              duration: const Duration(milliseconds: 180),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                height: 52,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(26),
                  gradient: LinearGradient(
                    colors: live
                        ? const [Color(0xFFEF4444), Color(0xFFB91C1C)]
                        : const [Color(0xFF8B5CF6), Color(0xFF6D28D9)],
                  ),
                  border: Border.all(
                      color: Colors.white.withValues(alpha: 0.7), width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: (live
                              ? const Color(0xFFEF4444)
                              : const Color(0xFF7C3AED))
                          .withValues(alpha: 0.45),
                      blurRadius: live ? 18 : 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      live
                          ? Icons.fiber_manual_record_rounded
                          : Icons.mic_rounded,
                      color: Colors.white,
                      size: 22,
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        tr(live ? 'duel.voice.recording' : 'duel.voice.hold'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// شريطُ التفاعلات السريعة: ضغطةٌ واحدة، فيطير الرمزُ على شاشات الجميع.
class DuelReactionBar extends StatelessWidget {
  const DuelReactionBar({required this.onReact, super.key});

  final ValueChanged<String> onReact;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: StudentSurface.card(context).withValues(alpha: 0.92),
        border: Border.all(color: const Color(0xFFA78BFA), width: 1.4),
        boxShadow: const [
          BoxShadow(
              color: Color(0x33000000), blurRadius: 14, offset: Offset(0, 5)),
        ],
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final emoji in duelReactions)
              _ReactionKey(emoji: emoji, onTap: () => onReact(emoji)),
          ],
        ),
      ),
    );
  }
}

class _ReactionKey extends StatefulWidget {
  const _ReactionKey({required this.emoji, required this.onTap});

  final String emoji;
  final VoidCallback onTap;

  @override
  State<_ReactionKey> createState() => _ReactionKeyState();
}

class _ReactionKeyState extends State<_ReactionKey> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: widget.emoji,
      child: GestureDetector(
        onTapDown: (_) => setState(() => _down = true),
        onTapCancel: () => setState(() => _down = false),
        onTapUp: (_) => setState(() => _down = false),
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _down ? 1.35 : 1,
          duration: const Duration(milliseconds: 120),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            child: Text(widget.emoji, style: const TextStyle(fontSize: 28)),
          ),
        ),
      ),
    );
  }
}

/// ما يطير الآن: رمزٌ، ومن أرسله، وهل هو أنا.
class DuelReactionPop {
  DuelReactionPop(this.emoji, this.who, this.mine) : id = _next++;
  static int _next = 0;

  final int id;
  final String emoji;
  final String who;
  final bool mine;
}

/// يُطلق التفاعلاتِ الطائرة. تلبسه طبقةُ [DuelReactionLayer].
class DuelReactionController extends ChangeNotifier {
  final List<DuelReactionPop> _pops = [];
  List<DuelReactionPop> get pops => List.unmodifiable(_pops);

  /// أقصى ما يطير معاً: ضغطٌ متتابعٌ لا يملأ الشاشة.
  static const _max = 12;

  void pop(String emoji, {String who = '', bool mine = false}) {
    _pops.add(DuelReactionPop(emoji, who, mine));
    if (_pops.length > _max) _pops.removeAt(0);
    notifyListeners();
  }

  void _done(DuelReactionPop pop) {
    _pops.remove(pop);
    notifyListeners();
  }
}

/// الطبقةُ التي تطير فيها التفاعلات: من أسفل الشاشة صعوداً، تكبر ثم تتلاشى.
/// لا تلتقط لمسةً: ما تحتها يُضغط كما هو.
class DuelReactionLayer extends StatelessWidget {
  const DuelReactionLayer({required this.controller, super.key});

  final DuelReactionController controller;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: ListenableBuilder(
        listenable: controller,
        builder: (context, _) => LayoutBuilder(
          builder: (context, constraints) => Stack(
            children: [
              for (final pop in controller.pops)
                _FloatingReaction(
                  key: ValueKey(pop.id),
                  pop: pop,
                  area: constraints.biggest,
                  onDone: () => controller._done(pop),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FloatingReaction extends StatefulWidget {
  const _FloatingReaction({
    required this.pop,
    required this.area,
    required this.onDone,
    super.key,
  });

  final DuelReactionPop pop;
  final Size area;
  final VoidCallback onDone;

  @override
  State<_FloatingReaction> createState() => _FloatingReactionState();
}

class _FloatingReactionState extends State<_FloatingReaction>
    with SingleTickerProviderStateMixin {
  late final AnimationController _flight = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1900),
  )..forward().whenComplete(widget.onDone);

  /// موضعٌ أفقيٌّ يختلف من رمزٍ لآخر: تطير متفرّقةً لا فوق بعضها.
  late final double _x = 0.15 + ((widget.pop.id * 37) % 70) / 100;
  late final double _drift = ((widget.pop.id * 53) % 21 - 10) / 100;

  @override
  void dispose() {
    _flight.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _flight,
      builder: (context, child) {
        final t = _flight.value;
        final rise = Curves.easeOutCubic.transform(t);
        final scale = t < 0.18
            ? Curves.easeOutBack.transform(t / 0.18) * 1.15
            : 1.15 - (t - 0.18) * 0.25;
        final opacity = t > 0.7 ? (1 - (t - 0.7) / 0.3).clamp(0.0, 1.0) : 1.0;
        final left = (widget.area.width * (_x + _drift * rise)) - 30;
        final bottom = 90 + rise * widget.area.height * 0.55;
        return Positioned(
          left: left,
          bottom: bottom,
          child: Opacity(
            opacity: opacity,
            child: Transform.scale(scale: scale, child: child),
          ),
        );
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            widget.pop.emoji,
            style: const TextStyle(
              fontSize: 46,
              shadows: [Shadow(color: Color(0x66000000), blurRadius: 10)],
            ),
          ),
          if (widget.pop.who.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: widget.pop.mine
                    ? const Color(0xCC16A34A)
                    : const Color(0xCC6D28D9),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                widget.pop.who,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
