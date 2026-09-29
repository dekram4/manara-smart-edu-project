import 'dart:async';

import 'package:flutter/material.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';

import '../l10n/student_strings.dart';

/// أدواتُ التحكّم التي يراها الطالب فوق فيديو الدرس، وهي كلُّ ما يراه.
///
/// ── لماذا واجهةٌ من عندنا ──
/// أدواتُ يوتيوب تعيش داخل الصفحة المضمَّنة، ومعها فيها ما ليس من الدرس:
/// شعارٌ يفتح الموقع، وعنوانٌ يفتح صفحة المقطع، وترسُ إعداداتٍ وقائمةُ
/// مشاركة، وشاشةُ نهايةٍ تعرض مقاطعَ مقترحةً بضغطةٍ واحدة. وكلُّها لا
/// تمرّ بشيفرتنا، فلا تُمنع بعد وقوعها.
///
/// فأُقفلت الصفحةُ عن اللمس كلِّه — `PointerEvents.none` — ورُسمت الأدوات
/// هنا. وما لا يُرسَم هنا لا سبيل إليه.
///
/// ── وثلاثةٌ لا خمسة ──
/// تشغيلٌ وإيقاف، وملءُ شاشةٍ وخروجٌ منها، ورجوع. ولا شريطَ وقتٍ ولا
/// عدّاد: المقطعُ شرحُ درسٍ يُشاهَد من أوّله، لا فيلماً يُبحث في مواضعه.
/// وشريطٌ تحت إصبع طفلٍ في الابتدائية يُسحب بلا قصدٍ فيضيع موضعُه من
/// الشرح ولا يعرف كيف يعود — وهي الشكوى التي جاءت. فما لا يُحتاج لا
/// يُعرَض.
///
/// ── والحدودُ مقولةٌ صراحةً ──
/// هذا يمنع الخروجَ باللمس، لا يمنع يوتيوب من رسم ما يرسمه. وشاشةُ
/// النهاية تُغطّى بطبقةٍ من عندنا حين ينتهي المقطع — انظر [_EndedCover] —
/// فلا تُرى المقترحاتُ ولا تُلمَس. وهذا أقربُ ما يُنال بإطارٍ مضمَّن:
/// المنعُ التامّ يحتاج ألّا يكون المقطعُ على يوتيوب أصلاً.
class YoutubeKioskControls extends StatefulWidget {
  const YoutubeKioskControls({
    required this.controller,
    required this.isFullscreen,
    required this.onExit,
    super.key,
  });

  final YoutubePlayerController controller;

  /// يُغيّر ما يفعله زرُّ ملء الشاشة وما يُظهره زرُّ الخروج.
  final bool isFullscreen;

  /// الخروج: من ملء الشاشة إن كان فيها، ومن الشاشة نفسها إن لم يكن.
  final VoidCallback onExit;

  @override
  State<YoutubeKioskControls> createState() => _YoutubeKioskControlsState();
}

class _YoutubeKioskControlsState extends State<YoutubeKioskControls> {
  StreamSubscription<YoutubePlayerValue>? _valueSub;

  PlayerState _playerState = PlayerState.unknown;

  /// الأدواتُ تختفي بعد سكون، فلا تحجب الشرح.
  bool _visible = true;
  Timer? _hideTimer;

  static const _hideAfter = Duration(seconds: 3);

  @override
  void initState() {
    super.initState();
    // حالُ المشغّل وحدها. ولا يُشترك في `videoStateStream`: كان يُقرأ منه
    // الموضعُ للشريط عشر مرّاتٍ في الثانية، ولا شريطَ الآن — واشتراكٌ
    // يُعيد البناء بلا شيء يتغيّر في الصورة عملٌ متّصل بلا ثمرة.
    _valueSub = widget.controller.stream.listen((value) {
      if (!mounted || value.playerState == _playerState) return;
      setState(() => _playerState = value.playerState);
      _restartHideTimer();
    });
    _restartHideTimer();
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _valueSub?.cancel();
    super.dispose();
  }

  void _restartHideTimer() {
    _hideTimer?.cancel();
    // ولا تختفي وهو متوقّف: الطفل الذي أوقف المقطع ينظر إلى الأدوات، لا
    // إلى صورةٍ جامدة.
    if (_playerState != PlayerState.playing) return;
    _hideTimer = Timer(_hideAfter, () {
      if (mounted) setState(() => _visible = false);
    });
  }

  void _showControls() {
    setState(() => _visible = true);
    _restartHideTimer();
  }

  void _toggleControls() {
    setState(() => _visible = !_visible);
    if (_visible) _restartHideTimer();
  }

