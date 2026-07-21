/// Tools Used Badge widget for Sourcely.
/// Shows which tools (Knowledge Base / Web Search) were used for an answer.
library;

import 'package:flutter/material.dart';

import '../config/theme.dart';

class ToolsUsedBadge extends StatelessWidget {
  final List<String> toolsUsed;

  const ToolsUsedBadge({super.key, required this.toolsUsed});

  @override
  Widget build(BuildContext context) {
    if (toolsUsed.isEmpty) return const SizedBox.shrink();

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.build_circle_outlined,
          size: 12,
          color: SourcelyColors.textMuted,
        ),
        const SizedBox(width: 4),
        ...toolsUsed.asMap().entries.map((entry) {
          final tool = entry.value;
          final isLast = entry.key == toolsUsed.length - 1;
          final isKb = tool == 'knowledge_base';

          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: (isKb
                          ? SourcelyColors.primary
                          : SourcelyColors.accent)
                      .withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isKb ? Icons.storage : Icons.travel_explore,
                      size: 10,
                      color: isKb
                          ? SourcelyColors.primaryLight
                          : SourcelyColors.accent,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      isKb ? 'Knowledge Base' : 'Web Search',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: isKb
                            ? SourcelyColors.primaryLight
                            : SourcelyColors.accent,
                      ),
                    ),
                  ],
                ),
              ),
              if (!isLast)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    '+',
                    style: TextStyle(
                      fontSize: 10,
                      color: SourcelyColors.textMuted,
                    ),
                  ),
                ),
            ],
          );
        }),
      ],
    );
  }
}
