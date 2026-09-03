import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
// `PlayerState` is defined by both media_kit and youtube_player_iframe;
// media_kit's is never referenced by name here (only `Player`, `Media`,
// and its streams are), so hide it and let youtube_player_iframe's
// `PlayerState` be the unqualified name used below.
import 'package:media_kit/media_kit.dart' hide PlayerState;
import 'package:media_kit_video/media_kit_video.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';

import '../models/student_content.dart';
import 'student_experience.dart';

/// A realistic, up to date mobile-Chrome user agent.
///
/// Android's system WebView appends a " wv" (WebView) token to its default
/// user agent. YouTube's embed player treats that token as "unsupported
/// browser" and refuses playback with error 153, even though the exact same
/// device renders the embed fine in real Chrome. Overriding the WebView user
/// agent with a normal browser string — and skipping the override on
/// iOS/macOS, where WKWebView already reports a standard Safari UA — is the
/// standard fix.
const String _kAndroidWebViewUserAgent =
    'Mozilla/5.0 (Linux; Android 14; Pixel 8) AppleWebKit/537.36 '
    '(KHTML, like Gecko) Chrome/126.0.0.0 Mobile Safari/537.36';

/// A realistic mobile-Safari user agent, used on iOS/macOS so direct video
/// requests present a browser identity that matches the platform actually
/// making them (AVFoundation otherwise identifies itself as a bare media
/// player, which some CDNs treat as a hotlinking client and reject).
const String _kApplePlatformUserAgent =
    'Mozilla/5.0 (iPhone; CPU iPhone OS 17_5 like Mac OS X) '
    'AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.5 '
    'Mobile/15E148 Safari/604.1';

/// The user agent presented to the in-app browser used for YouTube/Vimeo
/// embeds. `null` leaves the platform default (already a normal browser UA
/// on iOS/macOS/Windows) untouched.
String? get _webViewUserAgent =>
    (!kIsWeb && defaultTargetPlatform == TargetPlatform.android)
        ? _kAndroidWebViewUserAgent
        : null;

/// The user agent sent with direct MP4/HLS network requests. Some CDNs
/// (and YouTube's redirect chain when a raw video URL is resolved from it)
/// reject requests from generic HTTP clients that don't look like a browser.
String get _videoRequestUserAgent => (!kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.iOS ||
            defaultTargetPlatform == TargetPlatform.macOS))
    ? _kApplePlatformUserAgent
    : _kAndroidWebViewUserAgent;

/// Picks a `Referer` header matching the video's own origin. Sending a
/// same-origin referer is accepted by virtually every hotlink-protection
/// and embed-permission check (YouTube, Vimeo, Supabase Storage, generic
/// CDNs), whereas sending no `Referer` at all — the default for Flutter's
/// native HTTP clients — is what a number of providers block outright.
String _refererFor(String url) {
  final uri = Uri.tryParse(url);
  if (uri == null || uri.host.isEmpty) return 'https://www.youtube.com/';
  final host = uri.host.toLowerCase().replaceFirst('www.', '');
  if (isYoutubeHost(host)) return 'https://www.youtube.com/';
  if (host == 'vimeo.com' || host.endsWith('.vimeo.com')) {
    return 'https://player.vimeo.com/';
  }
  return '${uri.scheme}://${uri.host}/';
}

/// The full set of request headers sent for a direct MP4/HLS fetch, for
/// both the media_kit (libmpv) and video_player (ExoPlayer/AVPlayer)
/// backends. Modeled on what a real browser/native player sends for a
/// `<video>`/`AVPlayer` byte-range request:
///
/// - `User-Agent`/`Referer`: see [_videoRequestUserAgent]/[_refererFor] —
///   without these, CDNs with hotlink protection (or a Supabase Storage
///   bucket policy keyed on either) return 403 instead of the video body.
/// - `Accept: video/mp4,video/*;q=0.9,*/*;q=0.8`: prefers the exact MP4
///   representation while still accepting anything as a fallback, so a
///   CDN that runs content negotiation always has a match to serve —
///   unlike a bare `video/*`, which some origins 406 when they only
///   register the file's exact MIME type.
/// - `Range: bytes=0-`: establishes byte-range/seek support up front,
///   exactly like a browser's initial `<video>` request.
/// - `Accept-Encoding: identity`: forbids gzip/br compression. A
///   misconfigured origin that gzips a ranged response anyway breaks the
///   `Content-Length`/`Content-Range` contract the player relies on to
///   seek and to know when the stream has ended — this exact mismatch is
///   a common, otherwise-silent cause of "تعذر تشغيل الفيديو" on hosts
///   that compress everything by default.
Map<String, String> _videoHttpHeaders(String url) => {
      'Accept': 'video/mp4,video/*;q=0.9,*/*;q=0.8',
      'Accept-Encoding': 'identity',
      'Range': 'bytes=0-',
      'User-Agent': _videoRequestUserAgent,
      'Referer': _refererFor(url),
    };

/// Extracts the 11-character video id from any recognized YouTube URL
/// shape (watch, youtu.be, embed/shorts/live), or `null` if [url] isn't a
/// YouTube URL at all.
String? _youtubeIdFromUrl(String url) {
  final uri = Uri.tryParse(url);
  if (uri == null) return null;
  final host = uri.host.toLowerCase().replaceFirst('www.', '');
  if (!isYoutubeHost(host)) return null;
  final id = youtubeVideoId(uri, host);
  return id.isEmpty ? null : id;
}

