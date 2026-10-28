import 'package:flutter_test/flutter_test.dart';

import 'package:manara_student/src/services/quran_recitation.dart';
import 'package:manara_student/src/services/quran_recitation_worker.dart';

/// التقييمُ في الخيط الجانبيّ يطابق التقييمَ في مكانه حرفاً بحرف، والطابورُ
/// لا يُسقط ختامَ استماعٍ ولا يراكم الجزئيّ.
void main() {
  const transcripts = [
    'أعوذ بالله من الشيطان الرجيم',
    'أعوذ بالله من الشيطان الرجيم بسم الله الرحمن الرحيم',
    'أعوذ بالله من الشيطان الرجيم بسم الله الرحمن الرحيم الحمد لله رب العالمين',
    'أعوذ بالله من الشيطان الرجيم بسم الله الرحمن الرحيم الحمد لله رب العالمين الرحمن الرحيم ملك',
  ];

  test('الخيطُ الجانبيُّ يقيّم كما يُقيَّم في المكان', () async {
    final surah = quranSurahs.firstWhere((s) => s.id == 'fatiha');
    final worker = await RecitationWorker.start(background: true);
    addTearDown(worker.dispose);
    expect(worker.inBackground, isTrue);

    final inline = RecitationTracker(surah)..startSession();
    var remote = RecitationTracker(surah)..startSession();
    for (final t in transcripts) {
      inline.hear(t);
      remote = await worker.hear(remote, t);
      expect(remote.status, inline.status, reason: t);
      expect(remote.currentUnit, inline.currentUnit, reason: t);
    }
    // «ملك» مكان «مالك»: حمراء في الخيطين.
    expect(remote.blocked, isTrue);
  });

  test('الطابور: الجزئيُّ الأحدث يحلّ محلّ ما قبله، والختامُ والبدايةُ لا يسقطان', () {
    final queue = RecitationQueue()
      ..add(const StartSession())
      ..add(const Heard('أ'))
      ..add(const Heard('أ ب'))
      ..add(const Heard('أ ب ت', ended: true))
      ..add(const StartSession())
      ..add(const Heard('ث'));
    final taken = <RecitationJob>[];
    while (!queue.isEmpty) {
      taken.add(queue.take());
    }
    expect(taken, hasLength(5));
    expect(taken[0], isA<StartSession>());
    expect((taken[1] as Heard).transcript, 'أ ب');
    expect((taken[2] as Heard).ended, isTrue);
    expect(taken[3], isA<StartSession>());
    expect((taken[4] as Heard).transcript, 'ث');
  });
}
