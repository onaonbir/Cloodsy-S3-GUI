import 'package:material_ui/material_ui.dart';

/// Semantic colour tokens shared with the Cloodsy app family: the brand kit's
/// ink and cream with turquoise as the one accent (signal turquoise on ink,
/// deep turquoise on cream), the same values as the app's
/// shared/design/tokens.json. Widgets read these via `context.colors`, never raw hex.
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
    background: Color(0xFFF2EFE8),
    sidebar: Color(0xFFEBE7DE),
    titleBar: Color(0xFFE4E0D6),
    card: Color(0xFFFBFAF6),
    cardHover: Color(0xFFF6F3EC),
    border: Color(0xFFDCD8CE),
    borderStrong: Color(0xFFC9C4B8),
    foreground: Color(0xFF161B29),
    muted: Color(0xFF5E6678),
    subtle: Color(0xFF8A90A0),
    primary: Color(0xFF0A6E90),
    onPrimary: Color(0xFFFFFFFF),
    primarySoft: Color(0x140A6E90),
    success: Color(0xFF12703A),
    successSoft: Color(0x1A12703A),
    warning: Color(0xFFA15C07),
    warningSoft: Color(0x1AA15C07),
    danger: Color(0xFFC0392B),
    dangerSoft: Color(0x14C0392B),
    hover: Color(0x0A161B29),
    selected: Color(0x140A6E90),
  );

  static const dark = AppColors(
    background: Color(0xFF161B29),
    sidebar: Color(0xFF121725),
    titleBar: Color(0xFF0E121C),
    card: Color(0xFF1D2333),
    cardHover: Color(0xFF232A3C),
    border: Color(0xFF2A3246),
    borderStrong: Color(0xFF353D53),
    foreground: Color(0xFFF2EFE8),
    muted: Color(0xFFA3A9B8),
    subtle: Color(0xFF6B7385),
    primary: Color(0xFF2EC8F0),
    onPrimary: Color(0xFF0B1220),
    primarySoft: Color(0x222EC8F0),
    success: Color(0xFF4FD08A),
    successSoft: Color(0x1F4FD08A),
    warning: Color(0xFFF2B544),
    warningSoft: Color(0x1FF2B544),
    danger: Color(0xFFF2665E),
    dangerSoft: Color(0x1FF2665E),
    hover: Color(0x0FFFFFFF),
    selected: Color(0x222EC8F0),
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
