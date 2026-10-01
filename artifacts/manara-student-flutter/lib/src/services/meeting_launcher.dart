import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import 'student_content_service.dart';

/// نتيجةُ محاولة فتح اللقاء المباشر.
enum MeetingLaunchResult {
  /// فُتح في تطبيق الاجتماع أو المتصفّح.
  opened,

  /// لا رابط، أو رابطٌ لا يصلح أن يُفتح (ليس https، أو معطوب).
  invalidLink,

  /// الرابطُ سليمٌ والنظامُ لم يجد ما يفتحه به، أو رفض.
  failed,
}

/// يفتح رابطاً بنمطٍ معيّن. هو `launchUrl` في التطبيق، ويُستبدل في الاختبار.
typedef UrlOpener = Future<bool> Function(Uri uri, LaunchMode mode);

Future<bool> _systemOpener(Uri uri, LaunchMode mode) =>
    launchUrl(uri, mode: mode);

/// فتحُ اللقاء المباشر خارج التطبيق.
///
/// ── لماذا خارجه ──
/// Google Meet وZoom وTeams وWebex لا تعمل داخل WebView مضمَّن: Meet يرفضه
/// صراحةً، والبقيّةُ تحوّل إلى روابط تطبيقاتها (`intent://` و`zoomus://`) التي
/// لا يفتحها WebView. فكان زرُّ «الاتصال بالاجتماع» يعيد تحميلَ الإطار نفسه
/// أو يحاول تضمينَ ما لا يُضمَّن — والطفلُ يضغط ولا يحدث شيء.
///
/// ── وبأيّ ترتيب ──
/// تطبيقُ الاجتماع أوّلاً (`externalApplication`): يفتح Meet أو Zoom إن كان
/// مثبّتاً، أو المتصفّحَ إن لم يكن. فإن رفض النظام — جهازٌ بلا متصفّحٍ افتراضيّ،
/// أو قيودُ وليّ أمر — جُرّب النمطُ الافتراضيّ للمنصّة، وهو في أندرويد نافذةُ
/// متصفّحٍ داخل التطبيق. وما بعد ذلك فشلٌ يُقال للطفل، لا صمت.
class MeetingLauncher {
  const MeetingLauncher({UrlOpener opener = _systemOpener}) : _opener = opener;

  final UrlOpener _opener;

  /// الرابطُ صالحاً للفتح، أو `null`.
  ///
  /// بالقاعدة نفسها التي يُقبل بها رابطُ الدرس للعرض: https وحده، بلا
  /// بيانات دخولٍ في الرابط. وإعداداتُ Jitsi المضافة للتضمين تبقى: هي في جزء
  /// التجزئة، والمتصفّحُ وتطبيقُ Jitsi يقرآنها كما يقرؤها الإطار.
  static Uri? meetingUri(String? raw) {
    final normalized = normalizeTutorExperienceUrl(raw);
    return normalized == null ? null : Uri.tryParse(normalized);
  }

  Future<MeetingLaunchResult> open(String? raw) async {
    final uri = meetingUri(raw);
    if (uri == null) return MeetingLaunchResult.invalidLink;
    for (final mode in const [
      LaunchMode.externalApplication,
      LaunchMode.platformDefault,
    ]) {
      try {
        if (await _opener(uri, mode)) return MeetingLaunchResult.opened;
      } on PlatformException catch (error) {
        debugPrint('[meeting] $mode refused: ${error.code} ${error.message}');
      } catch (error) {
        debugPrint('[meeting] $mode failed: $error');
      }
    }
    return MeetingLaunchResult.failed;
  }

  /// يفتح رابطَ تطبيقٍ طلبه الاجتماعُ من داخل الإطار. انظر [appLinkTarget].
  Future<MeetingLaunchResult> openAppLink(Uri requested) async {
    final target = appLinkTarget(requested);
    if (target == null) return MeetingLaunchResult.invalidLink;
    try {
      if (await _opener(target, LaunchMode.externalApplication)) {
        return MeetingLaunchResult.opened;
      }
    } catch (error) {
      debugPrint('[meeting] app link refused: $error');
    }
    return MeetingLaunchResult.failed;
  }

  /// رابطٌ طلبه الاجتماعُ من داخل الإطار ولا يفتحه WebView — `intent://` أو
  /// `zoomus://` أو `msteams:` — بصيغةٍ يفتحها النظام، أو `null`.
  ///
  /// و`intent://` خاصّةٌ بكروم أندرويد: لا يفتحها `url_launcher` كما هي. وفيها
  /// غالباً `S.browser_fallback_url` — صفحةُ الاجتماع في المتصفّح — فهي
  /// المطلوبة. وإلا أُعيد بناؤها بمخطّطها الحقيقيّ (`scheme=`).
  static Uri? appLinkTarget(Uri uri) {
    final scheme = uri.scheme.toLowerCase();
    if (scheme == 'http' || scheme == 'https' || scheme.isEmpty) return null;
    if (scheme != 'intent') return uri;

    final raw = uri.toString();
    final marker = raw.indexOf('#Intent;');
    if (marker < 0) return null;
    final extras = raw.substring(marker + '#Intent;'.length).split(';');
    String? fallback;
    String? realScheme;
    for (final extra in extras) {
      if (extra.startsWith('S.browser_fallback_url=')) {
        fallback = Uri.decodeComponent(
          extra.substring('S.browser_fallback_url='.length),
        );
      } else if (extra.startsWith('scheme=')) {
        realScheme = extra.substring('scheme='.length);
      }
    }
    final fallbackUri = fallback == null ? null : Uri.tryParse(fallback);
    if (fallbackUri != null &&
        (fallbackUri.scheme == 'https' || fallbackUri.scheme == 'http')) {
      return fallbackUri;
    }
    if (realScheme == null || realScheme.isEmpty) return null;
    final rest = raw.substring('intent://'.length, marker);
    return Uri.tryParse('$realScheme://$rest');
  }
}
