import 'dart:async';
import 'dart:io';


import 'package:flutter/foundation.dart';
import 'package:record/record.dart';

import '../models/duel_chat.dart';

/// سببُ تعذُّرِ التسجيل، بمفتاحٍ تترجمه الشاشة.
enum VoiceNoteProblem { noPermission, unavailable, tooShort, tooBig }

/// نتيجةُ تسجيلٍ: بايتاتٌ جاهزةٌ للبثّ، أو سببُ تعذّرها.
class VoiceNote {
  const VoiceNote.ready(Uint8List this.bytes) : problem = null;
  const VoiceNote.failed(this.problem) : bytes = null;

  final Uint8List? bytes;
  final VoiceNoteProblem? problem;

  bool get ok => bytes != null;
}

/// يسجّل مقطعاً قصيراً من صوت الطالب ليُبثّ إلى خصمه.
///
/// ── لماذا مقطعٌ قصيرٌ بمعدّل بتٍّ منخفض ──
/// المقطعُ يمرّ في رسالةٍ على قناة المباراة، ولها سقفُ حجم. فالترميزُ AAC على
/// ١٦ كيلوبت/ث بقناةٍ واحدة وعيّنةٍ ١٦ كيلوهرتز: كلامُ طفلٍ يُفهَم تماماً عند
/// هذا، وخمسُ ثوانٍ منه ≈ عشرةُ كيلوبايت. وجودةُ الموسيقى تُضاعفه عشراً فلا
/// يصل المقطعُ أصلاً — ولا يُفيد الفهمَ شيئاً.
///
/// ── ويتوقّف وحده ──
/// الضغطُ المطوّل يُفلت بالخطأ، أو يبقى الإصبعُ على الزرّ وقد انتهى الطفلُ من
/// الكلام. فالمدّةُ محدودةٌ في المسجّل نفسه لا في يد المستخدم.
class DuelVoiceRecorder {
  DuelVoiceRecorder({AudioRecorder? recorder})
      : _recorder = recorder ?? AudioRecorder();

  final AudioRecorder _recorder;

  /// الملفُّ الذي يكتب فيه المسجّل الآن.
  String? _path;
  Timer? _limit;

  /// يُنادى حين تنتهي المدّةُ وحدها، لتُنهي الشاشةُ حالَ «يسجّل».
  VoidCallback? onAutoStop;

  bool _recording = false;
  bool get recording => _recording;

  /// يبدأ التسجيل. ويعود بـ`false` إن لم يُسمح أو لم يتوفّر مسجّل.
  ///
  /// والإذنُ يُسأل من المسجّل نفسه لا من حزمةِ أذونٍ ثانية: هو من يعرف أنّ
  /// الجهازَ يملك مدخلاً أصلاً، وإذنٌ مُنح على جهازٍ بلا ميكروفون لا يسجّل.
  Future<bool> start() async {
    if (_recording) return true;
    try {
      if (!await _recorder.hasPermission()) return false;
      final directory = await _tempDirectory();
      if (directory == null) return false;
      final path =
          '${directory.path}/duel_note_${DateTime.now().millisecondsSinceEpoch}.m4a';
      await _recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          bitRate: 16000,
          sampleRate: 16000,
          numChannels: 1,
        ),
        path: path,
      );
      _path = path;
      _recording = true;
      // الحدُّ في المسجّل: إفلاتٌ منسيٌّ لا يُسجّل دقيقة.
      _limit = Timer(duelVoiceMaxDuration, () {
        if (_recording) onAutoStop?.call();
      });
      return true;
    } catch (error) {
      debugPrint('[duel] recorder unavailable: $error');
      _recording = false;
      return false;
    }
  }

  /// يوقف التسجيل ويعود بالمقطع.
  Future<VoiceNote> stop() async {
    _limit?.cancel();
    _limit = null;
    if (!_recording) return const VoiceNote.failed(VoiceNoteProblem.unavailable);
    _recording = false;
    try {
      final path = await _recorder.stop() ?? _path;
      _path = null;
      if (path == null) {
        return const VoiceNote.failed(VoiceNoteProblem.unavailable);
      }
      final file = File(path);
      if (!file.existsSync()) {
        return const VoiceNote.failed(VoiceNoteProblem.unavailable);
      }
      final bytes = await file.readAsBytes();
      // والملفُّ يُحذف بعد قراءته: مقاطعُ مباراةٍ بعد مباراةٍ تتراكم في
      // المجلّد المؤقّت، ولا شيء يقرؤها بعد أن تُبثّ.
      unawaited(file.delete().catchError((_) => file));
      if (bytes.length < 512) {
        // ضغطةٌ عابرةٌ لا كلام: مقطعٌ بهذا القِصر لا يُسمع منه شيء.
        return const VoiceNote.failed(VoiceNoteProblem.tooShort);
      }
      if (bytes.length > duelVoiceMaxBytes) {
        return const VoiceNote.failed(VoiceNoteProblem.tooBig);
      }
      return VoiceNote.ready(bytes);
    } catch (error) {
      debugPrint('[duel] recording failed: $error');
      return const VoiceNote.failed(VoiceNoteProblem.unavailable);
    }
  }

  /// يُلغي تسجيلاً جارياً بلا أن يُنتج مقطعاً.
  Future<void> cancel() async {
    _limit?.cancel();
    _limit = null;
    if (!_recording) return;
    _recording = false;
    try {
      final path = await _recorder.stop() ?? _path;
      _path = null;
      if (path != null) {
        final file = File(path);
        if (file.existsSync()) unawaited(file.delete().catchError((_) => file));
      }
    } catch (_) {
      // إلغاءٌ لم يُقرّ به المشغّل: لا شيء يُبثّ على كل حال.
    }
  }

  Future<void> dispose() async {
    await cancel();
    try {
      await _recorder.dispose();
    } catch (_) {}
  }

  /// مجلّدٌ يُكتب فيه المقطع.
  ///
  /// ويُستعمل `Directory.systemTemp` لا `path_provider`: هو في `dart:io` فلا
  /// يُضاف اعتمادٌ لأجل مسارٍ واحد، والملفُّ يُحذف بعد قراءته بثوانٍ — فلا
  /// يحتاج مجلّدَ تطبيقٍ دائماً.
  Future<Directory?> _tempDirectory() async {
    try {
      final directory = Directory.systemTemp;
      if (!directory.existsSync()) await directory.create(recursive: true);
      return directory;
    } catch (_) {
      return null;
    }
  }
}
