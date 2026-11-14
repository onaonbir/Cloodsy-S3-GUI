import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../core/format.dart';
import '../../models/bucket.dart';
import '../../models/server_status.dart';
import '../../state/navigation_controller.dart';
import '../../state/server_controller.dart';
import '../../state/session_controller.dart';
import '../theme/app_colors.dart';
import '../theme/tokens.dart';
import '../widgets/common.dart';
import 'buckets_screen.dart' show createBucketFlow;
import '../../core/i18n.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final server = context.watch<ServerController>();
    final session = context.watch<SessionController>();
    final status = server.status;

    if (status == null) {
      if (server.error != null) {
        return ErrorState(server.error!, onRetry: server.refresh);
      }
      return const LoadingView();
    }

    return PageScaffold(
      title: tr('Dashboard'),
      subtitle: '${session.server?.name ?? ''} · ${tr('signed in as {u}', {'u': session.username ?? ''})}',
      actions: [
        OutlinedButton.icon(
          onPressed: server.loading ? null : server.refresh,
          icon: server.loading
              ? const ButtonSpinner()
              : const Icon(LucideIcons.refreshCw, size: 15),
          label: Text(tr('Refresh')),
        ),
        FilledButton.icon(
          onPressed: () => createBucketFlow(context),
          icon: const Icon(LucideIcons.plus, size: 16),
          label: Text(tr('New bucket')),
        ),
      ],
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (server.updateAvailable) ...[
            Callout(
              tr('Cloodsy S3 v{v} is available (this server runs v{c}). Run "cloodsys3 update" on the server to upgrade.',
                  {'v': server.latestVersion, 'c': status.version}),
              tone: Tone.primary,
              icon: LucideIcons.sparkles,
            ),
            const SizedBox(height: 16),
          ],
          if (server.error != null) ...[
            Callout(tr('Last refresh failed: {e}', {'e': server.error!.message}),
                tone: Tone.danger),
            const SizedBox(height: 16),
          ],
          _StatGrid(server: server),
          const SizedBox(height: 20),
          LayoutBuilder(builder: (context, box) {
            final twoCol = box.maxWidth > 900;
            final buckets = _TopBuckets(buckets: server.buckets);
            final info = _ServerInfo(status: status, server: server);
            if (!twoCol) {
              return Column(children: [buckets, const SizedBox(height: 16), info]);
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 3, child: buckets),
                const SizedBox(width: 16),
                Expanded(flex: 2, child: info),
              ],
            );
          }),
        ],
      ),
    );
  }
}

class _StatGrid extends StatelessWidget {
  final ServerController server;
  const _StatGrid({required this.server});

  @override
  Widget build(BuildContext context) {
    final st = server.status!;
    final disk = st.storage;
    final tiles = <Widget>[
      _StatTile(
        icon: LucideIcons.package,
        label: tr('Buckets'),
        value: formatCount(server.buckets.length),
        caption: tr('{n} public', {'n': server.buckets.where((b) => b.publicRead).length}),
      ),
      _StatTile(
        icon: LucideIcons.files,
        label: tr('Objects'),
        value: formatCount(server.totalObjects),
        caption: tr('across all buckets'),
      ),
      _StatTile(
        icon: LucideIcons.database,
        label: tr('Stored'),
        value: formatBytes(server.totalUsage),
        caption: tr('latest object versions'),
      ),
      if (disk != null && disk.hasDiskStats)
        _StatTile(
          icon: LucideIcons.hardDrive,
          label: tr('Disk'),
          value: tr('{size} free', {'size': formatBytes(disk.freeBytes)}),
          caption: tr('of {size}', {'size': formatBytes(disk.totalBytes)}),
          progress: disk.usedFraction,
        )
      else
        _StatTile(
          icon: LucideIcons.activity,
          label: tr('Status'),
          value: st.isOk ? 'Online' : st.status,
          caption: st.version.isEmpty ? '' : 'v${st.version}',
          tone: st.isOk ? Tone.success : Tone.danger,
        ),
    ];
    return LayoutBuilder(builder: (context, box) {
      final cols = box.maxWidth > 900 ? 4 : box.maxWidth > 520 ? 2 : 1;
      const gap = 14.0;
      final w = (box.maxWidth - gap * (cols - 1)) / cols;
      return Wrap(
        spacing: gap,
        runSpacing: gap,
        children: [for (final t in tiles) SizedBox(width: w, child: t)],
      );
    });
  }
}

