class ConversationSummary {
  const ConversationSummary({
    required this.id,
    required this.title,
    required this.preview,
    required this.timestamp,
    required this.assistantIds,
  });

  final String id;
  final String title;
  final String preview;
  final DateTime timestamp;
  final List<String> assistantIds;

  factory ConversationSummary.fromRow(Map<String, dynamic> row) {
    return ConversationSummary(
      id: row['id'] as String,
      title: row['title'] as String,
      preview: row['preview'] as String? ?? '',
      timestamp: DateTime.parse(row['updated_at'] as String),
      assistantIds: (row['assistant_ids'] as List<dynamic>?)?.cast<String>() ?? [],
    );
  }

  ConversationSummary copyWith({
    String? title,
    String? preview,
    DateTime? timestamp,
    List<String>? assistantIds,
  }) {
    return ConversationSummary(
      id: id,
      title: title ?? this.title,
      preview: preview ?? this.preview,
      timestamp: timestamp ?? this.timestamp,
      assistantIds: assistantIds ?? this.assistantIds,
    );
  }
}