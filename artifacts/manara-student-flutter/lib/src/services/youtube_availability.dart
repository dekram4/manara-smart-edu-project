import 'dart:async';

import 'package:http/http.dart' as http;

/// حالُ فيديو يوتيوب قبل أن يُفتح.
enum YoutubeAvailability {
  /// يُعرض كما هو.
  available,

  /// حذفه صاحبه أو جعله خاصاً: لا صورةَ له ولا يُشغَّل — كان يظهر «رمادياً».
  unavailable,

  /// موجودٌ، لكن صاحبه منع تضمينه خارج يوتيوب.
  embedBlocked,

  /// تعذّر السؤال (شبكة): يُعامل كالمتاح، فلا يُحجب فيديو سليم.
  unknown,
}

/// يسأل يوتيوب عن الفيديو مرّةً في الجلسة (oEmbed — بلا مفتاح ولا خادمنا).
///
/// ── لماذا ──
/// فيديو «تعليم الألوان والأشكال وتمييزها» الثامن (`9_CqQ1z1K3E`) لم يعد على
/// يوتيوب: oEmbed يردّ 404 ولا صورةَ له بأيّ مقاس. فكانت بطاقته رماديةً، وفتحُه
/// مشغّلاً فارغاً. والآن تقول البطاقةُ ذلك، ولمسُها يشرح بدل أن يفتح فراغاً.
/// ومشغّلُ الفيديو نفسه لا يتغيّر.
class YoutubeAvailabilityService {
  YoutubeAvailabilityService._();

  static final instance = YoutubeAvailabilityService._();

  final _cache = <String, Future<YoutubeAvailability>>{};

  /// ما عُرف من قبل في هذه الجلسة، بلا انتظار — لتقرأه اللمسة فوراً.
  final known = <String, YoutubeAvailability>{};

  static const _timeout = Duration(seconds: 6);

  Future<YoutubeAvailability> check(String videoId) {
    final id = videoId.trim();
    if (id.isEmpty) return Future.value(YoutubeAvailability.unknown);
    return _cache[id] ??= _ask(id).then((status) {
      known[id] = status;
      // ‏تعذّرُ السؤال لا يُحفظ: يُعاد في المرّة القادمة.
      if (status == YoutubeAvailability.unknown) _cache.remove(id);
      return status;
    });
  }

  Future<YoutubeAvailability> _ask(String id) async {
    try {
      final response = await http
          .get(Uri.parse(
            'https://www.youtube.com/oembed?url=https://www.youtube.com/watch?v=$id&format=json',
          ))
          .timeout(_timeout);
      return statusFor(response.statusCode);
    } catch (_) {
      return YoutubeAvailability.unknown;
    }
  }

  /// ردُّ oEmbed: 200 متاح، و401/403 منع التضمين، و404 محذوفٌ أو خاص. وما
  /// سواها لا يُحكم به — لا يُحجب فيديو سليم لخطأٍ عابر.
  static YoutubeAvailability statusFor(int code) => switch (code) {
        200 => YoutubeAvailability.available,
        401 || 403 => YoutubeAvailability.embedBlocked,
        404 => YoutubeAvailability.unavailable,
        _ => YoutubeAvailability.unknown,
      };
}
