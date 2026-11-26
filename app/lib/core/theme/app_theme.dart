import 'package:material_ui/material_ui.dart';

/// Couleurs du design QuizArena (turquoise, jaune d'accent).
abstract final class AppColors {
  static const background = Color(0xFFE6FAF9);
  static const primary = Color(0xFF1E7F7F);
  static const primarySoft = Color(0xFFCFF3F1);
  static const accent = Color(0xFFFFC857);
  static const ink = Color(0xFF0F2F33);
  static const muted = Color(0xFF3F6468);
  static const border = Color(0xFF9ED8D5);
  static const error = Color(0xFFB3261E);
  static const successBg = Color(0xFFD6F2DA);
  static const successInk = Color(0xFF1B5E20);
  static const neutralBg = Color(0xFFE3E8E8);
  static const neutralInk = Color(0xFF3F4A4A);
}

ThemeData buildAppTheme() {
  final scheme = ColorScheme.fromSeed(seedColor: AppColors.primary).copyWith(
    primary: AppColors.primary,
    onPrimary: Colors.white,
    secondary: AppColors.accent,
    error: AppColors.error,
    surface: Colors.white,
    onSurface: AppColors.ink,
  );

  final shape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(14));
  const textStyle = TextStyle(fontSize: 16, fontWeight: FontWeight.w700);

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: AppColors.background,
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(88, 52),
        shape: shape,
        textStyle: textStyle,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(88, 52),
        foregroundColor: AppColors.primary,
        side: const BorderSide(color: AppColors.primary, width: 2),
        shape: shape,
        textStyle: textStyle,
      ),
    ),
  );
}
