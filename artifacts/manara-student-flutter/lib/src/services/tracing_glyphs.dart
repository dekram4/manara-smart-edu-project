import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter/widgets.dart' show StringCharacters;

import '../models/study_games.dart';
import 'tracing_glyph_data.g.dart';
import 'tracing_routes.dart';
import 'tracing_path.dart';

/// خطُّ التتبّع المضمَّن في التطبيق (`assets/fonts/Tajawal-Bold.ttf`).
///
/// مضمَّنٌ لا منزَّل: مساراتُ حروف الروضة محسوبةٌ مسبقاً من أشكاله، فإن
/// رسم الجهازُ خطّاً غيره افترقت النقاطُ عن الحرف.
const tracingFontFamily = 'TracingTajawal';

/// هامشُ الرسم حول النصّ؛ والقصُّ ([TracingShape.crop]) يُقاس منه.
const tracingPad = 16.0;

/// النصُّ كما يُرسم للتتبّع — في توليد المسارات وفي عرضها سواءً بسواء.
/// أيُّ فرقٍ بين الموضعين (حجم، سماكة، ارتفاع سطر) يزيح النقاطَ عن الحرف.
TextPainter tracingTextPainter(TracingItem item, {Color color = const Color(0xFF000000)}) {
  final word = item.kind == 'word' || item.kind == 'answer';
  return TextPainter(
    text: TextSpan(
      text: item.text,
      style: TextStyle(
        fontFamily: tracingFontFamily,
        fontSize: word ? 110 : 150,
        fontWeight: FontWeight.w700,
        color: color,
        height: 1.3,
        letterSpacing: 0,
      ),
    ),
    textDirection: item.rtl ? TextDirection.rtl : TextDirection.ltr,
  )..layout();
}

/// شكلُ عنصرٍ جاهزٌ للتتبّع: موضعُ الحبر في مساحة الرسم، ومساراتُه.
///
/// لا صورة فيه: اللوحةُ ترسم النصَّ نفسه بـ[tracingTextPainter] وتقصّه بـ[crop]،
/// فلا يُقرأ من معالج الرسوم شيءٌ لعرضه.
class TracingShape {
  const TracingShape({required this.crop, required this.plan});

  /// موضعُ الحبر في مساحة الرسم (النصُّ مرسومٌ عند [tracingPad]).
  final Rect crop;
  final TracePlan plan;

  Map<String, Object> toJson() => {
        'crop': [crop.left, crop.top, crop.right, crop.bottom],
        ...plan.toJson(),
      };

  static TracingShape fromJson(Map<String, Object?> json) {
    final crop = [for (final v in json['crop'] as List) (v as num).toDouble()];
    return TracingShape(
      crop: Rect.fromLTRB(crop[0], crop[1], crop[2], crop[3]),
      plan: TracePlan.fromJson(json),
    );
  }
}

/// مفتاحُ العنصر في الجدول المحسوب مسبقاً.
String tracingGlyphKey(TracingItem item) => '${item.kind}|${item.lang}|${item.text}';

final Map<String, TracingShape> _decoded = {};

/// شكلٌ محسوبٌ مسبقاً لحروف الروضة وأرقامها، أو `null` لغيرها.
///
/// ── لماذا مسبقاً ──
/// بناءُ المسار وقتَ اللعب يرسم الحرفَ صورةً ثم يقرأ بكسلاتها من معالج
/// الرسوم (`toImage` ثم `toByteData`). وعلى بعض أجهزة Android بمحرّك Impeller
/// لا تعود هذه القراءةُ أبداً — فيبقى الطفلُ أمام دائرة تحميلٍ لا تنتهي، وهو
/// ما ظهر في صفّ الروضة. فحروفُها وأرقامُها (٥٤ حرفاً و٢٠٢ عدد) تُحسب عند
/// التطوير (`tool/generate_tracing_glyphs_test.dart`) وتُشحن مع التطبيق:
/// لا رسمَ ولا قراءةَ ولا انتظار.
TracingShape? precomputedTracingShape(TracingItem item) {
  final key = tracingGlyphKey(item);
  final cached = _decoded[key];
  if (cached != null) return cached;
  final raw = tracingGlyphData[key];
  if (raw == null) return null;
  final shape = TracingShape.fromJson(jsonDecode(raw) as Map<String, Object?>);
  _decoded[key] = shape;
  return shape;
}

