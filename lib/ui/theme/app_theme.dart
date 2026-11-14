import 'package:material_ui/material_ui.dart';

import 'app_colors.dart';
import 'tokens.dart';

class AppTheme {
  AppTheme._();

  static ThemeData light() => _build(AppColors.light, Brightness.light);
  static ThemeData dark() => _build(AppColors.dark, Brightness.dark);

  static TextTheme _textTheme(AppColors c) {
    TextStyle s(double size, FontWeight w, {double ls = 0, Color? color, double? h}) =>
        TextStyle(
          fontFamily: AppFonts.sans,
          fontSize: size,
          fontWeight: w,
          letterSpacing: ls,
          height: h,
          color: color ?? c.foreground,
        );
    return TextTheme(
      displaySmall: s(30, FontWeight.w700, ls: -0.6),
      headlineMedium: s(24, FontWeight.w700, ls: -0.4),
      headlineSmall: s(20, FontWeight.w700, ls: -0.3),
      titleLarge: s(18, FontWeight.w600, ls: -0.2),
      titleMedium: s(15, FontWeight.w600, ls: -0.1),
      titleSmall: s(13.5, FontWeight.w600),
      bodyLarge: s(14, FontWeight.w400, h: 1.45),
      bodyMedium: s(13, FontWeight.w400, color: c.muted, h: 1.45),
      bodySmall: s(12, FontWeight.w400, color: c.subtle, h: 1.4),
      labelLarge: s(13, FontWeight.w600),
      labelMedium: s(12, FontWeight.w600, color: c.muted),
      labelSmall: s(11, FontWeight.w600, ls: 0.6, color: c.subtle),
    );
  }

