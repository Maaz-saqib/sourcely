/// Source Card widget for Sourcely.
/// Displays a source with status badge, summary preview, and quiz access.
library;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../config/theme.dart';
import '../models/source.dart';
import 'quiz_widget.dart';

class SourceCard extends StatefulWidget {
  final Source source;
  final VoidCallback? onTap;
  final VoidCallback? onRefresh;

  const SourceCard({
    super.key,
    required this.source,
    this.onTap,
    this.onRefresh,
  });

  @override
  State<SourceCard> createState() => _SourceCardState();
}

class _SourceCardState extends State<SourceCard> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final source = widget.source;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: glassCardDecoration(),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => setState(() => _isExpanded = !_isExpanded),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header row: icon + name + status badge
                Row(
                  children: [
                    // Source type icon
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        gradient: SourcelyColors.primaryGradient,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Center(
                        child: Text(
                          source.typeIcon,
                          style: const TextStyle(fontSize: 20),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),

                    // Name + type
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            source.displayName,
                            style: Theme.of(context).textTheme.titleMedium,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            source.type.toUpperCase(),
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: SourcelyColors.primaryLight,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 1,
                                ),
                          ),
                        ],
                      ),
                    ),

                    // Status badge
                    _StatusBadge(status: source.status),
                  ],
                ),

                // Error message (if failed)
                if (source.isFailed && source.errorMessage != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: SourcelyColors.error.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: SourcelyColors.error.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline,
                            color: SourcelyColors.error, size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            source.errorMessage!,
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: SourcelyColors.error,
                                ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                // Processing indicator
                if (source.isProcessing) ...[
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: const LinearProgressIndicator(
                      backgroundColor: SourcelyColors.surfaceLight,
                      color: SourcelyColors.processing,
                      minHeight: 3,
                    ),
                  ),
                ],

                // Expanded content: summary + quiz
                if (_isExpanded && source.isReady) ...[
                  const SizedBox(height: 16),
                  const Divider(color: SourcelyColors.glassBorder),
                  const SizedBox(height: 12),

                  // Chunk count
                  if (source.chunkCount != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        children: [
                          Icon(Icons.dataset_outlined,
                              size: 14, color: SourcelyColors.textMuted),
                          const SizedBox(width: 6),
                          Text(
                            '${source.chunkCount} chunks indexed',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),

                  // Summary
                  if (source.summary != null && source.summary!.isNotEmpty) ...[
                    Text(
                      'Summary',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            color: SourcelyColors.accent,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      source.summary!,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Quiz
                  if (source.quiz != null && source.quiz!.isNotEmpty)
                    QuizWidget(quizItems: source.quiz!),
                ],

                // Expand/collapse hint
                if (source.isReady) ...[
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        _isExpanded
                            ? Icons.keyboard_arrow_up
                            : Icons.keyboard_arrow_down,
                        size: 18,
                        color: SourcelyColors.textMuted,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _isExpanded ? 'Collapse' : 'View summary & quiz',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: SourcelyColors.textMuted,
                            ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.05, end: 0);
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;

  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    Color color;
    IconData icon;
    String label;

    switch (status) {
      case 'ready':
        color = SourcelyColors.success;
        icon = Icons.check_circle;
        label = 'Ready';
      case 'processing':
        color = SourcelyColors.processing;
        icon = Icons.hourglass_top;
        label = 'Processing';
      case 'failed':
        color = SourcelyColors.error;
        icon = Icons.error;
        label = 'Failed';
      default:
        color = SourcelyColors.textMuted;
        icon = Icons.help;
        label = status;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
