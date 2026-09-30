import 'dart:async';

import 'package:flutter/material.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';

import '../l10n/student_strings.dart';

/// أدواتُ التحكّم التي يراها الطالب فوق فيديو الدرس، وهي كلُّ ما يراه.
///
/// ── زرّان ورجوع، ولا شيء غيرها ──
/// تشغيلٌ وإيقافٌ مؤقّت، وتكبيرٌ وتصغير، وزرُّ رجوعٍ في الأعلى. ولا شريطَ
/// وقتٍ ولا عدّاد: المقطعُ شرحُ درسٍ يُشاهَد من أوّله، وشريطٌ تحت إصبع
/// طفلٍ يُسحب بلا قصدٍ فيضيع موضعُه من الشرح.
///
/// ── ولماذا واجهةٌ من عندنا ──
/// أدواتُ يوتيوب تعيش داخل الصفحة المضمَّنة، ومعها فيها ما ليس من الدرس:
/// شعارٌ يفتح الموقع، وعنوانٌ يفتح صفحة المقطع، وترسُ إعداداتٍ وقائمةُ
/// مشاركة، وشاشةُ نهايةٍ تعرض مقاطعَ مقترحة. وكلُّها لا تمرّ بشيفرتنا،
/// فلا تُمنع بعد وقوعها.
///
/// فأُقفلت الصفحةُ عن اللمس بـ`PointerEvents.none` في مُعامِلات المشغّل،
/// ورُسمت الأدواتُ هنا. والقفلُ في الصفحة لا في فلاتر: لا ودجتَ يفرش
/// نفسه على الصورة، فلا شيء يبتلع لمسةً يقصدها الطفل.
///
/// ── وشريطٌ سفليٌّ دائمُ الظهور ──
/// كانت الأدواتُ تختفي بعد ثلاث ثوانٍ وتظهر بلمسةٍ على الصورة، واللمسةُ
/// تُلتقط بـ`GestureDetector` مفروشٍ على الفيديو كلِّه. فكان على الصورة
/// حاجبٌ ثانٍ يبتلع كلَّ لمسة، والطفل يضغط فلا يرى أثراً.
///
/// وهي الآن ظاهرةٌ دائماً: زرّان في شريطٍ لا يزيد على ارتفاعه، وما فوقه
/// من الصورة خالٍ من كل ودجتٍ يستقبل لمسة. وطفلٌ في الابتدائية يحتاج أن
/// يرى الزرَّ لا أن يعرف كيف يُظهره.
class YoutubeKioskControls extends StatefulWidget {
  const YoutubeKioskControls({
    required this.controller,
    required this.isFullscreen,
    required this.onExit,
    super.key,
  });

  final YoutubePlayerController controller;

  /// يُغيّر ما يفعله زرُّ ملء الشاشة وأيَّ أيقونةٍ يحمل.
  final bool isFullscreen;

  /// الخروج: من ملء الشاشة إن كان فيها، ومن الشاشة نفسها إن لم يكن.
  final VoidCallback onExit;

  @override
  State<YoutubeKioskControls> createState() => _YoutubeKioskControlsState();
}

class _YoutubeKioskControlsState extends State<YoutubeKioskControls> {
  StreamSubscription<YoutubePlayerValue>? _valueSub;
  PlayerState _playerState = PlayerState.unknown;

  @override
  void initState() {
    super.initState();
    _valueSub = widget.controller.stream.listen((value) {
      if (!mounted || value.playerState == _playerState) return;
      setState(() => _playerState = value.playerState);
    });
  }

  @override
  void dispose() {
    _valueSub?.cancel();
    super.dispose();
  }

  Future<void> _togglePlay() async {
    if (_playerState == PlayerState.playing) {
      await widget.controller.pauseVideo();
      return;
    }
    // والمنتهي يبدأ من أوّله: ضغطةُ «تشغيل» على مقطعٍ انتهى تعني الإعادة،
    // وإلا بدا الزرُّ معطّلاً.
    if (_playerState == PlayerState.ended) {
      await widget.controller.seekTo(seconds: 0, allowSeekAhead: true);
    }
    await widget.controller.playVideo();
  }

