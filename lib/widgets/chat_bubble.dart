/// Chat bubble widget for Sourcely.
/// Displays user and assistant message bubbles with citations.
library;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../config/theme.dart';
import '../models/message.dart';
import 'citation_chip.dart';
import 'tools_used_badge.dart';

class ChatBubble extends StatelessWidget {
  final Message message;
  final bool animate;

  const ChatBubble({
    super.key,
    required this.message,
    this.animate = true,
  });

  @override
  Widget build(BuildContext context) {
    final isUser = message.isUser;

    Widget bubble = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser) ...[
            // Assistant avatar
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                gradient: SourcelyColors.primaryGradient,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Center(
                child: Text('S', style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                )),
              ),
            ),
            const SizedBox(width: 8),
          ],

          // Message content
          Flexible(
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isUser
                    ? SourcelyColors.primary.withValues(alpha: 0.15)
                    : SourcelyColors.surfaceLight,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(isUser ? 16 : 4),
                  bottomRight: Radius.circular(isUser ? 4 : 16),
                ),
                border: Border.all(
                  color: isUser
                      ? SourcelyColors.primary.withValues(alpha: 0.3)
                      : SourcelyColors.glassBorder,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Message text
                  SelectableText(
                    message.content,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: SourcelyColors.textPrimary,
                          height: 1.5,
                        ),
                  ),

                  // Tools used badge
                  if (!isUser && message.toolsUsed != null && message.toolsUsed!.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    ToolsUsedBadge(toolsUsed: message.toolsUsed!),
                  ],

                  // Citations
                  if (message.hasCitations) ...[
                    const SizedBox(height: 10),
                    const Divider(color: SourcelyColors.glassBorder, height: 1),
                    const SizedBox(height: 8),
                    Text(
                      'Sources',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: SourcelyColors.textMuted,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: message.citations!
                          .map((c) => CitationChip(citation: c))
                          .toList(),
                    ),
                  ],
                ],
              ),
            ),
          ),

          if (isUser) ...[
            const SizedBox(width: 8),
            // User avatar
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: SourcelyColors.surfaceLight,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: SourcelyColors.glassBorder),
              ),
              child: const Center(
                child: Icon(Icons.person, size: 18, color: SourcelyColors.textSecondary),
              ),
            ),
          ],
        ],
      ),
    );

    if (animate) {
      return bubble.animate().fadeIn(duration: 300.ms).slideY(begin: 0.1, end: 0);
    }
    return bubble;
  }
}