/// أقصى انتظارٍ لرسم شكلٍ وقتَ اللعب، ثم يُكمل الطفلُ بدونه.
const tracingRasterTimeout = Duration(seconds: 5);

/// الشكلُ لأيّ عنصر: المحسوبُ مسبقاً فوراً، وإلا يُرسم الآن بمهلة
/// [tracingRasterTimeout] — فلا تدور دائرةُ التحميل بلا نهاية.
Future<TracingShape?> loadTracingShape(TracingItem item) async {
  final ready = precomputedTracingShape(item);
  if (ready != null) return ready;
  try {
    return await rasterizeTracingShape(item).timeout(tracingRasterTimeout);
  } on TimeoutException {
    debugPrint('[tracing] "${item.text}" did not render within $tracingRasterTimeout');
    return null;
  } catch (error) {
    debugPrint('[tracing] "${item.text}" failed to render: $error');
    return null;
  }
}

/// يرسم [item] ويبني مساراته الآن — لإجابات الذكاء الاصطناعي، ولتوليد الجدول.
///
/// [planInIsolate]: حسابُ المسار في خيطٍ آخر فلا تتجمّد الشاشة؛ والتوليدُ
/// والاختبارُ يحسبانه في مكانه.
Future<TracingShape?> rasterizeTracingShape(TracingItem item, {bool planInIsolate = true}) async {
  final painter = tracingTextPainter(item);
  final width = (painter.width + tracingPad * 2).ceil();
  final height = (painter.height + tracingPad * 2).ceil();
  if (width <= 0 || height <= 0) return null;

  final recorder = ui.PictureRecorder();
  painter.paint(ui.Canvas(recorder), const Offset(tracingPad, tracingPad));
  final image = await recorder.endRecording().toImage(width, height);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
  image.dispose();
  if (bytes == null) return null;

  final request = _PlanRequest(
    alpha: bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes),
    width: width,
    height: height,
    rtl: item.rtl,
    topFirst: item.kind != 'word' && item.kind != 'answer',
  );
  final result = planInIsolate ? await compute(_planFromPixels, request) : _planFromPixels(request);
  if (result == null) return null;
  return TracingShape(crop: result.crop, plan: result.plan);
}

class _PlanRequest {
  const _PlanRequest({
    required this.alpha,
    required this.width,
    required this.height,
    required this.rtl,
    required this.topFirst,
  });

  /// بكسلاتُ RGBA كما قرأها المحرّك.
  final Uint8List alpha;
  final int width;
  final int height;
  final bool rtl;
  final bool topFirst;
}

class _PlanResult {
  const _PlanResult(this.crop, this.plan);

  final Rect crop;
  final TracePlan plan;
}

/// الحبرُ مقصوصاً حوله بهامش ٣ بكسلات: الإطارُ الذي تُقاس فيه المسارات.
({Rect crop, List<List<bool>> ink})? _inkCrop(Uint8List alpha, int width, int height) {
  var minX = width, minY = height, maxX = -1, maxY = -1;
  final ink = List.generate(height, (_) => List<bool>.filled(width, false));
  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      if (alpha[(y * width + x) * 4 + 3] > 110) {
        ink[y][x] = true;
        if (x < minX) minX = x;
        if (y < minY) minY = y;
        if (x > maxX) maxX = x;
        if (y > maxY) maxY = y;
      }
    }
  }
  if (maxX < 0) return null;
  const margin = 3;
  final left = math.max(0, minX - margin);
  final top = math.max(0, minY - margin);
  final right = math.min(width - 1, maxX + margin);
  final bottom = math.min(height - 1, maxY + margin);
  return (
    crop: Rect.fromLTRB(left.toDouble(), top.toDouble(), right + 1.0, bottom + 1.0),
    ink: [for (var y = top; y <= bottom; y++) ink[y].sublist(left, right + 1)],
  );
}

