/// Citation chip widget for Sourcely.
/// Expandable citation tag showing source references.
library;

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config/theme.dart';
import '../models/message.dart';

class CitationChip extends StatefulWidget {
  final Citation citation;

  const CitationChip({super.key, required this.citation});

  @override
  State<CitationChip> createState() => _CitationChipState();
}

class _CitationChipState extends State<CitationChip> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final isWeb = widget.citation.type == 'web';

    return GestureDetector(
      onTap: () => setState(() => _isExpanded = !_isExpanded),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isWeb
              ? SourcelyColors.accent.withValues(alpha: 0.1)
              : SourcelyColors.primary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isWeb
                ? SourcelyColors.accent.withValues(alpha: 0.3)
                : SourcelyColors.primary.withValues(alpha: 0.3),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isWeb ? Icons.language : Icons.description,
                  size: 12,
                  color: isWeb ? SourcelyColors.accent : SourcelyColors.primaryLight,
                ),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    widget.citation.displayLabel,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: isWeb
                          ? SourcelyColors.accent
                          : SourcelyColors.primaryLight,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  _isExpanded ? Icons.expand_less : Icons.expand_more,
                  size: 14,
                  color: SourcelyColors.textMuted,
                ),
              ],
            ),

            // Expanded content
            if (_isExpanded) ...[
              const SizedBox(height: 6),
              if (widget.citation.snippet != null)
                Text(
                  widget.citation.snippet!,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: SourcelyColors.textSecondary,
                        height: 1.4,
                      ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              if (isWeb && widget.citation.url != null) ...[
                const SizedBox(height: 4),
                GestureDetector(
                  onTap: () async {
                    final uri = Uri.parse(widget.citation.url!);
                    if (await canLaunchUrl(uri)) {
                      await launchUrl(uri, mode: LaunchMode.externalApplication);
                    }
                  },
                  child: Text(
                    widget.citation.url!,
                    style: TextStyle(
                      fontSize: 10,
                      color: SourcelyColors.accent,
                      decoration: TextDecoration.underline,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}
