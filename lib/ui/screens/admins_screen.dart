import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../core/format.dart';
import '../../models/admin_user.dart';
import '../../state/admins_controller.dart';
import '../../state/session_controller.dart';
import '../dialogs/admin_dialogs.dart';
import '../theme/app_colors.dart';
import '../theme/tokens.dart';
import '../widgets/common.dart';
import '../../core/i18n.dart';

class AdminsScreen extends StatelessWidget {
  const AdminsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final api = context.read<SessionController>().api;
    return ChangeNotifierProvider(
      create: (_) => AdminsController(api)..load(),
      child: const _AdminsView(),
    );
  }
}

class _AdminsView extends StatelessWidget {
  const _AdminsView();

  Future<void> _add(BuildContext context) async {
    final ctrl = context.read<AdminsController>();
    final r = await showAdminPasswordDialog(context, submit: ctrl.create);
    if (r != null && context.mounted) await showPasswordResult(context, r);
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<AdminsController>();
    final c = context.colors;

    Widget body;
    if (!ctrl.loadedOnce) {
      body = const LoadingView();
    } else if (ctrl.error != null && ctrl.admins.isEmpty) {
      body = ErrorState(ctrl.error!, onRetry: ctrl.load);
    } else {
      body = Container(
        decoration: BoxDecoration(
          color: c.card,
          borderRadius: AppRadius.lgAll,
          border: Border.all(color: c.border),
        ),
        child: Column(
          children: [
            for (var i = 0; i < ctrl.admins.length; i++) ...[
              if (i > 0) Divider(height: 1, color: c.border),
              _AdminRow(admin: ctrl.admins[i]),
            ],
          ],
        ),
      );
    }

    return PageScaffold(
      title: tr('Admin users'),
      subtitle: tr('Accounts that can sign in to this server’s Admin API.'),
      actions: [
        IconButton(
          tooltip: tr('Refresh'),
          onPressed: ctrl.loading ? null : ctrl.load,
          icon: ctrl.loading
              ? const ButtonSpinner()
              : const Icon(LucideIcons.refreshCw, size: 16),
        ),
        FilledButton.icon(
          onPressed: () => _add(context),
          icon: const Icon(LucideIcons.userPlus, size: 16),
          label: Text(tr('Add admin')),
        ),
      ],
      maxWidth: 900,
      body: body,
    );
  }
}

class _AdminRow extends StatelessWidget {
  final AdminUser admin;
  const _AdminRow({required this.admin});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = Theme.of(context).textTheme;
    final ctrl = context.read<AdminsController>();
    final session = context.read<SessionController>();
    final isMe = admin.username == session.username;

    Future<void> reset() async {
      final r = await showAdminPasswordDialog(
        context,
        username: admin.username,
        submit: ctrl.resetPassword,
      );
      if (r == null || !context.mounted) return;
      if (isMe) {
        // The server just revoked our own session; sign in again with the
        // new password and store it, instead of being thrown out.
        await session.ownPasswordChanged(r.password);
      }
      if (context.mounted) await showPasswordResult(context, r);
    }

    Future<void> delete() async {
      final ok = await confirm(context,
          title: tr('Delete admin'),
          message: tr('Delete “{u}”? Their active sessions end immediately.', {'u': admin.username}),
          typeToConfirm: admin.username);
      if (ok && context.mounted) {
        await runAction(context, () => ctrl.delete(admin.username),
            success: tr('Admin “{u}” deleted', {'u': admin.username}));
      }
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 10, 12),
      child: Row(
        children: [
          CircleAvatar(
            radius: 17,
            backgroundColor: isMe ? c.primarySoft : c.hover,
            child: Text(
              admin.username.isEmpty
                  ? '?'
                  : admin.username.characters.first.toUpperCase(),
              style: t.labelLarge
                  ?.copyWith(color: isMe ? c.primary : c.muted),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                        child: Text(admin.username,
                            overflow: TextOverflow.ellipsis,
                            style: t.titleSmall)),
                    if (isMe) ...[
                      const SizedBox(width: 8),
                      Pill(tr('You'), tone: Tone.primary),
                    ],
                  ],
                ),
                Text(tr('Added {d}', {'d': formatDate(admin.createdAt)}),
                    style: t.bodySmall),
              ],
            ),
          ),
          OutlinedButton.icon(
            onPressed: reset,
            icon: const Icon(LucideIcons.keyRound, size: 15),
            label: Text(isMe ? 'Change password' : 'Reset password'),
          ),
          const SizedBox(width: 6),
          IconButton(
            tooltip: isMe ? 'You can’t delete your own account' : 'Delete',
            onPressed: isMe ? null : delete,
            icon: Icon(LucideIcons.trash2,
                size: 16, color: isMe ? c.subtle : c.danger),
          ),
        ],
      ),
    );
  }
}
