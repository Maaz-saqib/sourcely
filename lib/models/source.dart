/// Source model for Sourcely.
/// Represents an ingested knowledge source (PDF, DOCX, YouTube, URL).
library;

class QuizItem {
  final String question;
  final String answer;

  QuizItem({required this.question, required this.answer});

  factory QuizItem.fromJson(Map<String, dynamic> json) {
    return QuizItem(
      question: json['question'] as String,
      answer: json['answer'] as String,
    );
  }

  Map<String, dynamic> toJson() => {'question': question, 'answer': answer};
}

class Source {
  final String id;
  final String knowledgeSpaceId;
  final String type;
  final String? originalName;
  final String? sourceUrl;
  final String status;
  final String? errorMessage;
  final int? chunkCount;
  final String? summary;
  final List<QuizItem>? quiz;
  final String createdAt;

  Source({
    required this.id,
    required this.knowledgeSpaceId,
    required this.type,
    this.originalName,
    this.sourceUrl,
    required this.status,
    this.errorMessage,
    this.chunkCount,
    this.summary,
    this.quiz,
    required this.createdAt,
  });

  factory Source.fromJson(Map<String, dynamic> json) {
    return Source(
      id: json['id'] as String,
      knowledgeSpaceId: json['knowledge_space_id'] as String,
      type: json['type'] as String,
      originalName: json['original_name'] as String?,
      sourceUrl: json['source_url'] as String?,
      status: json['status'] as String,
      errorMessage: json['error_message'] as String?,
      chunkCount: json['chunk_count'] as int?,
      summary: json['summary'] as String?,
      quiz: (json['quiz'] as List<dynamic>?)
          ?.map((e) => QuizItem.fromJson(e as Map<String, dynamic>))
          .toList(),
      createdAt: json['created_at'] as String,
    );
  }

  /// Whether this source is ready for querying
  bool get isReady => status == 'ready';

  /// Whether this source is still being processed
  bool get isProcessing => status == 'processing';

  /// Whether ingestion failed
  bool get isFailed => status == 'failed';

  /// Display name for the source
  String get displayName => originalName ?? sourceUrl ?? 'Unknown Source';

  /// Icon data based on source type
  String get typeIcon {
    switch (type) {
      case 'pdf':
        return '📄';
      case 'docx':
        return '📝';
      case 'youtube':
        return '▶️';
      case 'url':
        return '🌐';
      default:
        return '📎';
    }
  }
}