/// من البكسلات إلى المسار: الحبرُ، ثم القصُّ حوله، ثم [TracePlanner].
_PlanResult? _planFromPixels(_PlanRequest request) {
  final cut = _inkCrop(request.alpha, request.width, request.height);
  if (cut == null) return null;
  final plan = TracePlanner.plan(cut.ink, rtl: request.rtl, topFirst: request.topFirst);
  if (plan.isEmpty) return null;
  return _PlanResult(cut.crop, plan);
}

/// يرسم [item] ويبني مساراته من الطرق المرسومة باليد ([tracingRoutes]) — لتوليد
/// الجدول. الأعدادُ من أكثر من رقمٍ تُركَّب من طرق أرقامها، كلُّ رقمٍ في
/// موضعه من العدد وبترتيب كتابته من اليسار. و`null` لعنصرٍ لا طريقَ له.
Future<TracingShape?> routedTracingShape(TracingItem item) async {
  final painter = tracingTextPainter(item);
  final width = (painter.width + tracingPad * 2).ceil();
  final height = (painter.height + tracingPad * 2).ceil();
  final recorder = ui.PictureRecorder();
  painter.paint(ui.Canvas(recorder), const Offset(tracingPad, tracingPad));
  final image = await recorder.endRecording().toImage(width, height);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
  image.dispose();
  if (bytes == null) return null;
  final alpha = bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes);
  final cut = _inkCrop(alpha, width, height);
  if (cut == null) return null;
  final crop = cut.crop;

  final own = tracingRoutes[tracingGlyphKey(item)];
  final List<List<TracePoint>> routes;
  if (own != null) {
    routes = own;
  } else if (item.kind == 'number' && item.text.length > 1) {
    routes = [];
    final chars = item.text.characters.toList();
    var offset = 0;
    for (final char in chars) {
      final digit = tracingRoutes['number|${item.lang}|$char'];
      if (digit == null) return null;
      // موضعُ الرقم في العدد: صندوقُه في النصّ، ثم حبرُه داخل ذلك الصندوق.
      final box = painter
          .getBoxesForSelection(TextSelection(baseOffset: offset, extentOffset: offset + char.length))
          .first;
      offset += char.length;
      final from = (box.left + tracingPad).floor();
      final to = (box.right + tracingPad).ceil();
      var minX = width, minY = height, maxX = -1, maxY = -1;
      for (var y = 0; y < height; y++) {
        for (var x = math.max(0, from); x < math.min(width, to); x++) {
          if (alpha[(y * width + x) * 4 + 3] > 110) {
            minX = math.min(minX, x);
            maxX = math.max(maxX, x);
            minY = math.min(minY, y);
            maxY = math.max(maxY, y);
          }
        }
      }
      if (maxX < 0) return null;
      final digitCrop = Rect.fromLTRB(minX - 3.0, minY - 3.0, maxX + 4.0, maxY + 4.0);
      for (final stroke in digit) {
        routes.add([
          for (final p in stroke)
            TracePoint(
              (digitCrop.left + p.x * digitCrop.width - crop.left) / crop.width,
              (digitCrop.top + p.y * digitCrop.height - crop.top) / crop.height,
            ),
        ]);
      }
    }
  } else {
    return null;
  }
  final plan = TracePlanner.route(cut.ink, routes);
  if (plan.isEmpty) return null;
  return TracingShape(crop: crop, plan: plan);
}

