import 'package:flutter_test/flutter_test.dart';

import 'package:manara_student/src/services/meeting_links.dart';

/// اللقاءُ يبقى داخل التطبيق: طلبُ صفحة الاجتماع لتطبيقها يُترجم إلى صفحة ويبٍ
/// تُحمَّل في الإطار نفسه، ولا شيءَ يُفتح خارجه.
void main() {
  group('webFallback', () {
    test('Meet: intent:// بصفحةٍ بديلة → الصفحةُ نفسها', () {
      final uri = Uri.parse(
        'intent://meet.google.com/abc-defg-hij#Intent;scheme=https;'
        'package=com.google.android.apps.meetings;'
        'S.browser_fallback_url=https%3A%2F%2Fmeet.google.com%2Fabc-defg-hij%3Fhs%3D1;end',
      );
      expect(
        MeetingLinks.webFallback(uri).toString(),
        'https://meet.google.com/abc-defg-hij?hs=1',
      );
    });

    test('intent:// بمخطّط https بلا بديلة → يُعاد بناؤه https', () {
      final uri = Uri.parse(
        'intent://meet.jit.si/Manara-abc#Intent;scheme=https;package=org.jitsi.meet;end',
      );
      expect(
        MeetingLinks.webFallback(uri).toString(),
        'https://meet.jit.si/Manara-abc',
      );
    });

    test('Zoom: تطبيقٌ بلا صفحة ويب → لا شيء، فيُقال للطفل', () {
      expect(MeetingLinks.webFallback(Uri.parse('zoomus://zoom.us/join?confno=1')), isNull);
      expect(
        MeetingLinks.webFallback(Uri.parse(
          'intent://zoom.us/join?confno=1#Intent;scheme=zoomus;package=us.zoom.videomeetings;end',
        )),
        isNull,
      );
    });

    test('بديلةٌ غيرُ آمنة لا تُحمَّل', () {
      expect(
        MeetingLinks.webFallback(Uri.parse(
          'intent://x#Intent;scheme=zoomus;S.browser_fallback_url=http%3A%2F%2Fevil.example;end',
        )),
        isNull,
        reason: 'http لا يُحمَّل في الإطار',
      );
      expect(
        MeetingLinks.webFallback(Uri.parse(
          'intent://x#Intent;S.browser_fallback_url=javascript%3Aalert(1);end',
        )),
        isNull,
      );
    });

    test('intent:// معطوب → لا شيء', () {
      expect(MeetingLinks.webFallback(Uri.parse('intent://x')), isNull);
    });
  });

  test('isGoogleMeet', () {
    expect(MeetingLinks.isGoogleMeet('https://meet.google.com/abc-defg-hij'), isTrue);
    expect(MeetingLinks.isGoogleMeet('https://meet.jit.si/Manara-abc'), isFalse);
    expect(MeetingLinks.isGoogleMeet(null), isFalse);
  });

  test('meetingUri: https وحده', () {
    expect(MeetingLinks.meetingUri('meet.jit.si/Manara-abc').toString(),
        'https://meet.jit.si/Manara-abc');
    expect(MeetingLinks.meetingUri('http://meet.jit.si/x'), isNull);
    expect(MeetingLinks.meetingUri(''), isNull);
  });
}
