import 'dart:async';

import 'package:flutter/material.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';

import '../l10n/student_strings.dart';

/// ما تفعله أزرارُ الفيديو، مجرَّداً عن المشغّل الذي تفعله فيه.
///
/// ── لماذا وسيطٌ بين الأزرار والمشغّل ──
/// هذه الأزرارُ أُخطئ فيها أربع مرّات، وكلُّ مرّةٍ كان العطبُ أنها تُرى ولا
/// تعمل — وهو عطبٌ لا يمسكه تحليلٌ ولا بناء، ويحتاج ضغطةَ إصبع. ولم يكن
/// لها اختبارٌ يضغطها لأنها كانت موصولةً بـ`YoutubePlayerController`،
/// وهو لا يُنشأ في اختبارٍ بلا قنوات منصّة ولا عرضِ ويب.
///
/// فصار ما تحتاجه الأزرارُ أربعةَ أفعالٍ ومَجرى حالة. والاختبارُ يمرّر بديلاً
/// يسجّل ما نُودي، فيُسأل: هل بلغت الضغطةُ المشغّل؟ وهو السؤالُ الذي كان
/// جوابُه «لا» أربع مرّات.
abstract class KioskPlayback {
  /// حالُ المشغّل كما تتغيّر، لتتبعها أيقونةُ التشغيل.
  Stream<PlayerState> get states;

  Future<void> play();
  Future<void> pause();

  /// من أوّله: ضغطةُ «تشغيل» على مقطعٍ انتهى تعني الإعادة.
  Future<void> replay();

  void toggleFullscreen();

  /// موضعُ التشغيل وطولُ المقطع كما يتغيّران، ليتبعهما شريطُ الوقت.
  Stream<KioskProgress> get progress;

  /// ينقل التشغيلَ إلى [position] — بالسحب على الشريط أو بأزرار القفز.
  Future<void> seekTo(Duration position);
}

/// موضعُ التشغيل من طول المقطع.
@immutable
class KioskProgress {
  const KioskProgress({required this.position, required this.duration});

  final Duration position;

  /// صفرٌ ما لم يُعرف بعد (قبل أن يُحمَّل المقطع).
  final Duration duration;
}

/// الوسيطُ على مشغّل يوتيوب الحقيقي.
class YoutubeKioskPlayback implements KioskPlayback {
  YoutubeKioskPlayback(this.controller);

  final YoutubePlayerController controller;

  @override
  Stream<PlayerState> get states =>
      controller.stream.map((value) => value.playerState);

  @override
  Future<void> play() => controller.playVideo();

  @override
  Future<void> pause() => controller.pauseVideo();

  @override
  Future<void> replay() async {
    await controller.seekTo(seconds: 0, allowSeekAhead: true);
    await controller.playVideo();
  }

  @override
  void toggleFullscreen() => controller.toggleFullScreen();

  /// طولُ المقطع: من بيانات الفيديو إن وصلت، وإلا يُسأل المشغّلُ مرّة.
  Duration _duration = Duration.zero;

  @override
  Stream<KioskProgress> get progress =>
      controller.videoStateStream.asyncMap((state) async {
        if (_duration == Duration.zero) {
          final known = controller.value.metaData.duration;
          if (known > Duration.zero) {
            _duration = known;
          } else {
            final seconds = await controller.duration;
            if (seconds > 0) {
              _duration = Duration(milliseconds: (seconds * 1000).round());
            }
          }
        }
        return KioskProgress(position: state.position, duration: _duration);
      });

  @override
  Future<void> seekTo(Duration position) => controller.seekTo(
        seconds: position.inMilliseconds / 1000,
        allowSeekAhead: true,
      );
}

