import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:manara_student/src/services/tracing_glyphs.dart';

/// الجدولُ المحسوب مسبقاً (`tracing_glyph_data.g.dart`) يطابق ما يُرسم اليوم.
///
/// إن غُيِّر الخطّ أو `tracing_path.dart` أو `tracingTextPainter` ولم يُولَّد
/// الجدولُ من جديد، افترقت نقاطُ اللوحة عن الحرف الذي تحتها بلا خطأٍ ظاهر.
/// فهذا يفشل، ويقول كيف يُصلَح.
void main() {
  testWidgets('الجدولُ المحسوب مسبقاً يطابق الخطَّ والخوارزمية', (tester) async {
    await tester.runAsync(() async {
      final bytes = File('assets/fonts/Tajawal-Bold.ttf').readAsBytesSync();
      await (FontLoader(tracingFontFamily)..addFont(Future.value(ByteData.sublistView(bytes)))).load();
      final stale = <String>[];
      for (final item in kindergartenTracingItems) {
        final fresh = await rasterizeTracingShape(item, planInIsolate: false);
        final stored = precomputedTracingShape(item);
        if (fresh == null || stored == null || jsonEncode(fresh.toJson()) != jsonEncode(stored.toJson())) {
          stale.add(item.text);
        }
      }
      expect(
        stale,
        isEmpty,
        reason: 'الجدولُ قديم لـ ${stale.join(' ')} — شغّل: flutter test tool/generate_tracing_glyphs_test.dart',
      );
    });
  });
}
