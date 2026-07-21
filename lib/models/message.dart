/// Message model for Sourcely chat.
/// Represents chat messages with citations and tool usage tracking.
library;

class Citation {
  final String? sourceId;
  final String? sourceName;
  final String? page;
  final String? timestamp;
  final String? snippet;
  final String? url;
  final String type; // 'knowledge_base' or 'web'

  Citation({
    this.sourceId,
    this.sourceName,
    this.page,
    this.timestamp,
    this.snippet,
    this.url,
    this.type = 'knowledge_base',
  });

  factory Citation.fromJson(Map<String, dynamic> json) {
    return Citation(
      sourceId: json['source_id'] as String?,
      sourceName: json['source_name'] as String?,
      page: json['page'] as String?,
      timestamp: json['timestamp'] as String?,
      snippet: json['snippet'] as String?,
      url: json['url'] as String?,
      type: json['type'] as String? ?? 'knowledge_base',
    );
  }

  /// Display label for the citation
  String get displayLabel {
    if (type == 'web') {
      return sourceName ?? url ?? 'Web Source';
    }
    final name = sourceName ?? 'Source';
    if (page != null && page != 'N/A') {
      return '$name (p.$page)';
    }
    if (timestamp != null) {
      return '$name ($timestamp)';
    }
    return name;
  }
}

class Message {
  final String id;
  final String conversationId;
  final String role;
  final String content;
  final List<Citation>? citations;
  final List<String>? toolsUsed;
  final String createdAt;

  Message({
    required this.id,
    required this.conversationId,
    required this.role,
    required this.content,
    this.citations,
    this.toolsUsed,
    required this.createdAt,
  });

  factory Message.fromJson(Map<String, dynamic> json) {
    return Message(
      id: json['id'] as String,
      conversationId: json['conversation_id'] as String,
      role: json['role'] as String,
      content: json['content'] as String,
      citations: (json['citations'] as List<dynamic>?)
          ?.map((e) => Citation.fromJson(e as Map<String, dynamic>))
          .toList(),
      toolsUsed: (json['tools_used'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList(),
      createdAt: json['created_at'] as String,
    );
  }

  bool get isUser => role == 'user';
  bool get isAssistant => role == 'assistant';
  bool get hasCitations => citations != null && citations!.isNotEmpty;

  /// Tools used display text
  String get toolsUsedDisplay {
    if (toolsUsed == null || toolsUsed!.isEmpty) return '';
    final tools = toolsUsed!
        .map((t) => t == 'knowledge_base' ? 'Knowledge Base' : 'Web Search')
        .join(' + ');
    return 'Used: $tools';
  }
}
