import 'api_clients/claude_client.dart';
import 'api_clients/custom_client.dart';
import 'api_clients/deepseek_client.dart';
import 'api_clients/gemini_client.dart';
import 'api_clients/grok_client.dart';
import 'api_clients/openai_client.dart';
import 'assistant_api_service.dart';
import 'api_key_service.dart';
import 'custom_assistant_service.dart';

/// Builds the right API client for a given assistant ID, fetching whatever
/// credentials it needs from secure storage. Returns null if that assistant
/// isn't connected yet.
class AssistantApiRegistry {
  AssistantApiRegistry._();

  static Future<AssistantApiService?> build(String assistantId) async {
    if (assistantId == 'custom') {
      final config = await CustomAssistantService.instance.getConfig();
      if (config == null) return null;
      return CustomApiService(
        endpoint: config.endpoint,
        apiKey: config.apiKey,
        model: config.model,
      );
    }

    final apiKey = await ApiKeyService.instance.getKey(assistantId);
    if (apiKey == null || apiKey.isEmpty) return null;

    switch (assistantId) {
      case 'claude':
        return ClaudeApiService(apiKey: apiKey);
      case 'gpt':
        return OpenAiApiService(apiKey: apiKey);
      case 'gemini':
        return GeminiApiService(apiKey: apiKey);
      case 'grok':
        return GrokApiService(apiKey: apiKey);
      case 'deepseek':
        return DeepSeekApiService(apiKey: apiKey);
      default:
        return null;
    }
  }
}