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
      await _feedbackAudio.stop();
    }
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

  /// A cheerful tap for buttons and cards, paired with light haptic feedback.
  void playTap() {
    HapticFeedback.lightImpact();
    play(StudentSoundCue.navigation);
  }

  /// The soft rustle of a page turning as one card is dealt into place.
  ///
  /// `page-flip.wav` is synthesised, not recorded: a run of very short noise
  /// grains — the edge of a sheet flexing against what is under it — thinning
  /// out under a quiet, immediately-decaying envelope, twice high-passed
  /// because paper carries no bass.
  ///
  /// It replaced an air whoosh, which was the wrong instrument however well
  /// made: a whoosh swells before it fades and lives in the low-mids, so it
  /// read as something being thrown. Paper starts at its loudest and thins
  /// away, and sits an octave higher. That difference is the whole brief.
  ///
  /// Deliberately not routed through [play]: the shared gate silences a cue
  /// repeated inside 220ms, which is close to the rhythm of a deal. It plays
  /// on its own player for the same reason, so a card landing never cuts off
  /// applause or a spoken phrase already running on the effects player.
  void playCardDeal() {
    if (muted.value) return;
    unawaited(() async {
      try {
        await _dealPlayer.stop();
        await _dealPlayer.play(
          AssetSource('audio/page-flip.wav'),
          volume: 0.42,
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