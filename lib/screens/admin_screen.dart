import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/bucket_provider.dart';
import '../providers/auth_provider.dart';
import '../widgets/empty_state.dart';

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<BucketProvider>().fetchAdmins();
    });
  }

  @override
  Widget build(BuildContext context) {
    final bp = context.watch<BucketProvider>();
    final auth = context.watch<AuthProvider>();
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Container(
          padding: const EdgeInsets.fromLTRB(20, 14, 16, 10),
          child: Row(
            children: [
              Text('Admin Users',
                  style: theme.textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text('${bp.admins.length}',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(fontWeight: FontWeight.w600)),
              ),
              const Spacer(),
              OutlinedButton.icon(
                onPressed: () => _createAdmin(context),
                icon: const Icon(LucideIcons.plus, size: 16),
                label: const Text('Add Admin'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, 38),
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                ),
              ),
            ],
          ),
        ),
        Divider(height: 1, color: theme.colorScheme.outlineVariant),
        // List
        Expanded(
          child: bp.admins.isEmpty
              ? const EmptyState(
                  icon: LucideIcons.shield,
                  title: 'No admin users',
                  subtitle: 'Create an admin to manage via GUI',
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(20),
                  itemCount: bp.admins.length,
                  itemBuilder: (context, index) {
                    final admin = bp.admins[index];
                    final isCurrentUser = admin.username == auth.username;

                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        child: Row(
                          children: [
                            Container(
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                color: isCurrentUser
                                    ? theme.colorScheme.primary
                                        .withValues(alpha: 0.1)
                                    : theme.colorScheme.surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(LucideIcons.user,
                                  size: 20,
                                  color: isCurrentUser
                                      ? theme.colorScheme.primary
                                      : theme.colorScheme.onSurface),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(admin.username,
                                          style: theme.textTheme.titleSmall
                                              ?.copyWith(
                                                  fontWeight: FontWeight.w600)),
                                      if (isCurrentUser) ...[
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 6, vertical: 1),
                                          decoration: BoxDecoration(
                                            color: theme.colorScheme.primary
                                                .withValues(alpha: 0.1),
                                            borderRadius:
                                                BorderRadius.circular(4),
                                          ),
                                          child: Text('you',
                                              style: theme.textTheme.bodySmall
                                                  ?.copyWith(
                                                color:
                                                    theme.colorScheme.primary,
                                                fontWeight: FontWeight.w500,
                                              )),
                                        ),
                                      ],
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Text('Created: ${_shortDate(admin.createdAt)}',
                                      style: theme.textTheme.bodySmall),
                                ],
                              ),
                            ),
                            // Reset password
                            IconButton(
                              icon: const Icon(LucideIcons.key, size: 18),
                              onPressed: () =>
                                  _resetPassword(context, admin.username),
                              tooltip: 'Reset password',
                            ),
                            // Delete
                            if (!isCurrentUser)
                              IconButton(
                                icon: Icon(LucideIcons.trash2,
                                    size: 18, color: theme.colorScheme.error),
                                onPressed: () =>
                                    _deleteAdmin(context, admin.username),
                                tooltip: 'Delete',
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  String _shortDate(String iso) {
    if (iso.isEmpty) return '';
    try {
      final dt = DateTime.parse(iso);
      return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
    } catch (_) {
      return iso;
    }
  }

  Future<void> _createAdmin(BuildContext context) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => const _CreateAdminDialog(),
    );
    if (result != null && context.mounted) {
      _showPasswordDialog(context, result['username'], result['password'],
          result['auto_generated'] == true);
    }
  }

  Future<void> _resetPassword(BuildContext context, String username) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => _ResetPasswordDialog(username: username),
    );
    if (result != null && context.mounted) {
      _showPasswordDialog(context, result['username'], result['password'],
          result['auto_generated'] == true);
    }
  }

  void _showPasswordDialog(
      BuildContext context, String username, String password, bool autoGen) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(autoGen ? 'Password Generated' : 'Password Set'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (autoGen)
              Text('Save this password now. It will not be shown again.',
                  style: TextStyle(
                      color: Theme.of(ctx).colorScheme.error,
                      fontWeight: FontWeight.w500)),
            if (autoGen) const SizedBox(height: 16),
            Text('Username', style: Theme.of(ctx).textTheme.bodySmall),
            const SizedBox(height: 4),
            Text(username,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 14)),
            const SizedBox(height: 12),
            Text('Password', style: Theme.of(ctx).textTheme.bodySmall),
            const SizedBox(height: 4),
            Row(
              children: [
                Expanded(
                  child: Text(password,
                      style:
                          const TextStyle(fontFamily: 'monospace', fontSize: 14)),
                ),
                IconButton(
                  icon: const Icon(LucideIcons.copy, size: 16),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: password));
                    ScaffoldMessenger.of(ctx).showSnackBar(
                        const SnackBar(content: Text('Password copied')));
                  },
                ),
              ],
            ),
          ],
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteAdmin(BuildContext context, String username) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Admin'),
        content: Text("Delete admin '$username'?"),
        actions: [
          OutlinedButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
                backgroundColor: Theme.of(ctx).colorScheme.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      final bp = context.read<BucketProvider>();
      final success = await bp.deleteAdmin(username);
      if (context.mounted && !success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(bp.error ?? 'Failed to delete')),
        );
      }
    }
  }
}

