import 'dart:convert';

import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/api/api_client.dart';
import '../../state/admins_controller.dart';
import '../widgets/common.dart';
import '../../core/i18n.dart';

// Mirrors the server's password policy (admin/admin.go validatePassword):
// at least 8 characters and at most 72 bytes, the bcrypt input limit.
const int minPasswordLength = 8;
const int maxPasswordBytes = 72;

String? passwordRuleError(String password) {
  if (password.length < minPasswordLength) {
    return tr('At least {n} characters', {'n': minPasswordLength});
  }
  if (utf8.encode(password).length > maxPasswordBytes) {
    return tr('At most {n} bytes (bcrypt limit)', {'n': maxPasswordBytes});
  }
  return null;
}

/// Shared dialog for "create admin" (with username) and "reset password".
/// [submit] gets (username, password) where password may be empty to let
/// the server generate one.
Future<PasswordResult?> showAdminPasswordDialog(
  BuildContext context, {
  String? username,
  required Future<PasswordResult> Function(String username, String password)
      submit,
}) =>
    showDialog<PasswordResult>(
      context: context,
      builder: (_) => _AdminDialog(username: username, submit: submit),
    );

class _AdminDialog extends StatefulWidget {
  final String? username; // null → create mode
  final Future<PasswordResult> Function(String, String) submit;
  const _AdminDialog({this.username, required this.submit});

  @override
  State<_AdminDialog> createState() => _AdminDialogState();
}

class _AdminDialogState extends State<_AdminDialog> {
  final _user = TextEditingController();
  final _pw = TextEditingController();
  bool _generate = true;
  bool _obscure = true;
  bool _busy = false;
  String? _userError, _pwError, _serverError;

  bool get _create => widget.username == null;

  @override
  void dispose() {
    _user.dispose();
    _pw.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final user = _create ? _user.text.trim() : widget.username!;
    setState(() {
      _userError = _create && user.isEmpty ? 'Username required' : null;
      _pwError = _generate ? null : passwordRuleError(_pw.text);
      _serverError = null;
    });
    if (_userError != null || _pwError != null) return;
    setState(() => _busy = true);
    try {
      final r = await widget.submit(user, _generate ? '' : _pw.text);
      if (mounted) Navigator.pop(context, r);
    } on ApiException catch (e) {
      setState(() {
        _busy = false;
        _serverError = e.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppDialog(
      title: _create ? 'Add admin' : 'Reset password',
      subtitle: _create
          ? tr('Admins have full control over every bucket on this server.')
          : tr('Signs “{u}” out of every active session.', {'u': widget.username}),
      icon: _create ? LucideIcons.userPlus : LucideIcons.keyRound,
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_create) ...[
            TextField(
              controller: _user,
              autofocus: true,
              decoration: InputDecoration(
                  labelText: tr('Username'), errorText: _userError),
            ),
            const SizedBox(height: 10),
          ],
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _generate,
            onChanged: (v) => setState(() => _generate = v),
            title: Text(tr('Generate a strong password')),
          ),
          if (!_generate)
            TextField(
              controller: _pw,
              autofocus: !_create,
              obscureText: _obscure,
              decoration: InputDecoration(
                labelText: tr('Password'),
                helperText: tr('8+ characters, max 72 bytes'),
                errorText: _pwError,
                suffixIcon: IconButton(
                  icon: Icon(_obscure ? LucideIcons.eye : LucideIcons.eyeOff,
                      size: 16),
                  onPressed: () => setState(() => _obscure = !_obscure),
                ),
              ),
              onSubmitted: (_) => _submit(),
            ),
          if (_serverError != null) ...[
            const SizedBox(height: 12),
            Callout(_serverError!, tone: Tone.danger),
          ],
        ],
      ),
      actions: [
        OutlinedButton(
            onPressed: () => Navigator.pop(context),
            child: Text(tr('Cancel'))),
        FilledButton(
          onPressed: _busy ? null : _submit,
          child: _busy
              ? const ButtonSpinner()
              : Text(_create ? 'Add admin' : 'Reset password'),
        ),
      ],
    );
  }
}

/// Shows a password returned by the server once.
Future<void> showPasswordResult(BuildContext context, PasswordResult r) =>
    showDialog(
      context: context,
      builder: (ctx) => AppDialog(
        title: r.generated ? 'Password generated' : 'Password set',
        icon: LucideIcons.circleCheck,
        iconTone: Tone.success,
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (r.generated) ...[
              Callout(
                  tr('Copy this password now. It will not be shown again.')),
              const SizedBox(height: 16),
            ],
            CopyValue(label: tr('Username'), value: r.username),
            const SizedBox(height: 14),
            CopyValue(label: tr('Password'), value: r.password, secret: !r.generated),
          ],
        ),
        actions: [
          FilledButton(
              onPressed: () => Navigator.pop(ctx), child: Text(tr('Done'))),
        ],
      ),
    );
