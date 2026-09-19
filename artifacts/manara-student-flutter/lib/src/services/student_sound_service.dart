import 'dart:async';
import 'dart:math' as math;

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../l10n/student_strings.dart';

import 'audio_service.dart';
import 'student_settings.dart';

enum StudentSoundCue {
  navigation,
  answerSelected,
  success,
  warning,
  loginSuccess,
  welcome,
  gameReward,
  levelUp,
}

/// A testable gate that avoids noisy repeated taps and competing feedback.
class StudentSoundGate {
  StudentSoundGate({DateTime Function()? now}) : _now = now ?? DateTime.now;

  final DateTime Function() _now;
  final Map<StudentSoundCue, DateTime> _lastPlayed = {};

  bool allow(StudentSoundCue cue, {Duration cooldown = const Duration(milliseconds: 220)}) {
    final current = _now();
    final previous = _lastPlayed[cue];
    if (previous != null && current.difference(previous) < cooldown) return false;
    _lastPlayed[cue] = current;
    return true;
  }
}

/// Owns student-facing sounds. Voices and UI feedback have separate players so
/// a short confirmation never cuts off the welcome message, while each group
/// is still stopped before replaying to avoid overlap.
///
/// It also watches the app's lifecycle, so nothing keeps sounding once the
/// screen is locked or the app leaves the foreground — see
/// [didChangeAppLifecycleState].
class StudentSoundService with WidgetsBindingObserver {
  StudentSoundService._();

  static final StudentSoundService instance = StudentSoundService._();
  static const _mutedKey = 'manara_student_sound_muted';

  final ValueNotifier<bool> muted = ValueNotifier(false);
  final StudentSoundGate _gate = StudentSoundGate();
  final AudioPlayer _effectsPlayer = AudioPlayer();
  final AudioPlayer _voicePlayer = AudioPlayer();

  /// The deal has its own player so a card landing cannot cut short a cue
  /// already sounding on the effects player — and so the rail's own cards
  /// cut each other, which is what makes a run of them read as a riffle.
  final AudioPlayer _dealPlayer = AudioPlayer();

  /// The background music. Its own player because it is the only sound that
  /// is supposed to still be playing while everything else comes and goes.
  final AudioPlayer _ambientPlayer = AudioPlayer();

  /// Whether the music has been asked for at all.
  ///
  /// Set once, by the hub, and never cleared: the music is meant to carry on
  /// across every screen after that. Deliberately not a per-screen claim —
  /// a claim released on dispose cuts the loop on every route change, which
  /// is the gap this replaced.
  bool _ambientWanted = false;

  /// Set while a lesson is open, so the music steps aside for the teaching.
  bool _ambientSuspended = false;
  bool _ambientPlaying = false;

  /// Set while the screen is locked or the app is in the background.
  bool _backgrounded = false;

