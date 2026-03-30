import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';
import '../../models/server_connection.dart';
import '../../providers/server_provider.dart';

class AddServerDialog extends StatefulWidget {
  final ServerConnection? existing;
  const AddServerDialog({super.key, this.existing});

  @override
  State<AddServerDialog> createState() => _AddServerDialogState();
}

class _AddServerDialogState extends State<AddServerDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _urlController;
  late final TextEditingController _usernameController;
  final _passwordController = TextEditingController();
  bool _obscure = true;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.existing?.name ?? '');
    _urlController = TextEditingController(text: widget.existing?.url ?? '');
    _usernameController =
        TextEditingController(text: widget.existing?.username ?? '');
    if (_isEdit) {
      _loadPassword();
    }
  }

  Future<void> _loadPassword() async {
    final sp = context.read<ServerProvider>();
    final pw = await sp.getPassword(widget.existing!.id);
    if (pw != null && mounted) {
      _passwordController.text = pw;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _urlController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final sp = context.read<ServerProvider>();
    final name = _nameController.text.trim();
    var url = _urlController.text.trim();
    if (url.endsWith('/')) url = url.substring(0, url.length - 1);
    final username = _usernameController.text.trim();
    final password = _passwordController.text;

    if (_isEdit) {
      final updated = widget.existing!.copyWith(
        name: name,
        url: url,
        username: username,
      );
      await sp.updateServer(updated, password.isNotEmpty ? password : null);
    } else {
      final id = DateTime.now().millisecondsSinceEpoch.toString();
      final server = ServerConnection(
        id: id,
        name: name,
        url: url,
        username: username,
      );
      await sp.addServer(server, password);
    }
    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_isEdit ? 'Edit Server' : 'Add Server'),
      content: SizedBox(
        width: 360,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Name',
                  hintText: 'Production',
                ),
                autofocus: true,
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Name required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _urlController,
                decoration: const InputDecoration(
                  labelText: 'Server URL',
                  hintText: 'http://192.168.1.100:9001',
                ),
                keyboardType: TextInputType.url,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'URL required';
                  final uri = Uri.tryParse(v.trim());
                  if (uri == null || !uri.hasScheme) return 'Invalid URL';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _usernameController,
                decoration: const InputDecoration(labelText: 'Username'),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Username required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _passwordController,
                decoration: InputDecoration(
                  labelText: _isEdit ? 'Password (leave empty to keep)' : 'Password',
                  suffixIcon: IconButton(
                    icon: Icon(
                        _obscure ? LucideIcons.eye : LucideIcons.eyeOff,
                        size: 18),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  ),
                ),
                obscureText: _obscure,
                validator: (v) {
                  if (!_isEdit && (v == null || v.isEmpty)) {
                    return 'Password required';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        OutlinedButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _save,
          child: Text(_isEdit ? 'Save' : 'Add'),
        ),
      ],
    );
  }
}