  Future<void> _togglePlay() async {
    if (_playerState == PlayerState.playing) {
      await widget.controller.pauseVideo();
    } else {
      // والمنتهي يبدأ من أوّله: ضغطةُ «تشغيل» على مقطعٍ انتهى تعني
      // الإعادة، وإلا بدا الزرُّ معطّلاً.
      if (_playerState == PlayerState.ended) {
        await widget.controller.seekTo(seconds: 0, allowSeekAhead: true);
      }
      await widget.controller.playVideo();
    }
    _showControls();
  }

  @override
  Widget build(BuildContext context) {
    final playing = _playerState == PlayerState.playing;
    final ended = _playerState == PlayerState.ended;

    return Stack(
      fit: StackFit.expand,
      children: [
        // طبقةُ اللمس: الصفحةُ تحتها لا تستقبل شيئاً، فهذه تلتقط كلَّ
        // لمسةٍ على الفيديو وتجعلها إظهاراً للأدوات أو إخفاءً لها.
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _toggleControls,
          child: const SizedBox.expand(),
        ),
        if (ended) _EndedCover(onReplay: _togglePlay),
        AnimatedOpacity(
          opacity: _visible || ended ? 1 : 0,
          duration: const Duration(milliseconds: 180),
          child: IgnorePointer(
            ignoring: !_visible && !ended,
            child: Stack(
              fit: StackFit.expand,
              children: [
                // تدرّجٌ أسفل الصورة تحت الأدوات: الشريطُ الأبيض فوق
                // مشهدٍ فاتح لا يُقرأ، وهذا يضمن قراءته على كل مقطع.
                const Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  height: 132,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [Color(0xCC000000), Color(0x00000000)],
                      ),
                    ),
                  ),
                ),
                PositionedDirectional(
                  top: 8,
                  start: 8,
                  child: SafeArea(
                    child: _KioskButton(
                      icon: Icons.arrow_back_rounded,
                      tooltip: tr('video.back'),
                      onPressed: widget.onExit,
                    ),
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: SafeArea(
                    top: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(8, 0, 8, 6),
                      // زرّان متباعدان في طرفي الشريط: التشغيل حيث يقع
                      // الإبهام، وملءُ الشاشة في الطرف الآخر فلا يُضغط
                      // أحدُهما مكان الآخر.
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _KioskButton(
                            icon: playing
                                ? Icons.pause_rounded
                                : Icons.play_arrow_rounded,
                            tooltip: tr(playing ? 'video.pause' : 'video.play'),
                            onPressed: _togglePlay,
                          ),
                          _KioskButton(
                            icon: widget.isFullscreen
                                ? Icons.fullscreen_exit_rounded
                                : Icons.fullscreen_rounded,
                            tooltip: tr(
                              widget.isFullscreen
                                  ? 'video.shrink'
                                  : 'video.fullscreen',
                            ),
                            onPressed: () {
                              widget.controller.toggleFullScreen();
                              _showControls();
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

}

/// يغطّي شاشةَ النهاية التي يرسمها يوتيوب.
///
/// المقترحاتُ تظهر داخل الإطار حين ينتهي المقطع. واللمسُ لا يصلها —
/// الإطار مقفل — لكنّها تُرى، وطفلٌ يرى صورةَ رسومٍ متحرّكة فوق درسه
/// يطلبها ممّن بجانبه. فتُغطّى بطبقةٍ معتمة فيها زرُّ إعادة، فيكون آخرُ
/// ما يراه من الدرس دعوةً إلى إعادته.
class _EndedCover extends StatelessWidget {
  const _EndedCover({required this.onReplay});

  final VoidCallback onReplay;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {},
      child: ColoredBox(
        color: const Color(0xF20B1220),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _KioskButton(
                icon: Icons.replay_rounded,
                tooltip: tr('video.replay'),
                onPressed: onReplay,
                large: true,
              ),
              const SizedBox(height: 10),
              Text(
                tr('video.ended'),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// زرٌّ دائريٌّ فوق الصورة: مساحةُ لمسٍ تكفي إصبعَ طفل، وخلفيّةٌ تفصله
/// عن أيّ مشهدٍ تحته.
class _KioskButton extends StatelessWidget {
  const _KioskButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.large = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final bool large;

  @override
  Widget build(BuildContext context) {
    final size = large ? 64.0 : 40.0;
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.black.withValues(alpha: 0.46),
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          child: SizedBox(
            width: size,
            height: size,
            child: Icon(icon, color: Colors.white, size: large ? 34 : 22),
          ),
        ),
      ),
    );
  }
}
