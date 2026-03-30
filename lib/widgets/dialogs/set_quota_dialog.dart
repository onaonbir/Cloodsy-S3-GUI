import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';
import '../../providers/bucket_provider.dart';

class SetQuotaDialog extends StatefulWidget {
  final String bucketName;
  const SetQuotaDialog({super.key, required this.bucketName});

  @override
  State<SetQuotaDialog> createState() => _SetQuotaDialogState();
}

class _SetQuotaDialogState extends State<SetQuotaDialog> {
  final _controller = TextEditingController();
  String _unit = 'GB';
  bool _isLoading = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  int _toBytes() {
    final val = double.tryParse(_controller.text) ?? 0;
    switch (_unit) {
      case 'KB': return (val * 1024).toInt();
      case 'MB': return (val * 1024 * 1024).toInt();
      case 'GB': return (val * 1024 * 1024 * 1024).toInt();
      case 'TB': return (val * 1024 * 1024 * 1024 * 1024).toInt();
      default: return val.toInt();
    }
  }

  Future<void> _save() async {
    setState(() => _isLoading = true);
    await context.read<BucketProvider>().setQuota(widget.bucketName, _toBytes());
    if (mounted) Navigator.pop(context);
  }

  Future<void> _removeQuota() async {
    setState(() => _isLoading = true);
    await context.read<BucketProvider>().setQuota(widget.bucketName, 0);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Set Quota'),
      content: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              decoration: const InputDecoration(labelText: 'Size'),
              keyboardType: TextInputType.number,
              autofocus: true,
            ),
          ),
          const SizedBox(width: 12),
          DropdownButton<String>(
            value: _unit,
            items: ['KB', 'MB', 'GB', 'TB']
                .map((u) => DropdownMenuItem(value: u, child: Text(u)))
                .toList(),
            onChanged: (v) => setState(() => _unit = v!),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : _removeQuota,
          child: Text('Remove Quota',
              style: TextStyle(color: Theme.of(context).colorScheme.error)),
        ),
        const Spacer(),
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
