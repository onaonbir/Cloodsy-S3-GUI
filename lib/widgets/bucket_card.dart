import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../models/bucket.dart';

String formatBytes(int bytes) {
  if (bytes >= 1024 * 1024 * 1024) {
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  } else if (bytes >= 1024 * 1024) {
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  } else if (bytes >= 1024) {
    return '${(bytes / 1024).toStringAsFixed(1)} KB';
  }
  return '$bytes B';
}

class BucketCard extends StatelessWidget {
  final Bucket bucket;
  final VoidCallback onTap;
  final VoidCallback? onDelete;

  const BucketCard({
    super.key,
    required this.bucket,
    required this.onTap,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(LucideIcons.box,
                        color: theme.colorScheme.onPrimaryContainer, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(bucket.name,
                            style: theme.textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w600)),
                        Text(
                          '${bucket.objects} objects',
                          style: theme.textTheme.bodySmall
                              ?.copyWith(color: theme.colorScheme.outline),
                        ),
                      ],
                    ),
                  ),
                  if (bucket.storageDir.isNotEmpty)
                    Tooltip(
                      message: 'Custom storage: ${bucket.storageDir}',
                      child: Icon(LucideIcons.folderCog,
                          size: 18, color: theme.colorScheme.tertiary),
                    ),
                  if (onDelete != null)
                    IconButton(
                      icon: Icon(LucideIcons.trash2,
                          color: theme.colorScheme.error, size: 20),
                      onPressed: onDelete,
                      tooltip: 'Delete bucket',
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _chip(context, LucideIcons.hardDrive,
                      formatBytes(bucket.usageBytes)),
                  const SizedBox(width: 8),
                  _chip(context, LucideIcons.key,
                      '${bucket.credentials} keys'),
                  const SizedBox(width: 8),
                  _chip(
                      context,
                      LucideIcons.gitBranch,
                      bucket.versioningDisplay),
                ],
              ),
              if (bucket.quotaBytes > 0) ...[
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: bucket.quotaUsagePercent.clamp(0.0, 1.0),
                    minHeight: 4,
                    backgroundColor: theme.colorScheme.surfaceContainerHighest,
                    color: bucket.quotaUsagePercent > 0.9
                        ? theme.colorScheme.error
                        : theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${formatBytes(bucket.usageBytes)} / ${formatBytes(bucket.quotaBytes)}',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.outline),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _chip(BuildContext context, IconData icon, String label) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: theme.colorScheme.outline),
          const SizedBox(width: 4),
          Text(label,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        ],
      ),
    );
  }
}