class _StatTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String caption;
  final double? progress;
  final Tone tone;

  const _StatTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.caption,
    this.progress,
    this.tone = Tone.primary,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = Theme.of(context).textTheme;
    return Container(
      height: 128,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: AppRadius.lgAll,
        border: Border.all(color: c.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(label, style: t.labelMedium),
              const Spacer(),
              IconBadge(icon, tone: tone, size: 30),
            ],
          ),
          const Spacer(),
          Text(value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: t.headlineSmall?.copyWith(fontSize: 22)),
          const SizedBox(height: 4),
          if (progress != null) ...[
            UsageBar(progress!, height: 4),
            const SizedBox(height: 5),
          ],
          Text(caption, style: t.bodySmall, maxLines: 1),
        ],
      ),
    );
  }
}

class _TopBuckets extends StatelessWidget {
  final List<Bucket> buckets;
  const _TopBuckets({required this.buckets});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = Theme.of(context).textTheme;
    final nav = context.read<NavigationController>();
    final top = [...buckets]..sort((a, b) => b.usageBytes.compareTo(a.usageBytes));
    final shown = top.take(6).toList();

    return Panel(
      title: tr('Largest buckets'),
      icon: LucideIcons.chartColumn,
      actions: [
        TextButton(
          onPressed: () => nav.go(const BucketsDestination()),
          child: Text(tr('View all')),
        ),
      ],
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 10),
      child: shown.isEmpty
          ? EmptyState(
              compact: true,
              icon: LucideIcons.package,
              title: tr('No buckets yet'),
              message: tr('Create a bucket to start storing objects.'),
              action: FilledButton.icon(
                onPressed: () => createBucketFlow(context),
                icon: const Icon(LucideIcons.plus, size: 16),
                label: Text(tr('New bucket')),
              ),
            )
          : Column(
              children: [
                for (final b in shown)
                  InkWell(
                    borderRadius: AppRadius.mdAll,
                    onTap: () => nav.go(BucketDestination(b.name)),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 10),
                      child: Row(
                        children: [
                          const IconBadge(LucideIcons.package, size: 32),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(b.name,
                                          overflow: TextOverflow.ellipsis,
                                          style: t.titleSmall),
                                    ),
                                    Text(formatBytes(b.usageBytes),
                                        style: t.labelMedium
                                            ?.copyWith(color: c.foreground)),
                                  ],
                                ),
                                // A bar only means something against a quota.
                                if (b.hasQuota) ...[
                                  const SizedBox(height: 6),
                                  UsageBar(b.quotaUsagePercent, height: 4),
                                ],
                                const SizedBox(height: 4),
                                Text(
                                  b.hasQuota
                                      ? tr('{n} objects · {p}% of {size} quota', {'n': formatCount(b.objects), 'p': (b.quotaUsagePercent * 100).toStringAsFixed(0), 'size': formatBytes(b.quotaBytes)})
                                      : tr('{n} objects · no quota', {'n': formatCount(b.objects)}),
                                  style: t.bodySmall,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}

class _ServerInfo extends StatelessWidget {
  final ServerStatus status;
  final ServerController server;
  const _ServerInfo({required this.status, required this.server});

  @override
  Widget build(BuildContext context) {
    final tls = status.tls;
    Widget onOff(bool on, {String onText = 'Enabled', String offText = 'Off'}) =>
        Align(
          alignment: Alignment.centerLeft,
          child: Pill(on ? onText : offText,
              tone: on ? Tone.success : Tone.neutral, dot: true),
        );

    return Panel(
      title: tr('Server'),
      icon: LucideIcons.server,
      child: Column(
        children: [
          InfoRow(tr('Status'),
              Align(
                  alignment: Alignment.centerLeft,
                  child: Pill(status.isOk ? 'Online' : status.status,
                      tone: status.isOk ? Tone.success : Tone.danger,
                      dot: true))),
          InfoRow.text(tr('Version'), status.version.isEmpty ? '—' : 'v${status.version}'),
          if (status.uptimeSeconds != null)
            InfoRow.text(tr('Uptime'), formatUptime(status.uptimeSeconds!)),
          if (tls != null) ...[
            InfoRow(tr('S3 TLS'), onOff(tls.s3)),
            InfoRow(tr('Admin TLS'), onOff(tls.admin)),
            if (tls.acme)
              InfoRow.text(tr('Certificates'),
                  'Let’s Encrypt · ${tls.acmeDomains.join(', ')}'),
          ],
          InfoRow(tr('WebDAV'),
              onOff(status.webdavEnabled,
                  onText: status.webdavListen.isEmpty
                      ? tr('Enabled')
                      : '${tr('Enabled')} · ${status.webdavListen}')),
          if (status.storage != null && status.storage!.path.isNotEmpty)
            InfoRow.text(tr('Data directory'), status.storage!.path, mono: true),
          if (status.features.isEmpty) ...[
            const SizedBox(height: 10),
            Callout(
              tr('This server predates file upload/download in the admin API. '
              'Update the server to browse, upload and download objects here.'),
              tone: Tone.neutral,
            ),
          ],
        ],
      ),
    );
  }
}
