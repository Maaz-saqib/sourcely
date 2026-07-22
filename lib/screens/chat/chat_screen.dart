/// Chat Screen for Sourcely.
/// Full chat interface with the AI agent, citations, and tool indicators.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../../config/theme.dart';
import '../../providers/chat_provider.dart';
import '../../providers/spaces_provider.dart';
import '../../models/source.dart';
import '../../widgets/chat_bubble.dart';
import '../../widgets/loading_shimmer.dart';

class ChatScreen extends StatefulWidget {
  final String spaceId;

  const ChatScreen({super.key, required this.spaceId});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  late final FocusNode _focusNode;

  String? _mentionQuery;
  final Set<Source> _activeMentions = {};

  @override
  void initState() {
    super.initState();
    _messageController.addListener(_onTextChanged);
    _focusNode = FocusNode(
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.enter) {
          if (!HardwareKeyboard.instance.isShiftPressed) {
            _sendMessage();
            return KeyEventResult.handled;
          }
        }
        return KeyEventResult.ignored;
      },
    );
  }

  void _onTextChanged() {
    final text = _messageController.text;
    final cursorPosition = _messageController.selection.baseOffset;
    
    if (cursorPosition >= 0 && cursorPosition <= text.length) {
      final textBeforeCursor = text.substring(0, cursorPosition);
      final words = textBeforeCursor.split(RegExp(r'\s+'));
      if (words.isNotEmpty) {
        final lastWord = words.last;
        if (lastWord.startsWith('@')) {
          setState(() {
            _mentionQuery = lastWord.substring(1).toLowerCase();
          });
          return;
        }
      }
    }
    
    if (_mentionQuery != null) {
      setState(() {
        _mentionQuery = null;
      });
    }
  }

  void _onSourceMentioned(Source source) {
    final text = _messageController.text;
    final cursorPosition = _messageController.selection.baseOffset;
    final textBeforeCursor = text.substring(0, cursorPosition);
    final words = textBeforeCursor.split(RegExp(r'\s+'));
    final lastWord = words.last;

    final startIdx = cursorPosition - lastWord.length;
    final formattedName = source.displayName.replaceAll(" ", "_");
    final newText = text.replaceRange(startIdx, cursorPosition, '@$formattedName ');
    
    _messageController.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: startIdx + ('@$formattedName ').length),
    );
    
    _activeMentions.add(source);
    setState(() {
      _mentionQuery = null;
    });
    _focusNode.requestFocus();
  }

  @override
  void dispose() {
    _messageController.removeListener(_onTextChanged);
    _messageController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    final mentionedSourceIds = _activeMentions
        .where((s) => text.contains('@${s.displayName.replaceAll(" ", "_")}'))
        .map((s) => s.id)
        .toList();

    _messageController.clear();
    _activeMentions.clear();
    _focusNode.requestFocus();
    _scrollToBottom();

    final success = await context.read<ChatProvider>().sendMessage(
      text,
      mentionedSourceIds: mentionedSourceIds.isNotEmpty ? mentionedSourceIds : null,
    );
    if (success) {
      _scrollToBottom();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Conversation Selector
        Consumer<ChatProvider>(
          builder: (context, provider, _) {
            if (provider.conversations.isEmpty) return const SizedBox.shrink();
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: Theme.of(context).dividerColor)),
                color: Theme.of(context).colorScheme.surface,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: provider.currentConversation?.id,
                        isExpanded: true,
                        icon: const Icon(Icons.arrow_drop_down),
                        items: provider.conversations.map((convo) {
                          return DropdownMenuItem(
                            value: convo.id,
                            child: Text(
                              convo.name,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.titleSmall,
                            ),
                          );
                        }).toList(),
                        onChanged: (id) {
                          if (id != null) {
                            final convo = provider.conversations.firstWhere((c) => c.id == id);
                            provider.loadConversation(convo);
                          }
                        },
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.add_circle_outline, color: SourcelyColors.primary),
                    onPressed: () => provider.createNewConversation(),
                    tooltip: 'New Conversation',
                  ),
                  if (provider.currentConversation != null)
                    PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert, color: SourcelyColors.textLightMuted),
                      onSelected: (value) async {
                        final convo = provider.currentConversation!;
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
                ],
              ),
            );
          },
        ),

        // Messages list
        Expanded(
          child: Consumer<ChatProvider>(
            builder: (context, provider, _) {
              if (provider.isLoading) {
                return const Center(
                  child: CircularProgressIndicator(
                    color: SourcelyColors.primary,
                  ),
                );
              }

              if (provider.messages.isEmpty) {
                return _EmptyChatState();
              }

              return ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.symmetric(vertical: 16),
                itemCount: provider.messages.length +
                    (provider.isSending ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index == provider.messages.length && provider.isSending) {
                    return const TypingIndicator();
                  }
                  return ChatBubble(
                    message: provider.messages[index],
                    animate: index >= provider.messages.length - 2,
                  );
                },
              );
            },
          ),
        ),

        // Error message
        Consumer<ChatProvider>(
          builder: (context, provider, _) {
            if (provider.errorMessage != null) {
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: SourcelyColors.error.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border:
                      Border.all(color: SourcelyColors.error.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline,
                        color: SourcelyColors.error, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        provider.errorMessage!,
                        style: const TextStyle(
                          color: SourcelyColors.error,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 16),
                      onPressed: provider.clearError,
                      color: SourcelyColors.error,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              );
            }
            return const SizedBox.shrink();
          },
        ),

        // Mention Overlay List
        if (_mentionQuery != null)
          Consumer<SpacesProvider>(
            builder: (context, spacesProvider, _) {
              final sources = spacesProvider.currentSources;
              final filteredSources = sources.where((s) {
                final name = s.displayName.toLowerCase();
                return name.contains(_mentionQuery!);
              }).toList();

              if (filteredSources.isEmpty) return const SizedBox.shrink();

              return Container(
                constraints: const BoxConstraints(maxHeight: 200),
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 10,
                      offset: const Offset(0, -4),
                    ),
                  ],
                  border: Border.all(color: Theme.of(context).dividerColor),
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: filteredSources.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final source = filteredSources[index];
                    return ListTile(
                      dense: true,
                      leading: Text(source.typeIcon, style: const TextStyle(fontSize: 18)),
                      title: Text(
                        source.displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
                      ),
                      onTap: () => _onSourceMentioned(source),
                    );
                  },
                ),
              ).animate().slideY(begin: 0.2, duration: 200.ms).fadeIn();
            },
          ),

        // Input bar
        _ChatInputBar(
          controller: _messageController,
          focusNode: _focusNode,
          onSend: _sendMessage,
        ),
      ],
    );
  }
}

