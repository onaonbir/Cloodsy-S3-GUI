import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../../core/format.dart';
import '../../../models/credential.dart';
import '../../../state/bucket_controller.dart';
import '../../dialogs/access_dialogs.dart';
import '../../theme/app_colors.dart';
import '../../widgets/common.dart';
import '../../../core/i18n.dart';

class AccessTab extends StatelessWidget {
  const AccessTab({super.key});

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<BucketController>();
    final creds = ctrl.credentials;

    void create() => showCreateCredentialDialog(context,
        bucket: ctrl.name, create: ctrl.createCredential);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                tr('Access keys authenticate S3 clients (SigV4) and WebDAV '
                'mounts for this bucket only.'),
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
            const SizedBox(width: 12),
            FilledButton.icon(
              onPressed: create,
              icon: const Icon(LucideIcons.plus, size: 16),
              label: Text(tr('New access key')),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (creds.isEmpty)
          Panel(
            child: EmptyState(
              compact: true,
              icon: LucideIcons.keyRound,
              title: tr('No access keys'),
              message: tr('Create a key to connect an S3 SDK, rclone or the '
                  'Cloodsy app to this bucket.'),
              action: FilledButton.icon(
                onPressed: create,
                icon: const Icon(LucideIcons.plus, size: 16),
                label: Text(tr('Create access key')),
              ),
            ),
          )
        else
          for (final cred in creds) ...[
            _CredentialCard(cred: cred),
            const SizedBox(height: 12),
          ],
      ],
    );
  }
}

class _CredentialCard extends StatelessWidget {
  final Credential cred;
  const _CredentialCard({required this.cred});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = Theme.of(context).textTheme;
    final ctrl = context.read<BucketController>();

    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconBadge(LucideIcons.keyRound,
                  tone: cred.isReadOnly ? Tone.neutral : Tone.primary, size: 34),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(cred.name.isNotEmpty ? cred.name : 'Unnamed key',
                        style: t.titleSmall),
                    Text(tr('Created {d}', {'d': formatDate(cred.createdAt)}),
                        style: t.bodySmall),
                  ],
                ),
              ),
              Pill(cred.isReadOnly ? 'Read only' : 'Read & write',
                  tone: cred.isReadOnly ? Tone.neutral : Tone.primary),
              const SizedBox(width: 4),
              IconButton(
                tooltip: tr('Revoke key'),
                icon: Icon(LucideIcons.trash2, size: 16, color: c.danger),
                onPressed: () async {
                  final ok = await confirm(context,
                      title: tr('Revoke access key'),
                      message: tr('Clients using this key lose access '
                          'immediately.'),
                      detail: cred.accessKey,
                      confirmLabel: tr('Revoke'));
                  if (ok && context.mounted) {
                    await runAction(
                        context, () => ctrl.deleteCredential(cred.accessKey),
                        success: 'Access key revoked');
                  }
                },
              ),
            ],
          ),
          const SizedBox(height: 16),
          LayoutBuilder(builder: (context, box) {
            final access = CopyValue(label: tr('Access key'), value: cred.accessKey);
            final secret = CopyValue(
                label: tr('Secret key'),
                value: cred.secretKey ?? '',
                secret: true);
            if (box.maxWidth < 620) {
              return Column(
                  children: [access, const SizedBox(height: 12), secret]);
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: access),
                const SizedBox(width: 14),
                Expanded(child: secret),
              ],
            );
          }),
        ],
      ),
    );
  }
}