/// How long a video is given to start loading/playing before the player
/// gives up and surfaces a retryable "connection timed out" error instead
/// of spinning forever.
const Duration _kLoadTimeout = Duration(seconds: 20);

/// Plays a short, muted preview only while a desktop pointer is over a card.
/// The underlying player is mounted lazily, so scrolling a library does not
/// open every video connection at once.
class StudentVideoHoverPreview extends StatefulWidget {
  const StudentVideoHoverPreview({
    required this.video,
    required this.apiBaseUrl,
    required this.child,
    this.enabled = true,
    this.previewDuration = const Duration(seconds: 3),
    this.borderRadius = const BorderRadius.all(Radius.circular(24)),
    super.key,
  });

  final LessonVideo video;
  final String apiBaseUrl;
  final Widget child;
  final bool enabled;
  final Duration previewDuration;
  final BorderRadius borderRadius;

  @override
  State<StudentVideoHoverPreview> createState() =>
      _StudentVideoHoverPreviewState();
}

class _StudentVideoHoverPreviewState extends State<StudentVideoHoverPreview> {
  Timer? _previewTimer;
  bool _previewing = false;

  bool get _motionEnabled =>
      !(MediaQuery.maybeOf(context)?.disableAnimations ?? false);

  void _startPreview(PointerEnterEvent _) {
    if (!widget.enabled || !_motionEnabled) return;
    _previewTimer?.cancel();
    if (!_previewing) setState(() => _previewing = true);
    _previewTimer = Timer(widget.previewDuration, _finishPreview);
  }

  void _finishPreview() {
    _previewTimer?.cancel();
    if (mounted && _previewing) setState(() => _previewing = false);
  }

  void _stopPreview(PointerExitEvent _) => _finishPreview();

  @override
  void didUpdateWidget(covariant StudentVideoHoverPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.enabled && _previewing) _finishPreview();
  }

  @override
  void dispose() {
    _previewTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor:
          widget.enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      onEnter: widget.enabled ? _startPreview : null,
      onExit: widget.enabled ? _stopPreview : null,
      child: ClipRRect(
        borderRadius: widget.borderRadius,
        child: Stack(
          fit: StackFit.expand,
          children: [
            widget.child,
            if (_previewing)
              Positioned.fill(
                child: IgnorePointer(
                  child: StudentVideoPlayer(
                    key: ValueKey('hover-preview-${widget.video.id}'),
                    video: widget.video,
                    apiBaseUrl: widget.apiBaseUrl,
                    compact: true,
                    autoPlay: true,
                    muted: true,
                  ),
                ),
              ),
            if (_previewing)
              const PositionedDirectional(
                top: 12,
                end: 12,
                child: _PreviewBadge(),
              ),
          ],
        ),
      ),
    );
  }
}

