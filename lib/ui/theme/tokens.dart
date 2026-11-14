import 'package:flutter/widgets.dart';

class AppRadius {
  AppRadius._();
  static const double sm = 6;
  static const double md = 8;
  static const double lg = 10;
  static const double xl = 14;

  static const BorderRadius smAll = BorderRadius.all(Radius.circular(sm));
  static const BorderRadius mdAll = BorderRadius.all(Radius.circular(md));
  static const BorderRadius lgAll = BorderRadius.all(Radius.circular(lg));
  static const BorderRadius xlAll = BorderRadius.all(Radius.circular(xl));
}

class AppSpace {
  AppSpace._();
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;

  /// Horizontal page gutter for content screens.
  static const double page = 28;
}

class AppDuration {
  AppDuration._();
  static const Duration fast = Duration(milliseconds: 120);
  static const Duration normal = Duration(milliseconds: 200);
}

class AppFonts {
  AppFonts._();
  static const String sans = 'PlusJakartaSans';
  static const String mono = 'JetBrainsMono';
}

/// Layout breakpoints.
class AppBreakpoints {
  AppBreakpoints._();

  /// At or above this width the sidebar is persistent; below it the shell
  /// switches to an app bar + drawer.
  static const double sidebar = 860;
}
