import '../models/assistant.dart';

/// Thrown when a provider call fails, with a message safe to show in the UI.
class AssistantApiException implements Exception {
  const AssistantApiException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Common interface every provider client implements.
abstract class AssistantApiService {
  const AssistantApiService();

  /// Sends [prompt] with the prior [history] (oldest first, excluding the
  /// currently-loading placeholder) and returns the assistant's reply text.
  Future<String> sendMessage({
    required String prompt,
    required List<ChatMessage> history,
  });
}