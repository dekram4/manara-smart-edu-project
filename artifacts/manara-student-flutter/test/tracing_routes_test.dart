import 'package:flutter_test/flutter_test.dart';

import 'package:manara_student/src/models/study_games.dart';
import 'package:manara_student/src/services/tracing_glyphs.dart';
import 'package:manara_student/src/services/tracing_path.dart';
import 'package:manara_student/src/services/tracing_routes.dart';

/// طرقُ الكتابة كما تُعلَّم: ترتيبُ الجرّات واتجاهُها في الحروف التي كان
/// الاستنتاجُ من الشكل يخطئها.
void main() {
  TracePlan plan(String text, {String kind = 'letter', String lang = 'ar'}) =>
      precomputedTracingShape(TracingItem(text: text, kind: kind, lang: lang))!.plan;
  List<TraceStroke> lines(TracePlan p) => [for (final s in p.strokes) if (!s.isDot) s];

  test('لكلّ حرفٍ ورقمٍ مفردٍ طريقٌ مرسوم، وكلُّ عددٍ في الجدول', () {
    for (final item in kindergartenTracingItems) {
      if (item.kind == 'letter' || item.text.length == 1) {
        expect(tracingRoutes.containsKey(tracingGlyphKey(item)), isTrue, reason: item.text);
      }
      expect(precomputedTracingShape(item), isNotNull, reason: item.text);
    }
  });

  group('العربية', () {
    test('السينُ والشينُ: الأسنانُ جرّةٌ واحدة من اليمين إلى الحوض', () {
      for (final letter in ['س', 'ش']) {
        final body = lines(plan(letter));
        expect(body, hasLength(1), reason: letter);
        expect(body.single.points.first.x, greaterThan(0.85), reason: '$letter من سنّها الأيمن');
        expect(body.single.points.last.x, lessThan(0.2), reason: '$letter تنتهي بالحوض');
      }
    });

    test('الصادُ والضادُ والعينُ والغينُ والفاءُ والقافُ والميم: جسمٌ واحدٌ بلا تقطيع', () {
      for (final letter in ['ص', 'ض', 'ع', 'غ', 'ف', 'ق', 'م', 'ك']) {
        expect(lines(plan(letter)), hasLength(letter == 'ك' ? 2 : 1), reason: letter);
      }
    });

    test('الفاءُ من رأسها لا من ذيلها', () {
      final first = plan('ف').strokes.first.points.first;
      expect(first.x, greaterThan(0.55));
    });

    test('الطاءُ والظاءُ: العصا بعد الجسم، ومن أعلى إلى أسفل', () {
      for (final letter in ['ط', 'ظ']) {
        final stem = lines(plan(letter))[1];
        expect(stem.points.first.y, lessThan(0.2), reason: letter);
        expect(stem.points.last.y, greaterThan(0.75), reason: letter);
      }
    });

    test('النقاطُ بعد الجسم دائماً', () {
      for (final letter in ['ب', 'ت', 'ث', 'ج', 'خ', 'ذ', 'ز', 'ش', 'ض', 'ظ', 'غ', 'ف', 'ق', 'ن', 'ي']) {
        final strokes = plan(letter).strokes;
        expect(strokes.first.isDot, isFalse, reason: letter);
      }
    });
  });

  group('الإنجليزية', () {
    test('الساقُ أوّلاً ومن أعلى: B D E F H K M N P R', () {
      for (final pair in ['Bb', 'Dd', 'Ee', 'Ff', 'Hh', 'Kk', 'Mm', 'Nn', 'Pp', 'Rr']) {
        final stem = plan(pair, lang: 'en').strokes.first.points;
        expect(stem.first.y, lessThan(stem.last.y), reason: pair);
        expect((stem.first.x - stem.last.x).abs(), lessThan(0.1), reason: pair);
      }
    });

    test('الدوائرُ عكسَ عقارب الساعة من الأعلى: O و C', () {
      for (final pair in ['Oo', 'Cc']) {
        final p = plan(pair, lang: 'en').strokes.first.points;
        // من الأعلى، وأوّلُ الحركة إلى اليسار.
        expect(p.first.y, lessThan(0.2), reason: pair);
        expect(p[2].x, lessThan(p.first.x), reason: pair);
      }
    });

    test('d و q: الدائرةُ ثم الساق', () {
      for (final pair in ['Dd', 'Qq']) {
        final strokes = plan(pair, lang: 'en').strokes;
        final stem = strokes.last.points;
        expect(stem.first.y, lessThan(stem.last.y), reason: pair);
      }
    });
  });

  group('الأرقام', () {
    test('8 جرّةٌ واحدة، و5 ساقُها ثم بطنُها ثم سقفُها', () {
      expect(plan('8', kind: 'number', lang: 'en').strokes, hasLength(1));
      final five = plan('5', kind: 'number', lang: 'en').strokes;
      expect(five, hasLength(2));
      expect(five.last.points.first.y, lessThan(0.2));
    });

    test('٣ و٤ و٩: جرّةٌ واحدة بلا ذيلٍ زائد', () {
      for (final digit in ['٣', '٤', '٩']) {
        expect(plan(digit, kind: 'number').strokes, hasLength(1), reason: digit);
      }
    });

    test('الأعدادُ تُكتب أرقاماً من اليسار: ٢٥ و25', () {
      for (final (text, lang) in [('٢٥', 'ar'), ('25', 'en')]) {
        final strokes = plan(text, kind: 'number', lang: lang).strokes;
        expect(strokes.first.points.first.x, lessThan(0.5), reason: text);
        expect(strokes.last.points.first.x, greaterThan(0.5), reason: text);
      }
    });
  });
}
