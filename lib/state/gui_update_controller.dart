import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../core/format.dart';

/// Checks GitHub once per launch for a newer release of this app.
class GuiUpdateController extends ChangeNotifier {
  static const repo = 'onaonbir/Cloodsy-S3-GUI';

  final String currentVersion;
  final http.Client? _client;

  GuiUpdateController(this.currentVersion, {http.Client? client})
      : _client = client; // ignore: prefer_initializing_formals

  String? _latest;
  String? _url;
  String? _notes;
  bool _checking = false;
  DateTime? _checkedAt;
  String? _error;

  String? get latest => _latest;
  String get releaseUrl =>
      _url ?? 'https://github.com/$repo/releases/latest';
  String? get notes => _notes;
  bool get checking => _checking;
  DateTime? get checkedAt => _checkedAt;
  String? get error => _error;

  bool get available =>
      _latest != null && compareVersions(currentVersion, _latest!) < 0;

  Future<void> check() async {
    if (_checking) return;
    _checking = true;
    _error = null;
    notifyListeners();
    final client = _client ?? http.Client();
    try {
      final r = await client
          .get(Uri.parse('https://api.github.com/repos/$repo/releases/latest'),
              headers: {'Accept': 'application/vnd.github+json'})
          .timeout(const Duration(seconds: 8));
      if (r.statusCode == 200) {
        final j = jsonDecode(r.body) as Map<String, dynamic>;
        final tag = (j['tag_name'] as String? ?? '').replaceFirst('v', '');
        if (tag.isNotEmpty) _latest = tag;
        _url = j['html_url'] as String?;
        _notes = j['body'] as String?;
      } else if (r.statusCode != 404) {
        _error = 'GitHub answered ${r.statusCode}';
      }
      _checkedAt = DateTime.now();
    } catch (e) {
      _error = 'Could not reach GitHub';
    } finally {
      if (_client == null) client.close();
      _checking = false;
      notifyListeners();
    }
  }
}
