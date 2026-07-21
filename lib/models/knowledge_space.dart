/// Knowledge Space model for Sourcely.
library;

class KnowledgeSpace {
  final String id;
  final String userId;
  final String name;
  final String emoji;
  final String createdAt;
  final String updatedAt;
  final int sourceCount;

  KnowledgeSpace({
    required this.id,
    required this.userId,
    required this.name,
    this.emoji = '📚',
    required this.createdAt,
    this.updatedAt = '',
    this.sourceCount = 0,
  });

  factory KnowledgeSpace.fromJson(Map<String, dynamic> json) {
    return KnowledgeSpace(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      name: json['name'] as String,
      emoji: json['emoji'] as String? ?? '📚',
      createdAt: json['created_at'] as String,
      updatedAt: json['updated_at'] as String? ?? json['created_at'] as String,
      sourceCount: json['source_count'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'name': name,
      'emoji': emoji,
      'created_at': createdAt,
      'updated_at': updatedAt,
      'source_count': sourceCount,
    };
  }

  KnowledgeSpace copyWith({
    String? id,
    String? userId,
    String? name,
    String? emoji,
    String? createdAt,
    String? updatedAt,
    int? sourceCount,
  }) {
    return KnowledgeSpace(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      emoji: emoji ?? this.emoji,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      sourceCount: sourceCount ?? this.sourceCount,
    );
  }
}