/// أدواتُ التحكّم التي يراها الطالب فوق فيديو الدرس، وهي كلُّ ما يراه.
///
/// ── ما فيها ──
/// تشغيلٌ وإيقافٌ مؤقّت بين زرَّي قفزٍ عشر ثوانٍ للخلف وللأمام، وتكبيرٌ
/// وتصغير، وزرُّ رجوعٍ في الأعلى، وشريطُ وقتٍ في الأسفل يُسحب مؤشّرُه إلى
/// أيّ موضعٍ من الشرح — فيعود الطالبُ إلى ما فاته أو يتجاوز ما فهمه.
///
/// والشريطُ والقفزُ من اليسار إلى اليمين في الواجهتين: خطُّ الزمن في الوسائط
/// لا يُعكس مع العربية (كما في يوتيوب نفسه)، وعكسُه يجعل «للأمام» يرجع.
///
/// ── ولماذا واجهةٌ من عندنا ──
/// أدواتُ يوتيوب تعيش داخل الصفحة المضمَّنة، ومعها فيها ما ليس من الدرس:
/// شعارٌ يفتح الموقع، وعنوانٌ يفتح صفحة المقطع، وترسُ إعداداتٍ وقائمةُ
/// مشاركة، وشاشةُ نهايةٍ تعرض مقاطعَ مقترحة. وكلُّها لا تمرّ بشيفرتنا،
/// فلا تُمنع بعد وقوعها.
///
/// فأُقفلت الصفحةُ عن اللمس بـ`PointerEvents.none` في مُعامِلات المشغّل،
/// ورُسمت الأدواتُ هنا.
///
/// ── وموضعُ رسمها: `controlsBuilder` وحده ──
/// `YoutubePlayer` على الهاتف لا يرسم في مكانه شيئاً: يرسم علامةً فارغة،
/// ويضع الصورةَ في `OverlayPortal` — أي فوق صفحة الشاشة كلِّها. فأيُّ ودجتٍ
/// يُرسم أخاً له يقع **تحت** الصورة: لا يُرى ولا تبلغه لمسة. و`controlsBuilder`
/// هو المسلكُ الوحيد الذي يُركَّب داخل تلك الطبقة، مصغّراً وفي ملء الشاشة.
///
/// ── وظاهرةٌ دائماً ──
/// كانت تختفي بعد ثلاث ثوانٍ وتظهر بلمسةٍ على الصورة، واللمسةُ تُلتقط
/// بـ`GestureDetector` مفروشٍ على الفيديو كلِّه — فكان على الصورة حاجبٌ
/// يبتلع كلَّ لمسة. وطفلٌ في الابتدائية يحتاج أن يرى الزرَّ لا أن يعرف كيف
/// يُظهره.
class YoutubeKioskControls extends StatefulWidget {
  const YoutubeKioskControls({
    required this.playback,
    required this.isFullscreen,
    required this.onExit,
    super.key,
  });

  final KioskPlayback playback;

  /// يُغيّر ما يفعله زرُّ ملء الشاشة وأيَّ أيقونةٍ يحمل.
  final bool isFullscreen;

  /// الخروج: من ملء الشاشة إن كان فيها، ومن الشاشة نفسها إن لم يكن.
  final VoidCallback onExit;

  @override
  State<YoutubeKioskControls> createState() => _YoutubeKioskControlsState();
}

class _YoutubeKioskControlsState extends State<YoutubeKioskControls> {
  StreamSubscription<PlayerState>? _valueSub;
  StreamSubscription<KioskProgress>? _progressSub;
  PlayerState _playerState = PlayerState.unknown;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;

  /// موضعُ الإصبع أثناء السحب بالثواني: يتبعه الشريطُ والعدّاد بدل ما يبلّغه
  /// المشغّل، فلا يقفز المؤشّرُ تحت الإصبع إلى الموضع القديم.
  double? _dragSeconds;

  /// قدرُ القفزة بالزرّين.
  static const _skip = Duration(seconds: 10);

  @override
  void initState() {
    super.initState();
    _listen();
  }

  @override
  void didUpdateWidget(covariant YoutubeKioskControls old) {
    super.didUpdateWidget(old);
    // ومشغّلٌ تبدّل يُتابع من جديد: لو بقي الاشتراكُ على الأوّل جمدت
    // الأيقونةُ على حالٍ لا تصفُ ما يُعرض.
    if (old.playback != widget.playback) _listen();
  }

  void _listen() {
    _valueSub?.cancel();
    _valueSub = widget.playback.states.listen((state) {
      if (!mounted || state == _playerState) return;
      setState(() => _playerState = state);
    });
    _progressSub?.cancel();
    _progressSub = widget.playback.progress.listen((progress) {
      if (!mounted || _dragSeconds != null) return;
      if (progress.position == _position && progress.duration == _duration) return;
      setState(() {
        _position = progress.position;
        _duration = progress.duration;
      });
    });
  }

  @override
  void dispose() {
    _valueSub?.cancel();
    _progressSub?.cancel();
    super.dispose();
  }

  /// ينقل التشغيل إلى [target] داخل حدود المقطع، ويُظهر الموضعَ الجديد فوراً
  /// قبل أن يبلّغه المشغّل.
  Future<void> _seek(Duration target) async {
    var clamped = target < Duration.zero ? Duration.zero : target;
    if (_duration > Duration.zero && clamped > _duration) clamped = _duration;
    setState(() => _position = clamped);
    await widget.playback.seekTo(clamped);
  }

  Future<void> _skipBy(Duration delta) => _seek(_position + delta);

  Future<void> _togglePlay() async {
    switch (_playerState) {
      case PlayerState.playing:
        await widget.playback.pause();
      // والمنتهي يبدأ من أوّله، وإلا بدا الزرُّ معطّلاً.
      case PlayerState.ended:
        await widget.playback.replay();
      default:
        await widget.playback.play();
    }
  }

