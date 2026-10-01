import 'student_content_service.dart';

/// روابطُ اللقاء المباشر: ما يُحمَّل في الإطار، وما يُعاد إليه حين تطلب صفحةُ
/// الاجتماع تطبيقاً آخر.
///
/// ── ولماذا لا يُفتح شيءٌ خارج التطبيق ──
/// اللقاءُ يعيش في بطاقته: الطفلُ لا يُسلَّم إلى متصفّحٍ أو تطبيقٍ آخر يتوه فيه
/// ولا يعرف كيف يعود. فطلبُ تطبيقٍ من داخل الصفحة (`intent://` من Meet،
/// `zoomus://` من Zoom) يُترجم إلى صفحة الويب البديلة ويُحمَّل في الإطار نفسه.
class MeetingLinks {
  const MeetingLinks._();

  /// الرابطُ صالحاً للتحميل، أو `null`: https وحده، بلا بيانات دخولٍ فيه —
  /// بالقاعدة التي يُقبل بها رابطُ الدرس.
  static Uri? meetingUri(String? raw) {
    final normalized = normalizeTutorExperienceUrl(raw);
    return normalized == null ? null : Uri.tryParse(normalized);
  }

  /// هل هو Google Meet؟ يرفض Google تشغيلَه داخل التطبيقات في أحيانٍ كثيرة،
  /// فيُقال ذلك للطفل بدل إطارٍ يبقى فارغاً بلا تفسير.
  static bool isGoogleMeet(String? url) =>
      (Uri.tryParse(url ?? '')?.host.toLowerCase() ?? '') == 'meet.google.com';

  /// صفحةُ الويب لرابط تطبيقٍ طلبته صفحةُ الاجتماع، أو `null` إن لم تكن.
  ///
  /// `intent://` خاصّةٌ بكروم أندرويد، وفيها غالباً `S.browser_fallback_url` —
  /// صفحةُ الاجتماع في المتصفّح — فهي المطلوبة. وإلا فإن كان مخطّطُها الحقيقيّ
  /// (`scheme=`) https أُعيد بناؤها به. وما سوى ذلك (`zoomus://`) لا صفحةَ له.
  static Uri? webFallback(Uri requested) {
    final scheme = requested.scheme.toLowerCase();
    if (scheme == 'http' || scheme == 'https') return requested;
    if (scheme != 'intent') return null;

    final raw = requested.toString();
    final marker = raw.indexOf('#Intent;');
    if (marker < 0) return null;
    String? fallback;
    String? realScheme;
    for (final extra in raw.substring(marker + '#Intent;'.length).split(';')) {
      if (extra.startsWith('S.browser_fallback_url=')) {
        fallback = Uri.decodeComponent(
          extra.substring('S.browser_fallback_url='.length),
        );
      } else if (extra.startsWith('scheme=')) {
        realScheme = extra.substring('scheme='.length).toLowerCase();
      }
    }
    final fallbackUri = fallback == null ? null : Uri.tryParse(fallback);
    if (fallbackUri != null && fallbackUri.scheme == 'https') return fallbackUri;
    if (realScheme == 'https') {
      return Uri.tryParse('https://${raw.substring('intent://'.length, marker)}');
    }
    return null;
  }
}
