class Conversation {
  final String id;
  final String knowledgeSpaceId;
  final String name;
  final String createdAt;
  final String updatedAt;

  Conversation({
    required this.id,
    required this.knowledgeSpaceId,
    required this.name,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Conversation.fromJson(Map<String, dynamic> json) {
    return Conversation(
      id: json['id'] as String,
      knowledgeSpaceId: json['knowledge_space_id'] as String,
      name: json['name'] as String,
      createdAt: json['created_at'] as String,
      updatedAt: json['updated_at'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'knowledge_space_id': knowledgeSpaceId,
      'name': name,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }
}
