/// Add Source Dialog for Sourcely.
/// Bottom sheet dialog for adding URL or YouTube sources.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/theme.dart';
import '../../providers/spaces_provider.dart';

class AddSourceDialog extends StatefulWidget {
  const AddSourceDialog({super.key});

  @override
  State<AddSourceDialog> createState() => _AddSourceDialogState();
}

class _AddSourceDialogState extends State<AddSourceDialog> {
  final _urlController = TextEditingController();
  final _nameController = TextEditingController();
  final String _sourceType = 'url';
  bool _isLoading = false;

  @override
  void dispose() {
    _urlController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  bool _isYouTubeUrl(String url) {
    return url.contains('youtube.com') ||
        url.contains('youtu.be') ||
        url.contains('youtube.com/watch');
  }

  Future<void> _handleSubmit() async {
    if (_urlController.text.trim().isEmpty) return;

    setState(() => _isLoading = true);

    final url = _urlController.text.trim();
    final type = _isYouTubeUrl(url) ? 'youtube' : _sourceType;

    final source = await context.read<SpacesProvider>().addLinkSource(
          sourceType: type,
          sourceUrl: url,
          originalName:
              _nameController.text.trim().isNotEmpty ? _nameController.text.trim() : null,
        );

    if (mounted) {
      setState(() => _isLoading = false);
      if (source != null) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Source added! Ingestion started...'),
            backgroundColor: SourcelyColors.success,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle bar
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: SourcelyColors.textLightMuted,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Title
          Text(
            'Add Source Link',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 4),
          Text(
            'Paste a YouTube video or website URL',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 20),

          // URL input
          TextField(
            controller: _urlController,
            autofocus: true,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              hintText: 'https://example.com/article or YouTube link',
              prefixIcon: Icon(
                Icons.link,
                color: SourcelyColors.textLightMuted,
              ),
            ),
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 12),

          // Optional name
          TextField(
            controller: _nameController,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) {
              if (!_isLoading) _handleSubmit();
            },
            decoration: const InputDecoration(
              hintText: 'Display name (optional)',
              prefixIcon: Icon(Icons.label_outline, color: SourcelyColors.textLightMuted),
            ),
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 24),

          // Submit button
          SizedBox(
            width: double.infinity,
            height: 50,
            child: Container(
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [SourcelyColors.primary, SourcelyColors.primary]),
                borderRadius: BorderRadius.circular(12),
              ),
              child: ElevatedButton(
                onPressed: _isLoading ? null : _handleSubmit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isLoading
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        'Add Source',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

