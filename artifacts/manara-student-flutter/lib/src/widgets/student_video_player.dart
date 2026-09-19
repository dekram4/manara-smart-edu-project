import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
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

import '../l10n/student_strings.dart';
import '../models/student_content.dart';

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
String get _videoRequestUserAgent =>
    (!kIsWeb &&
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
      cursor: widget.enabled
          ? SystemMouseCursors.click
          : SystemMouseCursors.basic,
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
        border: Border.all(color: const Color(0xFF5EEAD4).withValues(alpha: 0.7)),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.visibility_rounded, color: Color(0xFFBFFBFA), size: 15),
            SizedBox(width: 5),
            Text(
              tr('video.preview'),
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
  bool _nativeCompleted = false;
  String? _error;
  int _embedReloadTicket = 0;
  int _ytReloadTicket = 0;
  Timer? _loadTimeoutTimer;
  bool _webViewLoading = true;
  int _nativeRetryAttempt = 0;
  bool _nativeRetryScheduled = false;
  Timer? _videoTrackWatchdogTimer;

  /// Once `true`, media_kit opens with GPU/hardware-accelerated rendering
  /// disabled — i.e. forced onto its CPU/software decoder (`--hwdec=no`),
  /// which reliably produces a frame at some extra CPU cost, in exchange
  /// for never leaving the picture blank. Only reachable on Windows now
  /// (see [_usesMediaKit]) — sticky across retries within this widget's
  /// lifetime, since it only ever gets set once a hardware-accelerated open
  /// has already failed on this device, either explicitly
  /// ([_handleNativePlaybackError], once the same-backend retries below are
  /// exhausted) or silently ([_watchVideoTrackAppears] catching audio
  /// playing with no video frame) — so retrying hardware-accelerated again
  /// would just reproduce the same failure.
  bool _mediaKitSoftwareDecode = false;

  /// Automatic retries attempted on the *same* native backend before either
  /// forcing media_kit's software decoder on Windows (see
  /// [_mediaKitSoftwareDecode]) or finally showing the error screen —
  /// mirrors how Netflix/YouTube-style players silently ride out a
  /// transient network blip instead of immediately bothering the viewer.
  static const int _kMaxNativeRetries = 2;

  /// How long media_kit gets, once audio is confirmed playing, to also
  /// report a decoded video frame size before this is treated as "audio
  /// with no picture" rather than just a slow-starting video track. Kept
  /// short so a hardware-decode failure that never throws an exception —
  /// picture silently never attaches — still gets the software-decoder
  /// fallback (see [_mediaKitSoftwareDecode]) forced on it promptly instead
  /// of leaving the screen black for a long, undiagnosable stretch.
  static const Duration _kVideoTrackGracePeriod = Duration(seconds: 4);

  String get _url =>
      resolveStudentVideoUrl(widget.video, apiBaseUrl: widget.apiBaseUrl);

  bool get _isNativeVideo => isDirectVideoUrl(_url, widget.video);

  /// media_kit (libmpv) is used **only on Windows**. Android, iOS and
  /// iPadOS play every direct MP4/HLS source exclusively through
  /// `video_player` — ExoPlayer on Android, AVFoundation on iOS/iPadOS —
  /// which is Flutter's own officially maintained plugin for exactly this
  /// and does not share the Surface/TextureView attachment bug documented
  /// against media_kit on Android (audio decodes and plays while the
  /// hardware video surface silently never attaches, leaving the picture
  /// black). Using one real decoder pipeline per mobile platform, instead
  /// of routing Android through a third-party native renderer, is what
  /// actually eliminates that failure mode rather than working around it.
  bool get _usesMediaKit =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.windows;

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
    return uri
        .replace(
          queryParameters: {
            ...uri.queryParameters,
            'mute': '1',
            'controls': '0',
          },
        )
        .toString();
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
        _error = tr('video.slowLoad');
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
      _error = tr('video.badYoutubeLink');
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
          () => _error =
              trf('video.pageLoadFailed', {'code': error.errorCode}),
        );
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
    } else if (value.playerState == PlayerState.playing) {
      _completionReported = false;
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
        return tr('video.embedBlocked');
      case YoutubeError.videoNotFound:
      case YoutubeError.cannotFindVideo:
        return tr('video.notFound');
      case YoutubeError.invalidParam:
      case YoutubeError.html5Error:
      case YoutubeError.unknown:
      case YoutubeError.none:
        return "${tr('video.playFailed')}.";
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

  Future<void> _openVideo() async {
    final uri = Uri.tryParse(_url);
    final isWebRelativeUrl = kIsWeb && _url.startsWith('/');
    if (uri == null ||
        (!(uri.scheme == 'http' || uri.scheme == 'https') &&
            !isWebRelativeUrl)) {
      setState(() {
        _error = tr('video.needsHttp');
      });
      return;
    }

    if (_usesMediaKit) {
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
  /// 2. On Windows only, where media_kit is still used (see
  ///    [_usesMediaKit]): if hardware acceleration is still on, force its
  ///    software decoder ([_mediaKitSoftwareDecode]) and reopen. A
  ///    hardware-accelerated decode that is still failing once the
  ///    same-backend retries are exhausted is a GPU/codec incompatibility,
  ///    not a network hiccup — retrying the same hardware path again would
  ///    just reproduce it, while forcing software decoding reliably
  ///    produces a frame at some extra CPU cost.
  ///
  /// Android/iOS/iPadOS play exclusively through `video_player`
  /// (ExoPlayer/AVFoundation), which has no separate hardware/software
  /// decoder switch to force from here — the platform's own decoder
  /// pipeline already handles that class of fallback internally — so step 2
  /// never applies there and a same-backend retry failing is final.
  ///
  /// Only after every option is exhausted does it surface the error screen.
  Future<void> _handleNativePlaybackError(Object error) async {
    if (!mounted || _nativeRetryScheduled) return;
    final message = error is TimeoutException
        ? tr('video.slowLoad')
        : error.toString();

    final canRetrySameBackend = _nativeRetryAttempt < _kMaxNativeRetries;
    final canForceSoftwareDecode =
        !canRetrySameBackend && _usesMediaKit && !_mediaKitSoftwareDecode;

    if (!canRetrySameBackend && !canForceSoftwareDecode) {
      setState(() => _error = message);
      return;
    }

    _nativeRetryScheduled = true;
    _videoTrackWatchdogTimer?.cancel();
    _closeFullscreen();
    await _player?.dispose();
    await _networkController?.dispose();
    _player = null;
    _videoController = null;
    _networkController = null;

    if (canRetrySameBackend) {
      _nativeRetryAttempt++;
      await Future.delayed(Duration(seconds: _nativeRetryAttempt * 2));
    } else {
      _mediaKitSoftwareDecode = true;
    }

    _nativeRetryScheduled = false;
    if (!mounted) return;
    await _openVideo();
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
        if (mounted) setState(() => _nativeCompleted = true);
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
          .timeout(_kLoadTimeout);
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
        if (mounted) setState(() => _nativeCompleted = true);
        widget.onCompleted?.call();
      } else if (_nativeCompleted &&
          value.isInitialized &&
          value.position < value.duration &&
          mounted) {
        setState(() => _nativeCompleted = false);
      }
      if (!mounted || !value.hasError) return;
      _handleNativePlaybackError(
        Exception(value.errorDescription ?? tr('video.sourceFailed')),
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
    _closeFullscreen();
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
    final player = Stack(
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
            onToggleFullscreen: _toggleFullscreen,
          )
        else
          const ColoredBox(
            color: Colors.black,
            child: Center(
              child: CircularProgressIndicator(color: Color(0xFF5EEAD4)),
            ),
          ),
        if (_error != null)
          _buildError(tr('video.playFailed'), onRetry: _retryNativePlayback),
        if (_nativeCompleted && _error == null && !widget.compact)
          Center(
            child: FilledButton.icon(
              onPressed: _replayNativeVideo,
              icon: const Icon(Icons.replay_rounded, size: 34),
              label: Text(tr('video.replay')),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xE60B8693),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 16,
                ),
                textStyle: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
      ],
    );
    // While the video is enlarged, Back shrinks it rather than leaving the
    // page underneath.
    return PopScope(
      canPop: !_isFullscreen,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _closeFullscreen();
      },
      child: player,
    );
  }

  Future<void> _replayNativeVideo() async {
    if (_usesMediaKit) {
      final player = _player;
      if (player == null) return;
      await player.seek(Duration.zero);
      await player.play();
    } else {
      final controller = _networkController;
      if (controller == null || !controller.value.isInitialized) return;
      await controller.seekTo(Duration.zero);
      await controller.play();
    }
    if (!mounted) return;
    setState(() {
      _nativeCompleted = false;
      _completionReported = false;
    });
  }

  /// The layer covering the screen while the video is enlarged. It shows
  /// this state's own controller, so it must be gone before that controller
  /// is disposed.
  OverlayEntry? _fullscreenEntry;

  bool get _isFullscreen => _fullscreenEntry != null;

  void _toggleFullscreen() =>
      _isFullscreen ? _closeFullscreen() : _openFullscreen();

  /// Enlarges the MP4 in place to cover the whole screen, however the
  /// device is being held — upright stays upright, sideways stays
  /// sideways. Nothing turns the device and nothing is pushed: the same
  /// controller is drawn once more in a layer over everything, so the
  /// picture carries on exactly where it was, playing or paused.
  ///
  /// It used to push a route that forced landscape. Forcing the device
  /// round is what made the button feel broken: sideways it looked like
  /// nothing happened, upright the whole screen spun under the student's
  /// hands.
  void _openFullscreen() {
    final controller = _networkController;
    if (controller == null || _isFullscreen) return;
    final entry = OverlayEntry(
      builder: (_) => _FullscreenVideoLayer(
        controller: controller,
        onClose: _closeFullscreen,
      ),
    );
    Overlay.of(context, rootOverlay: true).insert(entry);
    // The lesson and cinema cards already run immersive; asserted again so
    // the layer has the whole screen even if the platform drifted back.
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    setState(() => _fullscreenEntry = entry);
  }

  /// Back to the video's place in the page. Also called before the
  /// controller the layer shows is disposed — a retry, a fallback, or this
  /// player leaving — so the layer never draws a released texture.
  void _closeFullscreen() {
    final entry = _fullscreenEntry;
    if (entry == null) return;
    _fullscreenEntry = null;
    // `remove` defers itself when called mid-frame (from dispose); the
    // entry is only released once that removal has gone through.
    entry.remove();
    WidgetsBinding.instance.addPostFrameCallback((_) => entry.dispose());
    if (mounted && SchedulerBinding.instance.schedulerPhase !=
        SchedulerPhase.persistentCallbacks) {
      setState(() {});
    }
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
            tr('video.playFailed'),
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
              tr('video.playFailed'),
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
    return YoutubeValueBuilder(
      controller: controller,
      buildWhen: (previous, current) =>
          previous.fullScreenOption != current.fullScreenOption,
      builder: (context, value) => PopScope(
        canPop: !value.fullScreenOption.enabled,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop && value.fullScreenOption.enabled) {
            _exitYoutubeFullscreen(controller);
          }
        },
        child: Stack(
          fit: StackFit.expand,
          children: [
            YoutubePlayer(
              key: ValueKey('youtube-$_ytReloadTicket'),
              controller: controller,
              aspectRatio: 16 / 9,
              backgroundColor: Colors.black,
              // THE fix for "the shrink button does nothing and Back is
              // dead". Left on (its default), the player re-enters
              // fullscreen from didChangeMetrics whenever the device is
              // physically landscape and fullscreen is off — and unlike
              // its auto-*exit*, that auto-*enter* does not check whether
              // the state was locked deliberately. So on a tablet held in
              // landscape every exit was undone within a frame: the button
              // looked broken, and Back could never pop because the
              // package's own PopScope saw fullscreen switched straight
              // back on. Fullscreen is now entered only when someone asks
              // for it — the player's own button still works, since that
              // arrives as a controller event, not through rotation.
              autoFullScreen: false,
              // On Android/iOS, real device fullscreen is rendered by this
              // package through its own app-level OverlayPortal — which
              // paints *above* this widget's own Stack, hiding the
              // PositionedDirectional back button below entirely. Only
              // `controlsBuilder` is actually composited inside that
              // overlay, so it's the only reliable place to put a visible
              // "رجوع" button while a YouTube video is fullscreen (matching
              // the dedicated back button the direct-MP4 player shows in
              // its own fullscreen route).
              controlsBuilder: (context, isFullscreen) {
                if (!isFullscreen) return const SizedBox.shrink();
                return SafeArea(
                  child: Stack(
                    children: [
                      PositionedDirectional(
                        start: 12,
                        top: 12,
                        child: _FullscreenBackButton(
                          onPressed: () => _handleYoutubeBack(controller),
                        ),
                      ),
                      // Our own shrink button, opposite the back button.
                      //
                      // The player draws a fullscreen toggle of its own
                      // inside the video, but the student reported pressing
                      // it while fullscreen and nothing happening. That
                      // control lives in the embedded page and only reaches
                      // Flutter as an event the page chooses to send, so
                      // when it does not arrive there is no way to act on
                      // it from here. This button is ours: it reads the
                      // controller's own state and drives it directly, so
                      // there is always a way out that does not depend on
                      // the page reporting anything.
                      PositionedDirectional(
                        end: 12,
                        top: 12,
                        child: _FullscreenExitButton(
                          onPressed: () => _exitYoutubeFullscreen(controller),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
            if (value.fullScreenOption.enabled)
              PositionedDirectional(
                top: 12,
                start: 12,
                child: SafeArea(
                  child: _FullscreenBackButton(
                    onPressed: () => _handleYoutubeBack(controller),
                  ),
                ),
              ),
            if (_error != null)
              _buildError(
                tr('video.playFailed'),
                onRetry: _retryYoutube,
                externalUrl: _externalYoutubeUrl,
              ),
          ],
        ),
      ),
    );
  }

  /// Leaves fullscreen only if it is actually in it, so a stray press
  /// can never toggle the player *into* fullscreen from a control whose
  /// whole purpose is getting out of it.
  ///
  /// This used to also force the device to portrait, on the theory that
  /// the exit could not be seen otherwise. That was treating the symptom.
  /// The real reason a tablet held in landscape appeared to ignore both
  /// the shrink button and Back is [YoutubePlayer.autoFullScreen], which
  /// is now off — see the comment at the widget. With that loop gone the
  /// exit simply holds, and there is no reason to spin the student's
  /// tablet around against their wishes.
  void _exitYoutubeFullscreen(YoutubePlayerController controller) {
    if (!controller.value.fullScreenOption.enabled) return;
    controller.exitFullScreen();
    // The player rebuilds from the controller's own stream, so no
    // setState is needed — and calling one here would be the wrong fix
    // anyway: the state that matters lives on the controller, not on this
    // widget.
  }

  /// The back button drawn over the video, and the device's own Back key,
  /// both follow the same two steps: the first press leaves fullscreen,
  /// and a press with the video already at its normal size closes the
  /// screen. Nothing here waits on the platform, so both act on the frame
  /// they are pressed.
  void _handleYoutubeBack(YoutubePlayerController controller) {
    if (controller.value.fullScreenOption.enabled) {
      _exitYoutubeFullscreen(controller);
      return;
    }
    Navigator.of(context).maybePop();
  }

  Future<void> _retryNativePlayback() async {
    _videoTrackWatchdogTimer?.cancel();
    _closeFullscreen();
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
                    label: Text(tr('action.retry')),
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
                      label: Text(tr('video.openYoutube')),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: BorderSide(color: Colors.white.withValues(alpha: 0.7)),
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
    required this.onToggleFullscreen,
    this.fullscreen = false,
  });

  final VideoPlayerController controller;

  /// Opens the fullscreen route from the card, or closes it from inside.
  final VoidCallback onToggleFullscreen;
  final bool fullscreen;

  @override
  State<_NetworkVideoSurface> createState() => _NetworkVideoSurfaceState();
}

class _NetworkVideoSurfaceState extends State<_NetworkVideoSurface> {
  bool _showControls = true;

  /// Whether the enlarged video fills the screen. On by default: the
  /// picture covers every pixel, at its true proportions, with whatever
  /// overflows the screen's shape cropped off. `contain` left black bars
  /// above and below instead, which is the "squeezed in the middle"
  /// report. The student can switch to the whole picture from the control
  /// bar.
  bool _fill = true;

  /// Hides the controls after a few idle seconds of playback.
  ///
  /// Restarted on every interaction, and never started while the video is
  /// paused: a student who has just paused is looking at the controls, and
  /// having them vanish underneath is how the play button became
  /// impossible to find again.
  Timer? _hideTimer;

  static const _idleBeforeHide = Duration(seconds: 3);

  @override
  void initState() {
    super.initState();
    _restartHideTimer();
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    super.dispose();
  }

  void _restartHideTimer() {
    _hideTimer?.cancel();
    if (!widget.controller.value.isPlaying) return;
    _hideTimer = Timer(_idleBeforeHide, () {
      if (mounted) setState(() => _showControls = false);
    });
  }

  /// The tap on the video surface itself — reveals the controls, or hides
  /// them again if they are already up.
  void _toggleControls() {
    setState(() => _showControls = !_showControls);
    if (_showControls) _restartHideTimer();
  }

  Future<void> _togglePlayback() async {
    final controller = widget.controller;
    if (controller.value.isPlaying) {
      await controller.pause();
    } else {
      final value = controller.value;
      final ended =
          value.isInitialized &&
          value.duration > Duration.zero &&
          value.position >= value.duration;
      if (ended) {
        await controller.seekTo(Duration.zero);
      }
      await controller.play();
    }
    if (!mounted) return;
    // Always ends with the controls up, so the button the student just
    // pressed is still under their finger and shows its new state.
    setState(() => _showControls = true);
    _restartHideTimer();
  }

  void _toggleFill(bool current) {
    setState(() {
      _fill = !current;
      _showControls = true;
    });
    _restartHideTimer();
  }

  @override
  Widget build(BuildContext context) {
    final rawSize = widget.controller.value.size;
    final videoSize = rawSize.isEmpty ? const Size(16, 9) : rawSize;
    // In fullscreen the controls keep clear of the camera cutout and the
    // rounded corners; the picture itself runs edge to edge underneath.
    final insets = widget.fullscreen
        ? MediaQuery.paddingOf(context)
        : EdgeInsets.zero;

    return Builder(
      builder: (context) {
        // Cropped in the card, where the frame is 16:9 and a portrait
        // source must still fill its width — and enlarged, where the
        // screen is filled edge to edge unless the student asks for the
        // whole picture.
        final fill = widget.fullscreen ? _fill : true;

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          // Tapping the video surface only reveals/hides the controls.
          // Playback changes are intentionally restricted to the dedicated
          // play button so an incidental touch cannot pause a lesson or
          // cinema video.
          onTap: _toggleControls,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Positioned.fill(
                child: ColoredBox(
                  color: Colors.black,
                  child: FittedBox(
                    fit: fill ? BoxFit.cover : BoxFit.contain,
                    clipBehavior: Clip.hardEdge,
                    child: SizedBox(
                      width: videoSize.width,
                      height: videoSize.height,
                      child: VideoPlayer(widget.controller),
                    ),
                  ),
                ),
              ),
              // ExoPlayer/AVPlayer both surface network stalls as a
              // transient "buffering" state rather than an error. Without
              // this, a slow connection just freezes the frame with no
              // feedback, which reads as "the video is broken" even though
              // it's still trying.
              ValueListenableBuilder<VideoPlayerValue>(
                valueListenable: widget.controller,
                builder: (context, value, _) {
                  final ended =
                      value.isInitialized &&
                      value.duration > Duration.zero &&
                      value.position >= value.duration;
                  if (!value.isBuffering || value.isPlaying || ended) {
                    return const SizedBox.shrink();
                  }
                  return const IgnorePointer(
                    child: CircularProgressIndicator(color: Color(0xFF5EEAD4)),
                  );
                },
              ),
              // The big centre button, and it is a real button: it drives
              // playback directly and stops the tap, so the surface's own
              // "toggle the controls" handler underneath never sees it.
              if (_showControls)
                Material(
                  color: Colors.transparent,
                  shape: const CircleBorder(),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: _togglePlayback,
                    customBorder: const CircleBorder(),
                    child: Semantics(
                      button: true,
                      label: widget.controller.value.isPlaying
                          ? tr('video.pause')
                          : tr('video.play'),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: Colors.black.withAlpha(110),
                          shape: BoxShape.circle,
                        ),
                        child: Padding(
                          // Roomy enough to be an easy target for a child's
                          // finger rather than a 34px glyph.
                          padding: const EdgeInsets.all(18),
                          child: Icon(
                            widget.controller.value.isPlaying
                                ? Icons.pause_rounded
                                : Icons.play_arrow_rounded,
                            color: Colors.white,
                            size: 40,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              // The control bar is the last child, so nothing in this stack
              // sits above it to take its taps.
              if (_showControls)
                Positioned(
                  left: 12 + insets.left,
                  right: 12 + insets.right,
                  bottom: 10 + insets.bottom,
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
                                ? tr('video.pause')
                                : tr('video.play'),
                            onPressed: _togglePlayback,
                            icon: Icon(
                              widget.controller.value.isPlaying
                                  ? Icons.pause_rounded
                                  : Icons.play_arrow_rounded,
                              color: Colors.white,
                            ),
                          ),
                          const Spacer(),
                          if (widget.fullscreen)
                            IconButton(
                              tooltip: fill
                                  ? tr('video.fitWhole')
                                  : tr('video.fillScreen'),
                              onPressed: () => _toggleFill(fill),
                              icon: Icon(
                                fill
                                    ? Icons.fit_screen_rounded
                                    : Icons.zoom_out_map_rounded,
                                color: Colors.white,
                              ),
                            ),
                          IconButton(
                            tooltip: widget.fullscreen
                                ? tr('video.exitFullscreen')
                                : tr('video.fullscreen'),
                            onPressed: widget.onToggleFullscreen,
                            icon: Icon(
                              widget.fullscreen
                                  ? Icons.fullscreen_exit_rounded
                                  : Icons.fullscreen_rounded,
                              color: Colors.white,
                              size: 30,
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
      },
    );
  }
}

/// The enlarged MP4: the card's own controller, drawn over the whole screen
/// in whatever orientation the device is already in.
///
/// A layer in the root overlay rather than a route, so nothing is pushed,
/// nothing reloads, and the page underneath keeps its place. The picture
/// fits the screen whole ([BoxFit.contain]) — the student can switch to
/// filling it from the control bar.
class _FullscreenVideoLayer extends StatelessWidget {
  const _FullscreenVideoLayer({
    required this.controller,
    required this.onClose,
  });

  final VideoPlayerController controller;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // The whole screen, edge to edge — no SafeArea and no fixed
          // aspect-ratio box around the picture.
          SizedBox.expand(
            child: _NetworkVideoSurface(
              controller: controller,
              onToggleFullscreen: onClose,
              fullscreen: true,
            ),
          ),
          // Only the back button keeps clear of the notch and rounded
          // corners — the picture itself does not need to.
          SafeArea(
            child: Align(
              alignment: AlignmentDirectional.topStart,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: _FullscreenBackButton(onPressed: onClose),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The app's own "leave fullscreen" control, sharing the back button's
/// look so the two read as a pair at opposite corners of the video.
class _FullscreenExitButton extends StatelessWidget {
  const _FullscreenExitButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: tr('video.shrink'),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(24),
          child: Ink(
            decoration: BoxDecoration(
              color: const Color(0xED071425),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: const Color(0x99FFFFFF), width: 1.5),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x66000000),
                  blurRadius: 14,
                  offset: Offset(0, 5),
                ),
              ],
            ),
            padding: const EdgeInsets.all(11),
            child: const Icon(
              Icons.fullscreen_exit_rounded,
              color: Colors.white,
              size: 24,
            ),
          ),
        ),
      ),
    );
  }
}

class _FullscreenBackButton extends StatelessWidget {
  const _FullscreenBackButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: tr('video.backToCard'),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(24),
          child: Ink(
            decoration: BoxDecoration(
              color: const Color(0xED071425),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: const Color(0x99FFFFFF), width: 1.5),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x66000000),
                  blurRadius: 14,
                  offset: Offset(0, 5),
                ),
              ],
            ),
            padding: const EdgeInsetsDirectional.fromSTEB(14, 10, 16, 10),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.arrow_back_rounded,
                    color: Colors.white, size: 25),
                const SizedBox(width: 7),
                Text(
                  tr('video.back'),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
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

String resolveStudentVideoUrl(LessonVideo video, {String apiBaseUrl = ''}) {
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
      return Uri.https('www.youtube.com', '/embed/$id', const {
        'autoplay': '1',
        'playsinline': '1',
        'rel': '0',
        'modestbranding': '1',
      }).toString();
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