  /// The music was paused, not stopped, by going to the background, so it
  /// picks up where it left off instead of restarting the loop.
  bool _ambientHeld = false;
  late final AudioService _feedbackAudio = AudioService(muted: muted);
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
    WidgetsBinding.instance.addObserver(this);
    try {
      // Why the music stopped the instant a card was touched.
      //
      // `audioplayers` defaults every player to `AudioContextConfigFocus.gain`,
      // which asks Android for *exclusive* audio focus each time it starts a
      // sound. The tap was therefore telling the system it was now the only
      // thing playing — and the background loop, a separate player inside this
      // same app, was duly stopped. Nothing in this class had asked for that;
      // it was the default doing exactly what it says.
      //
      // `mixWithOthers` asks for no focus at all, so a tap, a card landing and
      // the music simply sum. It also means the app no longer interrupts
      // whatever the student had playing before they opened it.
      final mixing = AudioContext(
        android: const AudioContextAndroid(
          isSpeakerphoneOn: false,
          stayAwake: false,
          contentType: AndroidContentType.music,
          usageType: AndroidUsageType.media,
          audioFocus: AndroidAudioFocus.none,
        ),
        iOS: AudioContextIOS(
          category: AVAudioSessionCategory.ambient,
          options: const {AVAudioSessionOptions.mixWithOthers},
        ),
      );
      await AudioPlayer.global.setAudioContext(mixing);
      // And on every player individually.
      //
      // Setting the global context alone was not enough, and this is why the
      // music kept cutting out after that was supposedly fixed: the global
      // context is the default handed to players *created after* it is set,
      // and all four of these are final fields, constructed the moment this
      // singleton is first touched — which happens before `initialize` runs.
      // They had already taken a copy of the old default, with its exclusive
      // focus request, and kept it.
      for (final player in [
        _effectsPlayer,
        _voicePlayer,
        _dealPlayer,
        _ambientPlayer,
      ]) {
        await player.setAudioContext(mixing);
      }
    } catch (_) {
      // An older plugin or a platform without audio: the app still runs, the
      // tap may just duck the music on that device.
    }
    try {
      final preferences = await SharedPreferences.getInstance();
      muted.value = preferences.getBool(_mutedKey) ?? false;
      await _effectsPlayer.setReleaseMode(ReleaseMode.stop);
      await _voicePlayer.setReleaseMode(ReleaseMode.stop);
      await _dealPlayer.setReleaseMode(ReleaseMode.stop);
      await _feedbackAudio.initialize();
    } catch (_) {
      // The student experience remains usable if local preferences are absent.
    }
  }

  Future<void> toggleMuted() async {
    final next = !muted.value;
    muted.value = next;
    if (next) {
      await _effectsPlayer.stop();
      await _voicePlayer.stop();
      await _dealPlayer.stop();
      await stopSpeaking();
      await _feedbackAudio.stop();
    }
    // The music follows the switch in both directions: muting has to silence
    // a loop that is already running, and unmuting has to bring it back for
    // whatever screen still wants it.
    await _syncAmbient();
    try {
      final preferences = await SharedPreferences.getInstance();
      await preferences.setBool(_mutedKey, next);
    } catch (_) {}
  }

  /// Silences everything the moment the screen locks or the app leaves the
  /// foreground, and brings only the music back on return.
  ///
  /// Without this the players simply carried on: `audioplayers` has no idea
  /// the screen went dark, and with `stayAwake: false` and no audio focus
  /// nothing else stops them either — so a tablet in a bag kept playing the
  /// loop and whatever line was mid-sentence.
  ///
  /// `inactive` counts as leaving too: it is the first state a lock passes
  /// through, and on some devices the only one before the process is frozen.
  /// A spoken line or a chime cut off there is not resumed — half a sentence
  /// minutes later means nothing. The music is, from where it paused, and
  /// only if the screen that was showing still wants it.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (!_backgrounded) return;
      _backgrounded = false;
      unawaited(_syncAmbient());
      return;
    }
    if (_backgrounded) return;
    _backgrounded = true;
    _applauseCancelled = true;
    // The line is being cut, so nothing is left for the music to duck under.
    _voiceClip = null;
    _duckAmbient(false);
    unawaited(() async {
      for (final stop in [
        _voicePlayer.stop,
        _effectsPlayer.stop,
        _dealPlayer.stop,
        _feedbackAudio.stop,
      ]) {
        try {
          await stop();
        } catch (_) {}
      }
    }());
    unawaited(_syncAmbient());
  }

  void play(StudentSoundCue cue) {
    unawaited(_play(cue));
  }

  /// Speaks the welcome and reports when it has actually finished.
  ///
  /// The hub holds its cards back until this fires. Waiting on the player
  /// rather than on a guessed delay is the point — a fixed wait is too short
  /// on a slow device and pointless on a muted one.
  ///
  /// [onComplete] fires once, when the voice has finished — or immediately if
  /// there is nothing to wait for because sound is muted.
  ///
  /// It deliberately owns no timeout of its own. A cap belongs to the caller,
  /// which can cancel it when its screen goes away; a timer started in here
  /// would outlive that screen, and a pending timer after teardown is both a
  /// leak and a test failure. On a device with no audio plugin the completion
  /// event never arrives, and the caller's cap is what moves things along.
  void speakWelcome({VoidCallback? onComplete}) {
    if (muted.value) {
      onComplete?.call();
      return;
    }
    var fired = false;
    void finish() {
      if (fired) return;
      fired = true;
      onComplete?.call();
    }

    // `first` unsubscribes itself as soon as the event arrives.
    unawaited(_voicePlayer.onPlayerComplete.first.then(
      (_) => finish(),
      onError: (_) => finish(),
    ));
    play(StudentSoundCue.welcome);
  }

  /// Speaks the line for the portal [portalKey] — `portal.lesson`,
  /// `portal.games` and so on — in the app's language, cutting off whatever
  /// was being said.
  ///
  /// **Recorded, not synthesised on the device.** This used to hand the text
  /// to `flutter_tts`, and so to whatever engine the phone shipped with. On
  /// most phones that engine has no Arabic voice worth the name: asking it for
  /// `ar-SA` either failed or found a voice that read the line like a machine,
  /// straight after a welcome recorded in a natural one. No amount of locale
  /// probing fixes a device that does not have a good voice.
  ///
  /// The Arabic clips are recordings supplied for the app, produced the same
  /// way as the hub's welcome (`manara-arabic-student-welcome.mp3`), so the
  /// greeting and the cards are one voice. What the student hears does not
  /// depend on the phone at all. Each clip is played at the welcome's
  /// loudness — see [voiceVolume].
  ///
  /// Every failure here is swallowed. A missing clip or a platform with no
  /// audio is not a reason a lesson should not open.
  Future<void> speakPortal(String portalKey) async {
    if (muted.value || _backgrounded) return;
    final language = StudentSettings.isArabic ? 'ar' : 'en';
    try {
      final asset = portalVoiceAsset(portalKey, language, await _bundledAssets());
      await _voicePlayer.stop();
      _voiceClip = asset;
      await _voicePlayer.play(AssetSource(asset), volume: voiceVolume(asset));
    } catch (_) {
      // No audio on this device: the screen opens in silence.
    }
  }

  /// How loud the hub's welcome actually sounds: its speech RMS (0.122)
  /// at the 0.78 it is played at. Every spoken line is brought to this.
  static const _welcomeLoudness = 0.122 * 0.78;

  /// Speech RMS of each clip in `assets/audio/voice/` — measured over its
  /// voiced frames, not its silences.
  ///
  /// The Arabic clips are recordings supplied for the app and arrive at
  /// their own levels, 5.5 dB apart from quietest to loudest (0.092 to
  /// 0.174). One volume for all of them made some cards shout and others
  /// mumble; dividing by the measured level gives each the same loudness
  /// as the welcome, without re-encoding the recordings themselves.
  ///
  /// Replace a clip, re-measure it here. `portal_voice_test.dart` fails
  /// for a clip that has no entry.
  @visibleForTesting
  static const Map<String, double> voiceRms = {
    'challenge_ar': 0.174,
    'challenge_en': 0.147,
    'chat_ar': 0.133,
    'chat_en': 0.136,
    'cinema_ar': 0.119,
    'cinema_en': 0.142,
    'games_ar': 0.137,
    'games_en': 0.144,
    'generic_ar': 0.086,
    'generic_en': 0.151,
    'lesson_ar': 0.137,
    'lesson_en': 0.142,
    'meeting_ar': 0.148,
    'meeting_en': 0.146,
    'path_ar': 0.092,
    'path_en': 0.148,
    'personality_ar': 0.129,
    'personality_en': 0.155,
    'quiz_ar': 0.131,
    'quiz_en': 0.132,
    'solver_ar': 0.154,
    'solver_en': 0.160,
    'tutor_ar': 0.138,
    'tutor_en': 0.145,
  };

  /// The player volume that makes [asset] as loud as the hub's welcome.
  ///
  /// Capped at full volume: a clip quieter than the welcome plays as loud
  /// as it can rather than being pushed into distortion.
  @visibleForTesting
  static double voiceVolume(String asset) {
    final file = asset.split('/').last;
    final name = file.endsWith('.mp3')
        ? file.substring(0, file.length - '.mp3'.length)
        : file;
    final rms = voiceRms[name];
    if (rms == null) return 0.6;
    return (_welcomeLoudness / rms).clamp(0.0, 1.0);
  }

  /// The clip the voice player was last asked to play.
  String? _voiceClip;

  static String _pathClip(String language) => 'audio/voice/path_$language.mp3';

  /// Greets the student on the path-choosing screen: «مَرْحَبًا يَا بَطَل!
  /// اِخْتَرْ مَسَارَكَ التَّعْلِيمِيَّ…» — `path_ar.mp3`, a supplied recording in
  /// the same voice as the hub's welcome and the portal lines.
  ///
  /// The music, if it is playing, is lowered underneath the line and brought
  /// back when the line ends or is stopped — the sentence is the point here.
  Future<void> speakPath() async {
    if (muted.value || _backgrounded) return;
    final asset = _pathClip(StudentSettings.isArabic ? 'ar' : 'en');
    try {
      await _voicePlayer.stop();
      _voiceClip = asset;
      _duckAmbient(true);
      unawaited(_voicePlayer.onPlayerComplete.first.then(
        (_) => _duckAmbient(false),
        onError: (_) => _duckAmbient(false),
      ));
      await _voicePlayer.play(AssetSource(asset), volume: voiceVolume(asset));
    } catch (_) {
      _duckAmbient(false);
      // No audio on this device: the path is still there to choose.
    }
  }

  /// Stops the path greeting if it is still what is being said.
  ///
  /// Only that line: the path screen is torn down after the hub has already
  /// started its own welcome on the same player, and a blanket stop there
  /// would cut the hub's greeting off instead.
  Future<void> stopPathVoice() async {
    final clip = _voiceClip;
    if (clip == null || !clip.startsWith('audio/voice/path_')) return;
    await stopSpeaking();
  }

  /// The clip to play for [portalKey] in [language], given the asset paths
  /// the app was built with.
  ///
  /// Falls back to the generic line when a portal has no clip of its own —
  /// a portal added to the rail before anyone re-ran the recording script
  /// should still greet the student, not fail to play a file that is not
  /// there.
  ///
  /// The path is relative to `assets/`, the way [AssetSource] takes it; the
  /// manifest lists it with the prefix.
  @visibleForTesting
  static String portalVoiceAsset(
    String portalKey,
    String language,
    Set<String> bundled,
  ) {
    final name = portalKey.startsWith('portal.')
        ? portalKey.substring('portal.'.length)
        : portalKey;
    final own = 'audio/voice/${name}_$language.mp3';
    if (bundled.contains('assets/$own')) return own;
    return 'audio/voice/generic_$language.mp3';
  }

  /// Every asset path in the build, read once.
  Future<Set<String>>? _assets;

  Future<Set<String>> _bundledAssets() => _assets ??= () async {
        final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
        return manifest.listAssets().toSet();
      }();

  /// Silences any portal line still being spoken.
  Future<void> stopSpeaking() async {
    _voiceClip = null;
    _duckAmbient(false);
    try {
      await _voicePlayer.stop();
    } catch (_) {}
  }

  /// Whether the music is lowered under a spoken line.
  bool _ambientDucked = false;

  /// Quiet enough to sit under a spoken lesson without competing with it.
  /// Music a child cannot talk over is music they will switch off.
  static const _ambientVolume = 0.05;

  /// Under a greeting: still there, but only just.
  static const _ambientDuckedVolume = 0.015;

  void _duckAmbient(bool duck) {
    if (_ambientDucked == duck) return;
    _ambientDucked = duck;
    if (!_ambientPlaying) return;
    unawaited(_ambientPlayer
        .setVolume(duck ? _ambientDuckedVolume : _ambientVolume)
        .catchError((_) {}));
  }

  Future<void> _play(StudentSoundCue cue) async {
    if (muted.value || _backgrounded || !_gate.allow(cue)) return;
    try {
      if (cue == StudentSoundCue.success) {
        await _feedbackAudio.playSuccess();
        return;
      }
      if (cue == StudentSoundCue.warning) {
        await _feedbackAudio.playFeedback();
        return;
      }
      if (cue == StudentSoundCue.gameReward) {
        await _effectsPlayer.stop();
        await _effectsPlayer.play(
          AssetSource('audio/success-reward.wav'),
          volume: 0.62,
        );
        return;
      }
      if (cue == StudentSoundCue.levelUp) {
        // A short back-to-back double chime reads as a bigger celebration
        // than a single reward ping, without needing a dedicated asset.
        await _effectsPlayer.stop();
        await _effectsPlayer.play(
          AssetSource('audio/success-reward.wav'),
          volume: 0.95,
        );
        return;
      }

      final isVoice = cue == StudentSoundCue.welcome || cue == StudentSoundCue.loginSuccess;
      final player = isVoice ? _voicePlayer : _effectsPlayer;
      final asset = switch (cue) {
        StudentSoundCue.navigation => 'audio/ui-tap.wav',
        StudentSoundCue.answerSelected => 'audio/answer-selected.wav',
        StudentSoundCue.success => 'audio/success-reward.wav',
        StudentSoundCue.warning => 'audio/gentle-warning.wav',
        StudentSoundCue.loginSuccess => 'audio/manara-login-chime.mp3',
        StudentSoundCue.welcome => 'audio/manara-arabic-student-welcome.mp3',
        StudentSoundCue.gameReward => 'audio/success-reward.wav',
        // Handled above and never reached here; kept only so this switch
        // stays exhaustive over every StudentSoundCue value.
        StudentSoundCue.levelUp => 'audio/success-reward.wav',
      };
      await player.stop();
      if (isVoice) _voiceClip = asset;
      await player.play(AssetSource(asset), volume: isVoice ? 0.78 : 0.56);
    } catch (_) {
      // Audio is an enhancement and must never block a lesson or assessment.
    }
  }

  /// Translation keys for the short phrases used as random encouragement.
  /// Kept public so a caller can show the same phrase as an on-screen toast
  /// alongside (or instead of, if audio is muted/unavailable) the sound.
  /// Keys rather than sentences, because this list is `const` and the
  /// phrase has to follow the language the student picked.
  static const List<String> encouragementPhraseKeys = [
    'cheer.1',
    'cheer.2',
    'cheer.3',
    'cheer.4',
    'cheer.5',
  ];

  static final math.Random _random = math.Random();

  /// Starts the background music if it is not already running.
  ///
  /// Safe to call on every build of every screen: it is idempotent, and the
  /// loop keeps playing until the app closes or the student mutes it.
  void ensureAmbient() {
    if (_ambientWanted) return;
    _ambientWanted = true;
    unawaited(_syncAmbient());
  }

  /// Silences the music for good. Only the app teardown needs this.
  Future<void> stopAmbient() async {
    _ambientWanted = false;
    await _syncAmbient();
  }

  /// Ducks the music out while a lesson, a video or a game is open.
  ///
  /// Separate from [stopAmbient] because it is not a decision, it is a pause:
  /// the intent to have music is untouched, so coming back out resumes it
  /// without the hub having to ask again.
  void pauseAmbient() {
    if (_ambientSuspended) return;
    _ambientSuspended = true;
    unawaited(_syncAmbient());
  }

  /// Brings the music back when the student returns to the hub.
  void resumeAmbient() {
    if (!_ambientSuspended) return;
    _ambientSuspended = false;
    unawaited(_syncAmbient());
  }

  /// Brings the player in line with whether anything wants music and whether
  /// the student has muted sound. Safe to call repeatedly.
  Future<void> _syncAmbient() async {
    final shouldPlay =
        _ambientWanted && !_ambientSuspended && !muted.value && !_backgrounded;
    if (shouldPlay == _ambientPlaying) return;
    _ambientPlaying = shouldPlay;
    try {
      if (shouldPlay && _ambientHeld) {
        _ambientHeld = false;
        await _ambientPlayer.resume();
      } else if (shouldPlay) {
        await _ambientPlayer.setReleaseMode(ReleaseMode.loop);
        await _ambientPlayer.setVolume(
          _ambientDucked ? _ambientDuckedVolume : _ambientVolume,
        );
        await _ambientPlayer.play(AssetSource('audio/kids_bgm.mp3'));
      } else if (_backgrounded) {
        _ambientHeld = true;
        await _ambientPlayer.pause();
      } else {
        _ambientHeld = false;
        await _ambientPlayer.stop();
      }
    } catch (_) {
      // Missing asset or no audio backend: the app is fine without music.
      _ambientPlaying = false;
      _ambientHeld = false;
    }
  }

  /// The feedback for a finger landing on a card or a button.
  ///
  /// `card_tap.mp3` is a real pop-click recording. It shares the deal's
  /// player, so a tap during the opening deal replaces the card sound rather
  /// than layering on top of it — a finger is the student's own action and
  /// should win over the scenery.
  ///
  /// The haptic stays: on a phone that is half of what makes a tap feel
  /// answered, and it costs nothing when the device has no motor.
  void playTap() {
    HapticFeedback.lightImpact();
    if (muted.value || _backgrounded) return;
    unawaited(() async {
      try {
        await _dealPlayer.stop();
        await _dealPlayer.play(
          AssetSource('audio/card_tap.mp3'),
          // نقرة خفيفة جداً: تُسمع تحت الموسيقى لا فوقها.
          volume: 0.22,
        );
      } catch (_) {
        // Audio is an enhancement and must never block an interaction.
      }
    }());
  }

  /// The sound of one card arriving.
  ///
  /// `card.mp3` is a real recording supplied for the app, and it replaced a
  /// run of synthesised stand-ins — an air whoosh, a chime, a paper rustle —
  /// each of which was an approximation of something nobody had yet heard.
  ///
  /// Deliberately not routed through [play]: the shared gate silences a cue
  /// repeated inside 220ms, and the rail deals every 180ms. It plays on its
  /// own player so a card arriving never cuts off applause or a spoken phrase
  /// on the effects player.
  void playCardDeal() {
    if (muted.value || _backgrounded) return;
    unawaited(() async {
      try {
        await _dealPlayer.stop();
        await _dealPlayer.play(
          AssetSource('audio/card.mp3'),
          volume: 0.55,
        );
      } catch (_) {
        // Audio is an enhancement and must never block the hub from opening.
      }
    }());
  }

  /// When applause last started. Everything below checks it.
  DateTime? _lastApplause;

  /// How long after applause the quieter reward cues stay silent.
  ///
  /// Finishing a lesson celebrates inside the card, and closing it sends
  /// the student back to the hub, which refetches their progress, sees the
  /// XP go up and celebrates all over again — a chime and a spoken phrase
  /// on top of applause the child is still hearing. One celebration per
  /// achievement; this window is what enforces it.
  static const _applauseQuiet = Duration(seconds: 6);

  bool get _justApplauded {
    final at = _lastApplause;
    return at != null && DateTime.now().difference(at) < _applauseQuiet;
  }

  /// The coin/gem chime for earning XP or gems.
  void playReward() {
    if (_justApplauded) return;
    HapticFeedback.mediumImpact();
    play(StudentSoundCue.gameReward);
  }

  /// A bigger celebration for finishing a lesson, quiz, or leveling up.
  void playLevelUp() {
    if (_justApplauded) return;
    HapticFeedback.heavyImpact();
    play(StudentSoundCue.levelUp);
  }

  /// Stops applause already in flight.
  ///
  /// Called when a card closes, so the clapping does not follow the
  /// student out to the hub. The chain listens for the first clip's
  /// completion, so stopping mid-clip would otherwise trigger the second
  /// one — the guard below is what prevents the stop from starting a clap.
  void stopEffects() {
    _applauseCancelled = true;
    unawaited(_effectsPlayer.stop().catchError((_) {}));
  }

  bool _applauseCancelled = false;

  /// Applause: `clap2.mp3` then `clap.mp3`, back to back.
  void playApplause() {
    _lastApplause = DateTime.now();
    _applauseCancelled = false;
    HapticFeedback.heavyImpact();
    unawaited(_playSequence(const [
      ('audio/clap2.mp3', 0.7),
      ('audio/clap.mp3', 0.7),
    ]));
  }

  /// إنهاء الدرس: هتاف ثم تصفيق.
  ///
  /// نغمة المكافأة تُصعِّد أولاً، ثم يدخل التصفيق على أثرها — والترتيب مقصود:
  /// التصفيق وحده يبدأ من الذروة بلا تمهيد، فيفاجئ الطفل بدل أن يحتفي به.
  ///
  /// ولا يحتاج حارساً ضد التكرار عند إعادة فتح الشاشة: نداؤه الوحيد خلف
  /// `reward.alreadyRewarded`، وسجلّ الأنشطة في الخادم يمنع مكافأة النشاط
  /// نفسه مرتين — فالدرس المنتهي سلفاً يأخذ النغمة الهادئة لا الاحتفال.
  void playLessonComplete() {
    _lastApplause = DateTime.now();
    _applauseCancelled = false;
    HapticFeedback.heavyImpact();
    unawaited(_playSequence(const [
      ('audio/success-reward.wav', 0.85),
      ('audio/clap2.mp3', 0.7),
      ('audio/clap.mp3', 0.7),
    ]));
  }

  /// يشغّل مقاطع متتابعة، كلٌّ عند انتهاء سابقه.
  ///
  /// التسلسل معلّق على حدث الانتهاء لا على مؤقّت: التوقيت الثابت إمّا
  /// يُراكب المقطعين أو يترك فجوة بينهما أول مرة يُعاد فيها قصّ أي ملف.
  ///
  /// والاشتراك يُلغى عند كل خطوة، فلا يتراكم مستمعان على المشغّل نفسه لو
  /// بدأ تسلسل جديد قبل انتهاء السابق.
  Future<void> _playSequence(List<(String, double)> clips) async {
    if (muted.value || _backgrounded || clips.isEmpty) return;
    var index = 0;
    try {
      late StreamSubscription<void> sub;
      sub = _effectsPlayer.onPlayerComplete.listen((_) async {
        index++;
        if (index >= clips.length ||
            muted.value ||
            _backgrounded ||
            _applauseCancelled) {
          await sub.cancel();
          return;
        }
        try {
          final (asset, volume) = clips[index];
          await _effectsPlayer.play(AssetSource(asset), volume: volume);
        } catch (_) {
          await sub.cancel();
          // ما سبق من المقاطع عُزف بالفعل؛ سقوط الأخير لا يستحق أن يُعرَض
          // على طفل.
        }
      });
      await _effectsPlayer.stop();
      final (asset, volume) = clips.first;
      await _effectsPlayer.play(AssetSource(asset), volume: volume);
    } catch (_) {
      // صوت الاحتفال زينة — لا يجوز أن يكسر المسار الذي أطلقه.
    }
  }

  /// Plays a random Arabic encouragement cue and returns the phrase that
  /// goes with it, so the caller can also show it as text (e.g. a snack
  /// bar) — this keeps the encouragement visible even when sound is muted
  /// or a voice-specific asset isn't bundled yet.
  String playEncouragementArabic() {
    // The phrase is still returned so the caller can show it; only the
    // sound is held back while applause is still running.
    if (!_justApplauded) {
      HapticFeedback.selectionClick();
      play(StudentSoundCue.success);
    }
    return tr(
      encouragementPhraseKeys[_random.nextInt(encouragementPhraseKeys.length)],
    );
  }
}