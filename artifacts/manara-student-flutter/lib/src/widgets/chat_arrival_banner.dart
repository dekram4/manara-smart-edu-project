import 'package:flutter/material.dart';

import '../l10n/student_strings.dart';
import '../services/student_chat_inbox.dart';
import '../services/student_settings.dart';

/// تنبيهٌ أعلى الشاشة: وصلت رسالةٌ والطالبُ في مكانٍ آخر من التطبيق.
///
/// ينزل مرّةً (أو يظهر بلا حركة إن طُلب تقليلُها)، ولمسُه يفتح الدردشة، و«×»
/// يغلقه. ويختفي وحده بعد ثوانٍ — والعدّادُ على بطاقة الدردشة يبقى.
class ChatArrivalBanner extends StatefulWidget {
  const ChatArrivalBanner({
    required this.arrival,
    required this.onOpen,
    required this.onClose,
    super.key,
  });

  final ChatArrival arrival;
  final VoidCallback onOpen;
  final VoidCallback onClose;

  /// سطرُ التنبيه الأوّل.
  static String titleOf(ChatArrival arrival) {
    if (arrival.count > 1) {
      return trf('chat.arrival.many', {'n': '${arrival.count}'});
    }
    final name = arrival.name.isEmpty
        ? tr(arrival.fromTeacher ? 'chat.teacher' : 'chat.student')
        : arrival.name;
    return trf('chat.arrival.title', {'name': name});
  }

  /// سطرُه الثاني: نصُّ الرسالة، أو نوعُها.
  static String bodyOf(ChatArrival arrival) {
    switch (arrival.kind) {
      case 'voice':
        return tr('chat.arrival.voice');
      case 'image':
        return tr('chat.arrival.image');
      case 'file':
        return tr('chat.arrival.file');
    }
    final text = arrival.text;
    return text.length > 90 ? '${text.substring(0, 90)}…' : text;
  }

  @override
  State<ChatArrivalBanner> createState() => _ChatArrivalBannerState();
}

class _ChatArrivalBannerState extends State<ChatArrivalBanner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _enter = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 320),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_enter.value == 0 && !_enter.isAnimating) {
      if (MediaQuery.maybeOf(context)?.disableAnimations ?? false) {
        _enter.value = 1;
      } else {
        _enter.forward();
      }
    }
  }

  @override
  void dispose() {
    _enter.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final arrival = widget.arrival;
    final body = ChatArrivalBanner.bodyOf(arrival);
    final slide = CurvedAnimation(parent: _enter, curve: Curves.easeOutBack);
    return Directionality(
      textDirection: StudentSettings.direction,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: AnimatedBuilder(
                animation: slide,
                builder: (context, child) => FractionalTranslation(
                  translation: Offset(0, (slide.value - 1) * 1.4),
                  child: Opacity(opacity: _enter.value.clamp(0.0, 1.0), child: child),
                ),
                child: Semantics(
                  liveRegion: true,
                  button: true,
                  label: '${ChatArrivalBanner.titleOf(arrival)}. $body',
                  child: Material(
                    key: const ValueKey('chat-arrival-banner'),
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(20),
                      onTap: widget.onOpen,
                      child: Ink(
                        padding: const EdgeInsets.fromLTRB(12, 10, 6, 10),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          gradient: const LinearGradient(
                            colors: [Color(0xFF1E3A8A), Color(0xFF2563EB)],
                          ),
                          border: Border.all(color: const Color(0xFFBFDBFE), width: 1.5),
                          boxShadow: const [
                            BoxShadow(color: Color(0x55000000), blurRadius: 18, offset: Offset(0, 8)),
                          ],
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              alignment: Alignment.center,
                              decoration: const BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                              ),
                              child: Text(arrival.fromTeacher ? '👩‍🏫' : '💬',
                                  style: const TextStyle(fontSize: 22)),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    ChatArrivalBanner.titleOf(arrival),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 15,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                  if (body.isNotEmpty && arrival.count <= 1)
                                    Text(
                                      body,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: Color(0xFFDBEAFE),
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 6),
                            FilledButton(
                              key: const ValueKey('chat-arrival-open'),
                              onPressed: widget.onOpen,
                              style: FilledButton.styleFrom(
                                backgroundColor: const Color(0xFFFBBF24),
                                foregroundColor: const Color(0xFF1E293B),
                                padding: const EdgeInsets.symmetric(horizontal: 14),
                                minimumSize: const Size(0, 38),
                              ),
                              child: Text(tr('chat.arrival.open'),
                                  style: const TextStyle(fontWeight: FontWeight.w900)),
                            ),
                            IconButton(
                              key: const ValueKey('chat-arrival-close'),
                              onPressed: widget.onClose,
                              tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
                              icon: const Icon(Icons.close_rounded, color: Colors.white),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
