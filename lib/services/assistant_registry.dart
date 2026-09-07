import 'api_clients/claude_client.dart';
import 'api_clients/gemini_client.dart';
import 'api_clients/grok_client.dart';
import 'api_clients/openai_client.dart';
import 'assistant_api_service.dart';

/// Builds the right API client for a given assistant ID + key.
class AssistantApiRegistry {
  AssistantApiRegistry._();

  static AssistantApiService? clientFor(String assistantId, String apiKey) {
    switch (assistantId) {
      case 'claude':
        return ClaudeApiService(apiKey: apiKey);
      case 'gpt':
        return OpenAiApiService(apiKey: apiKey);
      case 'gemini':
        return GeminiApiService(apiKey: apiKey);
      case 'grok':
        return GrokApiService(apiKey: apiKey);
      default:
        return null;
    }
  }
}