class _PreviewBadge extends StatelessWidget {
  const _PreviewBadge();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xD9071425),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF5EEAD4).withOpacity(0.7)),
      ),
      child: const Padding(
        padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.visibility_rounded, color: Color(0xFFBFFBFA), size: 15),
            SizedBox(width: 5),
            Text(
              'معاينة ٣ ثوانٍ',
              style: TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class StudentVideoPlayer extends StatefulWidget {
  const StudentVideoPlayer({
    required this.video,
    this.apiBaseUrl = '',
    this.compact = false,
    this.initialPosition = Duration.zero,
    this.autoPlay = true,
    this.muted = false,
    this.fullscreen = false,
    this.allowInteractivePermissions = false,
    this.onCompleted,
    super.key,
  });

  final LessonVideo video;
  final String apiBaseUrl;
  final bool compact;
  final Duration initialPosition;
  final bool autoPlay;
  final bool muted;
  final bool fullscreen;

  /// Enables only the browser permissions required by an interactive tutor
  /// embedded from another origin. Lesson videos keep this disabled.
  final bool allowInteractivePermissions;
  final VoidCallback? onCompleted;

  @override
  State<StudentVideoPlayer> createState() => _StudentVideoPlayerState();
}

class _StudentVideoPlayerState extends State<StudentVideoPlayer> {
  Player? _player;
  VideoController? _videoController;
  VideoPlayerController? _networkController;
  YoutubePlayerController? _ytController;
  StreamSubscription<YoutubePlayerValue>? _ytSubscription;
  bool _completionReported = false;
  String? _error;
  int _embedReloadTicket = 0;
  int _ytReloadTicket = 0;
  Timer? _loadTimeoutTimer;
  bool _webViewLoading = true;
  int _nativeRetryAttempt = 0;
  bool _nativeRetryScheduled = false;
  bool _triedExoPlayerFallback = false;
  Timer? _videoTrackWatchdogTimer;

  /// Once `true`, media_kit opens with GPU/hardware-accelerated rendering
  /// disabled — i.e. forced onto its CPU/software decoder (`--hwdec=no`),
  /// which reliably produces a frame on every H.264 profile at some extra
  /// CPU cost, in exchange for never leaving the picture blank. Sticky
  /// across retries within this widget's lifetime: it only ever gets set
  /// once a hardware-accelerated open has already failed on this device —
  /// either explicitly ([_handleNativePlaybackError], once the same-backend
  /// retries below are exhausted) or silently ([_watchVideoTrackAppears]
  /// catching audio playing with no video frame) — so retrying
  /// hardware-accelerated again would just reproduce the same failure.
  bool _mediaKitSoftwareDecode = false;

  /// Automatic retries attempted on the *same* native backend before either
  /// forcing media_kit's software decoder (see [_mediaKitSoftwareDecode]),
  /// falling back to the platform's other decoder entirely (Android), or
  /// finally showing the error screen — mirrors how Netflix/YouTube-style
  /// players silently ride out a transient network blip instead of
  /// immediately bothering the viewer.
  static const int _kMaxNativeRetries = 2;

  /// How long media_kit gets, once audio is confirmed playing, to also
  /// report a decoded video frame size before this is treated as "audio
  /// with no picture" rather than just a slow-starting video track. Kept
  /// short so a hardware-decode failure that never throws an exception —
  /// picture silently never attaches — still gets the software-decoder
  /// fallback (see [_mediaKitSoftwareDecode]) forced on it promptly instead
  /// of leaving the screen black for a long, undiagnosable stretch.
  static const Duration _kVideoTrackGracePeriod = Duration(seconds: 4);

  String get _url => resolveStudentVideoUrl(
        widget.video,
        apiBaseUrl: widget.apiBaseUrl,
      );

  bool get _isNativeVideo => isDirectVideoUrl(_url, widget.video);
  bool get _usesMediaKit =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.windows ||
          defaultTargetPlatform == TargetPlatform.android);

  /// The official `youtube_player_iframe` package correctly implements
  /// YouTube's IFrame Player API contract (a valid `origin` + `enablejsapi`
  /// + postMessage handshake), which is what actually prevents the
  /// "disallowed embed" family of errors (YouTube error codes 100/101/150/
  /// 152) — as opposed to the raw WebView navigation this app used before,
  /// which only mimics a browser closely enough to dodge *some* of them.
  /// It only ships an official web implementation for Android, iOS, and
  /// Flutter Web, so Windows/desktop keeps using the WebView fallback below.
  bool get _supportsYoutubePlayerIframe =>
      kIsWeb ||
      (!kIsWeb &&
          (defaultTargetPlatform == TargetPlatform.android ||
              defaultTargetPlatform == TargetPlatform.iOS));
  bool get _isYoutube => isYoutubeVideoUrl(_url);
  bool get _useYoutubePlayerIframe =>
      !_isNativeVideo && _isYoutube && _supportsYoutubePlayerIframe;

  /// A link to the same video on youtube.com/the YouTube app. Offered as a
  /// last-resort fallback whenever the embedded player can't play a
  /// YouTube video for a reason no amount of headers can fix — most
  /// commonly the video owner disabling embedding entirely (error 101/150/
  /// 152), or a school/ISP network blocking youtube.com inside iframes.
  Uri? get _externalYoutubeUrl {
    if (!_isYoutube) return null;
    final id = _youtubeIdFromUrl(_url);
    if (id == null) return null;
    return Uri.https('www.youtube.com', '/watch', {'v': id});
  }

  String get _embedUrl {
    if (!widget.muted) return _url;
    final uri = Uri.tryParse(_url);
    if (uri == null) return _url;
    return uri.replace(
      queryParameters: {
        ...uri.queryParameters,
        'mute': '1',
        'controls': '0',
      },
    ).toString();
  }

  @override
  void initState() {
    super.initState();
    if (_isNativeVideo) {
      _openVideo();
    } else if (_useYoutubePlayerIframe) {
      _initYoutubePlayer();
    }
  }

  void _startLoadTimeout() {
    _loadTimeoutTimer?.cancel();
    _loadTimeoutTimer = Timer(_kLoadTimeout, () {
      if (!mounted || _error != null) return;
      setState(() {
        _error = 'استغرق تحميل الفيديو وقتًا طويلاً. تحقق من اتصالك بالإنترنت.';
      });
    });
  }

  void _cancelLoadTimeout() {
    _loadTimeoutTimer?.cancel();
    _loadTimeoutTimer = null;
  }

  void _initYoutubePlayer() {
    final videoId = _youtubeIdFromUrl(_url);
    if (videoId == null) {
      // Called synchronously from initState() (or synchronously from a
      // retry action before the next build), so this runs before/outside
      // an active build — a direct field write is picked up by the next
      // build without needing (and safely being able to call) setState.
      _error = 'تعذر التعرف على رابط فيديو يوتيوب.';
      return;
    }
    // Uses the base constructor (not the `.fromVideoId` factory) because
    // only it exposes `onWebResourceError` — needed to surface a WebView
    // load failure (e.g. the underlying network request itself failing)
    // as a player error instead of leaving the loading thumbnail up
    // forever.
    final controller = YoutubePlayerController(
      params: YoutubePlayerParams(
        mute: widget.muted,
        showControls: !widget.compact,
        showFullscreenButton: !widget.compact,
        strictRelatedVideos: true,
        privacyEnhancedMode: true,
        // Android only; iOS/web keep the platform's own standards-compliant
        // WebView user agent, which YouTube already accepts.
        userAgent: _webViewUserAgent,
      ),
      onWebResourceError: (error) {
        // Only a failed top-level document load is a real player error; a
        // blocked sub-resource (ad/tracking beacon, etc.) is normal and
        // must not hide a video that is otherwise loading fine.
        if (error.isForMainFrame == false || !mounted) return;
        _cancelLoadTimeout();
        setState(
            () => _error = 'تعذر تحميل صفحة الفيديو (${error.errorCode}).');
      },
    );
    if (widget.autoPlay) {
      controller.loadVideoById(
        videoId: videoId,
        startSeconds: widget.initialPosition.inSeconds.toDouble(),
      );
    } else {
      controller.cueVideoById(
        videoId: videoId,
        startSeconds: widget.initialPosition.inSeconds.toDouble(),
      );
    }
    _ytController = controller;
    _ytSubscription = controller.stream.listen(_onYoutubeValueChanged);
    _startLoadTimeout();
  }

  void _onYoutubeValueChanged(YoutubePlayerValue value) {
    if (!mounted) return;
    if (value.hasError) {
      _cancelLoadTimeout();
      if (_error == null) {
        setState(() => _error = _describeYoutubeError(value.error));
      }
      return;
    }
    // Any state past "not started yet" proves the IFrame API handshake
    // succeeded, so the load-timeout guard is no longer needed.
    if (value.playerState != PlayerState.unknown &&
        value.playerState != PlayerState.unStarted) {
      _cancelLoadTimeout();
    }
    if (value.playerState == PlayerState.ended && !_completionReported) {
      _completionReported = true;
      widget.onCompleted?.call();
    }
  }

  String _describeYoutubeError(YoutubeError error) {
    switch (error) {
      case YoutubeError.notEmbeddable:
      case YoutubeError.sameAsNotEmbeddable:
      case YoutubeError.sameAsNotEmbeddable2:
        // YouTube error 101/150/152: the video owner disabled playback in
        // embedded/third-party players. No header or setting fixes this —
        // only opening the video on youtube.com itself works.
        return 'صاحب الفيديو عطّل تشغيله داخل التطبيقات. جرّب زر "افتح في يوتيوب".';
      case YoutubeError.videoNotFound:
      case YoutubeError.cannotFindVideo:
        return 'تعذر العثور على هذا الفيديو على يوتيوب.';
      case YoutubeError.invalidParam:
      case YoutubeError.html5Error:
      case YoutubeError.unknown:
      case YoutubeError.none:
        return 'تعذر تشغيل الفيديو.';
    }
  }

  Future<void> _retryYoutube() async {
    _cancelLoadTimeout();
    await _ytSubscription?.cancel();
    await _ytController?.close();
    if (!mounted) return;
    setState(() {
      _error = null;
      _ytController = null;
      _ytSubscription = null;
      _ytReloadTicket++;
    });
    _initYoutubePlayer();
  }

  Future<void> _openVideo({bool forceVideoPlayer = false}) async {
    final uri = Uri.tryParse(_url);
    final isWebRelativeUrl = kIsWeb && _url.startsWith('/');
    if (uri == null ||
        (!(uri.scheme == 'http' || uri.scheme == 'https') &&
            !isWebRelativeUrl)) {
      setState(() {
        _error = 'يجب أن يكون رابط الفيديو رابط HTTP أو HTTPS عامًا.';
      });
      return;
    }

    if (_usesMediaKit && !forceVideoPlayer) {
      await _openWithMediaKit();
    } else {
      await _openWithVideoPlayer(uri);
    }
  }

  /// Common recovery path for every native playback failure — the initial
  /// `open()`/`initialize()` throwing, a load timeout, or an async error
  /// reported later by the player/controller once already open.
  ///
  /// Tries, in order:
  /// 1. A same-backend retry with a short backoff (up to
  ///    [_kMaxNativeRetries] times) — rides out a transient network blip
  ///    without bothering the viewer, exactly like it did before.
  /// 2. If still using media_kit with hardware acceleration on, force its
  ///    software decoder ([_mediaKitSoftwareDecode]) and reopen *before*
  ///    giving up on media_kit entirely. A hardware-accelerated decode that
  ///    is still failing once the same-backend retries are exhausted is a
  ///    GPU/codec incompatibility, not a network hiccup — retrying the same
  ///    hardware path again would just reproduce it, while forcing software
  ///    decoding reliably produces a frame at some extra CPU cost.
  /// 3. On Android only, where media_kit (libmpv) and video_player
  ///    (ExoPlayer) are two genuinely independent decoder pipelines, one
  ///    attempt on the other backend — since a failure specific to one
  ///    decoder sometimes plays fine on the other.
  ///
  /// Only after every option is exhausted does it surface the error screen.
  Future<void> _handleNativePlaybackError(Object error) async {
    if (!mounted || _nativeRetryScheduled) return;
    final message = error is TimeoutException
        ? 'استغرق تحميل الفيديو وقتًا طويلاً. تحقق من اتصالك بالإنترنت.'
        : error.toString();

    final canRetrySameBackend = _nativeRetryAttempt < _kMaxNativeRetries;
    final canForceSoftwareDecode =
        !canRetrySameBackend && _usesMediaKit && !_mediaKitSoftwareDecode;
    final canTryOtherBackend = !canRetrySameBackend &&
        !canForceSoftwareDecode &&
        _usesMediaKit &&
        !kIsWeb &&
        defaultTargetPlatform == TargetPlatform.android &&
        !_triedExoPlayerFallback;

    if (!canRetrySameBackend && !canForceSoftwareDecode && !canTryOtherBackend) {
      setState(() => _error = message);
      return;
    }

    _nativeRetryScheduled = true;
    _videoTrackWatchdogTimer?.cancel();
    await _player?.dispose();
    await _networkController?.dispose();
    _player = null;
    _videoController = null;
    _networkController = null;

    if (canRetrySameBackend) {
      _nativeRetryAttempt++;
      await Future.delayed(Duration(seconds: _nativeRetryAttempt * 2));
    } else if (canForceSoftwareDecode) {
      _mediaKitSoftwareDecode = true;
    } else {
      _triedExoPlayerFallback = true;
    }

    _nativeRetryScheduled = false;
    if (!mounted) return;
    await _openVideo(forceVideoPlayer: canTryOtherBackend);
  }

  Future<void> _openWithMediaKit() async {
    final player = Player();
    _player = player;
    _videoController = VideoController(
      player,
      // Hardware-accelerated (GPU) decoding is the default and is fine on
      // most devices, but on some GPU + codec combinations it fails in one
      // of two ways: `player.open()`/the player itself throws (caught by
      // `_handleNativePlaybackError`, which forces this after the
      // same-backend retries are exhausted), or — a known media_kit/Android
      // failure mode — it opens silently with audio decoding and playing
      // normally while the hardware video surface never attaches, leaving
      // picture blank forever (`_watchVideoTrackAppears` below). Either way,
      // once one of those has actually observed the failure on this device,
      // every subsequent open forces the software decode path instead,
      // which reliably produces a frame — for any H.264 profile — at some
      // extra CPU cost.
      configuration: VideoControllerConfiguration(
        enableHardwareAcceleration: !_mediaKitSoftwareDecode,
      ),
    );
    player.stream.error.listen((error) {
      // Ignore late errors from a player instance this state has already
      // moved on from (disposed as part of a retry/fallback in progress).
      if (_player != player) return;
      _handleNativePlaybackError(error);
    });
    player.stream.completed.listen((completed) {
      if (completed && !_completionReported) {
        _completionReported = true;
        widget.onCompleted?.call();
      }
    });

    try {
      if (widget.muted) await player.setVolume(0);
      // media_kit uses the HTTP Range protocol for seeking. Supplying an
      // initial range keeps Windows' native backend on the streaming path
      // for public Supabase Storage objects and API compatibility URLs.
      await player
          .open(Media(_url, httpHeaders: _videoHttpHeaders(_url)))
          .timeout(
            _kLoadTimeout,
          );
      _watchVideoTrackAppears(player);
    } catch (error) {
      if (!mounted) return;
      await _handleNativePlaybackError(error);
    }
  }

  /// Detects "audio plays, picture never appears" — a failure that throws
  /// no exception at all, so nothing in [_handleNativePlaybackError] would
  /// ever catch it on its own. If audio is confirmed progressing but
  /// media_kit still hasn't reported a decoded video frame size after
  /// [_kVideoTrackGracePeriod], switch to software decoding and reopen.
  void _watchVideoTrackAppears(Player player) {
    _videoTrackWatchdogTimer?.cancel();
    _videoTrackWatchdogTimer = Timer(_kVideoTrackGracePeriod, () {
      if (!mounted || _player != player || _mediaKitSoftwareDecode) return;
      final state = player.state;
      final hasVideoFrame = (state.width ?? 0) > 0 && (state.height ?? 0) > 0;
      final audioIsProgressing =
          state.playing && state.position > Duration.zero;
      if (hasVideoFrame || !audioIsProgressing) return;
      _recoverFromMissingVideoTrack();
    });
  }

  Future<void> _recoverFromMissingVideoTrack() async {
    if (!mounted) return;
    _mediaKitSoftwareDecode = true;
    await _player?.dispose();
    _player = null;
    _videoController = null;
    if (!mounted) return;
    setState(() {}); // Show the loading spinner while it reopens.
    await _openWithMediaKit();
  }

  Future<void> _openWithVideoPlayer(Uri uri) async {
    // iOS/macOS play this through AVFoundation (AVPlayer/AVURLAsset).
    // `httpHeaders` is video_player's documented, officially supported way
    // to set AVURLAsset's HTTP header fields — no extra native
    // configuration is needed beyond passing them here. On Android this is
    // ExoPlayer, used either as the primary backend (when media_kit isn't
    // applicable) or as the one-time fallback from
    // `_handleNativePlaybackError` below.
    final controller = VideoPlayerController.networkUrl(
      uri,
      httpHeaders: _videoHttpHeaders(uri.toString()),
    );
    _networkController = controller;
    controller.addListener(() {
      // Ignore a stale listener firing after this controller was disposed
      // and replaced by a retry/fallback attempt already in progress.
      if (_networkController != controller) return;
      final value = controller.value;
      if (value.isInitialized &&
          value.duration > Duration.zero &&
          value.position >= value.duration &&
          !_completionReported) {
        _completionReported = true;
        widget.onCompleted?.call();
      }
      if (!mounted || !value.hasError) return;
      _handleNativePlaybackError(
        Exception(value.errorDescription ?? 'تعذر تحميل مصدر الفيديو.'),
      );
    });

    try {
      await controller.initialize().timeout(_kLoadTimeout);
      if (widget.muted) await controller.setVolume(0);
      if (widget.initialPosition > Duration.zero &&
          widget.initialPosition < controller.value.duration) {
        await controller.seekTo(widget.initialPosition);
      }
      await controller.setLooping(false);
      if (!mounted) return;
      setState(() {});
      if (widget.autoPlay) await controller.play();
    } catch (error) {
      if (!mounted) return;
      await _handleNativePlaybackError(error);
    }
  }

  @override
  void dispose() {
    _loadTimeoutTimer?.cancel();
    _videoTrackWatchdogTimer?.cancel();
    _ytSubscription?.cancel();
    _ytController?.close();
    _player?.dispose();
    _networkController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_useYoutubePlayerIframe) return _buildYoutubeEmbed();
    if (!_isNativeVideo) return _buildInlineEmbed();

    final controller = _videoController;
    final networkController = _networkController;
    return Stack(
      fit: StackFit.expand,
      children: [
        if (_usesMediaKit && controller != null)
          // `Video` already wraps its texture in a ClipRect+FittedBox
          // (fit: BoxFit.contain) sized from the video's *real* reported
          // aspect ratio — the surrounding `AspectRatio(aspectRatio: 16/9,
          // child: StudentVideoPlayer(...))` every caller wraps this in
          // gives it a deterministic, non-zero box to letterbox/pillarbox
          // within. Hard-coding `Video`'s own `aspectRatio` to 16/9 here
          // instead would stretch any non-16:9 lesson recording, since the
          // texture itself doesn't do aspect-correct scaling — it just
          // fills whatever box it's told to.
          Video(
            controller: controller,
            fill: Colors.black,
            fit: BoxFit.contain,
            controls: MaterialVideoControls,
          )
        else if (!_usesMediaKit &&
            networkController != null &&
            networkController.value.isInitialized)
          _NetworkVideoSurface(
            controller: networkController,
            video: widget.video,
            apiBaseUrl: widget.apiBaseUrl,
            fullscreen: widget.fullscreen,
          )
        else
          const ColoredBox(
            color: Colors.black,
            child: Center(
              child: CircularProgressIndicator(color: Color(0xFF5EEAD4)),
            ),
          ),
        if (_error != null)
          _buildError('تعذر تشغيل الفيديو', onRetry: _retryNativePlayback),
      ],
    );
  }

  Widget _buildInlineEmbed() {
    return Stack(
      fit: StackFit.expand,
      children: [
        InAppWebView(
          key: ValueKey('embed-$_embedReloadTicket'),
          onLoadStart: (controller, url) => _startLoadTimeout(),
          onLoadStop: (controller, url) {
            _cancelLoadTimeout();
            if (mounted) setState(() => _webViewLoading = false);
          },
          initialUrlRequest: URLRequest(
            url: WebUri(_embedUrl),
            // A same-origin Referer is what stops YouTube's embed player
            // from surfacing error 153 ("disallowed embed request") when
            // the request otherwise looks like it has no referring page,
            // which is the default for a WebView navigated to directly.
            headers: {'Referer': _refererFor(_embedUrl)},
          ),
          initialSettings: InAppWebViewSettings(
            javaScriptEnabled: true,
            mediaPlaybackRequiresUserGesture: false,
            // iOS: play video in place instead of forcing the system's
            // full-screen media player, and allow it to keep playing in
            // Picture-in-Picture / via AirPlay like a native player would.
            allowsInlineMediaPlayback: true,
            allowsPictureInPictureMediaPlayback: true,
            allowsAirPlayForMediaPlayback: true,
            // Android: swap the WebView's default "...; wv) ... Mobile
            // Safari" user agent for a normal Chrome UA. YouTube's embed
            // page detects the "wv" (WebView) token and refuses playback
            // with error 153; a browser-identical UA fixes it.
            userAgent: _webViewUserAgent,
            mixedContentMode: MixedContentMode.MIXED_CONTENT_COMPATIBILITY_MODE,
            supportZoom: !widget.compact,
            transparentBackground: true,
            supportMultipleWindows: false,
            javaScriptCanOpenWindowsAutomatically: false,
            // Flutter Web renders InAppWebView as an iframe. Interactive tutor
            // providers request getUserMedia from inside that frame, so the
            // microphone/camera feature policy must be delegated explicitly.
            iframeAllow: widget.allowInteractivePermissions
                ? 'camera *; microphone *; autoplay *; clipboard-write *; '
                    'encrypted-media *; fullscreen *; picture-in-picture *'
                : null,
            iframeAllowFullscreen: widget.allowInteractivePermissions,
          ),
          // Grants the camera/microphone access the `iframeAllow` feature
          // policy above already opens the door for — without this, the
          // interactive tutor's getUserMedia request is denied outright and
          // it silently falls back to a degraded, camera/mic-less mode.
          onPermissionRequest: widget.allowInteractivePermissions
              ? (controller, request) async => PermissionResponse(
                    resources: request.resources,
                    action: PermissionResponseAction.GRANT,
                  )
              : null,
          shouldOverrideUrlLoading: (controller, action) async {
            final target = action.request.url;
            if (target == null) return NavigationActionPolicy.CANCEL;
            return target.scheme == 'http' || target.scheme == 'https'
                ? NavigationActionPolicy.ALLOW
                : NavigationActionPolicy.CANCEL;
          },
          onReceivedError: (controller, request, error) {
            // Only the top-level document failing to load should surface
            // as a player error; a blocked sub-resource (analytics beacon,
            // ad request, etc.) is normal and must not hide the video.
            if (request.isForMainFrame != true || !mounted) return;
            _cancelLoadTimeout();
            setState(() {
              _error = error.description;
              _webViewLoading = false;
            });
          },
          onReceivedHttpError: (controller, request, response) {
            final statusCode = response.statusCode ?? 0;
            if (request.isForMainFrame != true ||
                !mounted ||
                statusCode < 400) {
              return;
            }
            _cancelLoadTimeout();
            setState(() {
              _error = 'HTTP $statusCode';
              _webViewLoading = false;
            });
          },
        ),
        if (_webViewLoading && _error == null)
          const IgnorePointer(
            child: ColoredBox(
              color: Colors.black,
              child: Center(
                child: CircularProgressIndicator(color: Color(0xFF5EEAD4)),
              ),
            ),
          ),
        if (_error != null)
          _buildError(
            'تعذر تشغيل الفيديو',
            onRetry: _retryEmbed,
            externalUrl: _externalYoutubeUrl,
          ),
      ],
    );
  }

  Widget _buildYoutubeEmbed() {
    final controller = _ytController;
    if (controller == null) {
      return _error != null
          ? _buildError(
              'تعذر تشغيل الفيديو',
              onRetry: _retryYoutube,
              externalUrl: _externalYoutubeUrl,
            )
          : const ColoredBox(
              color: Colors.black,
              child: Center(
                child: CircularProgressIndicator(color: Color(0xFF5EEAD4)),
              ),
            );
    }
    return Stack(
      fit: StackFit.expand,
      children: [
        YoutubePlayer(
          key: ValueKey('youtube-$_ytReloadTicket'),
          controller: controller,
          aspectRatio: 16 / 9,
          backgroundColor: Colors.black,
        ),
        if (_error != null)
          _buildError(
            'تعذر تشغيل الفيديو',
            onRetry: _retryYoutube,
            externalUrl: _externalYoutubeUrl,
          ),
      ],
    );
  }

  Future<void> _retryNativePlayback() async {
    _videoTrackWatchdogTimer?.cancel();
    await _player?.dispose();
    await _networkController?.dispose();
    if (!mounted) return;
    setState(() {
      _error = null;
      _player = null;
      _videoController = null;
      _networkController = null;
      // A manual tap gets a fresh full cycle of automatic retries/fallback,
      // not whatever was left over from the attempt that just failed.
      // `_mediaKitSoftwareDecode` deliberately stays sticky (see its
      // doc-comment) — a device that needed software decode once will need
      // it again.
      _nativeRetryAttempt = 0;
      _triedExoPlayerFallback = false;
    });
    await _openVideo();
  }

  void _retryEmbed() {
    if (!mounted) return;
    setState(() {
      _error = null;
      _webViewLoading = true;
      // Forces the InAppWebView below to remount with a fresh key, which
      // reloads the embed URL from scratch rather than replaying whatever
      // failed request is still cached in the existing webview instance.
      _embedReloadTicket++;
    });
  }

  Widget _buildError(
    String title, {
    required VoidCallback onRetry,
    Uri? externalUrl,
  }) {
    // The friendly title is intentionally generic, but showing the raw
    // technical reason underneath (HTTP status, timeout, decoder
    // exception...) is what turns "video doesn't work" reports into
    // something actually diagnosable — the previous version discarded it
    // entirely once automatic retries were exhausted.
    final detail = _error;
    return ColoredBox(
      color: const Color(0xED071425),
      child: Center(
        child: Padding(
          padding: EdgeInsets.all(widget.compact ? 14 : 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.error_outline_rounded,
                color: const Color(0xFF5EEAD4),
                size: widget.compact ? 34 : 52,
              ),
              const SizedBox(height: 10),
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: widget.compact ? 15 : 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
              if (!widget.compact && detail != null && detail.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  detail,
                  textAlign: TextAlign.center,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFFB3C8DE),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
              const SizedBox(height: 10),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 10,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: onRetry,
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('إعادة المحاولة'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFBFFBFA),
                      side: const BorderSide(color: Color(0xFF5EEAD4)),
                    ),
                  ),
                  // Some YouTube playback failures (the video owner disabled
                  // embedding entirely — YouTube error 101/150/152) can't be
                  // fixed by this app at all. Opening the same video in the
                  // YouTube app/browser is the only way the student still
                  // gets to watch the lesson in that case.
                  if (externalUrl != null)
                    OutlinedButton.icon(
                      onPressed: () => launchUrl(
                        externalUrl,
                        mode: LaunchMode.externalApplication,
                      ),
                      icon: const Icon(Icons.open_in_new_rounded),
                      label: const Text('افتح في يوتيوب'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: BorderSide(color: Colors.white.withOpacity(0.7)),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NetworkVideoSurface extends StatefulWidget {
  const _NetworkVideoSurface({
    required this.controller,
    required this.video,
    required this.apiBaseUrl,
    this.fullscreen = false,
  });

  final VideoPlayerController controller;
  final LessonVideo video;
  final String apiBaseUrl;
  final bool fullscreen;

  @override
  State<_NetworkVideoSurface> createState() => _NetworkVideoSurfaceState();
}

class _NetworkVideoSurfaceState extends State<_NetworkVideoSurface> {
  bool _showControls = true;

  void _togglePlayback() {
    final controller = widget.controller;
    if (controller.value.isPlaying) {
      controller.pause();
    } else {
      controller.play();
    }
    setState(() => _showControls = true);
  }

  Future<void> _openFullscreen() async {
    final controller = widget.controller;
    final wasPlaying = controller.value.isPlaying;
    final position = controller.value.position;
    await controller.pause();
    final result = await Navigator.of(context).push<_FullscreenPlaybackState>(
      StudentPageRoute<_FullscreenPlaybackState>(
        builder: (_) => _FullscreenNetworkVideoScreen(
          video: widget.video,
          apiBaseUrl: widget.apiBaseUrl,
          initialPosition: position,
          autoPlay: wasPlaying,
        ),
      ),
    );
    if (!mounted) return;
    if (!controller.value.isInitialized) return;
    await controller.seekTo(result?.position ?? position);
    if (result?.isPlaying ?? wasPlaying) {
      await controller.play();
    } else {
      await controller.pause();
    }
    setState(() => _showControls = true);
  }

  @override
  Widget build(BuildContext context) {
    final ratio = widget.controller.value.aspectRatio;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _togglePlayback,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Center(
            child: AspectRatio(
              aspectRatio: ratio <= 0 ? 16 / 9 : ratio,
              child: VideoPlayer(widget.controller),
            ),
          ),
          // ExoPlayer/AVPlayer both surface network stalls as a transient
          // "buffering" state rather than an error. Without this, a slow
          // connection just freezes the frame with no feedback, which reads
          // as "the video is broken" even though it's still trying.
          ValueListenableBuilder<VideoPlayerValue>(
            valueListenable: widget.controller,
            builder: (context, value, _) {
              if (!value.isBuffering) return const SizedBox.shrink();
              return const IgnorePointer(
                child: CircularProgressIndicator(color: Color(0xFF5EEAD4)),
              );
            },
          ),
          if (_showControls)
            IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.black.withAlpha(80),
                  shape: BoxShape.circle,
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Icon(
                    widget.controller.value.isPlaying
                        ? Icons.pause_rounded
                        : Icons.play_arrow_rounded,
                    color: Colors.white,
                    size: 34,
                  ),
                ),
              ),
            ),
          Positioned(
            left: 12,
            right: 12,
            bottom: 10,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                VideoProgressIndicator(
                  widget.controller,
                  allowScrubbing: true,
                  colors: const VideoProgressColors(
                    playedColor: Color(0xFF5EEAD4),
                    bufferedColor: Color(0x885EEAD4),
                    backgroundColor: Color(0x66788A9F),
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    IconButton(
                      tooltip: widget.controller.value.isPlaying
                          ? 'إيقاف مؤقت'
                          : 'تشغيل',
                      onPressed: _togglePlayback,
                      icon: Icon(
                        widget.controller.value.isPlaying
                            ? Icons.pause_rounded
                            : Icons.play_arrow_rounded,
                        color: Colors.white,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      tooltip:
                          widget.fullscreen ? 'إغلاق ملء الشاشة' : 'ملء الشاشة',
                      onPressed: widget.fullscreen
                          ? () => Navigator.of(context).pop(
                                _FullscreenPlaybackState(
                                  position: widget.controller.value.position,
                                  isPlaying: widget.controller.value.isPlaying,
                                ),
                              )
                          : _openFullscreen,
                      icon: Icon(
                        widget.fullscreen
                            ? Icons.fullscreen_exit_rounded
                            : Icons.fullscreen_rounded,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FullscreenPlaybackState {
  const _FullscreenPlaybackState({
    required this.position,
    required this.isPlaying,
  });

  final Duration position;
  final bool isPlaying;
}

class _FullscreenNetworkVideoScreen extends StatelessWidget {
  const _FullscreenNetworkVideoScreen({
    required this.video,
    required this.apiBaseUrl,
    required this.initialPosition,
    required this.autoPlay,
  });

  final LessonVideo video;
  final String apiBaseUrl;
  final Duration initialPosition;
  final bool autoPlay;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Center(
          child: AspectRatio(
            aspectRatio: 16 / 9,
            child: StudentVideoPlayer(
              video: video,
              apiBaseUrl: apiBaseUrl,
              initialPosition: initialPosition,
              autoPlay: autoPlay,
              fullscreen: true,
            ),
          ),
        ),
      ),
    );
  }
}

String resolveStudentVideoUrl(
  LessonVideo video, {
  String apiBaseUrl = '',
}) {
  var raw = video.url.trim();
  if (raw.startsWith('/')) {
    final base = apiBaseUrl.trim().replaceFirst(RegExp(r'/$'), '');
    if (base.isNotEmpty) raw = '$base$raw';
  }
  if (video.sourceType == VideoSourceType.mp4) return raw;

  final uri = Uri.tryParse(raw);
  if (uri == null) return raw;
  final host = uri.host.toLowerCase().replaceFirst('www.', '');
  if (isYoutubeHost(host)) {
    final id = youtubeVideoId(uri, host);
    if (id.isNotEmpty) {
      return Uri.https(
        'www.youtube.com',
        '/embed/$id',
        const {
          'autoplay': '1',
          'playsinline': '1',
          'rel': '0',
          'modestbranding': '1',
        },
      ).toString();
    }
  }
  if (host == 'vimeo.com') {
    final id = uri.pathSegments.isEmpty ? '' : uri.pathSegments.last;
    return 'https://player.vimeo.com/video/$id?autoplay=1';
  }
  return raw;
}

bool isDirectVideoUrl(String url, LessonVideo video) {
  if (video.sourceType == VideoSourceType.mp4) return true;
  final uri = Uri.tryParse(url);
  if (uri == null || !(uri.scheme == 'http' || uri.scheme == 'https')) {
    return false;
  }
  final path = uri.path.toLowerCase();
  return RegExp(r'\.(mp4|m4v|mov|webm|m3u8)$').hasMatch(path) ||
      (uri.host.endsWith('supabase.co') &&
          path.contains('/storage/v1/object/public/'));
}

bool isYoutubeVideoUrl(String url) {
  final uri = Uri.tryParse(url);
  return uri != null &&
      isYoutubeHost(uri.host.toLowerCase().replaceFirst('www.', ''));
}

bool isYoutubeHost(String host) =>
    host == 'youtube.com' ||
    host == 'youtube-nocookie.com' ||
    host == 'youtu.be' ||
    host.endsWith('.youtube.com') ||
    host.endsWith('.youtube-nocookie.com');

String youtubeVideoId(Uri uri, String host) {
  if (host == 'youtu.be') {
    return uri.pathSegments.isEmpty ? '' : uri.pathSegments.first;
  }
  final queryId = uri.queryParameters['v'];
  if (queryId != null && queryId.trim().isNotEmpty) return queryId;
  if (uri.pathSegments.length >= 2 &&
      const {'embed', 'shorts', 'live'}.contains(uri.pathSegments.first)) {
    return uri.pathSegments[1];
  }
  return '';
}
