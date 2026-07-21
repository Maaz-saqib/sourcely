/// Quiz widget for Sourcely.
/// Interactive quiz cards generated from source content.
library;

import 'package:flutter/material.dart';

import '../config/theme.dart';
import '../models/source.dart';

class QuizWidget extends StatelessWidget {
  final List<QuizItem> quizItems;

  const QuizWidget({super.key, required this.quizItems});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.quiz, size: 16, color: SourcelyColors.accent),
            const SizedBox(width: 6),
            Text(
              'Knowledge Check',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: SourcelyColors.accent,
                  ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        ...quizItems.asMap().entries.map(
              (entry) => _QuizCard(
                index: entry.key + 1,
                item: entry.value,
              ),
            ),
      ],
    );
  }
}

class _QuizCard extends StatefulWidget {
  final int index;
  final QuizItem item;

  const _QuizCard({required this.index, required this.item});

  @override
  State<_QuizCard> createState() => _QuizCardState();
}

class _QuizCardState extends State<_QuizCard> {
  bool _showAnswer = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: SourcelyColors.surfaceLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: SourcelyColors.glassBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  gradient: SourcelyColors.primaryGradient,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    '${widget.index}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  widget.item.question,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          GestureDetector(
            onTap: () => setState(() => _showAnswer = !_showAnswer),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: _showAnswer
                    ? SourcelyColors.success.withValues(alpha: 0.1)
                    : SourcelyColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: _showAnswer
                      ? SourcelyColors.success.withValues(alpha: 0.3)
                      : SourcelyColors.primary.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    _showAnswer ? Icons.visibility : Icons.visibility_off,
                    size: 16,
                    color: _showAnswer
                        ? SourcelyColors.success
                        : SourcelyColors.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _showAnswer ? widget.item.answer : 'Tap to reveal answer',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: _showAnswer
                                ? SourcelyColors.textPrimary
                                : SourcelyColors.primaryLight,
                          ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
