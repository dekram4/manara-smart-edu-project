import 'dart:async';
import 'dart:io' show Platform;
import 'dart:isolate';

import 'package:flutter/foundation.dart';

import 'quran_recitation.dart';

/// تقييمُ التسميع في خيطٍ جانبيّ: الشاشةُ لا تنتظره أبداً.
///
/// ── لماذا ──
/// المايكُ يرسل نصّاً جزئياً مراتٍ في الثانية، وكلُّ نصٍّ يُطابَق بالآية كلمةً
/// كلمة ([RecitationTracker.hear]). ذلك على خيط الواجهة يجمّد الرسمَ على جهازٍ
/// بطيء — وهو التعليقُ الذي ظهر. فالتقييمُ هنا في عاملٍ واحدٍ يعيش ما عاشت
/// اللعبة (فتبقى ذاكرةُ المطابقة فيه دافئة)، والشاشةُ ترسل وتمضي.
///
/// ── والترتيب ──
/// الطلباتُ تُقيَّم بترتيبها، والنصُّ الجزئيُّ الأحدثُ يُغني عمّا قبله ممّا لم
/// يُقيَّم بعد ([RecitationQueue]). فلا يتراكم عملٌ، ولا يُفقد ختامُ استماع.
class RecitationWorker {
  RecitationWorker._();

  /// في الاختبار يُقيَّم في مكانه: الوقتُ هناك مزيّف، والخيطُ الجانبيّ لا يمضي.
  static bool get _inline => !kIsWeb && Platform.environment.containsKey('FLUTTER_TEST');

  /// [background]: للاختبار وحده — يفرض الخيطَ الجانبيّ أو يمنعه.
  static Future<RecitationWorker> start({@visibleForTesting bool? background}) async {
    final worker = RecitationWorker._();
    if (!(background ?? !_inline)) return worker;
    try {
      worker._isolate = await Isolate.spawn(_main, worker._port.sendPort, debugName: 'quran-recitation');
      worker._port.listen(worker._onMessage);
      await worker._ready.future;
    } catch (error) {
      // تعذّر الخيطُ الجانبيّ: يُقيَّم في مكانه — أبطأ، لكنه يعمل.
      debugPrint('[quran] background evaluation unavailable: $error');
      worker._port.close();
      worker._isolate = null;
    }
    return worker;
  }

  final ReceivePort _port = ReceivePort();

  /// هل يُقيَّم في خيطٍ جانبيّ فعلاً؟
  @visibleForTesting
  bool get inBackground => _send != null;
  final Completer<void> _ready = Completer<void>();
  Isolate? _isolate;
  SendPort? _send;
  int _next = 0;
  final Map<int, ({Completer<RecitationTracker> done, RecitationTracker fallback})> _waiting = {};

  void _onMessage(Object? message) {
    if (message is SendPort) {
      _send = message;
      if (!_ready.isCompleted) _ready.complete();
      return;
    }
    if (message is (int, RecitationTracker)) {
      _waiting.remove(message.$1)?.done.complete(message.$2);
    }
  }

  /// [tracker] بعد أن سمع [transcript]. في الخيط الجانبيّ: نسخةٌ جديدة منه،
  /// و[tracker] نفسُه لا يُمسّ.
  Future<RecitationTracker> hear(RecitationTracker tracker, String transcript, {bool ended = false}) {
    final send = _send;
    if (send == null) {
      tracker.hear(transcript, ended: ended);
      return Future.value(tracker);
    }
    final id = _next++;
    final done = Completer<RecitationTracker>();
    _waiting[id] = (done: done, fallback: tracker);
    send.send((id, tracker, transcript, ended));
    return done.future;
  }

  void dispose() {
    _isolate?.kill(priority: Isolate.immediate);
    _isolate = null;
    _port.close();
    // ما ينتظر يعود بحاله: اللعبةُ أُغلقت ولا أحدَ يقرأ النتيجة.
    for (final entry in _waiting.values) {
      entry.done.complete(entry.fallback);
    }
    _waiting.clear();
  }

  static void _main(SendPort reply) {
    final inbox = ReceivePort();
    reply.send(inbox.sendPort);
    inbox.listen((message) {
      final (id, tracker, transcript, ended) = message as (int, RecitationTracker, String, bool);
      tracker.hear(transcript, ended: ended);
      reply.send((id, tracker));
    });
  }
}

/// ما ينتظر التقييم، بترتيبه: بدايةُ استماعٍ، ونصٌّ جزئيّ، وختامُ استماع.
sealed class RecitationJob {
  const RecitationJob();
}

/// استماعٌ جديد: نصُّه يبدأ من الصفر ([RecitationTracker.startSession]).
class StartSession extends RecitationJob {
  const StartSession();
}

/// ما سُمع حتى الآن في الاستماع الجاري؛ [ended]: انتهى الاستماع.
class Heard extends RecitationJob {
  const Heard(this.transcript, {this.ended = false});

  final String transcript;
  final bool ended;
}

/// طابورُ التقييم: بترتيبه، والجزئيُّ الأحدثُ يحلّ محلّ جزئيٍّ قبله لم يُقيَّم.
class RecitationQueue {
  final List<RecitationJob> _jobs = [];

  bool get isEmpty => _jobs.isEmpty;

  void add(RecitationJob job) {
    final last = _jobs.isEmpty ? null : _jobs.last;
    if (job is Heard && !job.ended && last is Heard && !last.ended) {
      _jobs[_jobs.length - 1] = job;
      return;
    }
    _jobs.add(job);
  }

  RecitationJob take() => _jobs.removeAt(0);

  void clear() => _jobs.clear();
}
