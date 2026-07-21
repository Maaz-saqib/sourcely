/// Space Screen for Sourcely.
/// Shows sources and chat for a knowledge space.
library;

import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../../config/theme.dart';
import '../../providers/spaces_provider.dart';
import '../../providers/chat_provider.dart';
import '../../widgets/source_card.dart';
import '../../widgets/loading_shimmer.dart';
import '../chat/chat_screen.dart';
import 'add_source_dialog.dart';

class SpaceScreen extends StatefulWidget {
  final String spaceId;
  final String spaceName;

  const SpaceScreen({
    super.key,
    required this.spaceId,
    required this.spaceName,
  });

  @override
  State<SpaceScreen> createState() => _SpaceScreenState();
}

class _SpaceScreenState extends State<SpaceScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  Timer? _pollingTimer;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SpacesProvider>().loadSpaceDetail(widget.spaceId);
      context.read<ChatProvider>().loadChatHistory(widget.spaceId);
      _startPolling();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _pollingTimer?.cancel();
    super.dispose();
  }

  void _startPolling() {
    _pollingTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      final provider = context.read<SpacesProvider>();
      for (final source in provider.currentSources) {
        if (source.isProcessing) {
          provider.refreshSourceStatus(source.id);
        }
      }
    });
  }

  void _showAddSourceDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const AddSourceDialog(),
    );
  }

  Future<void> _handleFileUpload() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        withData: true,
        allowMultiple: true,
      );

      if (result != null && result.files.isNotEmpty) {
        for (final file in result.files) {
          if (file.bytes != null && mounted) {
            String mimeType = 'application/octet-stream';
            if (file.extension == 'pdf') {
              mimeType = 'application/pdf';
            } else if (file.extension == 'docx' || file.extension == 'doc') {
              mimeType = 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
            }

            await context.read<SpacesProvider>().uploadFileSource(
                  fileName: file.name,
                  fileBytes: file.bytes!,
                  mimeType: mimeType,
                );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to upload file: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.spaceName),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              context.read<SpacesProvider>().loadSpaceDetail(widget.spaceId);
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: SourcelyColors.primary,
          labelColor: SourcelyColors.primary,
          unselectedLabelColor: SourcelyColors.textMuted,
          dividerColor: SourcelyColors.glassBorder,
          tabs: const [
            Tab(icon: Icon(Icons.source, size: 20), text: 'Sources'),
            Tab(icon: Icon(Icons.chat_bubble_outline, size: 20), text: 'Chat'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Sources tab
          _SourcesTab(
            onAddSource: _showAddSourceDialog,
            onUploadFile: _handleFileUpload,
          ),
          // Chat tab
          ChatScreen(spaceId: widget.spaceId),
        ],
      ),
    );
  }
}

class _SourcesTab extends StatelessWidget {
  final VoidCallback onAddSource;
  final VoidCallback onUploadFile;

  const _SourcesTab({
    required this.onAddSource,
    required this.onUploadFile,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<SpacesProvider>(
      builder: (context, provider, _) {
        if (provider.isLoading && provider.currentSources.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(20),
            child: LoadingShimmer(),
          );
        }

        return Column(
          children: [
            // Add source buttons
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: SourcelyColors.primaryGradient,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ElevatedButton.icon(
                        onPressed: onUploadFile,
                        icon: const Icon(Icons.upload_file, color: Colors.white, size: 20),
                        label: const Text('Upload File',
                            style: TextStyle(color: Colors.white)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onAddSource,
                      icon: const Icon(Icons.link, size: 20),
                      label: const Text('Add Link'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ],
              ),
            ).animate().fadeIn(duration: 300.ms),

            // Sources list
            Expanded(
              child: provider.currentSources.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.cloud_upload_outlined,
                            size: 48,
                            color: SourcelyColors.textMuted,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'No sources yet',
                            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                  color: SourcelyColors.textMuted,
                                ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Upload any file, or add YouTube/web links',
                            style: Theme.of(context).textTheme.bodyMedium,
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ).animate().fadeIn(duration: 500.ms),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: provider.currentSources.length,
                      itemBuilder: (context, index) {
                        return SourceCard(
                          source: provider.currentSources[index],
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }
}
