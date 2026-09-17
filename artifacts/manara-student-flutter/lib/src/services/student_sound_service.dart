import 'dart:async';
import 'dart:math' as math;

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../l10n/student_strings.dart';

import 'audio_service.dart';

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
class StudentSoundService {
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

  /// How many holders currently want the music.
  ///
  /// Today `main` takes one hold for the life of the app, so the music plays
  /// from launch and never gaps at a route change. It is a count rather than a
  /// flag because that is what makes a second holder — a screen that wants
  /// music the app-wide hold has released, say — safe to add later: a flag
  /// would let the first thing to finish silence it for everything else.
  int _ambientHolders = 0;
  bool _ambientPlaying = false;
  late final AudioService _feedbackAudio = AudioService(muted: muted);
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
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

  void play(StudentSoundCue cue) {
    unawaited(_play(cue));
  }

  Future<void> _play(StudentSoundCue cue) async {
    if (muted.value || !_gate.allow(cue)) return;
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

  /// Claims the background music.
  ///
  /// A caller that is not the app-wide hold — a screen, say — must pair this
  /// with [releaseAmbient] when it goes away.
  void holdAmbient() {
    _ambientHolders++;
    unawaited(_syncAmbient());
  }

  /// Gives up this screen's claim on the music.
  void releaseAmbient() {
    if (_ambientHolders > 0) _ambientHolders--;
    unawaited(_syncAmbient());
  }

  /// Brings the player in line with whether anything wants music and whether
  /// the student has muted sound. Safe to call repeatedly.
  Future<void> _syncAmbient() async {
    final shouldPlay = _ambientHolders > 0 && !muted.value;
    if (shouldPlay == _ambientPlaying) return;
    _ambientPlaying = shouldPlay;
    try {
      if (shouldPlay) {
        await _ambientPlayer.setReleaseMode(ReleaseMode.loop);
        // Quiet enough to sit under a spoken lesson without competing with
        // it. Music a child cannot talk over is music they will switch off.
        await _ambientPlayer.setVolume(0.12);
        await _ambientPlayer.play(AssetSource('audio/bgm-calm.wav'));
      } else {
        await _ambientPlayer.stop();
      }
    } catch (_) {
      // Missing asset or no audio backend: the app is fine without music.
      _ambientPlaying = false;
    }
  }

  /// The feedback for a finger landing on a card or a button.
  ///
  /// `wooden-pop.wav` is synthesised: a tone whose pitch drops steeply from
  /// 760Hz to about 190Hz inside a tenth of a second, under a very fast
  /// decay. That steep drop is what the ear hears as something small and
  /// hollow being tapped — a wooden block rather than a bell.
  ///
  /// It replaced an air swish, which was too diffuse to answer a finger:
  /// touch wants an edge, and noise has none. Before that it was a pitched
  /// chime, which had the opposite problem — it rang on after the finger had
  /// gone. The pop has an attack and is over.
  ///
  /// The haptic stays: on a phone that is half of what makes a tap feel
  /// answered, and it costs nothing when the device has no motor.
  void playTap() {
    HapticFeedback.lightImpact();
    if (muted.value) return;
    unawaited(() async {
      try {
        await _dealPlayer.stop();
        await _dealPlayer.play(
          AssetSource('audio/wooden-pop.wav'),
          volume: 0.34,
        );
      } catch (_) {
        // Audio is an enhancement and must never block an interaction.
      }
    }());
  }

  /// The rustle of a page turning as one card arrives.
  ///
  /// `page-flip.wav` is synthesised: a run of very short noise grains — the
  /// edge of a sheet flexing — twice high-passed, because paper carries no
  /// bass, and shaped by a quiet envelope that decays from its first instant.
  /// The grains are what give it an edge; the decay is what keeps it gentle.
  ///
  /// It has now been three sounds. A whoosh swelled before it faded and read
  /// as something thrown. A chime rang on after the card had landed and, nine
  /// in a row, turned the rail into a xylophone. Paper starts at its loudest,
  /// thins away inside a third of a second, and says nothing about pitch —
  /// which is why it sits under a sequence without becoming the sequence.
  ///
  /// Deliberately not routed through [play]: the shared gate silences a cue
  /// repeated inside 220ms. It plays on its own player so a card arriving
  /// never cuts off applause or a spoken phrase on the effects player.
  void playCardDeal() {
    if (muted.value) return;
    unawaited(() async {
      try {
        await _dealPlayer.stop();
        await _dealPlayer.play(
          AssetSource('audio/page-flip.wav'),
          volume: 0.40,
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
    if (muted.value || clips.isEmpty) return;
    var index = 0;
    try {
      late StreamSubscription<void> sub;
      sub = _effectsPlayer.onPlayerComplete.listen((_) async {
        index++;
        if (index >= clips.length || muted.value || _applauseCancelled) {
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