import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';
import '../../providers/bucket_provider.dart';

class AddWebhookDialog extends StatefulWidget {
  final String bucketName;
  const AddWebhookDialog({super.key, required this.bucketName});

  @override
  State<AddWebhookDialog> createState() => _AddWebhookDialogState();
}

class _AddWebhookDialogState extends State<AddWebhookDialog> {
  final _nameController = TextEditingController();
  final _urlController = TextEditingController();
  final _eventsController = TextEditingController(text: '*');
  final _secretController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _urlController.dispose();
    _eventsController.dispose();
    _secretController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final url = _urlController.text.trim();
    if (url.isEmpty) return;

    setState(() => _isLoading = true);
    final success = await context.read<BucketProvider>().addWebhook(
          widget.bucketName,
          _nameController.text.trim(),
          url,
          events: _eventsController.text.trim(),
          secret: _secretController.text.trim());
    if (mounted) {
      if (success) {
        Navigator.pop(context);
      } else {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add Webhook'),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Name (optional)',
                hintText: 'e.g. Slack Notification',
              ),
              autofocus: true,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _urlController,
              decoration: const InputDecoration(
                labelText: 'URL',
                hintText: 'https://example.com/hook',
              ),
              keyboardType: TextInputType.url,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _eventsController,
              decoration: const InputDecoration(
                labelText: 'Events',
                hintText: '* (all)',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _secretController,
              decoration: const InputDecoration(
                labelText: 'Secret (optional)',
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
