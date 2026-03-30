import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';
import '../../providers/bucket_provider.dart';

class SetStorageDialog extends StatefulWidget {
  final String bucketName;
  const SetStorageDialog({super.key, required this.bucketName});

  @override
  State<SetStorageDialog> createState() => _SetStorageDialogState();
}

class _SetStorageDialogState extends State<SetStorageDialog> {
  final _controller = TextEditingController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _controller.text =
        context.read<BucketProvider>().selectedBucket?.storageDir ?? '';
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _isLoading = true);
    final bp = context.read<BucketProvider>();
    final success =
        await bp.setStorage(widget.bucketName, _controller.text.trim());
    if (mounted) {
      if (success) {
        Navigator.pop(context);
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
      title: const Text('Storage Directory'),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Leave empty to use default storage directory.',
                style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 12),
            TextField(
              controller: _controller,
              decoration: const InputDecoration(
                labelText: 'Absolute Path',
                hintText: '/mnt/ssd or D:\\data',
              ),
              autofocus: true,
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
          child: const Text('Save'),
        ),
      ],
    );
  }
}
