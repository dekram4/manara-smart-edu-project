import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';

/// حالُ الميكروفون قبل رسالةٍ صوتية.
///
/// و[blocked] غيرُ [denied]: رفضٌ نهائيٌّ لا يُظهر النظامُ بعده نافذةَ السؤال
/// أبداً، فلا يفيد إلا أن يُفتح للطفل إعدادُ التطبيق.
enum MicAccess { granted, denied, blocked }

/// Holds the microphone/camera permission the virtual teacher needs, and
/// the D-ID session bookkeeping that goes with it.
///
/// The WebView already grants the page's own `getUserMedia` request, but
/// that grant is only as good as the app's: on Android the capture fails
/// inside the page unless the process already holds RECORD_AUDIO. When it
/// fails there, the provider's page reports it as an unsupported browser
/// and invites the child to open a real one — which is what was being
/// seen, and why the fix belongs here rather than in the embed.
class StudentMediaPermissions {
  const StudentMediaPermissions._();

  /// Whether the ask has already been made this run. The platform only
  /// shows its dialog once anyway, but repeating the call on every visit
  /// to the teacher costs a channel round trip for nothing.
  static bool _asked = false;

  /// Requests the microphone ahead of the virtual teacher's page.
  ///
  /// Never throws and never blocks the screen: a student who declines, or
  /// a platform with no such permission at all, still gets the teacher —
  /// just without their voice — which is a better outcome than a screen
  /// that refuses to open. The camera is deliberately not requested; the
  /// teacher listens and speaks, and asking a child for their camera
  /// without needing it is not something to do by default.
  static Future<bool> requestForTutor() async {
    if (_asked) return true;
    _asked = true;
    // Desktop and web have no runtime permission model here; the plugin
    // throws rather than answering on some of them.
    if (kIsWeb) return true;
    if (defaultTargetPlatform != TargetPlatform.android &&
        defaultTargetPlatform != TargetPlatform.iOS) {
      return true;
    }
    try {
      final status = await Permission.microphone.request();
      return status.isGranted || status.isLimited;
    } catch (_) {
      return false;
    }
  }

  static bool _askedMeeting = false;

  /// الكاميرا والميكروفون معاً، قبل أن تُحمَّل صفحةُ اللقاء المباشر.
  ///
  /// ── ولماذا الكاميرا هنا وليست في [requestForTutor] ──
  /// المعلمُ الافتراضيّ يسمع ولا يرى، فطلبُ الكاميرا له سؤالٌ لا داعي له. واللقاءُ
  /// صوتٌ وصورة: و`getUserMedia({video})` داخل WebView أندرويد يُرفض ما لم يملك
  /// التطبيقُ إذنَ الكاميرا — وكان لا يُطلب، فلا تعمل كاميرا الطفل داخل اللقاء
  /// أبداً، والصفحةُ لا تقول لماذا.
  static Future<bool> requestForMeeting() async {
    if (_askedMeeting) return true;
    _askedMeeting = true;
    if (kIsWeb) return true;
    if (defaultTargetPlatform != TargetPlatform.android &&
        defaultTargetPlatform != TargetPlatform.iOS) {
      return true;
    }
    try {
      final statuses =
          await [Permission.camera, Permission.microphone].request();
      return statuses.values.every((s) => s.isGranted || s.isLimited);
    } catch (_) {
      return false;
    }
  }

  /// الميكروفون لرسالةٍ صوتية في الدردشة.
  ///
  /// ── ولماذا يُسأل هنا قبل المسجّل ──
  /// المسجّلُ يعود بـ«لا» ولا يقول لماذا: لا يُفرَّق بين طفلٍ ضغط «رفض» الآن —
  /// فيُسأل ثانيةً — وطفلٍ رفض نهائياً — فلا تظهر النافذةُ مهما ضُغط الزرّ، ولا
  /// يبقى إلا الإعدادات. وبلا هذا الفرق يضغط الزرَّ مراراً ولا يحدث شيء.
  ///
  /// ولا يرمي: منصّةٌ بلا نظام أذونٍ هنا يُترك القرارُ فيها للمسجّل.
  static Future<MicAccess> microphoneForVoiceNote() async {
    if (kIsWeb) return MicAccess.granted;
    if (defaultTargetPlatform != TargetPlatform.android &&
        defaultTargetPlatform != TargetPlatform.iOS) {
      return MicAccess.granted;
    }
    try {
      var status = await Permission.microphone.status;
      if (status.isGranted || status.isLimited) return MicAccess.granted;
      if (status.isPermanentlyDenied || status.isRestricted) {
        return MicAccess.blocked;
      }
      status = await Permission.microphone.request();
      if (status.isGranted || status.isLimited) return MicAccess.granted;
      return status.isPermanentlyDenied || status.isRestricted
          ? MicAccess.blocked
          : MicAccess.denied;
    } catch (_) {
      return MicAccess.granted;
    }
  }

  /// يفتح إعدادَ التطبيق في النظام، حيث يُعاد السماحُ بعد رفضٍ نهائي.
  static Future<void> openSettings() async {
    try {
      await openAppSettings();
    } catch (_) {}
  }

  /// Test seam: lets a test start from a clean slate.
  @visibleForTesting
  static void resetForTest() {
    _asked = false;
    _askedMeeting = false;
  }
}