class _ChatInputBar extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final VoidCallback onSend;

  const _ChatInputBar({
    required this.controller,
    required this.focusNode,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        left: 16,
        right: 8,
        top: 12,
        bottom: MediaQuery.of(context).padding.bottom + 12,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          top: BorderSide(color: Theme.of(context).dividerColor),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              maxLines: 4,
              minLines: 1,
              decoration: InputDecoration(
                hintText: 'Ask about your sources...',
                filled: true,
                fillColor: SourcelyColors.surfaceLight,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: const BorderSide(color: SourcelyColors.borderLight),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: const BorderSide(color: SourcelyColors.borderLight),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide:
                      const BorderSide(color: SourcelyColors.primary, width: 1.5),
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
              style: Theme.of(context).textTheme.bodyLarge,
              onSubmitted: (_) => onSend(),
            ),
          ),
          const SizedBox(width: 8),
          Consumer<ChatProvider>(
            builder: (context, provider, _) {
              return Container(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [SourcelyColors.primary, SourcelyColors.primary]),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: SourcelyColors.primary.withValues(alpha: 0.3),
                      blurRadius: 8,
                    ),
                  ],
                ),
                child: IconButton(
                  icon: provider.isSending
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.send, color: Colors.white, size: 20),
                  onPressed: provider.isSending ? null : onSend,
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _EmptyChatState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [SourcelyColors.primary, SourcelyColors.primary]),
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: SourcelyColors.primary.withValues(alpha: 0.3),
                    blurRadius: 20,
                  ),
                ],
              ),
              child: const Icon(
                Icons.auto_awesome,
                size: 36,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Chat with your Sources',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Ask questions about your uploaded documents.\nI\'ll search your knowledge base and cite my sources.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 24),

            // Suggestion chips
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: [
                _SuggestionChip(text: '📝 Summarize the key points'),
                _SuggestionChip(text: '🔍 What does it say about...'),
                _SuggestionChip(text: '📊 Compare the sources'),
              ],
            ),
          ],
        ).animate().fadeIn(duration: 500.ms),
      ),
    );
  }
}

class _SuggestionChip extends StatelessWidget {
  final String text;

  const _SuggestionChip({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: SourcelyColors.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: SourcelyColors.primary.withValues(alpha: 0.2),
        ),
      ),
      child: Text(
        text,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: SourcelyColors.secondary,
            ),
      ),
    );
  }
}
