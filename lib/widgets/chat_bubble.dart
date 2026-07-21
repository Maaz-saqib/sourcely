/// Chat bubble widget for Sourcely.
/// Displays user and assistant message bubbles with citations.
library;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config/theme.dart';
import '../models/message.dart';
import '../providers/chat_provider.dart';
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
                gradient: const LinearGradient(colors: [SourcelyColors.primary, SourcelyColors.primary]),
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
                      : SourcelyColors.borderLight,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Message text
                  SelectableText(
                    message.content,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: SourcelyColors.textLightPrimary,
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
                    const Divider(color: SourcelyColors.borderLight, height: 1),
                    const SizedBox(height: 8),
                    Text(
                      'Sources',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: SourcelyColors.textLightMuted,
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
                  // Export button
                  if (!isUser) ...[
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        icon: const Icon(Icons.picture_as_pdf, size: 16),
                        label: const Text('Export PDF', style: TextStyle(fontSize: 12)),
                        onPressed: () async {
                          final url = await context.read<ChatProvider>().exportConversation(message.id);
                          if (url != null) {
                            final uri = Uri.parse(url);
                            if (await canLaunchUrl(uri)) {
                              await launchUrl(uri);
                            }
                          }
                        },
                      ),
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
                border: Border.all(color: SourcelyColors.borderLight),
              ),
              child: const Center(
                child: Icon(Icons.person, size: 18, color: SourcelyColors.textLightSecondary),
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
