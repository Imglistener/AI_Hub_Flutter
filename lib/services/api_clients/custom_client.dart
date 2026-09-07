import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../models/assistant.dart';
import '../assistant_api_service.dart';


/// Talks to a user-provided endpoint, assuming an OpenAI-compatible
/// `/chat/completions`-style API — this covers most self-hosted or
/// third-party options (Ollama, LM Studio, OpenRouter, vLLM, etc.).
/// If your custom assistant uses a different request/response shape,
/// this client will need to be adjusted to match it.
class CustomApiService extends AssistantApiService {
  const CustomApiService({
    required this.endpoint,
    required this.apiKey,
    required this.model,
  });

  final String endpoint;
  final String apiKey;
  final String model;

  @override
  Future<String> sendMessage({
    required String prompt,
    required List<ChatMessage> history,
  }) async {
    final messages = [
      for (final m in history)
        {'role': m.isUser ? 'user' : 'assistant', 'content': m.text},
      {'role': 'user', 'content': prompt},
    ];

    http.Response response;
    try {
      response = await http.post(
        Uri.parse(endpoint),
        headers: {
          'content-type': 'application/json',
          if (apiKey.isNotEmpty) 'Authorization': 'Bearer $apiKey',
        },
        body: jsonEncode({'model': model, 'messages': messages}),
      );
    } catch (_) {
      throw const AssistantApiException(
          'Could not reach your custom assistant. Check the endpoint URL and your connection.');
    }

    if (response.statusCode == 401 || response.statusCode == 403) {
      throw const AssistantApiException('Your custom assistant rejected the API key.');
    }
    if (response.statusCode != 200) {
      String detail = response.body;
      try {
        final errorJson = jsonDecode(response.body) as Map<String, dynamic>;
        detail = (errorJson['error'] as Map<String, dynamic>?)?['message'] as String? ?? response.body;
      } catch (_) {
        // response wasn't JSON — fall back to raw body
      }
      throw AssistantApiException('Custom assistant error (${response.statusCode}): $detail');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final choices = data['choices'] as List<dynamic>?;
    final text = choices?.isNotEmpty == true
        ? (choices!.first['message']?['content'] as String?)
        : null;

    return text ?? '(No response text returned.)';
  }
}