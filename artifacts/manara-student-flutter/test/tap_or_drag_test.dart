import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:manara_student/src/utils/tap_or_drag.dart';

/// يحرس العطب المُبلَّغ: ينقطع الصوت عند النزول بالصفحة لقراءة بقيّة
/// الجواب.
///
/// بطاقةُ حلّ المسائل تجعل الشاشة كلَّها زرَّ إيقافٍ للنطق، وكان الحارس
/// يعمل عند نزول الإصبع — وهو أوّلُ ما يقع في التمرير أيضاً. فالطفل
/// يُمرّر ليتابع القراءة والسماع معاً، فيُسكت ما جاء يتابعه.
void main() {
  test('لمسةٌ في موضعها تعني «اسكت»', () {
    final touch = TapOrDrag();
    touch.down(const Offset(100, 200));
    expect(touch.upIsTap(const Offset(100, 200)), isTrue);
  });

  test('واهتزازُ إصبعٍ دون العتبة لمسةٌ لا تمرير', () {
    // إصبعُ طفلٍ لا يقف ساكناً تماماً، وبكسلين من الحركة لا يُلغى قصدُه.
    final touch = TapOrDrag();
    touch.down(const Offset(100, 200));
    touch.move(const Offset(101, 202));
    expect(touch.upIsTap(const Offset(101, 202)), isTrue);
    expect(touch.dragged, isFalse);
  });

  test('والتمريرُ لا يُسكت — وهذا هو العطب المُبلَّغ', () {
    final touch = TapOrDrag();
    touch.down(const Offset(100, 400));
    // نزولٌ بالصفحة: ما يفعله الطفل ليقرأ بقيّة الجواب.
    touch.move(const Offset(100, 400 - kTouchSlop - 1));
    touch.move(const Offset(100, 120));
    expect(touch.dragged, isTrue);
    expect(touch.upIsTap(const Offset(100, 120)), isFalse);
  });

  test('والعتبةُ هي عتبةُ Flutter نفسها لا رقمٌ يخالفها', () {
    final touch = TapOrDrag();
    touch.down(Offset.zero);
    // عندها بالضبط: لمسةٌ بعد.
    expect(touch.upIsTap(const Offset(0, kTouchSlop)), isTrue);
    touch.down(Offset.zero);
    // وبعدها بشعرة: تمرير.
    expect(touch.upIsTap(const Offset(0, kTouchSlop + 0.01)), isFalse);
  });

  test('ويُقاس عند الرفع ولو لم تصل حركةٌ واحدة', () {
    // منصّةٌ تُرسل النزولَ والرفعَ بلا `move` بينهما تترك السحبَ غيرَ
    // ملحوظٍ لولا القياس عند الرفع.
    final touch = TapOrDrag();
    touch.down(const Offset(0, 400));
    expect(touch.upIsTap(const Offset(0, 100)), isFalse);
  });

  test('والإلغاءُ يُنهي اللمسة فلا تُحسب رفعةً بعده', () {
    final touch = TapOrDrag();
    touch.down(const Offset(10, 10));
    expect(touch.active, isTrue);
    touch.cancel();
    expect(touch.active, isFalse);
    expect(touch.upIsTap(const Offset(10, 10)), isFalse);
  });

  test('ورفعةٌ بلا نزولٍ لا تُسكت', () {
    expect(TapOrDrag().upIsTap(Offset.zero), isFalse);
  });
}
