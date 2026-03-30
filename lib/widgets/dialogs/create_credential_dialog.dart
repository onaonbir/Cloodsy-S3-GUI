import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';
import '../../providers/bucket_provider.dart';

class CreateCredentialDialog extends StatefulWidget {
  final String bucketName;
  const CreateCredentialDialog({super.key, required this.bucketName});

  @override
  State<CreateCredentialDialog> createState() => _CreateCredentialDialogState();
}

class _CreateCredentialDialogState extends State<CreateCredentialDialog> {
  final _nameController = TextEditingController();
  String _permission = 'read-write';
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    setState(() => _isLoading = true);
    final bp = context.read<BucketProvider>();
    final cred = await bp.createCredential(
        widget.bucketName, _nameController.text.trim(), _permission);

    if (mounted) {
      if (cred != null) {
        Navigator.pop(context, {
          'access_key': cred.accessKey,
          'secret_key': cred.secretKey,
          'permission': cred.permission,
        });
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
      title: const Text('Create Credential'),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Bucket: ${widget.bucketName}',
                style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 16),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Name (optional)',
                hintText: 'e.g. Production API Key',
              ),
              autofocus: true,
            ),
            const SizedBox(height: 16),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'read-write', label: Text('Read-Write')),
                ButtonSegment(value: 'read-only', label: Text('Read-Only')),
              ],
              selected: {_permission},
              onSelectionChanged: (s) => setState(() => _permission = s.first),
            ),
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
