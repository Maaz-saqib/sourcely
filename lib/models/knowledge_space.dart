/// Knowledge Space model for Sourcely.
library;

class KnowledgeSpace {
  final String id;
  final String userId;
  final String name;
  final String createdAt;
  final int sourceCount;

  KnowledgeSpace({
    required this.id,
    required this.userId,
    required this.name,
    required this.createdAt,
    this.sourceCount = 0,
  });

  factory KnowledgeSpace.fromJson(Map<String, dynamic> json) {
    return KnowledgeSpace(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      name: json['name'] as String,
      createdAt: json['created_at'] as String,
      sourceCount: json['source_count'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'name': name,
      'created_at': createdAt,
      'source_count': sourceCount,
    };
  }
}