  @override
  Widget build(BuildContext context) {
    final playing = _playerState == PlayerState.playing;
    final ended = _playerState == PlayerState.ended;

    // ── و`fit: expand` لازم، وهذا موضعُ عطبٍ كان ──
    //
    // أُزيل الاتّساعُ ظنّاً أنه هو ما يحجب اللمس، فاختفت الأدواتُ كلُّها:
    // هذا الودجت ابنٌ غيرُ موضَّعٍ في `Stack` الفيديو، فيأتيه قيدٌ فضفاض.
    // و`Stack` كلُّ أبنائه موضَّعون يأخذ أصغرَ ما يسمح به قيدُه — صفراً في
    // صفر. فرُسمت الأزرارُ في مساحةٍ لا أبعادَ لها: لا تُرى ولا تُلمس.
    // وهو ما رآه الطالب «مشغّلاً بلا أزرار».
    //
    // والاتّساعُ لا يحجب شيئاً: `Stack` يؤجّل فحصَ اللمس إلى أبنائه، فلا
    // يبتلع لمسةً في موضعٍ لا ابنَ فيه. والذي كان يحجب هو
    // `GestureDetector` المفروشُ على الصورة، وقد أُزيل — ولا يعود.
    return Stack(
      fit: StackFit.expand,
      children: [
        if (ended) Positioned.fill(child: _EndedCover(onReplay: _togglePlay)),

        // ── التشغيلُ في المنتصف ──
        //
        // حيث ينظر الطفل، وحيث يضغط بلا أن يبحث. وكان في زاويةٍ سفلية مع
        // ملءِ الشاشة، فصار الزرّان متجاورين في شريطٍ ضيّق يُخطئ بينهما
        // إصبعٌ صغير.
        //
        // وظاهرٌ في الوضعين: مصغّراً وفي ملء الشاشة. ولا يختفي بعد سكون —
        // طفلٌ في الابتدائية يحتاج أن يرى الزرَّ لا أن يعرف كيف يُظهره.
        if (!ended)
          Center(
            child: _KioskButton(
              icon: playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
              tooltip: tr(playing ? 'video.pause' : 'video.play'),
              onPressed: _togglePlay,
              large: true,
            ),
          ),

        // والرجوعُ في أعلى البداية.
        PositionedDirectional(
          top: 6,
          start: 6,
          child: SafeArea(
            child: _KioskButton(
              icon: Icons.arrow_back_rounded,
              tooltip: tr('video.back'),
              onPressed: widget.onExit,
            ),
          ),
        ),

        // وملءُ الشاشة في الزاوية السفلية، بعيداً عن زرّ التشغيل.
        //
        // وهو ظاهرٌ في الوضع المصغّر بلا سحبٍ ولا لمسةِ إظهار: كان يلزم
        // لظهوره أن تُلمَس الصورة، واللمسةُ لا تصل أصلاً حين يبتلعها عرضُ
        // المنصّة.
        PositionedDirectional(
          bottom: 6,
          end: 6,
          child: SafeArea(
            top: false,
            child: _KioskButton(
              icon: widget.isFullscreen
                  ? Icons.fullscreen_exit_rounded
                  : Icons.fullscreen_rounded,
              tooltip: tr(
                widget.isFullscreen ? 'video.shrink' : 'video.fullscreen',
              ),
              onPressed: () => widget.controller.toggleFullScreen(),
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
///
/// وهي الطبقةُ الوحيدة التي تفرش نفسها على الصورة، ولحالٍ واحدة: انتهاءُ
/// المقطع. وفيها زرٌّ يخرج منها.
class _EndedCover extends StatelessWidget {
  const _EndedCover({required this.onReplay});

  final VoidCallback onReplay;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
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
    // ٤٨ لا ٤٠: هذا أدنى ما توصي به إرشاداتُ اللمس، وإصبعُ طفلٍ في
    // الابتدائية أعرضُ من إصبع بالغ لا أدقّ.
    final size = large ? 68.0 : 48.0;
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.black.withValues(alpha: 0.52),
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          customBorder: const CircleBorder(),
          child: SizedBox(
            width: size,
            height: size,
            child: Icon(icon, color: Colors.white, size: large ? 36 : 26),
          ),
        ),
      ),
    );
  }
}
