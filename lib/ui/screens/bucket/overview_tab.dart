import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../../core/format.dart';
import '../../../state/bucket_controller.dart';
import '../../../state/navigation_controller.dart';
import '../../../state/server_controller.dart';
import '../../theme/app_colors.dart';
import '../../theme/tokens.dart';
import '../../widgets/common.dart';
import '../../../core/i18n.dart';

class OverviewTab extends StatelessWidget {
  const OverviewTab({super.key});

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<BucketController>();
    final server = context.watch<ServerController>();
    final nav = context.read<NavigationController>();
    final b = ctrl.bucket!;
    final t = Theme.of(context).textTheme;
    final c = context.colors;

    final usage = Panel(
      title: tr('Usage'),
      icon: LucideIcons.database,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(formatBytes(b.usageBytes), style: t.headlineMedium),
              const SizedBox(width: 8),
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                    b.hasQuota ? tr('of {size}', {'size': formatBytes(b.quotaBytes)}) : tr('no quota'),
                    style: t.bodyMedium),
              ),
            ],
          ),
          if (b.hasQuota) ...[
            const SizedBox(height: 10),
            UsageBar(b.quotaUsagePercent, height: 8),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              _Metric(label: tr('Objects'), value: formatCount(b.objects)),
              _Metric(label: tr('Access keys'), value: '${b.credentials}'),
              _Metric(label: tr('Rules'), value: '${ctrl.rules.length}'),
              _Metric(label: tr('Webhooks'), value: '${ctrl.webhooks.length}'),
            ],
          ),
        ],
      ),
    );

    final details = Panel(
      title: tr('Details'),
      icon: LucideIcons.info,
      child: Column(
        children: [
          InfoRow.text(tr('Name'), b.name, mono: true),
          InfoRow.text(tr('Created'), formatDateTime(b.createdAt)),
          InfoRow(
              tr('Versioning'),
              Align(
                alignment: Alignment.centerLeft,
                child: Pill(b.versioningDisplay,
                    tone: b.versioningEnabled ? Tone.primary : Tone.neutral),
              )),
          InfoRow(
              tr('Access'),
              Align(
                alignment: Alignment.centerLeft,
                child: Pill(b.publicRead ? 'Public read' : 'Private',
                    tone: b.publicRead ? Tone.warning : Tone.success,
                    icon: b.publicRead ? LucideIcons.globe : LucideIcons.lock),
              )),
          InfoRow(tr('WebDAV'),
              Align(
                alignment: Alignment.centerLeft,
                child: Pill(b.webdavEnabled ? 'Enabled' : 'Off',
                    tone: b.webdavEnabled ? Tone.success : Tone.neutral),
              )),
          InfoRow.text(
              tr('Storage'),
              b.storagePath ??
                  (b.storageDir.isNotEmpty ? b.storageDir : 'Default directory'),
              mono: b.storagePath != null || b.storageDir.isNotEmpty),
        ],
      ),
    );

    final mount = server.webdavMountUrl;
    final connect = Panel(
      title: tr('Connect'),
      icon: LucideIcons.plug,
      subtitle: tr('Use any S3 SDK, rclone, s3cmd or the Cloodsy app.'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CopyValue(label: tr('Bucket'), value: b.name),
          if (b.webdavEnabled && mount != null) ...[
            const SizedBox(height: 14),
            // The WebDAV root is per credential: the access key decides
            // which bucket the mount shows.
            CopyValue(label: tr('WebDAV mount'), value: mount),
            const SizedBox(height: 6),
            Text(tr('Sign in with an access key of this bucket as username and '
                'its secret key as password.'),
                style: t.bodySmall),
          ],
          const SizedBox(height: 14),
          if (ctrl.credentials.isEmpty)
            Callout(
              tr('No access keys yet. Create one to connect clients.'),
              tone: Tone.primary,
              action: TextButton(
                onPressed: () =>
                    nav.go(BucketDestination(b.name, BucketTab.access)),
                child: Text(tr('Create key')),
              ),
            )
          else
            Row(
              children: [
                Icon(LucideIcons.keyRound, size: 14, color: c.muted),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                      tr('{n} access keys can reach this bucket.', {'n': ctrl.credentials.length}),
                      style: t.bodyMedium),
                ),
                TextButton(
                  onPressed: () =>
                      nav.go(BucketDestination(b.name, BucketTab.access)),
                  child: Text(tr('Manage')),
                ),
              ],
            ),
        ],
      ),
    );

    return LayoutBuilder(builder: (context, box) {
      if (box.maxWidth < 860) {
        return Column(children: [
          usage,
          const SizedBox(height: 16),
          details,
          const SizedBox(height: 16),
          connect,
        ]);
      }
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
              child: Column(children: [
            usage,
            const SizedBox(height: AppSpace.lg),
            connect,
          ])),
          const SizedBox(width: AppSpace.lg),
          Expanded(child: details),
        ],
      );
    });
  }
}

class _Metric extends StatelessWidget {
  final String label;
  final String value;
  const _Metric({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value, style: t.titleMedium),
          Text(label, style: t.bodySmall),
        ],
      ),
    );
  }
}
