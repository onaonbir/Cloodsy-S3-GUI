import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../core/desktop.dart';
import '../../core/format.dart';
import '../../state/transfers_controller.dart';
import '../theme/app_colors.dart';
import '../theme/tokens.dart';
import '../../core/i18n.dart';

/// Floating list of uploads/downloads (bottom-right of the content area).
class TransfersPanel extends StatelessWidget {
  final VoidCallback onClose;
  const TransfersPanel({super.key, required this.onClose});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = Theme.of(context).textTheme;
    final transfers = context.watch<TransfersController>();
    final items = transfers.items.reversed.toList();

    return Material(
      color: c.card,
      elevation: 12,
      shadowColor: Colors.black38,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.xlAll,
        side: BorderSide(color: c.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        width: 380,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 6, 10),
              child: Row(
                children: [
                  Text(tr('Transfers'), style: t.titleSmall),
                  const SizedBox(width: 8),
                  if (transfers.activeCount > 0)
                    Text(tr('{n} active', {'n': transfers.activeCount}), style: t.bodySmall),
                  const Spacer(),
                  if (transfers.activeCount > 0)
                    TextButton(
                        onPressed: transfers.cancelAll,
                        child: Text(tr('Cancel all'))),
                  if (items.any((x) => !x.isActive))
                    TextButton(
                        onPressed: transfers.clearFinished,
                        child: Text(tr('Clear'))),
                  IconButton(
                    tooltip: tr('Hide'),
                    icon: const Icon(LucideIcons.chevronDown, size: 16),
                    onPressed: onClose,
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: c.border),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 320),
              child: items.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(tr('No transfers'),
                          textAlign: TextAlign.center, style: t.bodyMedium),
                    )
                  : ListView.separated(
                      shrinkWrap: true,
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      itemCount: items.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 2),
                      itemBuilder: (_, i) => _TransferRow(items[i]),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TransferRow extends StatelessWidget {
  final Transfer t;
  const _TransferRow(this.t);

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final tt = Theme.of(context).textTheme;
    final transfers = context.read<TransfersController>();
    final up = t.kind == TransferKind.upload;

    final (String status, Color color) = switch (t.status) {
      TransferStatus.queued => (tr('Waiting'), c.subtle),
      TransferStatus.running => (
          t.total != null
              ? tr('{done} of {total}', {'done': formatBytes(t.done), 'total': formatBytes(t.total!)})
              : formatBytes(t.done),
          c.muted
        ),
      TransferStatus.done => (up ? tr('Uploaded') : tr('Saved'), c.success),
      TransferStatus.failed => (t.error ?? tr('Failed'), c.danger),
      TransferStatus.cancelled => (tr('Cancelled'), c.subtle),
    };

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 8, 6),
      child: Row(
        children: [
          Icon(up ? LucideIcons.upload : LucideIcons.download,
              size: 16,
              color: t.status == TransferStatus.failed ? c.danger : c.muted),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(t.name,
                    overflow: TextOverflow.ellipsis, style: tt.bodyLarge),
                const SizedBox(height: 2),
                Text(status,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: tt.bodySmall?.copyWith(color: color)),
                if (t.status == TransferStatus.running) ...[
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(
                        value: t.progress, minHeight: 3),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 4),
          if (t.isActive)
            IconButton(
              tooltip: tr('Cancel'),
              icon: const Icon(LucideIcons.x, size: 15),
              onPressed: () => transfers.cancel(t),
            )
          else if (t.status == TransferStatus.failed ||
              t.status == TransferStatus.cancelled)
            IconButton(
              tooltip: t.isMultipart && t.status == TransferStatus.failed
                  ? tr('Resume ({n} parts already uploaded)', {'n': t.parts.length})
                  : tr('Retry'),
              icon: Icon(
                  t.isMultipart && t.status == TransferStatus.failed
                      ? LucideIcons.play
                      : LucideIcons.rotateCw,
                  size: 15),
              onPressed: () => transfers.retry(t),
            )
          else if (t.status == TransferStatus.done && !up) ...[
            IconButton(
              tooltip: tr('Open'),
              icon: const Icon(LucideIcons.externalLink, size: 15),
              onPressed: () => Desktop.openFile(t.localPath),
            ),
            IconButton(
              tooltip: tr('Show in folder'),
              icon: const Icon(LucideIcons.folderSearch, size: 15),
              onPressed: () => Desktop.showInFolder(t.localPath),
            ),
          ],
        ],
      ),
    );
  }
}
