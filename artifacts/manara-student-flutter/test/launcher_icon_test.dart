import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';

/// The launcher icon is the two characters and the Manara mark with nothing
/// behind them. It has swung between a blue square, a white one and a black
/// one filled in by the launcher; these pin down the version asked for.
void main() {
  test('there is no adaptive icon, and so no background layer', () {
    // An adaptive icon always carries a background layer: a colour draws a
    // square behind the characters, and a transparent one was filled with
    // black by tablet and Samsung launchers.
    expect(
      File('android/app/src/main/res/mipmap-anydpi-v26/ic_launcher.xml')
          .existsSync(),
      isFalse,
    );
    final pubspec = File('pubspec.yaml').readAsStringSync();
    expect(pubspec, isNot(contains('adaptive_icon_background:')));
    expect(pubspec, isNot(contains('adaptive_icon_foreground:')));
  });

  testWidgets('every launcher image is fully transparent around the artwork',
      (tester) async {
    for (final density in ['mdpi', 'hdpi', 'xhdpi', 'xxhdpi', 'xxxhdpi']) {
      final path = 'android/app/src/main/res/mipmap-$density/ic_launcher.png';
      final bytes = File(path).readAsBytesSync();
      final pixels = await tester.runAsync(() async {
        final codec = await ui.instantiateImageCodec(bytes);
        final image = (await codec.getNextFrame()).image;
        final data =
            await image.toByteData(format: ui.ImageByteFormat.rawRgba);
        return (image.width, image.height, data!);
      });
      final (width, height, data) = pixels!;
      int alphaAt(int x, int y) => data.getUint8((y * width + x) * 4 + 3);
      for (final (x, y) in [
        (0, 0),
        (width - 1, 0),
        (0, height - 1),
        (width - 1, height - 1),
        (width ~/ 2, 0),
        (0, height ~/ 2),
      ]) {
        expect(alphaAt(x, y), 0,
            reason: '$path has a background at ($x, $y)');
      }
    }
  });
}
