import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';
import '../../providers/bucket_provider.dart';

class CreateBucketDialog extends StatefulWidget {
  const CreateBucketDialog({super.key});

  @override
  State<CreateBucketDialog> createState() => _CreateBucketDialogState();
}

class _CreateBucketDialogState extends State<CreateBucketDialog> {
  final _nameController = TextEditingController();
  final _storageDirController = TextEditingController();
  bool _useCustomStorage = false;
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _storageDirController.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;

    setState(() => _isLoading = true);
    final bp = context.read<BucketProvider>();
    final storageDir =
        _useCustomStorage ? _storageDirController.text.trim() : '';
    final success = await bp.createBucket(name, storageDir: storageDir);

    if (mounted) {
      if (success) {
        Navigator.pop(context, true);
      } else {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(bp.error ?? 'Failed to create bucket')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Create Bucket'),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Bucket Name',
                hintText: 'my-bucket',
              ),
              autofocus: true,
              onSubmitted: (_) => _create(),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Switch(
                  value: _useCustomStorage,
                  onChanged: (v) => setState(() => _useCustomStorage = v),
                ),
                const SizedBox(width: 8),
                Text('Custom Storage Directory',
                    style: Theme.of(context).textTheme.bodyMedium),
              ],
            ),
            if (_useCustomStorage) ...[
              const SizedBox(height: 8),
              TextField(
                controller: _storageDirController,
                decoration: const InputDecoration(
                  labelText: 'Storage Path',
                  hintText: '/mnt/ssd or D:\\data',
                ),
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
