import 'package:flutter_test/flutter_test.dart';
import 'package:manara_student/src/services/student_content_service.dart';

/// The meeting link a teacher pastes is a plain Jitsi room URL. On a phone
/// that opens an install prompt and a waiting room before the child ever
/// sees the class — so the client settings are appended here rather than
/// asked of every teacher in every link.
void main() {
  group('withMeetingDefaults', () {
    test('appends the four settings to a bare room link', () {
      final url = withMeetingDefaults('https://meet.jit.si/manara-grade4');
      expect(url, startsWith('https://meet.jit.si/manara-grade4#'));
      for (final key in [
        'config.disableDeepLinking=true',
        'config.prejoinPageEnabled=false',
        'config.startWithAudioMuted=false',
        'config.startWithVideoMuted=false',
      ]) {
        expect(url, contains(key));
      }
    });

    test('keeps what the teacher already set', () {
      // معلّمٌ كتم الصوت عمداً لا يُنقض قصدُه.
      final url = withMeetingDefaults(
        'https://meet.jit.si/room#config.startWithAudioMuted=true',
      );
      expect(url, contains('config.startWithAudioMuted=true'));
      expect(url, isNot(contains('config.startWithAudioMuted=false')));
      expect(url, contains('config.prejoinPageEnabled=false'));
    });

    test('leaves a non-Jitsi link untouched', () {
      // تجربةٌ أخرى قد تُعطب بمعاملاتٍ لا تعرفها.
      for (final other in [
        'https://example.test/room',
        // `meet.` بادئةٌ شائعة لخدماتٍ أخرى، فلا تكفي وحدها دليلاً.
        'https://meet.example.com/chosen',
        'https://meet.google.com/abc-defg-hij',
      ]) {
        expect(withMeetingDefaults(other), other, reason: other);
      }
    });

    test('recognises a self-hosted Jitsi by name', () {
      expect(
        withMeetingDefaults('https://jitsi.school.edu/grade4'),
        contains('config.prejoinPageEnabled=false'),
      );
    });

    test('adding twice does not duplicate', () {
      final once = withMeetingDefaults('https://meet.jit.si/room');
      expect(withMeetingDefaults(once), once);
    });
  });
}
