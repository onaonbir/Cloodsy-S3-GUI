import 'package:material_ui/material_ui.dart';

/// Semantic colour tokens shared with the Cloodsy app family: slate/navy
/// surfaces, Plus Jakarta Sans, and the brand blue of the Cloodsy cloud logo
/// as the accent. Widgets read these via `context.colors`, never raw hex.
@immutable
class AppColors extends ThemeExtension<AppColors> {
  final Color background; // content area
  final Color sidebar;
  final Color titleBar;
  final Color card;
  final Color cardHover;
  final Color border;
  final Color borderStrong;
  final Color foreground;
  final Color muted; // secondary text
  final Color subtle; // tertiary text, placeholders
  final Color primary;
  final Color onPrimary;
  final Color primarySoft;
  final Color success;
  final Color successSoft;
  final Color warning;
  final Color warningSoft;
  final Color danger;
  final Color dangerSoft;
  final Color hover;
  final Color selected;

  const AppColors({
    required this.background,
    required this.sidebar,
    required this.titleBar,
    required this.card,
    required this.cardHover,
    required this.border,
    required this.borderStrong,
    required this.foreground,
    required this.muted,
    required this.subtle,
    required this.primary,
    required this.onPrimary,
    required this.primarySoft,
    required this.success,
    required this.successSoft,
    required this.warning,
    required this.warningSoft,
    required this.danger,
    required this.dangerSoft,
    required this.hover,
    required this.selected,
  });

  static const light = AppColors(
    background: Color(0xFFF8FAFC),
    sidebar: Color(0xFFF1F5F9),
    titleBar: Color(0xFFF1F5F9),
    card: Color(0xFFFFFFFF),
    cardHover: Color(0xFFF8FAFC),
    border: Color(0xFFE2E8F0),
    borderStrong: Color(0xFFCBD5E1),
    foreground: Color(0xFF0F172A),
    muted: Color(0xFF475569),
    subtle: Color(0xFF94A3B8),
    primary: Color(0xFF1D72E8),
    onPrimary: Color(0xFFFFFFFF),
    primarySoft: Color(0x141D72E8),
    success: Color(0xFF16A34A),
    successSoft: Color(0x1A16A34A),
    warning: Color(0xFFD97706),
    warningSoft: Color(0x1AF59E0B),
    danger: Color(0xFFDC2626),
    dangerSoft: Color(0x14DC2626),
    hover: Color(0x0A0F172A),
    selected: Color(0x141D72E8),
  );

  static const dark = AppColors(
    background: Color(0xFF1E2230),
    sidebar: Color(0xFF181C27),
    titleBar: Color(0xFF131720),
    card: Color(0xFF252A38),
    cardHover: Color(0xFF2B3141),
    border: Color(0xFF323849),
    borderStrong: Color(0xFF454C63),
    foreground: Color(0xFFF1F5F9),
    muted: Color(0xFFA7B1C2),
    subtle: Color(0xFF6B758A),
    primary: Color(0xFF4DA3FF),
    onPrimary: Color(0xFF07152B),
    primarySoft: Color(0x224DA3FF),
    success: Color(0xFF4ADE80),
    successSoft: Color(0x1F4ADE80),
    warning: Color(0xFFFBBF24),
    warningSoft: Color(0x1FFBBF24),
    danger: Color(0xFFF87171),
    dangerSoft: Color(0x1FF87171),
    hover: Color(0x0FFFFFFF),
    selected: Color(0x224DA3FF),
  );

  @override
  AppColors copyWith() => this;

  @override
  AppColors lerp(ThemeExtension<AppColors>? other, double t) {
    if (other is! AppColors) return this;
    Color l(Color a, Color b) => Color.lerp(a, b, t)!;
    return AppColors(
      background: l(background, other.background),
      sidebar: l(sidebar, other.sidebar),
      titleBar: l(titleBar, other.titleBar),
      card: l(card, other.card),
      cardHover: l(cardHover, other.cardHover),
      border: l(border, other.border),
      borderStrong: l(borderStrong, other.borderStrong),
      foreground: l(foreground, other.foreground),
      muted: l(muted, other.muted),
      subtle: l(subtle, other.subtle),
      primary: l(primary, other.primary),
      onPrimary: l(onPrimary, other.onPrimary),
      primarySoft: l(primarySoft, other.primarySoft),
      success: l(success, other.success),
      successSoft: l(successSoft, other.successSoft),
      warning: l(warning, other.warning),
      warningSoft: l(warningSoft, other.warningSoft),
      danger: l(danger, other.danger),
      dangerSoft: l(dangerSoft, other.dangerSoft),
      hover: l(hover, other.hover),
      selected: l(selected, other.selected),
    );
  }
}

extension AppColorsContext on BuildContext {
  AppColors get colors => Theme.of(this).extension<AppColors>()!;
}
