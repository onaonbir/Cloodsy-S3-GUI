import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // shadcn zinc palette
  static const _zinc50 = Color(0xFFFAFAFA);
  static const _zinc100 = Color(0xFFF4F4F5);
  static const _zinc200 = Color(0xFFE4E4E7);
  static const _zinc300 = Color(0xFFD4D4D8);
  static const _zinc400 = Color(0xFFA1A1AA);
  static const _zinc500 = Color(0xFF71717A);
  static const _zinc600 = Color(0xFF52525B);
  static const _zinc700 = Color(0xFF3F3F46);
  static const _zinc800 = Color(0xFF27272A);
  static const _zinc900 = Color(0xFF18181B);
  static const _zinc950 = Color(0xFF09090B);

  static const _primary = Color(0xFF171717);
  static const _primaryFg = Color(0xFFFFFFFF);
  static const _destructive = Color(0xFFEF4444);
  static const _blue500 = Color(0xFF3B82F6);

  static ThemeData light() {
    final textTheme = GoogleFonts.geistTextTheme(ThemeData.light().textTheme);

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: _zinc50,
      colorScheme: const ColorScheme.light(
        primary: _primary,
        onPrimary: _primaryFg,
        secondary: _zinc100,
        onSecondary: _zinc900,
        surface: Colors.white,
        onSurface: _zinc950,
        surfaceContainerHighest: _zinc100,
        outline: _zinc300,
        outlineVariant: _zinc200,
        error: _destructive,
        onError: Colors.white,
        tertiary: _blue500,
      ),
      textTheme: textTheme.copyWith(
        headlineLarge: textTheme.headlineLarge?.copyWith(
            fontWeight: FontWeight.w700, color: _zinc950, letterSpacing: -0.5),
        headlineMedium: textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w600, color: _zinc950, letterSpacing: -0.3),
        titleLarge: textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w600, color: _zinc900),
        titleMedium: textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w500, color: _zinc900),
        bodyLarge:
            textTheme.bodyLarge?.copyWith(color: _zinc700),
        bodyMedium:
            textTheme.bodyMedium?.copyWith(color: _zinc600),
        bodySmall:
            textTheme.bodySmall?.copyWith(color: _zinc500),
        labelLarge: textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w500, color: _zinc700),
      ),
      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: _zinc900,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w600, color: _zinc900, fontSize: 18),
        shape: const Border(bottom: BorderSide(color: _zinc200, width: 1)),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: Colors.white,
        surfaceTintColor: Colors.transparent,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: const BorderSide(color: _zinc200, width: 1),
        ),
      ),
      dividerTheme: const DividerThemeData(color: _zinc200, thickness: 1, space: 0),
      inputDecorationTheme: InputDecorationTheme(
        filled: false,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: _zinc300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: _zinc300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: _zinc950, width: 1),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: _destructive),
        ),
        hintStyle: textTheme.bodyMedium?.copyWith(color: _zinc400),
        labelStyle: textTheme.bodyMedium?.copyWith(color: _zinc500),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: _primary,
          foregroundColor: _primaryFg,
          minimumSize: const Size(0, 40),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: _zinc700,
          minimumSize: const Size(0, 40),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          side: const BorderSide(color: _zinc300),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: _zinc600,
          minimumSize: const Size(0, 40),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 8,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        titleTextStyle: textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w600, color: _zinc900, fontSize: 18),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: _zinc100,
        side: const BorderSide(color: _zinc200),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        labelStyle: textTheme.bodySmall?.copyWith(color: _zinc700),
        padding: const EdgeInsets.symmetric(horizontal: 4),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: _zinc900,
        contentTextStyle: textTheme.bodyMedium?.copyWith(color: Colors.white),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: _primary,
        foregroundColor: _primaryFg,
        elevation: 0,
        hoverElevation: 1,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: _zinc900,
        unselectedLabelColor: _zinc500,
        indicatorColor: _zinc900,
        indicatorSize: TabBarIndicatorSize.label,
        labelStyle: textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w500),
        unselectedLabelStyle:
            textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w400),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) =>
            states.contains(WidgetState.selected)
                ? Colors.white
                : _zinc400),
        trackColor: WidgetStateProperty.resolveWith((states) =>
            states.contains(WidgetState.selected)
                ? _zinc900
                : _zinc200),
        trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
      ),
      progressIndicatorTheme:
          const ProgressIndicatorThemeData(color: _zinc900),
      iconTheme: const IconThemeData(color: _zinc600, size: 20),
      listTileTheme: ListTileThemeData(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  static ThemeData dark() {
    final textTheme = GoogleFonts.geistTextTheme(ThemeData.dark().textTheme);

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: _zinc950,
      colorScheme: const ColorScheme.dark(
        primary: _zinc50,
        onPrimary: _zinc900,
        secondary: _zinc800,
        onSecondary: _zinc100,
        surface: _zinc900,
        onSurface: _zinc50,
        surfaceContainerHighest: _zinc800,
        outline: _zinc700,
        outlineVariant: _zinc800,
        error: _destructive,
        onError: Colors.white,
        tertiary: _blue500,
      ),
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: _zinc900,
        foregroundColor: _zinc50,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w600, color: _zinc50, fontSize: 18),
        shape: const Border(bottom: BorderSide(color: _zinc800, width: 1)),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: _zinc900,
        surfaceTintColor: Colors.transparent,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: const BorderSide(color: _zinc800, width: 1),
        ),
      ),
      dividerTheme: const DividerThemeData(color: _zinc800, thickness: 1, space: 0),
      inputDecorationTheme: InputDecorationTheme(
        filled: false,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: _zinc700),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: _zinc700),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: _zinc400, width: 1),
        ),
        hintStyle: textTheme.bodyMedium?.copyWith(color: _zinc600),
        labelStyle: textTheme.bodyMedium?.copyWith(color: _zinc500),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: _zinc50,
          foregroundColor: _zinc900,
          minimumSize: const Size(0, 40),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: _zinc300,
          minimumSize: const Size(0, 40),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          side: const BorderSide(color: _zinc700),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: _zinc900,
        surfaceTintColor: Colors.transparent,
        elevation: 8,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        titleTextStyle: textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w600, color: _zinc50, fontSize: 18),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: _zinc800,
        side: const BorderSide(color: _zinc700),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        labelStyle: textTheme.bodySmall?.copyWith(color: _zinc300),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: _zinc50,
        contentTextStyle: textTheme.bodyMedium?.copyWith(color: _zinc900),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: _zinc50,
        foregroundColor: _zinc900,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: _zinc50,
        unselectedLabelColor: _zinc500,
        indicatorColor: _zinc50,
        indicatorSize: TabBarIndicatorSize.label,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) =>
            states.contains(WidgetState.selected)
                ? _zinc900
                : _zinc600),
        trackColor: WidgetStateProperty.resolveWith((states) =>
            states.contains(WidgetState.selected)
                ? _zinc100
                : _zinc700),
        trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
      ),
      progressIndicatorTheme:
          const ProgressIndicatorThemeData(color: _zinc50),
      iconTheme: const IconThemeData(color: _zinc400, size: 20),
    );
  }
}
