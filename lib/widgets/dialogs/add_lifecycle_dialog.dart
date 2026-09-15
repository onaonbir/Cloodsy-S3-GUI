import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';
import '../../providers/bucket_provider.dart';

class AddLifecycleDialog extends StatefulWidget {
  final String bucketName;
  const AddLifecycleDialog({super.key, required this.bucketName});

  @override
  State<AddLifecycleDialog> createState() => _AddLifecycleDialogState();
}

class _AddLifecycleDialogState extends State<AddLifecycleDialog> {
  final _nameController = TextEditingController();
  final _prefixController = TextEditingController();
  final _daysController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _prefixController.dispose();
    _daysController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final days = int.tryParse(_daysController.text);
    if (days == null || days <= 0) return;

    setState(() => _isLoading = true);
    final bp = context.read<BucketProvider>();
    final success = await bp.addLifecycleRule(
          widget.bucketName,
          _nameController.text.trim(),
          _prefixController.text.trim(),
          days);
    if (mounted) {
      if (success) {
        Navigator.pop(context);
      } else {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(bp.error ?? 'Failed to add rule')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add Lifecycle Rule'),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Name (optional)',
                hintText: 'e.g. Log Cleanup',
              ),
              autofocus: true,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _daysController,
              decoration: const InputDecoration(
                labelText: 'Expiration Days',
                hintText: '30',
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _prefixController,
              decoration: const InputDecoration(
                labelText: 'Prefix (optional)',
                hintText: 'logs/',
              ),
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
          onPressed: _isLoading ? null : _save,
          child: const Text('Add'),
        ),
      ],
    );
  }
}
