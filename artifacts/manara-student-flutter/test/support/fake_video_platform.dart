import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

/// منصّةُ فيديو للاختبارات: تُعلن طولَ فيلم الترحيب وتُبلغ انتهاءه، أو تفشل
/// فوراً بـ[fail].
///
/// ── ولماذا الفشلُ الفوريّ لاختبارات الافتتاحية ──
/// بلا منصّةٍ مسجّلة لا يفشل الفيلمُ في الاختبار بل يبقى ينتظر، فلا تبدأ
/// الافتتاحيةُ إلا بعد مهلة الفكّ — وتنزاح عن توقيتها كلُّ ثانيةٍ تختبرها.
/// والمنصّةُ الفاشلة تجعلها تبدأ من أوّل إطارٍ كما على جهازٍ لا يفكّ الفيلم.
class FakeVideoPlatform extends VideoPlayerPlatform {
  FakeVideoPlatform({this.fail = false});

  final bool fail;
  final calls = <String>[];
  final _events = <int, StreamController<VideoEvent>>{};
  double? volume;
  String? asset;
  var _next = 0;

  void complete() {
    for (final events in _events.values) {
      events.add(VideoEvent(eventType: VideoEventType.completed));
    }
  }

  @override
  Future<void> init() async {}

  @override
  Future<int?> createWithOptions(VideoCreationOptions options) async {
    calls.add('create');
    asset = options.dataSource.asset;
    if (fail) {
      throw PlatformException(code: 'no_decoder', message: 'no decoder');
    }
    final id = _next++;
    _events[id] = StreamController<VideoEvent>();
    return id;
  }

  @override
  Stream<VideoEvent> videoEventsFor(int playerId) {
    final events = _events[playerId]!;
    scheduleMicrotask(() => events.add(VideoEvent(
          eventType: VideoEventType.initialized,
          duration: const Duration(milliseconds: 12546),
          size: const Size(1080, 1920),
        )));
    return events.stream;
  }

  @override
  Future<void> play(int playerId) async => calls.add('play');

  @override
  Future<void> pause(int playerId) async => calls.add('pause');

  @override
  Future<void> setVolume(int playerId, double volume) async =>
      this.volume = volume;

  @override
  Future<void> setLooping(int playerId, bool looping) async {}

  @override
  Future<void> setPlaybackSpeed(int playerId, double speed) async {}

  @override
  Future<void> seekTo(int playerId, Duration position) async {}

  @override
  Future<Duration> getPosition(int playerId) async => Duration.zero;

  @override
  Future<void> setMixWithOthers(bool mixWithOthers) async {}

  @override
  Widget buildViewWithOptions(VideoViewOptions options) =>
      const ColoredBox(key: ValueKey('fake-film'), color: Color(0xFFDDCCAA));

  @override
  Future<void> dispose(int playerId) async {
    calls.add('dispose');
    await _events.remove(playerId)?.close();
  }
}
