import 'package:flutter_test/flutter_test.dart';

import 'package:manara_student/src/services/tracing_path.dart';

/// شبكةٌ من رسمٍ نصّيّ: `#` حبر.
List<List<bool>> grid(List<String> rows) => [
      for (final row in rows) [for (final c in row.split('')) c == '#'],
    ];

/// خطٌّ أفقيٌّ سميك بعرض [w] وسُمك [t]، في شبكةٍ بهامش.
List<List<bool>> bar({int w = 60, int t = 7, int pad = 4}) => [
      for (var y = 0; y < t + pad * 2; y++)
        [
          for (var x = 0; x < w + pad * 2; x++)
            y >= pad && y < pad + t && x >= pad && x < pad + w,
        ],
    ];

void main() {
  test('خطٌّ أفقي: جرّةٌ واحدة تبدأ من اليمين في العربية', () {
    final plan = TracePlanner.plan(bar(), rtl: true);
    expect(plan.strokes, hasLength(1));
    final points = plan.strokes.single.points;
    expect(points.length, greaterThan(3));
    expect(points.first.x, greaterThan(points.last.x), reason: 'من اليمين إلى اليسار');
  });

  test('والإنجليزيةُ من اليسار', () {
    final points = TracePlanner.plan(bar(), rtl: false).strokes.single.points;
    expect(points.first.x, lessThan(points.last.x));
  });

  test('النقاطُ متتابعةٌ متقاربة: لا قفزةَ تسمح بتجاوز جزءٍ من الحرف', () {
    final plan = TracePlanner.plan(bar(w: 120), rtl: true);
    final points = plan.strokes.single.points;
    for (var i = 1; i < points.length; i++) {
      expect(points[i].distanceTo(points[i - 1]), lessThan(0.25));
    }
  });

  test('عمودٌ رأسي: يبدأ من أعلاه', () {
    final rows = [
      for (var y = 0; y < 70; y++)
        [for (var x = 0; x < 20; x++) x >= 6 && x < 13 && y >= 4 && y < 66],
    ];
    final points = TracePlanner.plan(rows, rtl: true).strokes.single.points;
    expect(points.first.y, lessThan(points.last.y));
  });

  test('جسمٌ ونقطةٌ تحته (كالباء): الجسمُ أوّلاً ثم النقطةُ لمسةً واحدة', () {
    final rows = [
      for (var y = 0; y < 60; y++)
        [
          for (var x = 0; x < 90; x++)
            (y >= 10 && y < 18 && x >= 5 && x < 85) ||
                (y >= 38 && y < 46 && x >= 40 && x < 48),
        ],
    ];
    final plan = TracePlanner.plan(rows, rtl: true);
    expect(plan.strokes, hasLength(2));
    expect(plan.strokes.first.isDot, isFalse);
    expect(plan.strokes.last.isDot, isTrue);
    expect(plan.strokes.last.points.single.y, greaterThan(0.5));
  });

  test('حلقةٌ بلا طرف (كالصفر): جرّةٌ تبدأ من أعلاها', () {
    final rows = [
      for (var y = 0; y < 80; y++)
        [
          for (var x = 0; x < 80; x++)
            () {
              final d = (x - 40) * (x - 40) + (y - 40) * (y - 40);
              return d <= 34 * 34 && d >= 26 * 26;
            }(),
        ],
    ];
    final plan = TracePlanner.plan(rows, rtl: false);
    expect(plan.strokes, isNotEmpty);
    expect(plan.strokes.first.points.first.y, lessThan(0.2));
    expect(plan.strokes.first.points.length, greaterThan(6));
  });

  test('شبكةٌ فارغة: لا مسار', () {
    expect(TracePlanner.plan(grid(['....', '....']), rtl: true).isEmpty, isTrue);
    expect(TracePlanner.plan(const [], rtl: true).isEmpty, isTrue);
  });

  test('سُمكُ الخطّ يُقدَّر نسبةً إلى ارتفاعه', () {
    final plan = TracePlanner.plan(bar(t: 7), rtl: true);
    expect(plan.inkWidth, greaterThan(0.5)); // الشكلُ سُمكه كلُّ ارتفاعه
  });
}
