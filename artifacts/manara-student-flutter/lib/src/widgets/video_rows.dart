import 'dart:math' as math;

import 'package:flutter/widgets.dart';

/// قائمةُ فيديوهاتٍ بلا حدّ: صفوفٌ تُبنى كسولةً أثناء التمرير، وارتفاعُ كلِّ صفٍّ
/// من محتواه.
///
/// ── لماذا لا شبكة ──
/// كانت «شرح الدرس» و«سينما منارة» شبكةً (GridView) داخل قائمة، بنسبة ارتفاعٍ
/// ثابتة لكل خانة (1.30). فعنوانٌ طويل، أو خطٌّ كبيرٌ في إعدادات الجهاز، يتجاوز
/// الخانةَ فيُقصّ أو يفيض. والشبكةُ داخل القائمة تُبنى كلُّها مرّةً واحدة ولو
/// كانت مئة فيديو. هنا: عددُ الأعمدة من العرض كما كان (عمودٌ لكل ٣٣٠ نقطة)،
/// والصفُّ يأخذ ارتفاعَ أطولِ بطاقةٍ فيه، والصفوفُ تُبنى حين تقترب من الشاشة.
///
/// البطاقةُ نفسها وما تفعله عند اللمس لا تتغيّر — هذه الحاوية وحدها.
class SliverVideoRows extends StatelessWidget {
  const SliverVideoRows({
    required this.itemCount,
    required this.itemBuilder,
    this.maxCrossAxisExtent = 330,
    this.mainAxisSpacing = 18,
    this.crossAxisSpacing = 14,
    super.key,
  });

  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;
  final double maxCrossAxisExtent;
  final double mainAxisSpacing;
  final double crossAxisSpacing;

  /// عددُ الأعمدة لهذا العرض — كـ `SliverGridDelegateWithMaxCrossAxisExtent`.
  static int columnsFor(double width, double maxExtent, double spacing) =>
      math.max(1, ((width + spacing) / (maxExtent + spacing)).ceil());

  @override
  Widget build(BuildContext context) {
    return SliverLayoutBuilder(
      builder: (context, constraints) {
        final columns = columnsFor(
          constraints.crossAxisExtent,
          maxCrossAxisExtent,
          crossAxisSpacing,
        );
        final rows = (itemCount / columns).ceil();
        return SliverList.builder(
          itemCount: rows,
          itemBuilder: (context, row) {
            final start = row * columns;
            return Padding(
              padding: EdgeInsets.only(top: row == 0 ? 0 : mainAxisSpacing),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var column = 0; column < columns; column++) ...[
                    if (column > 0) SizedBox(width: crossAxisSpacing),
                    Expanded(
                      child: start + column < itemCount
                          ? itemBuilder(context, start + column)
                          : const SizedBox.shrink(),
                    ),
                  ],
                ],
              ),
            );
          },
        );
      },
    );
  }
}
