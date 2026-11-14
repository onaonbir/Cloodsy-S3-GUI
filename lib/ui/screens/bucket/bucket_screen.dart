import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../../state/bucket_controller.dart';
import '../../../state/navigation_controller.dart';
import '../../../state/objects_controller.dart';
import '../../../state/server_controller.dart';
import '../../../state/session_controller.dart';
import '../../shell/sidebar.dart' show bucketTabIcon;
import '../../theme/app_colors.dart';
import '../../widgets/common.dart';
import '../buckets_screen.dart' show deleteBucketFlow;
import 'access_tab.dart';
import 'files_tab.dart';
import 'lifecycle_tab.dart';
import 'overview_tab.dart';
import 'settings_tab.dart';
import 'webhooks_tab.dart';
import '../../../core/i18n.dart';

/// One bucket with its tabs. Controllers live as long as the bucket is
/// open, so switching tabs keeps data and the file browser's folder.
class BucketScreen extends StatelessWidget {
  final String bucket;
  final BucketTab tab;
  const BucketScreen({super.key, required this.bucket, required this.tab});

  @override
  Widget build(BuildContext context) {
    final api = context.read<SessionController>().api;
    final server = context.read<ServerController>();
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => BucketController(api, bucket,
              onBucketChanged: server.updateBucket)
            ..load(),
        ),
        ChangeNotifierProvider(create: (_) => ObjectsController(api, bucket)),
      ],
      child: _BucketView(tab: tab),
    );
  }
}

class _BucketView extends StatelessWidget {
  final BucketTab tab;
  const _BucketView({required this.tab});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final ctrl = context.watch<BucketController>();
    final nav = context.read<NavigationController>();
    final b = ctrl.bucket;

    Widget body;
    if (b == null) {
      body = ctrl.error != null
          ? ErrorState(ctrl.error!, onRetry: ctrl.load)
          : const LoadingView();
    } else {
      body = switch (tab) {
        BucketTab.overview => const OverviewTab(),
        BucketTab.files => const FilesTab(),
        BucketTab.access => const AccessTab(),
        BucketTab.settings => const SettingsTab(),
        BucketTab.lifecycle => const LifecycleTab(),
        BucketTab.webhooks => const WebhooksTab(),
      };
    }

    final tabs = SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final t in BucketTab.values)
            _TabButton(
              icon: bucketTabIcon(t),
              label: t.label,
              badge: switch (t) {
                BucketTab.access => ctrl.credentials.length,
                BucketTab.lifecycle => ctrl.rules.length,
                BucketTab.webhooks => ctrl.webhooks.length,
                _ => null,
              },
              selected: t == tab,
              onTap: () => nav.go(BucketDestination(ctrl.name, t)),
            ),
        ],
      ),
    );

    return PageScaffold(
      title: ctrl.name,
      leading: IconButton(
        tooltip: tr('All buckets'),
        icon: const Icon(LucideIcons.arrowLeft, size: 18),
        onPressed: () => nav.go(const BucketsDestination()),
      ),
      titleTrailing: b == null
          ? null
          : Wrap(spacing: 6, children: [
              if (b.versioningEnabled)
                Pill(tr('Versioned'), tone: Tone.primary),
              if (b.publicRead) Pill(tr('Public'), tone: Tone.warning),
            ]),
      actions: [
        IconButton(
          tooltip: tr('Reload'),
          onPressed: ctrl.loading ? null : ctrl.load,
          icon: ctrl.loading
              ? const ButtonSpinner()
              : const Icon(LucideIcons.refreshCw, size: 16),
        ),
        MoreMenu(
          children: [
            MenuItemButton(
              leadingIcon: Icon(LucideIcons.trash2, size: 16, color: c.danger),
              onPressed: () => deleteBucketFlow(context, ctrl.name),
              child:
                  Text(tr('Delete bucket…'), style: TextStyle(color: c.danger)),
            ),
          ],
        ),
      ],
      below: Container(
        decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: c.border))),
        child: tabs,
      ),
      scrollable: tab != BucketTab.files,
      body: Padding(padding: const EdgeInsets.only(top: 18), child: body),
    );
  }
}

class _TabButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final int? badge;
  final bool selected;
  final VoidCallback onTap;

  const _TabButton({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = Theme.of(context).textTheme;
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.fromLTRB(4, 10, 4, 10),
        margin: const EdgeInsets.only(right: 18),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
                color: selected ? c.primary : Colors.transparent, width: 2),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: selected ? c.primary : c.muted),
            const SizedBox(width: 7),
            Text(label,
                style: t.labelLarge?.copyWith(
                    color: selected ? c.foreground : c.muted,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w500)),
            if (badge != null && badge! > 0) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                    color: c.hover, borderRadius: BorderRadius.circular(99)),
                child: Text('$badge',
                    style: t.labelSmall?.copyWith(letterSpacing: 0)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