  @override
  Widget build(BuildContext context) {
    final playing = _playerState == PlayerState.playing;
    final ended = _playerState == PlayerState.ended;

    // ── و`fit: expand` لازم، وهذا موضعُ عطبٍ كان ──
    //
    // أُزيل الاتّساعُ ظنّاً أنه هو ما يحجب اللمس، فاختفت الأدواتُ كلُّها:
    // هذا الودجت ابنٌ غيرُ موضَّعٍ في `Stack`، فيأتيه قيدٌ فضفاض. و`Stack`
    // كلُّ أبنائه موضَّعون يأخذ أصغرَ ما يسمح به قيدُه — صفراً في صفر.
    // فرُسمت الأزرارُ في مساحةٍ لا أبعادَ لها: لا تُرى ولا تُلمس.
    //
    // والاتّساعُ لا يحجب شيئاً: `Stack` يؤجّل فحصَ اللمس إلى أبنائه، فلا
    // يبتلع لمسةً في موضعٍ لا ابنَ فيه.
    return Stack(
      fit: StackFit.expand,
      children: [
        if (ended) Positioned.fill(child: _EndedCover(onReplay: _togglePlay)),

        // ── التشغيلُ في المنتصف ──
        //
        // حيث ينظر الطفل، وحيث يضغط بلا أن يبحث. وكان في زاويةٍ سفلية مع
        // ملءِ الشاشة، فصار الزرّان متجاورين في شريطٍ ضيّق يُخطئ بينهما
        // إصبعٌ صغير.
        if (!ended)
          Center(
            // ‏وبجانبه القفزُ عشر ثوانٍ: للخلف يساراً وللأمام يميناً، كخطّ الزمن.
            child: Directionality(
              textDirection: TextDirection.ltr,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _KioskButton(
                    icon: Icons.replay_10_rounded,
                    tooltip: tr('video.back10'),
                    onPressed: () => _skipBy(-_skip),
                  ),
                  const SizedBox(width: 18),
                  _KioskButton(
                    icon: playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                    tooltip: tr(playing ? 'video.pause' : 'video.play'),
                    onPressed: _togglePlay,
                    large: true,
                  ),
                  const SizedBox(width: 18),
                  _KioskButton(
                    icon: Icons.forward_10_rounded,
                    tooltip: tr('video.forward10'),
                    onPressed: () => _skipBy(_skip),
                  ),
                ],
              ),
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
              onPressed: widget.playback.toggleFullscreen,
            ),
          ),
        ),

        // ── وشريطُ الوقت على الحافّة السفلى، حتى زرّ ملء الشاشة ──
        //
        // يظهر متى عُرف طولُ المقطع. والسحبُ يحرّك المؤشّرَ والعدّادَ مع
        // الإصبع، والتشغيلُ ينتقل حين يُرفع — فلا يُطلب من المشغّل موضعٌ
        // جديد مع كل بكسل.
        if (!ended && _duration > Duration.zero)
          PositionedDirectional(
            bottom: 6,
            start: 6,
            end: 6 + 48 + 8,
            child: SafeArea(
              top: false,
              child: _SeekBar(
                position: _dragSeconds != null
                    ? Duration(milliseconds: (_dragSeconds! * 1000).round())
                    : _position,
                duration: _duration,
                onChanged: (seconds) => setState(() => _dragSeconds = seconds),
                onChangeEnd: (seconds) {
                  setState(() => _dragSeconds = null);
                  _seek(Duration(milliseconds: (seconds * 1000).round()));
                },
              ),
            ),
          ),
      ],
    );
  }
}

/// شريطُ الوقت: الموضعُ الحالي، والمؤشّرُ يُسحب إلى أيّ نقطة، وطولُ المقطع.
class _SeekBar extends StatelessWidget {
  const _SeekBar({
    required this.position,
    required this.duration,
    required this.onChanged,
    required this.onChangeEnd,
  });

  final Duration position;
  final Duration duration;
  final ValueChanged<double> onChanged;
  final ValueChanged<double> onChangeEnd;

  static String _clock(Duration value) {
    final total = value.inSeconds;
    final hours = total ~/ 3600;
    final minutes = (total % 3600) ~/ 60;
    final seconds = (total % 60).toString().padLeft(2, '0');
    return hours > 0
        ? '$hours:${minutes.toString().padLeft(2, '0')}:$seconds'
        : '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final max = duration.inMilliseconds / 1000;
    final value = (position.inMilliseconds / 1000).clamp(0.0, max);
    const label = TextStyle(
      color: Colors.white,
      fontSize: 12,
      fontWeight: FontWeight.w800,
      fontFeatures: [FontFeature.tabularFigures()],
    );
    // ‏خطُّ الزمن لا يُعكس مع العربية: البدايةُ يساراً والنهايةُ يميناً.
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Container(
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.52),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Row(
          children: [
            Text(_clock(position), style: label),
            Expanded(
              child: SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight: 4,
                  activeTrackColor: const Color(0xFF5EEAD4),
                  inactiveTrackColor: Colors.white.withValues(alpha: 0.32),
                  thumbColor: Colors.white,
                  overlayColor: const Color(0xFF5EEAD4).withValues(alpha: 0.24),
                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 9),
                ),
                child: Slider(
                  value: value,
                  max: max,
                  semanticFormatterCallback: (seconds) =>
                      _clock(Duration(milliseconds: (seconds * 1000).round())),
                  onChanged: onChanged,
                  onChangeEnd: onChangeEnd,
                ),
              ),
            ),
            Text(_clock(duration), style: label),
          ],
        ),
      ),
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
