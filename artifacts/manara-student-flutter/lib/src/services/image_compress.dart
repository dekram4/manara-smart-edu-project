import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

/// ضغطُ الصور على الجهاز قبل رفعها: صورةُ كاميرا أو لوحةٌ كبيرة تصير بضعَ
/// مئات من الكيلوبايتات على الأكثر، فلا تتجاوز سقفَ الخادم، ولا تستهلك من
/// مساحته ولا من باقة الطفل.
///
/// ── متى لا يُمسّ شيء ──
/// صورةٌ أصغرُ من [maxBytes] وضلعُها الأطولُ في حدود [maxSide] تُرسل كما هي —
/// لوحاتُ «لوحة الألوان السحرية» بخطوطها ومساحاتها الملساء تكون كذلك عادةً،
/// وPNG يحفظ حوافَّها حادّةً أفضلَ من JPEG.
///
/// ── وإلا ──
/// تُصغَّر وتُرمَّز JPEG بجودةٍ تنزل درجةً درجة، ثم بضلعٍ أصغر، حتى تدخل السقف.
/// والعملُ في عزلةٍ (`compute`) فلا يتجمّد الشاشة أثناءه.
const int uploadMaxBytes = 280 * 1024;
const int uploadMaxSide = 1280;

Future<Uint8List> compressForUpload(
  Uint8List bytes, {
  int maxBytes = uploadMaxBytes,
  int maxSide = uploadMaxSide,
}) async {
  // ‏تحت السقف: تُرسل كما هي — بلا فكٍّ ولا عزلة. الخادمُ يحسب البايتاتِ لا الأبعاد.
  if (bytes.isEmpty || bytes.length <= maxBytes) return bytes;
  try {
    return await compute(_compress, (bytes, maxBytes, maxSide));
  } catch (error) {
    debugPrint('[compress] failed: $error');
    return bytes;
  }
}

/// متزامنةً — للعزلة وللاختبار.
@visibleForTesting
Uint8List compressSync(Uint8List bytes, {int maxBytes = uploadMaxBytes, int maxSide = uploadMaxSide}) =>
    _compress((bytes, maxBytes, maxSide));

Uint8List _compress((Uint8List, int, int) job) {
  final (bytes, maxBytes, maxSide) = job;
  final decoded = img.decodeImage(bytes);
  if (decoded == null) return bytes;
  final longest = decoded.width > decoded.height ? decoded.width : decoded.height;
  if (bytes.length <= maxBytes && longest <= maxSide) return bytes;

  // ‏صورةٌ بشفافية تُوضع على أبيض: JPEG لا يحمل الشفافية، والأسودُ مكانها قبيح.
  var base = decoded;
  if (decoded.hasAlpha) {
    base = img.Image(width: decoded.width, height: decoded.height, numChannels: 3);
    img.fill(base, color: img.ColorRgb8(255, 255, 255));
    img.compositeImage(base, decoded);
  }

  var side = longest < maxSide ? longest : maxSide;
  Uint8List best = bytes;
  for (var attempt = 0; attempt < 6; attempt++) {
    final resized = side >= longest
        ? base
        : (base.width >= base.height
            ? img.copyResize(base, width: side, interpolation: img.Interpolation.average)
            : img.copyResize(base, height: side, interpolation: img.Interpolation.average));
    for (final quality in const [82, 72, 62, 52]) {
      final jpg = img.encodeJpg(resized, quality: quality);
      if (jpg.length < best.length) best = jpg;
      if (jpg.length <= maxBytes) return jpg;
    }
    side = (side * 0.75).round();
    if (side < 200) break;
  }
  return best;
}
