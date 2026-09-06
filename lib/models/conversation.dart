/// Represents a past multi-assistant chat session shown in the sidebar.
class ConversationSummary {
  const ConversationSummary({
    required this.id,
    required this.title,
    required this.preview,
    required this.timestamp,
  });

  final String id;
  final String title;
  final String preview;
  final DateTime timestamp;
}

/// Placeholder history. Wire this up to real persistence later.
final List<ConversationSummary> kMockConversations = [
  ConversationSummary(
    id: 'c1',
    title: 'Refactoring the auth flow',
    preview: 'Compared how Claude and GPT would structure the login form…',
    timestamp: DateTime.now().subtract(const Duration(hours: 2)),
  ),
  ConversationSummary(
    id: 'c2',
    title: 'Trip to Lisbon',
    preview: 'Asked all four assistants for a 3-day itinerary…',
    timestamp: DateTime.now().subtract(const Duration(hours: 6)),
  ),
  ConversationSummary(
    id: 'c3',
    title: 'Explaining quantum entanglement',
    preview: 'Wanted an ELI5 comparison across models…',
    timestamp: DateTime.now().subtract(const Duration(days: 1, hours: 3)),
  ),
  ConversationSummary(
    id: 'c4',
    title: 'Naming a startup',
    preview: 'Brainstormed names for a fintech app…',
    timestamp: DateTime.now().subtract(const Duration(days: 3)),
  ),
  ConversationSummary(
    id: 'c5',
    title: 'Debugging a CORS error',
    preview: 'Pasted a stack trace and asked for root cause…',
    timestamp: DateTime.now().subtract(const Duration(days: 9)),
  ),
];