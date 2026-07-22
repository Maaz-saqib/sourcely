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
      context.read<ChatProvider>().loadConversations(widget.spaceId);
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
    if (context.read<SpacesProvider>().currentSources.length >= 6) {
      _showLimitReachedDialog();
      return;
    }
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const AddSourceDialog(),
    );
  }

  void _showLimitReachedDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange),
            SizedBox(width: 8),
            Text('Limit Reached'),
          ],
        ),
        content: const Text(
          'You have reached the maximum limit of 6 sources for this knowledge space.\n\n'
          'To add a new source, please delete an existing one first.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }

  void _showUnsupportedFileDialog(String ext) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange),
            SizedBox(width: 8),
            Text('Unsupported File Type'),
          ],
        ),
        content: Text(
          'The file type "${ext.isEmpty ? 'unknown' : '.$ext'}" is currently not supported.\n\n'
          'Please upload a file in one of the following formats:\n'
          '• Documents: PDF, DOCX, DOC\n'
          '• Spreadsheets: CSV, XLSX\n'
          '• Images: JPG, JPEG, PNG',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }

  void _showUploadErrorDialog(String error) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.error_outline, color: Colors.red),
            SizedBox(width: 8),
            Text('Upload Failed'),
          ],
        ),
        content: Text(
          'We encountered an issue while uploading your file:\n\n'
          '$error\n\n'
          'Please check your connection and try again.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _handleFileUpload() async {
    if (context.read<SpacesProvider>().currentSources.length >= 6) {
      _showLimitReachedDialog();
      return;
    }

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'docx', 'doc', 'csv', 'jpg', 'jpeg', 'png', 'xlsx'],
        withData: true,
        allowMultiple: true,
      );

      if (result != null && result.files.isNotEmpty) {
        for (final file in result.files) {
          if (file.bytes != null && mounted) {
            String mimeType = 'application/octet-stream';
            final ext = file.extension?.toLowerCase() ?? '';
            
            // Validate extension
            if (!['pdf', 'docx', 'doc', 'csv', 'jpg', 'jpeg', 'png', 'xlsx'].contains(ext)) {
              _showUnsupportedFileDialog(ext);
              continue;
            }

            if (ext == 'pdf') {
              mimeType = 'application/pdf';
            } else if (ext == 'docx' || ext == 'doc') {
              mimeType = 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
            } else if (ext == 'csv') {
              mimeType = 'text/csv';
            } else if (ext == 'jpg' || ext == 'jpeg') {
              mimeType = 'image/jpeg';
            } else if (ext == 'png') {
              mimeType = 'image/png';
            } else if (ext == 'xlsx') {
              mimeType = 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
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
        String errorMessage = e.toString();
        // Try to strip exception type if present, or format nicely
        if (errorMessage.startsWith('ApiException')) {
          final parts = errorMessage.split(': ');
          if (parts.length > 1) {
            errorMessage = parts.sublist(1).join(': ');
          }
        }
        _showUploadErrorDialog(errorMessage);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width > 800;

    final sourcesPanel = _SourcesTab(
      onAddSource: _showAddSourceDialog,
      onUploadFile: _handleFileUpload,
    );
    final conversationsPanel = const _ConversationsPanel();

    if (isDesktop) {
      return Scaffold(
        appBar: AppBar(
          title: Text(widget.spaceName),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () {
                context.read<SpacesProvider>().loadSpaceDetail(widget.spaceId);
                context.read<ChatProvider>().loadConversations(widget.spaceId);
              },
            ),
          ],
        ),
        body: Row(
          children: [
            SizedBox(
              width: 350,
              child: Column(
                children: [
                  Expanded(flex: 1, child: sourcesPanel),
                  const Divider(height: 1),
                  Expanded(flex: 1, child: conversationsPanel),
                ],
              ),
            ),
            const VerticalDivider(width: 1),
            Expanded(
              child: ChatScreen(spaceId: widget.spaceId),
            ),
          ],
        ),
      );
    }

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
          unselectedLabelColor: SourcelyColors.textLightMuted,
          dividerColor: SourcelyColors.borderLight,
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
            // Header with count
            Padding(
              padding: const EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Sources',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: provider.currentSources.length >= 6 
                          ? Colors.orange.withValues(alpha: 0.2) 
                          : SourcelyColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${provider.currentSources.length} / 6',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: provider.currentSources.length >= 6 
                            ? Colors.orange 
                            : SourcelyColors.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            // Add source buttons
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: [
                          provider.currentSources.length >= 6 ? Colors.grey : SourcelyColors.primary, 
                          provider.currentSources.length >= 6 ? Colors.grey : SourcelyColors.primary
                        ]),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ElevatedButton.icon(
                        onPressed: provider.currentSources.length >= 6 ? onUploadFile : onUploadFile, // Will trigger dialog
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
                            color: SourcelyColors.textLightMuted,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'No sources yet',
                            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                  color: SourcelyColors.textLightMuted,
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

class _ConversationsPanel extends StatelessWidget {
  const _ConversationsPanel();

  @override
  Widget build(BuildContext context) {
    return Consumer<ChatProvider>(
      builder: (context, provider, _) {
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Conversations',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  IconButton(
                    icon: const Icon(Icons.add, color: SourcelyColors.primary),
                    onPressed: () => provider.createNewConversation(),
                    tooltip: 'New Conversation',
                  ),
                ],
              ),
            ),
            Expanded(
              child: provider.conversations.isEmpty
                  ? Center(
                      child: Text(
                        'No conversations yet',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: SourcelyColors.textLightMuted,
                            ),
                      ),
                    )
                  : ListView.builder(
                      itemCount: provider.conversations.length,
                      itemBuilder: (context, index) {
                        final convo = provider.conversations[index];
                        final isSelected = provider.currentConversation?.id == convo.id;
                        return ListTile(
                          title: Text(
                            convo.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                          selected: isSelected,
                          selectedTileColor: SourcelyColors.primary.withValues(alpha: 0.1),
                          onTap: () => provider.loadConversation(convo),
                          trailing: PopupMenuButton<String>(
                            icon: const Icon(Icons.more_vert, size: 20),
                            onSelected: (value) async {
                              if (value == 'rename') {
                                final newName = await showDialog<String>(
                                  context: context,
                                  builder: (context) {
                                    final controller = TextEditingController(text: convo.name);
                                    return AlertDialog(
                                      title: const Text('Rename Conversation'),
                                      content: TextField(
                                        controller: controller,
                                        autofocus: true,
                                        textInputAction: TextInputAction.done,
                                        onSubmitted: (_) => Navigator.pop(context, controller.text.trim()),
                                        decoration: const InputDecoration(
                                          hintText: 'Conversation name',
                                        ),
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () => Navigator.pop(context),
                                          child: const Text('Cancel'),
                                        ),
                                        ElevatedButton(
                                          onPressed: () => Navigator.pop(context, controller.text.trim()),
                                          child: const Text('Rename'),
                                        ),
                                      ],
                                    );
                                  },
                                );
                                if (newName != null && newName.isNotEmpty && newName != convo.name) {
                                  await provider.updateConversationName(convo.id, newName);
                                }
                              } else if (value == 'delete') {
                                final confirm = await showDialog<bool>(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    title: const Text('Delete Conversation?'),
                                    content: const Text('Are you sure you want to delete this conversation? This cannot be undone.'),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(context, false),
                                        child: const Text('Cancel'),
                                      ),
                                      ElevatedButton(
                                        onPressed: () => Navigator.pop(context, true),
                                        style: ElevatedButton.styleFrom(backgroundColor: SourcelyColors.error),
                                        child: const Text('Delete', style: TextStyle(color: Colors.white)),
                                      ),
                                    ],
                                  ),
                                );
                                if (confirm == true) {
                                  await provider.deleteConversation(convo.id);
                                }
                              }
                            },
                            itemBuilder: (context) => [
                              const PopupMenuItem(
                                value: 'rename',
                                child: Row(
                                  children: [
                                    Icon(Icons.edit, size: 18),
                                    SizedBox(width: 8),
                                    Text('Rename'),
                                  ],
                                ),
                              ),
                              const PopupMenuItem(
                                value: 'delete',
                                child: Row(
                                  children: [
                                    Icon(Icons.delete, size: 18, color: SourcelyColors.error),
                                    SizedBox(width: 8),
                                    Text('Delete', style: TextStyle(color: SourcelyColors.error)),
                                  ],
                                ),
                              ),
                            ],
                          ),
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