  static ThemeData _build(AppColors c, Brightness brightness) {
    final text = _textTheme(c);
    final scheme = ColorScheme(
      brightness: brightness,
      primary: c.primary,
      onPrimary: c.onPrimary,
      secondary: c.primary,
      onSecondary: c.onPrimary,
      error: c.danger,
      onError: Colors.white,
      surface: c.background,
      onSurface: c.foreground,
      onSurfaceVariant: c.muted,
      surfaceContainerLowest: c.card,
      surfaceContainerLow: c.card,
      surfaceContainer: c.card,
      surfaceContainerHigh: c.card,
      surfaceContainerHighest: c.sidebar,
      outline: c.borderStrong,
      outlineVariant: c.border,
      tertiary: c.success,
      onTertiary: Colors.white,
    );

    final inputBorder = OutlineInputBorder(
      borderRadius: AppRadius.mdAll,
      borderSide: BorderSide(color: c.borderStrong),
    );

    final buttonShape =
        const RoundedRectangleBorder(borderRadius: AppRadius.mdAll);
    const buttonPadding = EdgeInsets.symmetric(horizontal: 14, vertical: 10);
    const buttonMin = Size(0, 36);

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      fontFamily: AppFonts.sans,
      textTheme: text,
      scaffoldBackgroundColor: c.background,
      canvasColor: c.background,
      dividerColor: c.border,
      splashFactory: NoSplash.splashFactory,
      highlightColor: Colors.transparent,
      hoverColor: c.hover,
      focusColor: c.primarySoft,
      visualDensity: VisualDensity.standard,
      extensions: [c],
      iconTheme: IconThemeData(color: c.muted, size: 18),
      dividerTheme: DividerThemeData(color: c.border, thickness: 1, space: 1),
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: c.titleBar,
        foregroundColor: c.foreground,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: text.titleMedium,
        shape: Border(bottom: BorderSide(color: c.border)),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        color: c.card,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.lgAll,
          side: BorderSide(color: c.border),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        isDense: true,
        filled: true,
        fillColor: c.card,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        border: inputBorder,
        enabledBorder: inputBorder,
        focusedBorder: inputBorder.copyWith(
            borderSide: BorderSide(color: c.primary, width: 1.5)),
        errorBorder:
            inputBorder.copyWith(borderSide: BorderSide(color: c.danger)),
        focusedErrorBorder: inputBorder.copyWith(
            borderSide: BorderSide(color: c.danger, width: 1.5)),
        hintStyle: text.bodyMedium?.copyWith(color: c.subtle),
        labelStyle: text.bodyMedium,
        floatingLabelStyle: text.bodyMedium?.copyWith(color: c.primary),
        helperStyle: text.bodySmall,
        errorStyle: text.bodySmall?.copyWith(color: c.danger),
        prefixIconColor: c.subtle,
        suffixIconColor: c.subtle,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: c.primary,
          foregroundColor: c.onPrimary,
          disabledBackgroundColor: c.border,
          minimumSize: buttonMin,
          padding: buttonPadding,
          shape: buttonShape,
          textStyle: text.labelLarge,
          elevation: 0,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: c.foreground,
          backgroundColor: c.card,
          minimumSize: buttonMin,
          padding: buttonPadding,
          shape: buttonShape,
          side: BorderSide(color: c.borderStrong),
          textStyle: text.labelLarge,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: c.muted,
          minimumSize: buttonMin,
          padding: buttonPadding,
          shape: buttonShape,
          textStyle: text.labelLarge,
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: c.muted,
          minimumSize: const Size(32, 32),
          padding: const EdgeInsets.all(6),
          iconSize: 18,
          shape: buttonShape,
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: c.card,
        surfaceTintColor: Colors.transparent,
        elevation: 12,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.xlAll,
          side: BorderSide(color: c.border),
        ),
        titleTextStyle: text.titleLarge,
        contentTextStyle: text.bodyLarge?.copyWith(color: c.muted),
        actionsPadding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: c.card,
        surfaceTintColor: Colors.transparent,
        elevation: 8,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.lgAll,
          side: BorderSide(color: c.border),
        ),
        textStyle: text.bodyLarge,
        labelTextStyle: WidgetStatePropertyAll(text.bodyLarge),
      ),
      menuTheme: MenuThemeData(
        style: MenuStyle(
          backgroundColor: WidgetStatePropertyAll(c.card),
          surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
          shape: WidgetStatePropertyAll(RoundedRectangleBorder(
            borderRadius: AppRadius.lgAll,
            side: BorderSide(color: c.border),
          )),
        ),
      ),
      tooltipTheme: TooltipThemeData(
        waitDuration: const Duration(milliseconds: 400),
        decoration: BoxDecoration(
          color: brightness == Brightness.dark
              ? const Color(0xFFF1F5F9)
              : const Color(0xFF0F172A),
          borderRadius: AppRadius.smAll,
        ),
        textStyle: text.bodySmall?.copyWith(
          color: brightness == Brightness.dark
              ? const Color(0xFF0F172A)
              : Colors.white,
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: brightness == Brightness.dark
            ? const Color(0xFFF1F5F9)
            : const Color(0xFF0F172A),
        contentTextStyle: text.bodyLarge?.copyWith(
          color: brightness == Brightness.dark
              ? const Color(0xFF0F172A)
              : Colors.white,
        ),
        actionTextColor: c.primary,
        width: 440,
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.lgAll),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((s) =>
            s.contains(WidgetState.selected) ? c.onPrimary : c.subtle),
        trackColor: WidgetStateProperty.resolveWith((s) =>
            s.contains(WidgetState.selected) ? c.primary : c.border),
        trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
      ),
      checkboxTheme: CheckboxThemeData(
        shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(4))),
        side: BorderSide(color: c.borderStrong, width: 1.5),
        fillColor: WidgetStateProperty.resolveWith((s) =>
            s.contains(WidgetState.selected) ? c.primary : Colors.transparent),
        checkColor: WidgetStatePropertyAll(c.onPrimary),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          visualDensity: VisualDensity.compact,
          textStyle: WidgetStatePropertyAll(text.labelLarge),
          side: WidgetStatePropertyAll(BorderSide(color: c.borderStrong)),
          shape: const WidgetStatePropertyAll(
              RoundedRectangleBorder(borderRadius: AppRadius.mdAll)),
          backgroundColor: WidgetStateProperty.resolveWith((s) =>
              s.contains(WidgetState.selected) ? c.primarySoft : c.card),
          foregroundColor: WidgetStateProperty.resolveWith((s) =>
              s.contains(WidgetState.selected) ? c.primary : c.muted),
        ),
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: c.foreground,
        unselectedLabelColor: c.muted,
        indicatorColor: c.primary,
        indicatorSize: TabBarIndicatorSize.label,
        dividerColor: c.border,
        labelStyle: text.labelLarge,
        unselectedLabelStyle:
            text.labelLarge?.copyWith(fontWeight: FontWeight.w500),
        overlayColor: const WidgetStatePropertyAll(Colors.transparent),
        tabAlignment: TabAlignment.start,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: c.primary,
        linearTrackColor: c.border,
        circularTrackColor: Colors.transparent,
      ),
      listTileTheme: ListTileThemeData(
        iconColor: c.muted,
        titleTextStyle: text.titleSmall,
        subtitleTextStyle: text.bodySmall,
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.mdAll),
      ),
      drawerTheme: DrawerThemeData(
        backgroundColor: c.sidebar,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(),
      ),
      scrollbarTheme: ScrollbarThemeData(
        thumbColor: WidgetStatePropertyAll(c.borderStrong),
        radius: const Radius.circular(8),
        thickness: const WidgetStatePropertyAll(6),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: c.primary,
        foregroundColor: c.onPrimary,
        elevation: 2,
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.lgAll),
      ),
    );
  }
}
