import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

abstract final class StudentPalette {
  static const indigo = Color(0xFF4F46E5);
  static const deepIndigo = Color(0xFF312E81);
  static const sky = Color(0xFF0EA5E9);
  static const cyan = Color(0xFF22D3EE);
  static const orange = Color(0xFFF59E0B);
  static const success = Color(0xFF10B981);
  static const ink = Color(0xFF172554);
  static const mutedInk = Color(0xFF526581);
  static const canvas = Color(0xFFF3F7FF);
  static const surface = Color(0xFFFDFEFF);

  /// The Manara blue, sampled from the logo artwork itself rather than
  /// chosen: the mark is a left-to-right gradient, and this is the
  /// dominant colour across its blue end. Used wherever the mark is drawn
  /// as a flat silhouette — the splash, the login board, the path
  /// watermark and the portal top bar — so every one of them is the same
  /// blue as the full-colour original.
  static const brandBlue = Color(0xFF1D517E);
}

/// The handful of colours a screen actually needs to ask the theme for.
///
/// Screens were painting fixed values — `0xFFFDF3EA` for a page, white
/// for a card — which is why dark mode darkened the chrome and left the
/// screens themselves bright. Rather than rewriting three hundred
/// literals into `Theme.of(context).colorScheme.…` at each site, the
/// handful of *roles* those literals played are named here, and each
/// resolves from the brightness in play.
///
/// The roles are deliberately few. A screen needs a ground, a raised
/// surface, two weights of text and a hairline; everything else on these
/// screens is brand colour, which is identity and stays put in both
/// modes because it reads on either ground.
abstract final class StudentSurface {
  static bool isDark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;

  /// The page behind everything. The light value is the warm cream the
  /// screens already used, so nothing changes in light mode.
  static Color ground(BuildContext context) =>
      isDark(context) ? const Color(0xFF121212) : const Color(0xFFFDF3EA);

  /// The cooler ground the entry screens use (login, the path).
  static Color coolGround(BuildContext context) =>
      isDark(context) ? const Color(0xFF121212) : const Color(0xFFEFF3F6);

  /// A card or panel raised above the ground.
  static Color card(BuildContext context) =>
      isDark(context) ? const Color(0xFF1E1E2E) : Colors.white;

  /// A panel that was a translucent white over artwork. Kept translucent
  /// so the watermark still shows through in both modes.
  static Color glass(BuildContext context, [double opacity = 0.88]) => isDark(context)
      ? const Color(0xFF1E1E2E).withOpacity(opacity)
      : Colors.white.withOpacity(opacity);

  /// Body text.
  static Color ink(BuildContext context) =>
      isDark(context) ? const Color(0xFFF3F4F6) : const Color(0xFF183047);

  /// Secondary text: labels, hints, captions.
  static Color mutedInk(BuildContext context) =>
      isDark(context) ? const Color(0xFFB6BDCC) : const Color(0xFF5B6B7C);

  /// The hairline around a card.
  static Color outline(BuildContext context) => isDark(context)
      ? Colors.white.withOpacity(0.16)
      : Colors.black.withOpacity(0.10);

  /// The warm ground the splash and the lesson card use.
  static Color warmGround(BuildContext context) =>
      isDark(context) ? const Color(0xFF121212) : const Color(0xFFFFF7EA);

  /// The empty half of a progress bar, a slider groove, a disabled track —
  /// anything that reads as "the part not filled in yet".
  static Color track(BuildContext context) => isDark(context)
      ? Colors.white.withOpacity(0.14)
      : const Color(0xFFE5EDF5);

  /// The three-stop sweep behind a light app bar. In dark mode it
  /// collapses to the raised surface, because a pale gradient is exactly
  /// what reads as a slab of daylight in a dark app.
  static List<Color> barSweep(BuildContext context) => isDark(context)
      ? const [Color(0xFF1E1E2E), Color(0xFF1A1A28), Color(0xFF1E1E2E)]
      : const [Color(0xFFDCEFF7), Color(0xFFEFF6FA), Color(0xFFFFF6E7)];