// Mirrors the server's password policy (admin/admin.go validatePassword):
// at least 8 characters and at most 72 bytes, the bcrypt input limit.
const int _minPasswordLen = 8;
const int _maxPasswordBytes = 72;
const String _passwordHint = '8+ characters, max 72 bytes';

String? _passwordRuleError(String password) {
  if (password.length < _minPasswordLen) {
    return 'Password must be at least $_minPasswordLen characters';
  }
  if (utf8.encode(password).length > _maxPasswordBytes) {
    return 'Password must be at most $_maxPasswordBytes bytes (bcrypt limit)';
  }
  return null;
}

// ========================= Create Admin Dialog =========================
class _CreateAdminDialog extends StatefulWidget {
  const _CreateAdminDialog();

  @override
  State<_CreateAdminDialog> createState() => _CreateAdminDialogState();
}

class _CreateAdminDialogState extends State<_CreateAdminDialog> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _autoGenerate = true;
  bool _isLoading = false;
  String? _passwordError;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    final username = _usernameController.text.trim();
    if (username.isEmpty) return;

    final password = _autoGenerate ? '' : _passwordController.text;
    if (!_autoGenerate) {
      final err = _passwordRuleError(password);
      if (err != null) {
        setState(() => _passwordError = err);
        return;
      }
    }

    setState(() {
      _isLoading = true;
      _passwordError = null;
    });
    final bp = context.read<BucketProvider>();
    final result = await bp.createAdmin(username, password);

    if (mounted) {
      if (result != null) {
        Navigator.pop(context, result);
      } else {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(bp.error ?? 'Failed')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Create Admin'),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _usernameController,
              decoration: const InputDecoration(
                labelText: 'Username',
                hintText: 'admin2',
              ),
              autofocus: true,
              onSubmitted: (_) => _create(),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Switch(
                  value: _autoGenerate,
                  onChanged: (v) => setState(() => _autoGenerate = v),
                ),
                const SizedBox(width: 8),
                Text('Auto-generate password',
                    style: Theme.of(context).textTheme.bodyMedium),
              ],
            ),
            if (!_autoGenerate) ...[
              const SizedBox(height: 8),
              TextField(
                controller: _passwordController,
                decoration: InputDecoration(
                  labelText: 'Password',
                  hintText: 'Enter custom password',
                  helperText: _passwordHint,
                  errorText: _passwordError,
                ),
                obscureText: true,
                onChanged: (_) {
                  if (_passwordError != null) {
                    setState(() => _passwordError = null);
                  }
                },
                onSubmitted: (_) => _create(),
              ),
            ],
          ],
        ),
      ),
      actions: [
        OutlinedButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _isLoading ? null : _create,
          child: _isLoading
              ? const SizedBox(
                  width: 16, height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Create'),
        ),
      ],
    );
  }
}

// ========================= Reset Password Dialog =========================
class _ResetPasswordDialog extends StatefulWidget {
  final String username;
  const _ResetPasswordDialog({required this.username});

  @override
  State<_ResetPasswordDialog> createState() => _ResetPasswordDialogState();
}

class _ResetPasswordDialogState extends State<_ResetPasswordDialog> {
  final _passwordController = TextEditingController();
  bool _autoGenerate = true;
  bool _isLoading = false;
  String? _passwordError;

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _reset() async {
    final password = _autoGenerate ? '' : _passwordController.text;
    if (!_autoGenerate) {
      final err = _passwordRuleError(password);
      if (err != null) {
        setState(() => _passwordError = err);
        return;
      }
    }

    setState(() {
      _isLoading = true;
      _passwordError = null;
    });
    final bp = context.read<BucketProvider>();
    final result = await bp.resetAdminPassword(widget.username, password);

    if (mounted) {
      if (result != null) {
        Navigator.pop(context, result);
      } else {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(bp.error ?? 'Failed')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Reset Password: ${widget.username}'),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Switch(
                  value: _autoGenerate,
                  onChanged: (v) => setState(() => _autoGenerate = v),
                ),
                const SizedBox(width: 8),
                Text('Auto-generate password',
                    style: Theme.of(context).textTheme.bodyMedium),
              ],
            ),
            if (!_autoGenerate) ...[
              const SizedBox(height: 8),
              TextField(
                controller: _passwordController,
                decoration: InputDecoration(
                  labelText: 'New Password',
                  helperText: _passwordHint,
                  errorText: _passwordError,
                ),
                obscureText: true,
                autofocus: true,
                onChanged: (_) {
                  if (_passwordError != null) {
                    setState(() => _passwordError = null);
                  }
                },
                onSubmitted: (_) => _reset(),
              ),
            ],
          ],
        ),
      ),
      actions: [
        OutlinedButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _isLoading ? null : _reset,
          child: _isLoading
              ? const SizedBox(
                  width: 16, height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Reset'),
        ),
      ],
    );
  }
}
