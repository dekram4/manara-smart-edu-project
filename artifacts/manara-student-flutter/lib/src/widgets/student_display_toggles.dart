import 'package:flutter/material.dart';

import '../l10n/student_strings.dart';
import '../services/student_settings.dart';
import '../services/student_sound_service.dart';

/// The sun/moon button. Switches theme on the frame it is tapped.
class StudentThemeToggle extends StatelessWidget {
  const StudentThemeToggle({this.color, super.key});

  /// Overridden on screens that paint their own bar and need the icon to
  /// read against it; elsewhere the theme's own foreground is right.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: StudentSettings.themeMode,
      builder: (context, mode, _) {
        final dark = mode == ThemeMode.dark;
        return IconButton(
          onPressed: () {
            StudentSoundService.instance.playTap();
            StudentSettings.toggleTheme();
          },
          color: color,
          tooltip: tr(
            dark ? 'settings.theme.toLight' : 'settings.theme.toDark',
          ),
          // Shows the state it will switch *to*, which is what a child
          // reads a toggle as: press the moon to get night.
          icon: Icon(dark ? Icons.light_mode_rounded : Icons.dark_mode_rounded),
        );
      },
    );
  }
}

/// The AR/EN button. Switches language and direction together, with no
/// restart — the whole app rebuilds from the notifier in main.dart.
class StudentLanguageToggle extends StatelessWidget {
  const StudentLanguageToggle({this.color, super.key});

  final Color? color;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Locale>(
      valueListenable: StudentSettings.locale,
      builder: (context, locale, _) {
        final arabic = locale.languageCode == 'ar';
        return Tooltip(
          message: tr('settings.language'),
          child: InkResponse(
            onTap: () {
              StudentSoundService.instance.playTap();
              StudentSettings.toggleLocale();
            },
            radius: 26,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.language_rounded, size: 20, color: color),
                  const SizedBox(width: 4),
                  // Names the language a press switches to, matching the
                  // theme button beside it rather than labelling the
                  // current state and reading as a contradiction.
                  Text(
                    arabic ? 'EN' : 'ع',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 13,
                      color: color,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Both toggles side by side, for a bar that wants the pair.
class StudentDisplayToggles extends StatelessWidget {
  const StudentDisplayToggles({this.color, super.key});

  final Color? color;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          StudentThemeToggle(color: color),
          StudentLanguageToggle(color: color),
        ],
      );
}