  /// A control sitting on top of artwork or a gradient bar: a translucent
  /// wash of the page's own ground rather than a fixed white.
  static Color controlWash(BuildContext context, [double opacity = 0.70]) =>
      isDark(context)
      ? Colors.white.withOpacity(opacity * 0.22)
      : Colors.white.withOpacity(opacity);
}

/// A shared "playful sticker" silhouette used across student-facing cards
/// instead of a plain uniform rounded rectangle — one large corner and one
/// small corner on each edge, so cards read as friendly stickers rather than
/// boxes. Values are RTL-resolved (the app is Arabic-only): the bigger
/// radius sits on the visual-right/start side.
abstract final class StudentShapes {
  static const BorderRadius playfulCard = BorderRadius.only(
    topRight: Radius.circular(34),
    topLeft: Radius.circular(16),
    bottomLeft: Radius.circular(16),
    bottomRight: Radius.circular(34),
  );

  static const BorderRadius playfulCardTight = BorderRadius.only(
    topRight: Radius.circular(24),
    topLeft: Radius.circular(12),
    bottomLeft: Radius.circular(12),
    bottomRight: Radius.circular(24),
  );
}

abstract final class StudentTheme {
  static ThemeData light() {
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: StudentPalette.indigo,
        primary: StudentPalette.indigo,
        secondary: StudentPalette.sky,
        tertiary: StudentPalette.orange,
        brightness: Brightness.light,
        surface: StudentPalette.surface,
      ),
      scaffoldBackgroundColor: StudentPalette.canvas,
      textTheme: GoogleFonts.tajawalTextTheme(),
    );

    return base.copyWith(
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        foregroundColor: StudentPalette.ink,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: StudentPalette.surface,
        surfaceTintColor: Colors.transparent,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(26),
          side: const BorderSide(color: Color(0x1F4F46E5)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white.withOpacity(0.92),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(22),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(22),
          borderSide: const BorderSide(color: Color(0x244F46E5)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(22),
          borderSide: const BorderSide(
            color: StudentPalette.indigo,
            width: 2,
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: StudentPalette.indigo,
          foregroundColor: Colors.white,
          minimumSize: const Size(48, 52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: StudentPalette.deepIndigo,
        contentTextStyle: GoogleFonts.tajawal(
          color: Colors.white,
          fontWeight: FontWeight.w800,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
        ),
      ),
      // The surfaces Material builds for itself. A dialog, a sheet or a
      // dropdown that is never given a colour paints the framework's own
      // default rather than the app's, which is how a light panel survives
      // into a dark app — the one place a screen-by-screen audit cannot
      // reach, because no screen writes the colour.
      dialogTheme: _dialogTheme(StudentPalette.surface, StudentPalette.ink),
      bottomSheetTheme: _sheetTheme(StudentPalette.surface),
      popupMenuTheme: _menuTheme(StudentPalette.surface, StudentPalette.ink),
      dropdownMenuTheme: _dropdownTheme(StudentPalette.surface),
      listTileTheme: const ListTileThemeData(
        textColor: StudentPalette.ink,
        iconColor: StudentPalette.mutedInk,
      ),
      expansionTileTheme: const ExpansionTileThemeData(
        textColor: StudentPalette.ink,
        collapsedTextColor: StudentPalette.ink,
        iconColor: StudentPalette.mutedInk,
        collapsedIconColor: StudentPalette.mutedInk,
      ),
      dividerTheme: const DividerThemeData(color: Color(0x1F4F46E5)),
      iconTheme: const IconThemeData(color: StudentPalette.ink),
      tooltipTheme: _tooltipTheme(StudentPalette.deepIndigo, Colors.white),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: StudentPalette.indigo,
      ),
    );
  }

  // Shared shapes for the component themes above, so light and dark differ
  // only in the two colours each takes and can never drift apart in radius,
  // elevation or padding.

  static DialogThemeData _dialogTheme(Color surface, Color ink) =>
      DialogThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: GoogleFonts.tajawal(
          color: ink,
          fontSize: 20,
          fontWeight: FontWeight.w900,
        ),
        contentTextStyle: GoogleFonts.tajawal(color: ink, height: 1.5),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(26),
        ),
      );

  static BottomSheetThemeData _sheetTheme(Color surface) =>
      BottomSheetThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        modalBackgroundColor: surface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
      );

  static PopupMenuThemeData _menuTheme(Color surface, Color ink) =>
      PopupMenuThemeData(
        color: surface,
        surfaceTintColor: Colors.transparent,
        textStyle: GoogleFonts.tajawal(color: ink, fontWeight: FontWeight.w700),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
        ),
      );

  static DropdownMenuThemeData _dropdownTheme(Color surface) =>
      DropdownMenuThemeData(
        menuStyle: MenuStyle(
          backgroundColor: WidgetStatePropertyAll<Color>(surface),
          surfaceTintColor: const WidgetStatePropertyAll<Color>(
            Colors.transparent,
          ),
        ),
      );

  static TooltipThemeData _tooltipTheme(Color background, Color ink) =>
      TooltipThemeData(
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(12),
        ),
        textStyle: GoogleFonts.tajawal(
          color: ink,
          fontWeight: FontWeight.w700,
        ),
      );

  /// The dark counterpart.
  ///
  /// Built from the same seed so the app keeps its identity rather than
  /// becoming a different product at night: the indigo, sky and orange
  /// accents survive, and only the grounds and the text invert.
  ///
  /// The two dark surfaces are the near-black the request names — #121212 for
  /// the page and #1E1E2E for anything raised above it — which is dark
  /// enough to rest the eyes without the pure black that makes white text
  /// smear on OLED panels.
  static ThemeData dark() {
    const canvas = Color(0xFF121212);
    const surface = Color(0xFF1E1E2E);
    const ink = Color(0xFFF3F4F6);
    const mutedInk = Color(0xFFB6BDCC);

    final base = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: StudentPalette.indigo,
        primary: StudentPalette.sky,
        secondary: StudentPalette.cyan,
        tertiary: StudentPalette.orange,
        brightness: Brightness.dark,
        surface: surface,
      ),
      scaffoldBackgroundColor: canvas,
      textTheme: GoogleFonts.tajawalTextTheme(ThemeData.dark().textTheme),
    );

    return base.copyWith(
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        foregroundColor: ink,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: surface,
        surfaceTintColor: Colors.transparent,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(26),
          side: const BorderSide(color: Color(0x33FFFFFF)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white.withOpacity(0.08),
        hintStyle: const TextStyle(color: mutedInk),
        labelStyle: const TextStyle(color: mutedInk),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(22),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(22),
          borderSide: const BorderSide(color: Color(0x33FFFFFF)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(22),
          borderSide: const BorderSide(color: StudentPalette.sky, width: 2),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: StudentPalette.sky,
          foregroundColor: const Color(0xFF07213A),
          minimumSize: const Size(48, 52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: surface,
        contentTextStyle: GoogleFonts.tajawal(
          color: ink,
          fontWeight: FontWeight.w800,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
        ),
      ),
      dialogTheme: _dialogTheme(surface, ink),
      bottomSheetTheme: _sheetTheme(surface),
      popupMenuTheme: _menuTheme(surface, ink),
      dropdownMenuTheme: _dropdownTheme(surface),
      listTileTheme: const ListTileThemeData(
        textColor: ink,
        iconColor: mutedInk,
      ),
      expansionTileTheme: const ExpansionTileThemeData(
        textColor: ink,
        collapsedTextColor: ink,
        iconColor: mutedInk,
        collapsedIconColor: mutedInk,
      ),
      dividerTheme: const DividerThemeData(color: Color(0x33FFFFFF)),
      iconTheme: const IconThemeData(color: ink),
      tooltipTheme: _tooltipTheme(const Color(0xFF2A2A3E), ink),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: StudentPalette.sky,
      ),
    );
  }
}