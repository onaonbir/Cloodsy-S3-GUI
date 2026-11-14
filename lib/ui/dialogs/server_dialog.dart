import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../models/server_connection.dart';
import '../../state/servers_controller.dart';
import '../widgets/common.dart';
import '../../core/i18n.dart';

/// Validates an Admin API base URL; returns an error text or null.
String? validateServerUrl(String? v) {
  final s = v?.trim() ?? '';
  if (s.isEmpty) return 'URL required';
  final uri = Uri.tryParse(s);
  if (uri == null || !uri.hasScheme) {
    return 'Include the scheme, e.g. https://host:9001';
  }
  if (uri.scheme != 'http' && uri.scheme != 'https') {
    return 'Only http:// and https:// are supported';
  }
  if (uri.host.isEmpty) return 'Host missing';
  return null;
}

/// Adds or edits a saved server. Returns the saved connection.
Future<ServerConnection?> showServerDialog(BuildContext context,
        {ServerConnection? existing}) =>
    showDialog<ServerConnection>(
        context: context, builder: (_) => ServerDialog(existing: existing));

class ServerDialog extends StatefulWidget {
  final ServerConnection? existing;
  const ServerDialog({super.key, this.existing});

  @override
  State<ServerDialog> createState() => _ServerDialogState();
}

class _ServerDialogState extends State<ServerDialog> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.existing?.name ?? '');
  late final _url = TextEditingController(text: widget.existing?.url ?? '');
  late final _user =
      TextEditingController(text: widget.existing?.username ?? 'admin');
  final _password = TextEditingController();
  late final _s3 = TextEditingController(text: widget.existing?.s3Url ?? '');
  bool _obscure = true;
  bool _saving = false;

  bool get _isEdit => widget.existing != null;

  @override
  void dispose() {
    _name.dispose();
    _url.dispose();
    _user.dispose();
    _password.dispose();
    _s3.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _saving = true);
    final servers = context.read<ServersController>();
    var url = _url.text.trim();
    while (url.endsWith('/')) {
      url = url.substring(0, url.length - 1);
    }
    final name = _name.text.trim().isEmpty
        ? (Uri.tryParse(url)?.host ?? url)
        : _name.text.trim();
    final ServerConnection saved;
    var s3 = _s3.text.trim();
    while (s3.endsWith('/')) {
      s3 = s3.substring(0, s3.length - 1);
    }
    if (_isEdit) {
      saved = widget.existing!.copyWith(
          name: name, url: url, username: _user.text.trim(), s3Url: s3);
      await servers.update(saved,
          password: _password.text.isEmpty ? null : _password.text);
    } else {
      saved = ServerConnection(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        name: name,
        url: url,
        username: _user.text.trim(),
        s3Url: s3,
      );
      await servers.add(saved, _password.text);
    }
    if (mounted) Navigator.pop(context, saved);
  }

  @override
  Widget build(BuildContext context) {
    return AppDialog(
      title: _isEdit ? 'Edit server' : 'Add server',
      subtitle: tr('Connect to a Cloodsy S3 Admin API endpoint.'),
      icon: LucideIcons.server,
      content: Form(
        key: _form,
        child: Column(
          children: [
            TextFormField(
              controller: _url,
              autofocus: !_isEdit,
              keyboardType: TextInputType.url,
              decoration: InputDecoration(
                labelText: tr('Admin API URL'),
                hintText: tr('https://storage.example.com:9001'),
                helperText: tr('Use https:// when admin TLS is enabled'),
              ),
              validator: validateServerUrl,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _name,
              decoration: InputDecoration(
                labelText: tr('Display name'),
                hintText: tr('Production (defaults to the host)'),
              ),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _user,
              decoration: InputDecoration(labelText: tr('Username')),
              validator: (v) =>
                  (v ?? '').trim().isEmpty ? 'Username required' : null,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _password,
              obscureText: _obscure,
              decoration: InputDecoration(
                labelText: tr('Password'),
                hintText: _isEdit ? 'Leave empty to keep the saved one' : null,
                suffixIcon: IconButton(
                  icon: Icon(_obscure ? LucideIcons.eye : LucideIcons.eyeOff,
                      size: 16),
                  onPressed: () => setState(() => _obscure = !_obscure),
                ),
              ),
              validator: (v) =>
                  !_isEdit && (v ?? '').isEmpty ? 'Password required' : null,
              onFieldSubmitted: (_) => _save(),
            ),
            const SizedBox(height: 14),
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              childrenPadding: const EdgeInsets.only(bottom: 4),
              title: Text(tr('Advanced'),
                  style: Theme.of(context).textTheme.labelLarge),
              initiallyExpanded: _s3.text.isNotEmpty,
              children: [
                TextFormField(
                  controller: _s3,
                  keyboardType: TextInputType.url,
                  decoration: InputDecoration(
                    labelText: tr('Public S3 endpoint (optional)'),
                    hintText: tr('https://s3.example.com'),
                    helperText:
                        tr('Used for share links. Default: admin host + S3 port'),
                  ),
                  validator: (v) => (v ?? '').trim().isEmpty
                      ? null
                      : validateServerUrl(v),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(LucideIcons.lock, size: 13),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    tr('The password is stored in the system keychain.'),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        OutlinedButton(
            onPressed: () => Navigator.pop(context),
            child: Text(tr('Cancel'))),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const ButtonSpinner()
              : Text(_isEdit ? 'Save' : 'Add server'),
        ),
      ],
    );
  }
}
