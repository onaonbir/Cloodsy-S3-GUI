import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

import 'i18n_tr.dart';

/// Minimal UI translation: the English text is the key, other languages
/// are lookup tables. Missing entries fall back to English, so an
/// untranslated string is never blank.
///
/// Placeholders use `{name}`: `tr('{n} objects', {'n': '3'})`.
class I18n {
  I18n._();

  static const supported = ['en', 'tr'];
  static String _code = 'en';
  static String get code => _code;

  static const Map<String, Map<String, String>> _tables = {'tr': trTable};

  /// [preferred] null → follow the OS language.
  static void setLocale(String? preferred) {
    final sys = ui.PlatformDispatcher.instance.locale.languageCode;
    final c = preferred ?? sys;
    _code = supported.contains(c) ? c : 'en';
  }

  static String translate(String en, [Map<String, Object?>? args]) {
    var s = _code == 'en' ? en : (_tables[_code]?[en] ?? en);
    if (args != null) {
      args.forEach((k, v) => s = s.replaceAll('{$k}', '$v'));
    }
    return s;
  }

  /// Rebuilds every widget after a language switch without resetting any
  /// state (open bucket, running transfers, form input).
  static void rebuildAll(BuildContext context) {
    void mark(Element e) {
      e.markNeedsBuild();
      e.visitChildren(mark);
    }

    (context as Element).visitChildren(mark);
  }
}

String tr(String en, [Map<String, Object?>? args]) => I18n.translate(en, args);

/// "1 object" / "3 objects" with translation of both forms.
String trPlural(int n, String one, String many) =>
    tr(n == 1 ? one : many, {'n': n});
