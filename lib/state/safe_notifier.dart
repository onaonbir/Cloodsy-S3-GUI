import 'package:flutter/foundation.dart';

import '../core/api/api_client.dart';

/// A [ChangeNotifier] that tolerates async work finishing after dispose
/// (screen-scoped controllers are disposed when the user navigates away
/// while a request is still in flight).
class SafeNotifier extends ChangeNotifier {
  bool _disposed = false;
  bool get disposed => _disposed;

  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

/// Loading/error bookkeeping for a screen that shows one remote resource.
class LoadState extends SafeNotifier {
  bool _loading = false;
  bool _loadedOnce = false;
  ApiException? _error;

  bool get loading => _loading;

  /// True after the first load finished (successfully or not); screens show
  /// a skeleton/spinner only before this.
  bool get loadedOnce => _loadedOnce;
  ApiException? get error => _error;

  /// Runs [body] as "the" load of this controller: flips [loading], records
  /// the error (cleared on success) and notifies.
  @protected
  Future<void> runLoad(Future<void> Function() body) async {
    _loading = true;
    notifyListeners();
    try {
      await body();
      _error = null;
    } on ApiException catch (e) {
      _error = e;
    } finally {
      _loading = false;
      _loadedOnce = true;
      notifyListeners();
    }
  }
}
