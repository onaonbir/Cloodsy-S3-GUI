import 'package:flutter/foundation.dart';
import '../core/i18n.dart';

enum BucketTab {
  overview('Overview'),
  files('Files'),
  access('Access keys'),
  settings('Settings'),
  lifecycle('Lifecycle'),
  webhooks('Webhooks');

  const BucketTab(this._label);
  final String _label;
  String get label => tr(_label);
}

/// Where the connected shell is. Every screen is reachable from every other
/// one through the sidebar, so there is no state that can trap the user
/// (the v1 "Admin Users" screen could only be left by disconnecting).
sealed class Destination {
  const Destination();
}

class DashboardDestination extends Destination {
  const DashboardDestination();
  @override
  bool operator ==(Object other) => other is DashboardDestination;
  @override
  int get hashCode => 1;
}

class BucketsDestination extends Destination {
  const BucketsDestination();
  @override
  bool operator ==(Object other) => other is BucketsDestination;
  @override
  int get hashCode => 2;
}

class BucketDestination extends Destination {
  final String bucket;
  final BucketTab tab;
  const BucketDestination(this.bucket, [this.tab = BucketTab.overview]);

  @override
  bool operator ==(Object other) =>
      other is BucketDestination && other.bucket == bucket && other.tab == tab;
  @override
  int get hashCode => Object.hash(bucket, tab);
}

class AdminsDestination extends Destination {
  const AdminsDestination();
  @override
  bool operator ==(Object other) => other is AdminsDestination;
  @override
  int get hashCode => 4;
}

enum ServerPage {
  sessions('Sessions'),
  logs('Activity log'),
  metrics('Metrics'),
  maintenance('Maintenance'),
  config('Configuration'),
  servers('All servers');

  const ServerPage(this._label);
  final String _label;
  String get label => tr(_label);
}

class ServerPageDestination extends Destination {
  final ServerPage page;
  const ServerPageDestination(this.page);
  @override
  bool operator ==(Object other) =>
      other is ServerPageDestination && other.page == page;
  @override
  int get hashCode => Object.hash(6, page);
}

class SettingsDestination extends Destination {
  const SettingsDestination();
  @override
  bool operator ==(Object other) => other is SettingsDestination;
  @override
  int get hashCode => 5;
}

class NavigationController extends ChangeNotifier {
  Destination _current = const DashboardDestination();
  final List<Destination> _history = [];

  Destination get current => _current;
  bool get canGoBack => _history.isNotEmpty;

  /// The open bucket, if the current screen belongs to one.
  String? get openBucket => switch (_current) {
        BucketDestination(:final bucket) => bucket,
        _ => null,
      };

  void go(Destination d) {
    if (d == _current) return;
    // Tab switches inside one bucket don't pile up history entries.
    final sameBucket = d is BucketDestination &&
        _current is BucketDestination &&
        (_current as BucketDestination).bucket == d.bucket;
    if (!sameBucket) {
      _history.add(_current);
      if (_history.length > 50) _history.removeAt(0);
    }
    _current = d;
    notifyListeners();
  }

  void openBucketTab(String bucket, BucketTab tab) =>
      go(BucketDestination(bucket, tab));

  void back() {
    if (_history.isEmpty) {
      go(const DashboardDestination());
      return;
    }
    _current = _history.removeLast();
    notifyListeners();
  }

  /// Called when a bucket disappears (deleted here or elsewhere).
  void forgetBucket(String bucket) {
    _history.removeWhere((d) => d is BucketDestination && d.bucket == bucket);
    if (openBucket == bucket) {
      _current = const BucketsDestination();
      notifyListeners();
    }
  }

  void reset() {
    _history.clear();
    _current = const DashboardDestination();
    notifyListeners();
  }
}