/// حروفُ الروضة وأرقامُها كما يرسلها الخادم (`alphabetItems` في `lib/tracing.ts`)
/// — ما يُحسب له الجدول.
final kindergartenTracingItems = <TracingItem>[
  for (final letter in [
    'ا', 'ب', 'ت', 'ث', 'ج', 'ح', 'خ', 'د', 'ذ', 'ر', 'ز', 'س', 'ش', 'ص',
    'ض', 'ط', 'ظ', 'ع', 'غ', 'ف', 'ق', 'ك', 'ل', 'م', 'ن', 'ه', 'و', 'ي',
  ])
    TracingItem(text: letter, kind: 'letter', lang: 'ar'),
  for (final pair in [
    'Aa', 'Bb', 'Cc', 'Dd', 'Ee', 'Ff', 'Gg', 'Hh', 'Ii', 'Jj', 'Kk', 'Ll', 'Mm',
    'Nn', 'Oo', 'Pp', 'Qq', 'Rr', 'Ss', 'Tt', 'Uu', 'Vv', 'Ww', 'Xx', 'Yy', 'Zz',
  ])
    TracingItem(text: pair, kind: 'letter', lang: 'en'),
  // من الصفر إلى المئة بالنظامين، كما في `alphabetItems` على الخادم.
  for (var n = 0; n <= 100; n++)
    TracingItem(text: arabicIndicDigits('$n'), kind: 'number', lang: 'ar'),
  for (var n = 0; n <= 100; n++)
    TracingItem(text: '$n', kind: 'number', lang: 'en'),
];

/// «25» بالأرقام الهندية: «٢٥».
String arabicIndicDigits(String value) => value.replaceAllMapped(
      RegExp('[0-9]'),
      (m) => String.fromCharCode(0x0660 + int.parse(m[0]!)),
    );

/// أسماءُ الحروف العربية بأصواتٍ مسجّلة (ElevenLabs)، في `assets/audio/ar/`.
///
/// تُشغَّل هذه بدل محرّك النطق: صوتٌ واحدٌ واضحٌ فصيح على كل جهاز، لا ما
/// يملكه هذا الجهازُ من أصواتٍ أو لا يملكه. والأسماءُ لاتينية في الحزمة —
/// «letter_ba.mp3» لا «حرف الباء.mp3»: المسافةُ والحروفُ العربية في مسارات
/// الأصول تتعثّر على بعض المنصّات — والربطُ بالحرف هنا.
const arabicLetterClips = <String, String>{
  'ا': 'audio/ar/letter_alif.mp3',
  'ب': 'audio/ar/letter_ba.mp3',
  'ت': 'audio/ar/letter_ta.mp3',
  'ث': 'audio/ar/letter_tha.mp3',
  'ج': 'audio/ar/letter_jim.mp3',
  'ح': 'audio/ar/letter_hha.mp3',
  'خ': 'audio/ar/letter_kha.mp3',
  'د': 'audio/ar/letter_dal.mp3',
  'ذ': 'audio/ar/letter_dhal.mp3',
  'ر': 'audio/ar/letter_ra.mp3',
  'ز': 'audio/ar/letter_zay.mp3',
  'س': 'audio/ar/letter_sin.mp3',
  'ش': 'audio/ar/letter_shin.mp3',
  'ص': 'audio/ar/letter_sad.mp3',
  'ض': 'audio/ar/letter_dad.mp3',
  'ط': 'audio/ar/letter_tta.mp3',
  'ظ': 'audio/ar/letter_zza.mp3',
  'ع': 'audio/ar/letter_ain.mp3',
  'غ': 'audio/ar/letter_ghain.mp3',
  'ف': 'audio/ar/letter_fa.mp3',
  'ق': 'audio/ar/letter_qaf.mp3',
  'ك': 'audio/ar/letter_kaf.mp3',
  'ل': 'audio/ar/letter_lam.mp3',
  'م': 'audio/ar/letter_mim.mp3',
  'ن': 'audio/ar/letter_nun.mp3',
  'ه': 'audio/ar/letter_ha.mp3',
  'و': 'audio/ar/letter_waw.mp3',
  'ي': 'audio/ar/letter_ya.mp3',
};

/// المقطعُ المسجّل لعنصرٍ إن كان حرفاً عربياً له تسجيل، وإلا `null` — فيُنطق
/// بمحرّك النطق (الإنجليزيةُ والأعداد).
String? recordedClipFor(TracingItem item) =>
    item.kind == 'letter' && item.lang == 'ar' ? arabicLetterClips[item.text] : null;
